// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// voip_test -- Protocol conformance tests for v_voip.
// Covers call lifecycle, RTP packet encoding/decoding, codec mapping,
// and signal type labels.
module v_voip

import encoding.binary

// test_call_state_to_string verifies labels for all call states.
fn test_call_state_to_string() {
	assert call_state_to_string(.idle) == 'Idle'
	assert call_state_to_string(.ringing) == 'Ringing'
	assert call_state_to_string(.connected) == 'Connected'
	assert call_state_to_string(.on_hold) == 'On Hold'
	assert call_state_to_string(.transferring) == 'Transferring'
	assert call_state_to_string(.ended) == 'Ended'
}

// test_codec_to_string verifies codec names.
fn test_codec_to_string() {
	assert codec_to_string(.opus) == 'Opus'
	assert codec_to_string(.g711u) == 'G.711u'
	assert codec_to_string(.g711a) == 'G.711a'
	assert codec_to_string(.g722) == 'G.722'
	assert codec_to_string(.pcm) == 'PCM'
}

// test_signal_type_to_string verifies SIP method names.
fn test_signal_type_to_string() {
	assert signal_type_to_string(.invite) == 'INVITE'
	assert signal_type_to_string(.ack) == 'ACK'
	assert signal_type_to_string(.bye) == 'BYE'
	assert signal_type_to_string(.cancel) == 'CANCEL'
	assert signal_type_to_string(.register) == 'REGISTER'
	assert signal_type_to_string(.options) == 'OPTIONS'
}

// test_create_rtp_packet verifies RTP packet construction.
fn test_create_rtp_packet() {
	pkt := create_rtp_packet(111, 1, 160, 0x12345678, [u8(0xAA), 0xBB])
	assert pkt.version == 2
	assert pkt.payload_type == 111
	assert pkt.sequence == 1
	assert pkt.timestamp == 160
	assert pkt.ssrc == 0x12345678
	assert pkt.payload.len == 2
}

// test_encode_rtp_packet verifies RTP wire-format encoding.
fn test_encode_rtp_packet() {
	pkt := create_rtp_packet(0, 42, 320, 0xDEADBEEF, [u8(0x01), 0x02, 0x03])
	encoded := encode_rtp_packet(pkt)
	// 12-byte header + 3 bytes payload
	assert encoded.len == 15
	// Version bits: 0x80 (V=2)
	assert encoded[0] == 0x80
	// Payload type
	assert encoded[1] == 0
	// Sequence number
	assert binary.big_endian_u16_at(encoded, 2) == 42
	// Timestamp
	assert binary.big_endian_u32_at(encoded, 4) == 320
	// SSRC
	assert binary.big_endian_u32_at(encoded, 8) == 0xDEADBEEF
	// Payload
	assert encoded[12] == 0x01
	assert encoded[13] == 0x02
	assert encoded[14] == 0x03
}

// test_parse_rtp_packet verifies RTP wire-format decoding.
fn test_parse_rtp_packet() {
	original := create_rtp_packet(111, 100, 4800, 0xAABBCCDD, [u8(0xFF)])
	encoded := encode_rtp_packet(original)
	parsed := parse_rtp_packet(encoded)!
	assert parsed.version == 2
	assert parsed.payload_type == 111
	assert parsed.sequence == 100
	assert parsed.timestamp == 4800
	assert parsed.ssrc == 0xAABBCCDD
	assert parsed.payload.len == 1
	assert parsed.payload[0] == 0xFF
}

// test_parse_rtp_packet_too_short verifies rejection of truncated packets.
fn test_parse_rtp_packet_too_short() {
	parse_rtp_packet([]u8{len: 5}) or {
		assert err.msg().contains('too short')
		return
	}
	assert false, 'expected error for short packet'
}

// test_parse_rtp_packet_bad_version verifies rejection of wrong RTP version.
fn test_parse_rtp_packet_bad_version() {
	mut data := []u8{len: 12, init: 0}
	data[0] = 0x00 // version 0
	parse_rtp_packet(data) or {
		assert err.msg().contains('unsupported RTP version')
		return
	}
	assert false, 'expected error for bad version'
}

// test_rtp_encode_decode_roundtrip verifies encode/decode roundtrip.
fn test_rtp_encode_decode_roundtrip() {
	payloads := [
		[]u8{},
		[u8(0x00)],
		[u8(0x01), 0x02, 0x03, 0x04, 0x05],
	]
	for i, payload in payloads {
		original := create_rtp_packet(u8(i), u16(i * 10), u32(i * 160), u32(0x1000 + i), payload)
		encoded := encode_rtp_packet(original)
		parsed := parse_rtp_packet(encoded)!
		assert parsed.payload_type == original.payload_type
		assert parsed.sequence == original.sequence
		assert parsed.timestamp == original.timestamp
		assert parsed.ssrc == original.ssrc
		assert parsed.payload == original.payload
	}
}

// test_initiate_call verifies call creation.
fn test_initiate_call() {
	mut server := new_server(5060)
	call := server.initiate_call('sip:alice@example.com', 'sip:bob@example.com', .opus)
	assert call.state == .ringing
	assert call.caller == 'sip:alice@example.com'
	assert call.callee == 'sip:bob@example.com'
	assert call.codec == .opus
	assert call.id in server.calls
}

// test_answer_call verifies call answer transition.
fn test_answer_call() {
	mut server := new_server(5060)
	call := server.initiate_call('sip:alice@example.com', 'sip:bob@example.com', .opus)
	server.answer(call.id)!
	assert server.calls[call.id].state == .connected
}

// test_reject_call verifies call rejection.
fn test_reject_call() {
	mut server := new_server(5060)
	call := server.initiate_call('sip:alice@example.com', 'sip:bob@example.com', .g711u)
	server.reject(call.id)!
	assert server.calls[call.id].state == .ended
}

// test_hangup verifies call hangup from connected state.
fn test_hangup() {
	mut server := new_server(5060)
	call := server.initiate_call('sip:alice@example.com', 'sip:bob@example.com', .opus)
	server.answer(call.id)!
	server.hangup(call.id)!
	assert server.calls[call.id].state == .ended
}

// test_hold verifies placing a call on hold.
fn test_hold() {
	mut server := new_server(5060)
	call := server.initiate_call('sip:alice@example.com', 'sip:bob@example.com', .opus)
	server.answer(call.id)!
	server.hold(call.id)!
	assert server.calls[call.id].state == .on_hold
}

// test_transfer verifies call transfer initiation.
fn test_transfer() {
	mut server := new_server(5060)
	call := server.initiate_call('sip:alice@example.com', 'sip:bob@example.com', .opus)
	server.answer(call.id)!
	server.transfer(call.id, 'sip:charlie@example.com')!
	assert server.calls[call.id].state == .transferring
}

// test_answer_not_ringing verifies error when answering non-ringing call.
fn test_answer_not_ringing() {
	mut server := new_server(5060)
	call := server.initiate_call('sip:alice@example.com', 'sip:bob@example.com', .opus)
	server.answer(call.id)!
	server.answer(call.id) or {
		assert err.msg().contains('not ringing')
		return
	}
	assert false, 'expected error for already-answered call'
}
