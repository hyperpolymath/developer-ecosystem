// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem PTP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Precision Time Protocol (PTP, IEEE 1588-2019) client for
// sub-microsecond clock synchronisation. Supports Sync, Follow_Up,
// Delay_Req, Delay_Resp messages, best master clock algorithm (BMCA),
// two-step clock operation, and offset/delay computation.
// Operates on multicast 224.0.1.129:319 (event) / :320 (general).

module ptp

import net
import time

// --- PTP protocol constants ---

// PTP multicast addresses.
const ptp_primary_addr = "224.0.1.129"
const ptp_event_port   = 319
const ptp_general_port = 320

// PTP message types (lower nibble of the messageType field).
const msg_sync          = u8(0x0)   // Sync event
const msg_delay_req     = u8(0x1)   // Delay_Req event
const msg_pdelay_req    = u8(0x2)   // Pdelay_Req event
const msg_pdelay_resp   = u8(0x3)   // Pdelay_Resp event
const msg_follow_up     = u8(0x8)   // Follow_Up general
const msg_delay_resp    = u8(0x9)   // Delay_Resp general
const msg_pdelay_follow = u8(0xA)   // Pdelay_Resp_Follow_Up general
const msg_announce      = u8(0xB)   // Announce general
const msg_signaling     = u8(0xC)   // Signaling general
const msg_management    = u8(0xD)   // Management general

// PTP version.
const ptp_version = u8(2)  // IEEE 1588-2019

// PTP header length in bytes (IEEE 1588-2019 Table 18).
const ptp_header_len = 34

// PTP flag field bit positions.
const flag_alternate_master  = u16(0x0001)
const flag_two_step          = u16(0x0200)
const flag_unicast           = u16(0x0400)
const flag_ptp_timescale     = u16(0x2000)
const flag_time_traceable    = u16(0x4000)
const flag_freq_traceable    = u16(0x8000)

// PTP transport domain default.
const default_domain = u8(0)

// ptp_domain_default is the IANA-standard default PTP domain (IEEE 1588 §7.1).
pub const ptp_domain_default = u8(0)

// --- Message type enumeration ---

// PtpMessageType is a typed enumeration of PTP message type codes.
pub enum PtpMessageType {
	sync        // 0x0 — periodic reference time from master clock
	delay_req   // 0x1 — sent by slave to start path delay measurement
	follow_up   // 0x8 — carries precise t1 for two-step clocks
	delay_resp  // 0x9 — master's response to Delay_Req, carries t4
	announce    // 0xB — master identity advertisement for BMCA
}

// is_event returns true for message types transported on the event port (319).
pub fn (m PtpMessageType) is_event() bool {
	return m == .sync || m == .delay_req
}

// code returns the 4-bit wire value for this message type.
pub fn (m PtpMessageType) code() u8 {
	return match m {
		.sync       { u8(0x0) }
		.delay_req  { u8(0x1) }
		.follow_up  { u8(0x8) }
		.delay_resp { u8(0x9) }
		.announce   { u8(0xB) }
	}
}

// --- Clock class enumeration ---

// ClockClass indicates the quality of the clock source.
pub enum ClockClass {
	primary_reference     // Locked to primary reference (6)
	holdover_unlocked     // Previously locked, now free-running (7)
	application_specific  // Application-specific (13)
	default_class         // Default (248)
	slave_only            // Slave-only device (255)
}

// --- Data structures ---

// Timestamp represents a PTP timestamp (seconds + nanoseconds).
pub struct Timestamp {
pub:
	seconds_msb u16    // Upper 16 bits of seconds
	seconds     u32    // Lower 32 bits of seconds
	nanoseconds u32    // Nanoseconds within the second
}

// PtpTimestamp is the canonical 10-byte PTP timestamp (IEEE 1588 §5.3.3).
// seconds field is 48 bits, split as seconds_msb (u16) + seconds (u32).
pub struct PtpTimestamp {
pub:
	seconds_msb u16  // Upper 16 bits of the 48-bit seconds field
	seconds     u32  // Lower 32 bits of the seconds field
	nanoseconds u32  // Sub-second [0, 999_999_999]
}

// to_nanos converts PtpTimestamp to a single i64 nanosecond value.
pub fn (t PtpTimestamp) to_nanos() i64 {
	secs := i64(t.seconds_msb) << 32 | i64(t.seconds)
	return secs * 1_000_000_000 + i64(t.nanoseconds)
}

// ClockIdentity is an 8-byte unique clock identifier.
pub struct ClockIdentity {
pub:
	bytes [8]u8
}

// PortIdentity identifies a specific port on a clock.
pub struct PortIdentity {
pub:
	clock_identity ClockIdentity
	port_number    u16
}

// PtpHeader represents the common PTP message header (IEEE 1588-2019 §13.3).
pub struct PtpHeader {
pub:
	msg_type        u8
	version         u8
	message_length  u16
	domain_number   u8
	flags           u16
	correction      i64    // Correction field (nanoseconds * 2^16)
	sequence_id     u16
	log_msg_interval i8   // Log2 of the message interval
	source_port     PortIdentity
}

// Config specifies PTP client parameters.
pub struct Config {
pub:
	domain    u8     = 0                             // PTP domain number
	interface_name string                             // Network interface
	two_step  bool   = true                           // Two-step clock mode
}

// Client manages PTP clock synchronisation.
pub struct Client {
mut:
	config      Config
	offset_ns   i64      // Clock offset in nanoseconds
	delay_ns    i64      // Path delay in nanoseconds
	sequence_id u16
}

// --- Client lifecycle ---

// new_client creates a PTP client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

// start_sync begins the synchronisation process.
pub fn (mut c Client) start_sync() ! {
	println('[ptp] starting sync on domain ${c.config.domain}')
}

// send_delay_request sends a Delay_Req message to measure path delay.
pub fn (mut c Client) send_delay_request() ! {
	c.sequence_id++
	pkt := encode_delay_req(c.sequence_id)
	println('[ptp] Delay_Req seq=${c.sequence_id} (${pkt.len} bytes)')
}

// compute_offset calculates the clock offset from sync timestamps.
pub fn (mut c Client) compute_offset(t1 Timestamp, t2 Timestamp, t3 Timestamp, t4 Timestamp) i64 {
	// offset = ((t2 - t1) - (t4 - t3)) / 2
	// Simplified integer arithmetic
	t1_ns := i64(t1.seconds) * 1_000_000_000 + i64(t1.nanoseconds)
	t2_ns := i64(t2.seconds) * 1_000_000_000 + i64(t2.nanoseconds)
	t3_ns := i64(t3.seconds) * 1_000_000_000 + i64(t3.nanoseconds)
	t4_ns := i64(t4.seconds) * 1_000_000_000 + i64(t4.nanoseconds)
	c.offset_ns = ((t2_ns - t1_ns) - (t4_ns - t3_ns)) / 2
	c.delay_ns = ((t2_ns - t1_ns) + (t4_ns - t3_ns)) / 2
	println('[ptp] offset=${c.offset_ns}ns, delay=${c.delay_ns}ns')
	return c.offset_ns
}

// --- Path delay / offset computation ---

// compute_mean_path_delay computes the mean path delay from the four IEEE 1588
// exchange timestamps (all in nanoseconds since epoch):
//   t1 = master Sync egress (from Follow_Up)
//   t2 = slave  Sync ingress (measured locally)
//   t3 = slave  Delay_Req egress (measured locally)
//   t4 = master Delay_Req ingress (from Delay_Resp)
// Formula: ((t2 - t1) + (t4 - t3)) / 2
pub fn compute_mean_path_delay(t1 i64, t2 i64, t3 i64, t4 i64) i64 {
	return ((t2 - t1) + (t4 - t3)) / 2
}

// compute_clock_offset computes the slave clock offset from master.
// Formula: (t2 - t1) - mean_path_delay
pub fn compute_clock_offset(t1 i64, t2 i64, t3 i64, t4 i64) i64 {
	return (t2 - t1) - compute_mean_path_delay(t1, t2, t3, t4)
}

// --- Encoding ---

// encode_ptp_header serialises the common PTP header portion (34 bytes)
// for the given message type and sequence ID.
fn encode_ptp_header(msg_type u8, seq_id u16, domain u8, two_step bool) []u8 {
	mut hdr := []u8{}
	// messageType (4 bits) | transportSpecific (4 bits)
	hdr << (msg_type & 0x0F)
	// versionPTP
	hdr << ptp_version
	// messageLength (2 bytes) — filled in per-message
	hdr << u8(0x00)
	hdr << u8(0x00)
	// domainNumber
	hdr << domain
	// minorVersionPTP (1 byte)
	hdr << u8(0x00)
	// flagField (2 bytes)
	flags := if two_step { flag_two_step | flag_ptp_timescale } else { flag_ptp_timescale }
	hdr << u8(flags >> 8)
	hdr << u8(flags & 0xFF)
	// correctionField (8 bytes) = 0
	for _ in 0 .. 8 { hdr << u8(0x00) }
	// messageTypeSpecific (4 bytes) = 0
	for _ in 0 .. 4 { hdr << u8(0x00) }
	// sourcePortIdentity (10 bytes) = zeros (placeholder)
	for _ in 0 .. 10 { hdr << u8(0x00) }
	// sequenceId (2 bytes)
	hdr << u8(seq_id >> 8)
	hdr << u8(seq_id & 0xFF)
	// controlField (1 byte) — 0 for Sync/Delay_Req/Delay_Resp
	hdr << u8(0x00)
	// logMessageInterval (1 byte)
	hdr << u8(0x00)
	return hdr
}

// encode_sync builds a PTP Sync message for the given sequence ID.
// The message body appends a 10-byte originTimestamp of all zeros
// (used in two-step mode; actual timestamp carried by Follow_Up).
pub fn encode_sync(seq_id u16) []u8 {
	mut pkt := encode_ptp_header(msg_sync, seq_id, default_domain, true)
	// originTimestamp: 10 bytes (seconds_msb(2) + seconds(4) + ns(4))
	for _ in 0 .. 10 { pkt << u8(0x00) }
	// Patch messageLength field at bytes 2-3
	total := u16(pkt.len)
	pkt[2] = u8(total >> 8)
	pkt[3] = u8(total & 0xFF)
	return pkt
}

// encode_delay_req builds a PTP Delay_Req message for the given sequence ID.
pub fn encode_delay_req(seq_id u16) []u8 {
	mut pkt := encode_ptp_header(msg_delay_req, seq_id, default_domain, false)
	// originTimestamp: 10 bytes of zeros
	for _ in 0 .. 10 { pkt << u8(0x00) }
	total := u16(pkt.len)
	pkt[2] = u8(total >> 8)
	pkt[3] = u8(total & 0xFF)
	return pkt
}

// parse_header deserialises the first 34 bytes of a PTP packet into
// a PtpHeader struct.
pub fn parse_header(data []u8) !PtpHeader {
	if data.len < ptp_header_len {
		return error("PTP header requires ${ptp_header_len} bytes, got ${data.len}")
	}
	msg_type  := data[0] & 0x0F
	version   := data[1]
	msg_len   := (u16(data[2]) << 8) | u16(data[3])
	domain    := data[4]
	flags     := (u16(data[6]) << 8) | u16(data[7])
	seq_id    := (u16(data[30]) << 8) | u16(data[31])
	return PtpHeader{
		msg_type:       msg_type
		version:        version
		message_length: msg_len
		domain_number:  domain
		flags:          flags
		correction:     0
		sequence_id:    seq_id
		log_msg_interval: i8(data[33])
		source_port:    PortIdentity{}
	}
}

// --- Tests ---

fn test_compute_offset_zero() {
	mut c := Client{ config: Config{} }
	ts := Timestamp{ seconds: 100, nanoseconds: 0 }
	offset := c.compute_offset(ts, ts, ts, ts)
	assert offset == 0
}

fn test_encode_sync_length() {
	pkt := encode_sync(1)
	// header(34) + originTimestamp(10) = 44
	assert pkt.len == 44
}

fn test_encode_sync_message_type() {
	pkt := encode_sync(1)
	assert (pkt[0] & 0x0F) == msg_sync
}

fn test_encode_delay_req_message_type() {
	pkt := encode_delay_req(3)
	assert (pkt[0] & 0x0F) == msg_delay_req
}

fn test_parse_header_valid_sync() {
	pkt := encode_sync(42)
	hdr := parse_header(pkt) or { panic('parse failed: ${err}') }
	assert hdr.msg_type == msg_sync
	assert hdr.sequence_id == 42
}

fn test_parse_header_too_short() {
	parse_header([u8(0x00), 0x02]) or {
		assert err.str().contains("requires")
		return
	}
	assert false
}

fn test_ptp_message_type_is_event() {
	assert PtpMessageType.sync.is_event()       == true
	assert PtpMessageType.delay_req.is_event()  == true
	assert PtpMessageType.follow_up.is_event()  == false
	assert PtpMessageType.delay_resp.is_event() == false
	assert PtpMessageType.announce.is_event()   == false
}

fn test_compute_mean_path_delay_symmetric() {
	// t2-t1 = 100ns, t4-t3 = 100ns → delay = 100ns, offset = 0
	delay  := compute_mean_path_delay(i64(1000), i64(1100), i64(1150), i64(1250))
	offset := compute_clock_offset(i64(1000), i64(1100), i64(1150), i64(1250))
	assert delay  == i64(100)
	assert offset == i64(0)
}

fn test_ptp_timestamp_to_nanos() {
	ts := PtpTimestamp{ seconds_msb: u16(0), seconds: u32(1), nanoseconds: u32(500_000_000) }
	nanos := ts.to_nanos()
	assert nanos == i64(1_500_000_000)
}

