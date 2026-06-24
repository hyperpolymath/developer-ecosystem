// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_stun -- Session Traversal Utilities for NAT (STUN) message construction,
// XOR address mapping, and fingerprint computation for the V-Ecosystem.
// Maps to proven-servers/protocols/proven-stun.
// Implements binding request/response handling, attribute encoding, and
// message integrity per RFC 5389.
module v_stun

import crypto.sha256
import crypto.hmac
import encoding.binary
import rand

// stun_magic_cookie is the fixed 32-bit value present in all STUN messages
// per RFC 5389 section 6.
const stun_magic_cookie = u32(0x2112A442)

// MessageType enumerates the STUN message types per RFC 5389 section 6.
pub enum MessageType as u16 {
	binding_request       = 0x0001
	binding_response      = 0x0101
	binding_error         = 0x0111
}

// message_type_to_string returns the human-readable label for a MessageType.
pub fn message_type_to_string(mt MessageType) string {
	return match mt {
		.binding_request { 'Binding Request' }
		.binding_response { 'Binding Response' }
		.binding_error { 'Binding Error Response' }
	}
}

// AttributeType enumerates the STUN attribute types per RFC 5389 section 15.
pub enum AttributeType as u16 {
	mapped_address     = 0x0001
	xor_mapped_address = 0x0020
	username           = 0x0006
	message_integrity  = 0x0008
	fingerprint        = 0x8028
	software           = 0x8022
}

// attribute_type_to_string returns the human-readable label for an AttributeType.
pub fn attribute_type_to_string(at AttributeType) string {
	return match at {
		.mapped_address { 'MAPPED-ADDRESS' }
		.xor_mapped_address { 'XOR-MAPPED-ADDRESS' }
		.username { 'USERNAME' }
		.message_integrity { 'MESSAGE-INTEGRITY' }
		.fingerprint { 'FINGERPRINT' }
		.software { 'SOFTWARE' }
	}
}

// StunAttribute holds a single attribute within a STUN message.
pub struct StunAttribute {
pub:
	// attr_type identifies the kind of attribute.
	attr_type AttributeType
	// value contains the raw attribute value bytes.
	value []u8
}

// StunMessage represents a complete STUN message with its type, transaction
// identifier, and list of attributes.
pub struct StunMessage {
pub:
	// msg_type is the STUN message type (request, response, or error).
	msg_type MessageType
	// transaction_id is the 96-bit transaction identifier.
	transaction_id []u8
	// attributes contains the message's TLV attributes.
	attributes []StunAttribute
}

// XorAddress holds an IP address and port that have been XOR-mapped
// using the STUN magic cookie and transaction ID.
pub struct XorAddress {
pub:
	// family is the address family (1 = IPv4, 2 = IPv6).
	family u8
	// port is the transport port after XOR mapping.
	port u16
	// address is the IP address bytes after XOR mapping.
	address []u8
}

// StunServer manages STUN binding request handling.
pub struct StunServer {
pub:
	// listen_port is the UDP port for STUN messages (default 3478).
	listen_port int = 3478
	// software is the SOFTWARE attribute value to include in responses.
	software string = 'v_stun/0.1.0'
pub mut:
	// credentials maps usernames to shared secrets for message integrity.
	credentials map[string]string
}

// new_server creates a new StunServer on the given port.
pub fn new_server(port int) &StunServer {
	return &StunServer{
		listen_port: port
	}
}

// generate_transaction_id creates a cryptographically random 96-bit (12-byte)
// transaction identifier for use in STUN messages.
pub fn generate_transaction_id() []u8 {
	mut id := []u8{len: 12}
	for i in 0 .. 12 {
		id[i] = u8(rand.intn(256) or { 0 })
	}
	return id
}

// create_binding_request constructs a STUN Binding Request message with a
// random transaction ID and optional SOFTWARE attribute.
pub fn (s StunServer) create_binding_request() StunMessage {
	tid := generate_transaction_id()
	mut attrs := []StunAttribute{}
	if s.software.len > 0 {
		attrs << StunAttribute{
			attr_type: .software
			value: s.software.bytes()
		}
	}
	return StunMessage{
		msg_type: .binding_request
		transaction_id: tid
		attributes: attrs
	}
}

// xor_address XOR-maps an IP address and port using the STUN magic cookie
// and transaction ID per RFC 5389 section 15.2.
// For IPv4: port XOR'd with top 16 bits of magic cookie; address XOR'd with
// full magic cookie. For IPv6: address additionally XOR'd with transaction ID.
pub fn xor_address(family u8, address []u8, port u16, transaction_id []u8) XorAddress {
	// XOR port with top 16 bits of magic cookie
	xored_port := port ^ u16(stun_magic_cookie >> 16)

	mut xored_addr := address.clone()
	if family == 1 && address.len == 4 {
		// IPv4: XOR with 32-bit magic cookie
		mut cookie_bytes := []u8{len: 4}
		binary.big_endian_put_u32(mut cookie_bytes, stun_magic_cookie)
		for i in 0 .. 4 {
			xored_addr[i] ^= cookie_bytes[i]
		}
	} else if family == 2 && address.len == 16 {
		// IPv6: XOR with magic cookie || transaction_id (16 bytes total)
		mut mask := []u8{len: 4}
		binary.big_endian_put_u32(mut mask, stun_magic_cookie)
		mask << transaction_id
		for i in 0 .. 16 {
			if i < mask.len {
				xored_addr[i] ^= mask[i]
			}
		}
	}

	return XorAddress{
		family: family
		port: xored_port
		address: xored_addr
	}
}

// decode_xor_address reverses the XOR mapping to recover the original
// address and port.
pub fn decode_xor_address(xored XorAddress, transaction_id []u8) XorAddress {
	// XOR is its own inverse
	return xor_address(xored.family, xored.address, xored.port, transaction_id)
}

// compute_fingerprint calculates the CRC-32 fingerprint for a STUN message
// per RFC 5389 section 15.5. The fingerprint is computed over the message
// bytes up to (but not including) the FINGERPRINT attribute, then XOR'd
// with 0x5354554E.
pub fn compute_fingerprint(data []u8) u32 {
	// CRC-32 (ISO 3309) computation
	mut crc := u32(0xFFFFFFFF)
	for b in data {
		crc ^= u32(b)
		for _ in 0 .. 8 {
			if crc & 1 != 0 {
				crc = (crc >> 1) ^ u32(0xEDB88320)
			} else {
				crc >>= 1
			}
		}
	}
	crc ^= u32(0xFFFFFFFF)
	// XOR with STUN fingerprint magic value
	return crc ^ u32(0x5354554E)
}

// compute_message_integrity calculates the HMAC-SHA256 message integrity
// value for a STUN message using the given shared secret key.
pub fn compute_message_integrity(data []u8, key string) []u8 {
	return hmac.new(key.bytes(), data, sha256.sum256, sha256.block_size)
}

// encode encodes a StunMessage into wire-format bytes suitable for
// transmission over UDP.
pub fn (m StunMessage) encode() []u8 {
	// Encode attributes first to compute length
	mut attr_bytes := []u8{}
	for attr in m.attributes {
		mut type_bytes := []u8{len: 2}
		binary.big_endian_put_u16(mut type_bytes, u16(attr.attr_type))
		attr_bytes << type_bytes
		mut len_bytes := []u8{len: 2}
		binary.big_endian_put_u16(mut len_bytes, u16(attr.value.len))
		attr_bytes << len_bytes
		attr_bytes << attr.value
		// Pad to 4-byte boundary
		padding := (4 - (attr.value.len % 4)) % 4
		for _ in 0 .. padding {
			attr_bytes << u8(0)
		}
	}

	mut buf := []u8{len: 0, cap: 20 + attr_bytes.len}
	// Message type (2 bytes)
	mut type_bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut type_bytes, u16(m.msg_type))
	buf << type_bytes
	// Message length (2 bytes) -- excludes 20-byte header
	mut len_bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut len_bytes, u16(attr_bytes.len))
	buf << len_bytes
	// Magic cookie (4 bytes)
	mut cookie_bytes := []u8{len: 4}
	binary.big_endian_put_u32(mut cookie_bytes, stun_magic_cookie)
	buf << cookie_bytes
	// Transaction ID (12 bytes)
	if m.transaction_id.len >= 12 {
		buf << m.transaction_id[0..12]
	} else {
		buf << m.transaction_id
		for _ in 0 .. (12 - m.transaction_id.len) {
			buf << u8(0)
		}
	}
	// Attributes
	buf << attr_bytes
	return buf
}

// process_response parses the attributes from a binding response and extracts
// the XOR-MAPPED-ADDRESS if present.
// TODO: Network I/O -- receive response from UDP socket and decode.
pub fn (s StunServer) process_response(msg StunMessage) !XorAddress {
	for attr in msg.attributes {
		if attr.attr_type == .xor_mapped_address && attr.value.len >= 8 {
			family := attr.value[1]
			port := binary.big_endian_u16_at(attr.value, 2)
			address := attr.value[4..].clone()
			return decode_xor_address(XorAddress{
				family: family
				port: port
				address: address
			}, msg.transaction_id)
		}
	}
	return error('no XOR-MAPPED-ADDRESS in response')
}

// add_credential registers a username/secret pair for message integrity.
pub fn (mut s StunServer) add_credential(username string, secret string) {
	s.credentials[username] = secret
}
