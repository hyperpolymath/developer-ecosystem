// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_voip -- VoIP protocol types and server for the V-Ecosystem.
// Implements call signalling, RTP packet handling, and codec negotiation.
// Network I/O is stubbed with TODO markers; all type definitions and
// logic are real.
module v_voip

import time
import rand
import encoding.binary

// CallState represents the lifecycle states of a VoIP call.
pub enum CallState {
	idle
	ringing
	connected
	on_hold
	transferring
	ended
}

// call_state_to_string returns a human-readable label for a CallState.
pub fn call_state_to_string(cs CallState) string {
	return match cs {
		.idle { 'Idle' }
		.ringing { 'Ringing' }
		.connected { 'Connected' }
		.on_hold { 'On Hold' }
		.transferring { 'Transferring' }
		.ended { 'Ended' }
	}
}

// Codec enumerates the audio codecs supported by this connector.
pub enum Codec as u8 {
	opus    = 111
	g711u   = 0
	g711a   = 8
	g722    = 9
	pcm     = 96
}

// codec_to_string returns the human-readable name for a Codec.
pub fn codec_to_string(c Codec) string {
	return match c {
		.opus { 'Opus' }
		.g711u { 'G.711u' }
		.g711a { 'G.711a' }
		.g722 { 'G.722' }
		.pcm { 'PCM' }
	}
}

// SignalType represents the SIP-like signalling message types.
pub enum SignalType {
	invite
	ack
	bye
	cancel
	register
	options
}

// signal_type_to_string returns the SIP method name for a SignalType.
pub fn signal_type_to_string(st SignalType) string {
	return match st {
		.invite { 'INVITE' }
		.ack { 'ACK' }
		.bye { 'BYE' }
		.cancel { 'CANCEL' }
		.register { 'REGISTER' }
		.options { 'OPTIONS' }
	}
}

// RtpPacket represents a Real-time Transport Protocol packet per RFC 3550.
pub struct RtpPacket {
pub:
	// version is the RTP version (always 2).
	version u8
	// payload_type identifies the codec used (maps to Codec values).
	payload_type u8
	// sequence is the 16-bit sequence number for ordering.
	sequence u16
	// timestamp is the 32-bit RTP timestamp for synchronisation.
	timestamp u32
	// ssrc is the synchronisation source identifier.
	ssrc u32
	// payload is the raw audio data.
	payload []u8
}

// create_rtp_packet constructs an RTP packet with the given parameters.
// Sets the version field to 2 per RFC 3550.
pub fn create_rtp_packet(payload_type u8, sequence u16, timestamp u32, ssrc u32, payload []u8) RtpPacket {
	return RtpPacket{
		version: 2
		payload_type: payload_type
		sequence: sequence
		timestamp: timestamp
		ssrc: ssrc
		payload: payload
	}
}

// encode_rtp_packet serialises an RtpPacket into wire-format bytes.
// Produces a minimal 12-byte header followed by the payload.
pub fn encode_rtp_packet(pkt RtpPacket) []u8 {
	mut buf := []u8{len: 0, cap: 12 + pkt.payload.len}
	// Byte 0: V=2, P=0, X=0, CC=0 -> 0x80
	buf << u8(0x80)
	// Byte 1: M=0, PT
	buf << pkt.payload_type & 0x7F
	// Bytes 2-3: sequence number
	mut seq_bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut seq_bytes, pkt.sequence)
	buf << seq_bytes
	// Bytes 4-7: timestamp
	mut ts_bytes := []u8{len: 4}
	binary.big_endian_put_u32(mut ts_bytes, pkt.timestamp)
	buf << ts_bytes
	// Bytes 8-11: SSRC
	mut ssrc_bytes := []u8{len: 4}
	binary.big_endian_put_u32(mut ssrc_bytes, pkt.ssrc)
	buf << ssrc_bytes
	// Payload
	buf << pkt.payload
	return buf
}

// parse_rtp_packet deserialises wire-format bytes into an RtpPacket.
// Expects at least a 12-byte header.
pub fn parse_rtp_packet(data []u8) !RtpPacket {
	if data.len < 12 {
		return error('RTP packet too short: need at least 12 bytes, got ${data.len}')
	}
	version := (data[0] >> 6) & 0x03
	if version != 2 {
		return error('unsupported RTP version: ${version}')
	}
	payload_type := data[1] & 0x7F
	sequence := binary.big_endian_u16_at(data, 2)
	timestamp := binary.big_endian_u32_at(data, 4)
	ssrc := binary.big_endian_u32_at(data, 8)
	payload := if data.len > 12 { data[12..] } else { []u8{} }

	return RtpPacket{
		version: version
		payload_type: payload_type
		sequence: sequence
		timestamp: timestamp
		ssrc: ssrc
		payload: payload
	}
}

// Call represents an active VoIP call between two endpoints.
pub struct Call {
pub:
	// id is the unique call identifier.
	id string
	// caller is the calling party's address/URI.
	caller string
	// callee is the called party's address/URI.
	callee string
	// codec is the negotiated audio codec.
	codec Codec
	// started_at is the time the call was initiated.
	started_at time.Time
pub mut:
	// state is the current call lifecycle state.
	state CallState
}

// VoipServer holds the state for a VoIP server instance.
pub struct VoipServer {
pub:
	// port is the SIP/signalling port (default 5060).
	port int
pub mut:
	// calls holds active calls by ID.
	calls map[string]Call
}

// new_server creates a new VoipServer on the given port.
pub fn new_server(port int) &VoipServer {
	return &VoipServer{
		port: port
	}
}

// generate_call_id creates a unique call identifier.
fn generate_call_id() string {
	bytes := rand.bytes(8) or { return 'call-fallback' }
	mut hex := ''
	for b in bytes {
		hex += '${b:02x}'
	}
	return 'call-${hex}'
}

// initiate_call starts a new call from caller to callee with the
// specified codec. Transitions the call to the Ringing state.
// TODO: Full network I/O -- send SIP INVITE via UDP/TCP.
pub fn (mut s VoipServer) initiate_call(caller string, callee string, codec Codec) Call {
	id := generate_call_id()
	call := Call{
		id: id
		caller: caller
		callee: callee
		codec: codec
		started_at: time.now()
		state: .ringing
	}
	s.calls[id] = call
	return call
}

// answer transitions a ringing call to the Connected state.
pub fn (mut s VoipServer) answer(call_id string) ! {
	if call_id !in s.calls {
		return error('call not found: ${call_id}')
	}
	mut call := &s.calls[call_id]
	if call.state != .ringing {
		return error('call ${call_id} is not ringing (state: ${call_state_to_string(call.state)})')
	}
	call.state = .connected
}

// reject ends a ringing call (callee declines).
pub fn (mut s VoipServer) reject(call_id string) ! {
	if call_id !in s.calls {
		return error('call not found: ${call_id}')
	}
	mut call := &s.calls[call_id]
	if call.state != .ringing {
		return error('call ${call_id} is not ringing (state: ${call_state_to_string(call.state)})')
	}
	call.state = .ended
}

// hangup ends a connected or on-hold call.
pub fn (mut s VoipServer) hangup(call_id string) ! {
	if call_id !in s.calls {
		return error('call not found: ${call_id}')
	}
	mut call := &s.calls[call_id]
	if call.state != .connected && call.state != .on_hold {
		return error('call ${call_id} cannot be hung up (state: ${call_state_to_string(call.state)})')
	}
	call.state = .ended
}

// hold places a connected call on hold.
pub fn (mut s VoipServer) hold(call_id string) ! {
	if call_id !in s.calls {
		return error('call not found: ${call_id}')
	}
	mut call := &s.calls[call_id]
	if call.state != .connected {
		return error('call ${call_id} is not connected (state: ${call_state_to_string(call.state)})')
	}
	call.state = .on_hold
}

// transfer begins transferring a connected call to a new target.
// TODO: Full network I/O -- send SIP REFER.
pub fn (mut s VoipServer) transfer(call_id string, target string) ! {
	if call_id !in s.calls {
		return error('call not found: ${call_id}')
	}
	if target.len == 0 {
		return error('transfer target must not be empty')
	}
	mut call := &s.calls[call_id]
	if call.state != .connected && call.state != .on_hold {
		return error('call ${call_id} cannot be transferred (state: ${call_state_to_string(call.state)})')
	}
	call.state = .transferring
}
