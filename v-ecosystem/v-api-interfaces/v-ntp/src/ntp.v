// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem NTP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// NTPv4 (RFC 5905) client over UDP. Supports unicast time queries,
// clock offset/delay calculation, stratum inspection, and kiss-of-
// death (KoD) code handling. Implements the NTP timestamp format
// (64-bit: 32-bit seconds since 1900-01-01 + 32-bit fraction).
// Designed for time synchronisation checks within the V-Ecosystem.

module ntp

import net
import time

// --- NTP protocol constants ---

// NTP packet size is fixed at 48 bytes for the basic header.
const ntp_packet_size = 48

// NTP epoch offset: seconds between 1900-01-01 and 1970-01-01.
const ntp_epoch_offset = u64(2208988800)

// Leap indicator values (2-bit field in the first byte).
const li_no_warning = u8(0)
const li_last_61    = u8(1)
const li_last_59    = u8(2)
const li_alarm      = u8(3)

// NTP version number (3 bits, currently version 4).
const ntp_version = u8(4)

// Mode values (3-bit field).
const mode_client = u8(3)
const mode_server = u8(4)

// --- Stratum levels ---

// Stratum enumerates the NTP clock stratum levels.
pub enum Stratum {
	unspecified       // Stratum 0 (kiss-of-death or unspecified)
	primary_reference // Stratum 1 (GPS, atomic clock, radio)
	secondary         // Stratum 2-15 (synchronised via NTP)
	unsynchronised    // Stratum 16 (unsynchronised)
}

// --- Data structures ---

// Timestamp represents an NTP 64-bit timestamp (seconds since
// 1900-01-01 plus fractional seconds).
pub struct Timestamp {
pub:
	seconds  u32   // Whole seconds since NTP epoch (1900-01-01)
	fraction u32   // Fractional second (2^-32 seconds resolution)
}

// NtpPacket is the 48-byte NTP message structure (RFC 5905 section 7.3).
pub struct NtpPacket {
pub mut:
	li_vn_mode         u8         // Leap indicator (2) + version (3) + mode (3)
	stratum            u8         // Stratum level
	poll               i8         // Poll interval (log2 seconds)
	precision          i8         // Clock precision (log2 seconds)
	root_delay         u32        // Round-trip delay to primary source (fixed-point)
	root_dispersion    u32        // Maximum error relative to primary source
	reference_id       u32        // Reference clock identifier
	reference_ts       Timestamp  // Time when system clock was last set
	origin_ts          Timestamp  // Time at client when request departed
	receive_ts         Timestamp  // Time at server when request arrived
	transmit_ts        Timestamp  // Time at server when reply departed
}

// TimeResult holds the calculated clock offset and round-trip delay
// from an NTP query.
pub struct TimeResult {
pub:
	offset        f64          // Clock offset in seconds (positive = local is behind)
	delay         f64          // Round-trip network delay in seconds
	stratum       u8           // Server stratum
	reference_id  string       // Reference source identifier
	server_time   time.Time    // Server timestamp as V time
	leap          u8           // Leap indicator
}

// Config specifies the NTP server and query parameters.
pub struct Config {
pub:
	server   string                               // NTP server hostname or IP
	port     int    = 123                           // NTP port (default 123)
	timeout  time.Duration = 5 * time.second       // Query timeout
	version  u8    = 4                              // NTP version (3 or 4)
}

// --- Client ---

// Client manages NTP queries to a single server.
pub struct Client {
	config Config
}

// new_client creates an NTP client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{
		config: config
	}
}

// query sends a single NTP request and returns the time result
// with calculated offset and delay.
pub fn (c &Client) query() !TimeResult {
	addr := '${c.config.server}:${c.config.port}'

	// Build client request packet (mode 3, version 4)
	mut pkt := []u8{len: ntp_packet_size, init: 0}
	pkt[0] = (li_no_warning << 6) | (c.config.version << 3) | mode_client

	// Record transmit timestamp (T1)
	t1 := time.now()
	t1_ntp := unix_to_ntp(t1.unix())
	write_timestamp(mut pkt, 40, t1_ntp)

	// Send via UDP
	mut conn := net.dial_udp(addr)!
	defer {
		conn.close() or {}
	}
	conn.set_read_timeout(c.config.timeout)
	conn.write(pkt)!

	// Receive response
	mut buf := []u8{len: ntp_packet_size}
	conn.read(mut buf)!
	t4 := time.now() // Destination timestamp (T4)

	// Parse response
	response := parse_packet(buf)

	// Validate response
	resp_mode := response.li_vn_mode & 0x07
	if resp_mode != mode_server {
		return error('unexpected NTP mode ${resp_mode} (expected server mode 4)')
	}

	// Check for kiss-of-death (stratum 0)
	if response.stratum == 0 {
		kod_code := response.reference_id
		return error('kiss-of-death received: code 0x${kod_code:08x}')
	}

	// Calculate offset and delay using NTP clock filter algorithm
	// T1 = origin, T2 = receive, T3 = transmit, T4 = destination
	t2 := ntp_to_seconds(response.receive_ts)
	t3 := ntp_to_seconds(response.transmit_ts)
	t1_sec := f64(t1.unix())
	t4_sec := f64(t4.unix())

	offset := ((t2 - t1_sec) + (t3 - t4_sec)) / 2.0
	delay := (t4_sec - t1_sec) - (t3 - t2)

	// Convert reference ID to string (for stratum 1, it's ASCII)
	ref_id := if response.stratum == 1 {
		ref_id_to_ascii(response.reference_id)
	} else {
		'0x${response.reference_id:08x}'
	}

	server_time := time.unix(i64(ntp_to_seconds(response.transmit_ts)))

	println('[ntp] offset=${offset:.6f}s delay=${delay:.6f}s stratum=${response.stratum}')
	return TimeResult{
		offset: offset
		delay: delay
		stratum: response.stratum
		reference_id: ref_id
		server_time: server_time
		leap: (response.li_vn_mode >> 6) & 0x03
	}
}

// get_time is a convenience function that queries the server and
// returns the corrected local time.
pub fn (c &Client) get_time() !time.Time {
	result := c.query()!
	now := time.now()
	corrected_unix := f64(now.unix()) + result.offset
	return time.unix(i64(corrected_unix))
}

// --- Internal helpers ---

// parse_packet deserialises a 48-byte buffer into an NtpPacket.
fn parse_packet(buf []u8) NtpPacket {
	return NtpPacket{
		li_vn_mode: buf[0]
		stratum: buf[1]
		poll: i8(buf[2])
		precision: i8(buf[3])
		root_delay: read_u32(buf, 4)
		root_dispersion: read_u32(buf, 8)
		reference_id: read_u32(buf, 12)
		reference_ts: read_timestamp(buf, 16)
		origin_ts: read_timestamp(buf, 24)
		receive_ts: read_timestamp(buf, 32)
		transmit_ts: read_timestamp(buf, 40)
	}
}

// read_u32 reads a big-endian 32-bit unsigned integer from buf at offset.
fn read_u32(buf []u8, offset int) u32 {
	return (u32(buf[offset]) << 24) |
		(u32(buf[offset + 1]) << 16) |
		(u32(buf[offset + 2]) << 8) |
		u32(buf[offset + 3])
}

// read_timestamp reads an NTP timestamp (8 bytes) at the given offset.
fn read_timestamp(buf []u8, offset int) Timestamp {
	return Timestamp{
		seconds: read_u32(buf, offset)
		fraction: read_u32(buf, offset + 4)
	}
}

// write_timestamp writes an NTP timestamp into buf at offset.
fn write_timestamp(mut buf []u8, offset int, ts Timestamp) {
	buf[offset] = u8(ts.seconds >> 24)
	buf[offset + 1] = u8(ts.seconds >> 16)
	buf[offset + 2] = u8(ts.seconds >> 8)
	buf[offset + 3] = u8(ts.seconds)
	buf[offset + 4] = u8(ts.fraction >> 24)
	buf[offset + 5] = u8(ts.fraction >> 16)
	buf[offset + 6] = u8(ts.fraction >> 8)
	buf[offset + 7] = u8(ts.fraction)
}

// unix_to_ntp converts a Unix timestamp to an NTP timestamp.
fn unix_to_ntp(unix_sec i64) Timestamp {
	return Timestamp{
		seconds: u32(u64(unix_sec) + ntp_epoch_offset)
		fraction: 0
	}
}

// ntp_to_seconds converts an NTP timestamp to seconds as f64.
fn ntp_to_seconds(ts Timestamp) f64 {
	return f64(u64(ts.seconds) - ntp_epoch_offset) + f64(ts.fraction) / f64(u64(1) << 32)
}

// ref_id_to_ascii converts a 4-byte reference ID to its ASCII
// representation (used for stratum 1 sources like "GPS\0", "PPS\0").
fn ref_id_to_ascii(ref_id u32) string {
	mut chars := []u8{}
	for i := 3; i >= 0; i-- {
		ch := u8((ref_id >> (i * 8)) & 0xFF)
		if ch >= 0x20 && ch <= 0x7E {
			chars << ch
		}
	}
	return chars.bytestr().trim_right('\x00 ')
}

// --- Tests ---

fn test_unix_to_ntp() {
	// Unix epoch 0 = NTP epoch + 2208988800
	ts := unix_to_ntp(0)
	assert ts.seconds == u32(ntp_epoch_offset)
	assert ts.fraction == 0
}

fn test_ntp_to_seconds() {
	// NTP epoch offset maps to Unix 0
	ts := Timestamp{ seconds: u32(ntp_epoch_offset), fraction: 0 }
	assert ntp_to_seconds(ts) == 0.0
}

fn test_ref_id_to_ascii() {
	// "GPS\0" = 0x47505300
	assert ref_id_to_ascii(0x47505300) == 'GPS'
}

fn test_read_u32() {
	buf := [u8(0x01), u8(0x02), u8(0x03), u8(0x04)]
	assert read_u32(buf, 0) == 0x01020304
}
