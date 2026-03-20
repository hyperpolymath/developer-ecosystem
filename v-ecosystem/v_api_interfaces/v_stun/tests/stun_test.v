// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// stun_test -- Protocol conformance tests for v_stun.
// Covers message construction, XOR address mapping, fingerprint computation,
// message encoding, and transaction ID generation.
module v_stun

// test_message_type_to_string verifies human-readable labels for all
// STUN message types.
fn test_message_type_to_string() {
	assert message_type_to_string(.binding_request) == 'Binding Request'
	assert message_type_to_string(.binding_response) == 'Binding Response'
	assert message_type_to_string(.binding_error) == 'Binding Error Response'
}

// test_attribute_type_to_string verifies human-readable labels for all
// STUN attribute types.
fn test_attribute_type_to_string() {
	assert attribute_type_to_string(.mapped_address) == 'MAPPED-ADDRESS'
	assert attribute_type_to_string(.xor_mapped_address) == 'XOR-MAPPED-ADDRESS'
	assert attribute_type_to_string(.username) == 'USERNAME'
	assert attribute_type_to_string(.message_integrity) == 'MESSAGE-INTEGRITY'
	assert attribute_type_to_string(.fingerprint) == 'FINGERPRINT'
	assert attribute_type_to_string(.software) == 'SOFTWARE'
}

// test_generate_transaction_id verifies that transaction IDs are 12 bytes.
fn test_generate_transaction_id() {
	tid := generate_transaction_id()
	assert tid.len == 12
}

// test_generate_transaction_id_uniqueness verifies that consecutive IDs
// are distinct (probabilistic check).
fn test_generate_transaction_id_uniqueness() {
	a := generate_transaction_id()
	b := generate_transaction_id()
	assert a != b
}

// test_xor_address_ipv4 verifies XOR mapping for an IPv4 address.
fn test_xor_address_ipv4() {
	addr := [u8(192), 168, 1, 100]
	port := u16(12345)
	tid := []u8{len: 12, init: 0}

	xored := xor_address(1, addr, port, tid)
	assert xored.family == 1
	assert xored.port != port // XOR'd with magic cookie top bits
	assert xored.address != addr // XOR'd with magic cookie

	// Reversing should recover the original
	recovered := decode_xor_address(xored, tid)
	assert recovered.port == port
	assert recovered.address == addr
}

// test_xor_address_roundtrip verifies that XOR mapping is its own inverse.
fn test_xor_address_roundtrip() {
	addr := [u8(10), 0, 0, 1]
	port := u16(3478)
	tid := generate_transaction_id()

	xored := xor_address(1, addr, port, tid)
	recovered := decode_xor_address(xored, tid)
	assert recovered.port == port
	assert recovered.address == addr
}

// test_compute_fingerprint verifies that the fingerprint function produces
// a deterministic value for known input.
fn test_compute_fingerprint() {
	data := 'Hello STUN'.bytes()
	fp1 := compute_fingerprint(data)
	fp2 := compute_fingerprint(data)
	assert fp1 == fp2
}

// test_compute_fingerprint_different verifies that different inputs produce
// different fingerprints.
fn test_compute_fingerprint_different() {
	fp1 := compute_fingerprint('Hello'.bytes())
	fp2 := compute_fingerprint('World'.bytes())
	assert fp1 != fp2
}

// test_create_binding_request verifies request construction.
fn test_create_binding_request() {
	s := new_server(3478)
	req := s.create_binding_request()
	assert req.msg_type == .binding_request
	assert req.transaction_id.len == 12
	// Should have SOFTWARE attribute
	assert req.attributes.len >= 1
}

// test_encode_message verifies wire-format encoding of a STUN message.
fn test_encode_message() {
	msg := StunMessage{
		msg_type: .binding_request
		transaction_id: []u8{len: 12, init: 0xAB}
		attributes: []
	}
	encoded := msg.encode()
	// Header is always 20 bytes
	assert encoded.len == 20
	// First two bytes: message type 0x0001
	assert encoded[0] == 0x00
	assert encoded[1] == 0x01
	// Bytes 4-7: magic cookie 0x2112A442
	assert encoded[4] == 0x21
	assert encoded[5] == 0x12
	assert encoded[6] == 0xA4
	assert encoded[7] == 0x42
}

// test_encode_message_with_attributes verifies encoding includes attributes
// with proper TLV padding.
fn test_encode_message_with_attributes() {
	msg := StunMessage{
		msg_type: .binding_response
		transaction_id: []u8{len: 12, init: 0}
		attributes: [
			StunAttribute{
				attr_type: .software
				value: 'test'.bytes()
			},
		]
	}
	encoded := msg.encode()
	// 20 header + 4 TLV header + 4 value = 28 bytes
	assert encoded.len == 28
}

// test_add_credential verifies credential registration.
fn test_add_credential() {
	mut s := new_server(3478)
	s.add_credential('alice', 'secret123')
	assert 'alice' in s.credentials
	assert s.credentials['alice'] == 'secret123'
}

// test_compute_message_integrity verifies HMAC computation is deterministic.
fn test_compute_message_integrity() {
	data := 'test message'.bytes()
	key := 'shared-secret'
	h1 := compute_message_integrity(data, key)
	h2 := compute_message_integrity(data, key)
	assert h1 == h2
	assert h1.len == 32 // SHA-256 produces 32 bytes
}
