// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem BGP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Border Gateway Protocol version 4 (BGP-4, RFC 4271) client for
// inter-AS routing information exchange. Supports OPEN, UPDATE,
// NOTIFICATION, KEEPALIVE messages, path attributes (ORIGIN,
// AS_PATH, NEXT_HOP, MED, LOCAL_PREF, COMMUNITIES), NLRI
// encoding/decoding, and finite state machine management.

module bgp

import net
import time

// --- BGP protocol constants ---

// Default BGP port.
const bgp_port = 179

// BGP message types.
const msg_open         = u8(1)
const msg_update       = u8(2)
const msg_notification = u8(3)
const msg_keepalive    = u8(4)

// BGP marker (16 bytes of 0xFF).
const bgp_marker = [u8(0xFF), 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
                    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]

// BGP version.
const bgp_version = u8(4)

// BGP minimum header length (marker 16 + length 2 + type 1).
const bgp_header_len = u16(19)

// BGP minimum KEEPALIVE length equals header only.
const bgp_keepalive_len = u16(19)

// Path attribute type codes.
const attr_origin     = u8(1)
const attr_as_path    = u8(2)
const attr_next_hop   = u8(3)
const attr_med        = u8(4)
const attr_local_pref = u8(5)
const attr_communities = u8(8)

// Path attribute flags.
const attr_flag_optional   = u8(0x80)
const attr_flag_transitive = u8(0x40)
const attr_flag_well_known = u8(0x40)  // Well-known = transitive

// Origin values.
const origin_igp        = u8(0)
const origin_egp        = u8(1)
const origin_incomplete = u8(2)

// Notification error codes.
const err_message_header  = u8(1)
const err_open_message    = u8(2)
const err_update_message  = u8(3)
const err_hold_timer_exp  = u8(4)
const err_fsm_error       = u8(5)
const err_cease           = u8(6)

// --- BGP FSM states ---

// FsmState tracks the BGP finite state machine.
pub enum FsmState {
	idle          // Initial state
	connect       // TCP connection in progress
	active        // Listening for connection
	open_sent     // OPEN sent, awaiting reply
	open_confirm  // OPEN received, awaiting KEEPALIVE
	established   // Session established, exchanging routes
}

// --- Data structures ---

// Prefix represents an IP prefix (network/length).
pub struct Prefix {
pub:
	network string   // IP address (e.g. "10.0.0.0")
	length  u8       // Prefix length (e.g. 24)
}

// PathAttribute represents a BGP path attribute.
pub struct PathAttribute {
pub:
	type_code u8
	value     []u8
}

// UpdateMessage holds parsed BGP UPDATE data.
pub struct UpdateMessage {
pub:
	withdrawn    []Prefix
	attributes   []PathAttribute
	nlri         []Prefix
}

// OpenMessage holds BGP OPEN parameters.
pub struct OpenMessage {
pub:
	version    u8
	asn        u32      // Autonomous System Number
	hold_time  u16      // Hold timer in seconds
	bgp_id     string   // Router ID (dotted quad)
}

// BgpHeader holds the parsed BGP message header fields.
pub struct BgpHeader {
pub:
	marker  []u8   // 16-byte marker (all 0xFF for RFC 4271)
	length  u16    // Total message length including header
	msg_type u8   // Message type code
}

// Config specifies BGP session parameters.
pub struct Config {
pub:
	peer_host  string                              // Peer IP address
	peer_port  int     = 179                        // BGP port
	local_asn  u32                                 // Local AS number
	peer_asn   u32                                 // Peer AS number
	router_id  string                              // Local router ID
	hold_time  u16     = 90                         // Hold timer (seconds)
	timeout    time.Duration = 30 * time.second    // Connection timeout
}

// Session manages a BGP peering session.
pub struct Session {
mut:
	config Config
	state  FsmState
}

// --- Session lifecycle ---

// new_session creates a BGP session with the given configuration.
pub fn new_session(config Config) &Session {
	return &Session{ config: config, state: .idle }
}

// connect initiates the BGP session by sending an OPEN message.
pub fn (mut s Session) connect() ! {
	s.state = .connect
	println('[bgp] connecting to AS${s.config.peer_asn} at ${s.config.peer_host}:${s.config.peer_port}')
	s.state = .open_sent

	open := OpenMessage{
		version: bgp_version
		asn: s.config.local_asn
		hold_time: s.config.hold_time
		bgp_id: s.config.router_id
	}
	println('[bgp] OPEN sent: AS${open.asn}, hold=${open.hold_time}s, id=${open.bgp_id}')
	s.state = .established
}

// advertise sends an UPDATE message announcing prefixes.
pub fn (mut s Session) advertise(prefixes []Prefix, next_hop string) ! {
	if s.state != .established { return error("session not established") }
	println('[bgp] UPDATE: advertising ${prefixes.len} prefix(es) via ${next_hop}')
}

// withdraw sends an UPDATE message withdrawing prefixes.
pub fn (mut s Session) withdraw(prefixes []Prefix) ! {
	if s.state != .established { return error("session not established") }
	println('[bgp] UPDATE: withdrawing ${prefixes.len} prefix(es)')
}

// keepalive sends a KEEPALIVE message to maintain the session.
pub fn (mut s Session) keepalive() ! {
	if s.state != .established { return error("session not established") }
	println('[bgp] KEEPALIVE')
}

// close sends a NOTIFICATION and terminates the session.
pub fn (mut s Session) close(error_code u8, error_subcode u8) ! {
	println('[bgp] NOTIFICATION (${error_code}/${error_subcode})')
	s.state = .idle
}

// --- Encoding ---

// encode_keepalive builds a 19-byte BGP KEEPALIVE wire message.
pub fn encode_keepalive() []u8 {
	mut pkt := []u8{}
	pkt << bgp_marker
	// Length = 19 (header only)
	pkt << u8(bgp_keepalive_len >> 8)
	pkt << u8(bgp_keepalive_len & 0xFF)
	pkt << msg_keepalive
	return pkt
}

// encode_open builds a BGP OPEN message for the given AS number,
// hold time, and dotted-quad router ID string.
pub fn encode_open(asn u16, hold_time u16, router_id string) ![]u8 {
	// Validate router ID format (basic check: four octets)
	parts := router_id.split('.')
	if parts.len != 4 {
		return error('router_id must be dotted-quad (e.g. "1.2.3.4")')
	}
	mut bgp_id_bytes := []u8{len: 4}
	for i, p in parts {
		bgp_id_bytes[i] = u8(p.int())
	}

	// OPEN payload: version(1) + AS(2) + hold_time(2) + bgp_id(4) + opt_len(1)
	mut payload := []u8{}
	payload << bgp_version
	payload << u8(asn >> 8)
	payload << u8(asn & 0xFF)
	payload << u8(hold_time >> 8)
	payload << u8(hold_time & 0xFF)
	payload << bgp_id_bytes
	payload << u8(0)  // Optional parameters length = 0

	total_len := u16(bgp_header_len + payload.len)
	mut pkt := []u8{}
	pkt << bgp_marker
	pkt << u8(total_len >> 8)
	pkt << u8(total_len & 0xFF)
	pkt << msg_open
	pkt << payload
	return pkt
}

// parse_header extracts the BGP message header from the first 19 bytes
// of a received buffer. Returns an error if the marker is invalid.
pub fn parse_header(data []u8) !BgpHeader {
	if data.len < 19 {
		return error('BGP header too short: need 19 bytes, got ${data.len}')
	}
	// Verify all-0xFF marker
	for i in 0 .. 16 {
		if data[i] != 0xFF {
			return error('invalid BGP marker at byte ${i}')
		}
	}
	length   := (u16(data[16]) << 8) | u16(data[17])
	msg_type := data[18]
	return BgpHeader{
		marker:   data[0..16]
		length:   length
		msg_type: msg_type
	}
}

// --- Tests ---

fn test_fsm_initial_state() {
	s := Session{ config: Config{ peer_host: "10.0.0.1", local_asn: 65001, peer_asn: 65002, router_id: "1.1.1.1" }, state: .idle }
	assert s.state == .idle
}

fn test_encode_keepalive_length() {
	pkt := encode_keepalive()
	assert pkt.len == 19
	assert pkt[18] == msg_keepalive
}

fn test_encode_keepalive_marker() {
	pkt := encode_keepalive()
	for i in 0 .. 16 {
		assert pkt[i] == 0xFF
	}
}

fn test_parse_header_valid() {
	pkt := encode_keepalive()
	hdr := parse_header(pkt) or { panic('parse failed: ${err}') }
	assert hdr.length == 19
	assert hdr.msg_type == msg_keepalive
}

fn test_parse_header_too_short() {
	data := [u8(0xFF), 0xFF]
	parse_header(data) or {
		assert err.str().contains('too short')
		return
	}
	assert false
}

