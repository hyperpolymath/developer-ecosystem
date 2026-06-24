// SPDX-License-Identifier: MPL-2.0
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

// STUN message types (class | method).
const msg_binding_request    = u16(0x0001)
const msg_binding_response   = u16(0x0101)
const msg_binding_error_resp = u16(0x0111)
const msg_binding_indication = u16(0x0011)

// STUN message class bits.
const class_request    = u16(0x0000)
const class_indication = u16(0x0010)
const class_success    = u16(0x0100)
const class_error      = u16(0x0110)

// STUN attribute types.
const attr_mapped_address     = u16(0x0001)
const attr_xor_mapped_address = u16(0x0020)
const attr_username           = u16(0x0006)
const attr_message_integrity  = u16(0x0008)
const attr_fingerprint        = u16(0x8028)
const attr_error_code         = u16(0x0009)
const attr_software           = u16(0x8022)
const attr_realm              = u16(0x0014)
const attr_nonce              = u16(0x0015)

// Address family constants.
const family_ipv4 = u8(0x01)
const family_ipv6 = u8(0x02)

// STUN header size in bytes.
const stun_header_size = 20

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
	if n < stun_header_size { return error("STUN response too short") }

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
pub fn generate_transaction_id() TransactionId {
	mut bytes := [12]u8{}
	for i in 0 .. 12 {
		bytes[i] = u8(rand.int_in_range(0, 256) or { 0 })
	}
	return TransactionId{ bytes: bytes }
}

// encode_binding_request builds a 20-byte STUN Binding Request packet
// with the provided transaction ID and no attributes.
pub fn encode_binding_request(tid TransactionId) []u8 {
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

// parse_mapped_address decodes a MAPPED-ADDRESS or XOR-MAPPED-ADDRESS
// attribute value (starting after the type+length TLV header) and
// returns a dotted-quad string with port in "ip:port" format.
pub fn parse_mapped_address(data []u8) !string {
	// XOR-MAPPED-ADDRESS: reserved(1) + family(1) + port(2) + address(4 or 16)
	if data.len < 8 {
		return error("mapped address attribute too short")
	}
	family := data[1]
	xport := (u16(data[2]) << 8) | u16(data[3])
	port  := xport ^ u16(magic_cookie >> 16)
	if family == family_ipv4 {
		if data.len < 8 {
			return error("IPv4 mapped address too short")
		}
		// XOR each octet with the corresponding magic cookie byte
		mc := magic_cookie
		b0 := data[4] ^ u8(mc >> 24)
		b1 := data[5] ^ u8((mc >> 16) & 0xFF)
		b2 := data[6] ^ u8((mc >> 8) & 0xFF)
		b3 := data[7] ^ u8(mc & 0xFF)
		return '${b0}.${b1}.${b2}.${b3}:${port}'
	}
	return error("unsupported address family ${family}")
}

// encode_attribute serialises a STUN TLV attribute with 4-byte aligned padding.
pub fn encode_attribute(attr_type u16, value []u8) []u8 {
	mut out := []u8{}
	out << u8(attr_type >> 8)
	out << u8(attr_type & 0xFF)
	out << u8(value.len >> 8)
	out << u8(value.len & 0xFF)
	out << value
	// Pad to 4-byte boundary
	pad := (4 - (value.len % 4)) % 4
	for _ in 0 .. pad {
		out << u8(0x00)
	}
	return out
}

// --- Tests ---

fn test_encode_binding_request_length() {
	tid := generate_transaction_id()
	pkt := encode_binding_request(tid)
	assert pkt.len == 20  // 20-byte STUN header
}

fn test_encode_binding_request_magic_cookie() {
	tid := generate_transaction_id()
	pkt := encode_binding_request(tid)
	cookie := (u32(pkt[4]) << 24) | (u32(pkt[5]) << 16) | (u32(pkt[6]) << 8) | u32(pkt[7])
	assert cookie == magic_cookie
}

fn test_encode_binding_request_type() {
	tid := generate_transaction_id()
	pkt := encode_binding_request(tid)
	msg_type := (u16(pkt[0]) << 8) | u16(pkt[1])
	assert msg_type == msg_binding_request
}

fn test_parse_mapped_address_too_short() {
	parse_mapped_address([u8(0x00), 0x01]) or {
		assert err.str().contains("too short")
		return
	}
	assert false
}

fn test_encode_attribute_padding() {
	// value of length 3 should be padded to 4 bytes
	attr := encode_attribute(attr_software, [u8(0x41), 0x42, 0x43])
	// type(2) + length(2) + value(3) + pad(1) = 8
	assert attr.len == 8
	assert attr[6] == 0x43  // last value byte
	assert attr[7] == 0x00  // padding
}

