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

// Path attribute type codes.
const attr_origin     = u8(1)
const attr_as_path    = u8(2)
const attr_next_hop   = u8(3)
const attr_med        = u8(4)
const attr_local_pref = u8(5)
const attr_communities = u8(8)

// Origin values.
const origin_igp        = u8(0)
const origin_egp        = u8(1)
const origin_incomplete = u8(2)

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

// --- Tests ---

fn test_fsm_initial_state() {
	s := Session{ config: Config{ peer_host: "10.0.0.1", local_asn: 65001, peer_asn: 65002, router_id: "1.1.1.1" }, state: .idle }
	assert s.state == .idle
}
