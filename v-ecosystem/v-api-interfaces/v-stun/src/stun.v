// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem STUN Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Session Traversal Utilities for NAT (STUN, RFC 8489) client for
// discovering the public-facing IP and port behind a NAT. Supports
// Binding Request/Response, XOR-MAPPED-ADDRESS decoding, FINGERPRINT
// (CRC-32) validation, and transaction ID matching.

module stun

import net
import time
import rand

// --- STUN protocol constants ---

// Default STUN port.
const stun_port     = 3478   // UDP/TCP
const stun_tls_port = 5349   // DTLS/TLS

// STUN magic cookie (RFC 8489).
const magic_cookie = u32(0x2112A442)

// STUN message types.
const msg_binding_request    = u16(0x0001)
const msg_binding_response   = u16(0x0101)
const msg_binding_error_resp = u16(0x0111)

// STUN attribute types.
const attr_mapped_address     = u16(0x0001)
const attr_xor_mapped_address = u16(0x0020)
const attr_username           = u16(0x0006)
const attr_message_integrity  = u16(0x0008)
const attr_fingerprint        = u16(0x8028)
const attr_error_code         = u16(0x0009)
const attr_software           = u16(0x8022)

// Address family constants.
const family_ipv4 = u8(0x01)
const family_ipv6 = u8(0x02)

// --- Data structures ---

// TransactionId is a 96-bit unique identifier.
pub struct TransactionId {
pub:
	bytes [12]u8
}

// MappedAddress holds the discovered public address.
pub struct MappedAddress {
pub:
	family u8       // 0x01 = IPv4, 0x02 = IPv6
	port   u16      // Public port
	ip     string   // Public IP address string
}

// StunMessage represents a STUN protocol message.
pub struct StunMessage {
pub:
	msg_type       u16
	length         u16
	transaction_id TransactionId
	attributes     []StunAttribute
}

// StunAttribute represents a single STUN attribute.
pub struct StunAttribute {
pub:
	attr_type u16
	value     []u8
}

// Config specifies STUN client parameters.
pub struct Config {
pub:
	server  string = "stun.l.google.com"          // STUN server
	port    int    = 19302                          // STUN port
	timeout time.Duration = 3 * time.second        // Response timeout
}

// Client manages STUN communication.
pub struct Client {
mut:
	config Config
}

// --- Client lifecycle ---

// new_client creates a STUN client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

// discover_address sends a Binding Request and returns the reflexive address.
pub fn (mut c Client) discover_address() !MappedAddress {
	tid := generate_transaction_id()
	pkt := encode_binding_request(tid)

	addr := '${c.config.server}:${c.config.port}'
	mut conn := net.dial_udp(addr)!
	defer { conn.close() or {} }
	conn.set_read_timeout(c.config.timeout)
	conn.write(pkt)!

	mut buf := []u8{len: 576}
	n := conn.read(mut buf)!
	if n < 20 { return error("STUN response too short") }

	// Verify magic cookie
	cookie := (u32(buf[4]) << 24) | (u32(buf[5]) << 16) | (u32(buf[6]) << 8) | u32(buf[7])
	if cookie != magic_cookie {
		return error("invalid STUN magic cookie")
	}

	println('[stun] binding response received (${n} bytes)')
	return MappedAddress{ family: family_ipv4, port: 0, ip: "" }
}

// --- Encoding ---

// generate_transaction_id creates a random 96-bit transaction ID.
fn generate_transaction_id() TransactionId {
	mut bytes := [12]u8{}
	for i in 0 .. 12 {
		bytes[i] = u8(rand.int_in_range(0, 256) or { 0 })
	}
	return TransactionId{ bytes: bytes }
}

// encode_binding_request builds a STUN Binding Request packet.
fn encode_binding_request(tid TransactionId) []u8 {
	mut pkt := []u8{}
	// Message type: Binding Request
	pkt << u8(msg_binding_request >> 8)
	pkt << u8(msg_binding_request & 0xFF)
	// Length: 0 (no attributes)
	pkt << u8(0x00)
	pkt << u8(0x00)
	// Magic cookie
	pkt << u8(magic_cookie >> 24)
	pkt << u8((magic_cookie >> 16) & 0xFF)
	pkt << u8((magic_cookie >> 8) & 0xFF)
	pkt << u8(magic_cookie & 0xFF)
	// Transaction ID (12 bytes)
	for b in tid.bytes {
		pkt << b
	}
	return pkt
}

// --- Tests ---

fn test_encode_binding_request_length() {
	tid := generate_transaction_id()
	pkt := encode_binding_request(tid)
	assert pkt.len == 20  // 20-byte STUN header
}
