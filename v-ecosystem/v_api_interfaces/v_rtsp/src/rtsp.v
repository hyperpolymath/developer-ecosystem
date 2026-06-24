// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_rtsp -- RTSP protocol types and server for the V-Ecosystem.
// Implements streaming session management, transport negotiation,
// and request/response handling per RFC 7826. Network I/O is stubbed
// with TODO markers; all type definitions and logic are real.
module v_rtsp

import rand

// Method enumerates the RTSP methods per RFC 7826 section 13.
pub enum Method {
	describe
	announce
	setup
	play
	pause
	teardown
	get_parameter
	set_parameter
	record
	options
}

// method_to_string returns the RTSP wire keyword for a Method.
pub fn method_to_string(m Method) string {
	return match m {
		.describe { 'DESCRIBE' }
		.announce { 'ANNOUNCE' }
		.setup { 'SETUP' }
		.play { 'PLAY' }
		.pause { 'PAUSE' }
		.teardown { 'TEARDOWN' }
		.get_parameter { 'GET_PARAMETER' }
		.set_parameter { 'SET_PARAMETER' }
		.record { 'RECORD' }
		.options { 'OPTIONS' }
	}
}

// SessionState represents the lifecycle of an RTSP session.
pub enum SessionState {
	init
	ready
	playing
	recording
}

// state_to_string returns a human-readable label for a SessionState.
pub fn state_to_string(s SessionState) string {
	return match s {
		.init { 'Init' }
		.ready { 'Ready' }
		.playing { 'Playing' }
		.recording { 'Recording' }
	}
}

// TransportSpec describes the transport parameters for an RTSP session.
pub struct TransportSpec {
pub:
	// protocol is the transport protocol (e.g. "RTP").
	protocol string
	// profile is the transport profile (e.g. "AVP").
	profile string
	// unicast indicates unicast delivery (false = multicast).
	unicast bool
	// client_port is the client's RTP port.
	client_port int
	// server_port is the server's RTP port.
	server_port int
	// ssrc is the synchronisation source identifier.
	ssrc string
}

// parse_transport parses an RTSP Transport header value into a TransportSpec.
// Format: RTP/AVP;unicast;client_port=8000-8001;server_port=9000-9001;ssrc=ABCD1234
pub fn parse_transport(header string) !TransportSpec {
	if header.len == 0 {
		return error('empty transport header')
	}
	parts := header.split(';')
	if parts.len == 0 {
		return error('malformed transport header')
	}

	// Parse protocol/profile from first part (e.g. "RTP/AVP")
	proto_parts := parts[0].split('/')
	protocol := if proto_parts.len > 0 { proto_parts[0].trim_space() } else { '' }
	profile := if proto_parts.len > 1 { proto_parts[1].trim_space() } else { '' }

	mut unicast := false
	mut client_port := 0
	mut server_port := 0
	mut ssrc := ''

	for i := 1; i < parts.len; i++ {
		part := parts[i].trim_space()
		if part == 'unicast' {
			unicast = true
		} else if part == 'multicast' {
			unicast = false
		} else if part.starts_with('client_port=') {
			port_str := part[12..]
			// Take the first port from a range (e.g. "8000-8001")
			dash := port_str.index_u8(`-`)
			first := if dash > 0 { port_str[..dash] } else { port_str }
			client_port = first.int()
		} else if part.starts_with('server_port=') {
			port_str := part[12..]
			dash := port_str.index_u8(`-`)
			first := if dash > 0 { port_str[..dash] } else { port_str }
			server_port = first.int()
		} else if part.starts_with('ssrc=') {
			ssrc = part[5..]
		}
	}

	return TransportSpec{
		protocol: protocol
		profile: profile
		unicast: unicast
		client_port: client_port
		server_port: server_port
		ssrc: ssrc
	}
}

// format_transport serialises a TransportSpec into an RTSP Transport header value.
pub fn format_transport(ts TransportSpec) string {
	mut result := '${ts.protocol}/${ts.profile}'
	if ts.unicast {
		result += ';unicast'
	} else {
		result += ';multicast'
	}
	if ts.client_port > 0 {
		result += ';client_port=${ts.client_port}-${ts.client_port + 1}'
	}
	if ts.server_port > 0 {
		result += ';server_port=${ts.server_port}-${ts.server_port + 1}'
	}
	if ts.ssrc.len > 0 {
		result += ';ssrc=${ts.ssrc}'
	}
	return result
}

// Session represents an active RTSP streaming session.
pub struct Session {
pub:
	// id is the unique session identifier.
	id string
	// url is the stream URL this session is bound to.
	url string
pub mut:
	// transport holds the negotiated transport parameters.
	transport TransportSpec
	// state is the current session lifecycle state.
	state SessionState
}

// RtspRequest represents an RTSP request message.
pub struct RtspRequest {
pub:
	// method is the RTSP method.
	method Method
	// url is the request URL.
	url string
	// cseq is the command sequence number.
	cseq int
	// headers holds additional request headers.
	headers map[string]string
	// body is the optional request body.
	body string
}

// RtspResponse represents an RTSP response message.
pub struct RtspResponse {
pub:
	// status_code is the three-digit RTSP status code.
	status_code int
	// cseq echoes the request's CSeq value.
	cseq int
	// headers holds response headers.
	headers map[string]string
	// body is the optional response body.
	body string
}

// RtspServer holds the state for an RTSP server instance.
pub struct RtspServer {
pub:
	// port is the TCP port the server listens on (default 554).
	port int
pub mut:
	// sessions holds active sessions by ID.
	sessions map[string]Session
	// streams holds available stream descriptions by URL.
	streams map[string]string
}

// new_server creates a new RtspServer on the given port.
pub fn new_server(port int) &RtspServer {
	return &RtspServer{
		port: port
	}
}

// generate_session_id creates a unique session identifier.
fn generate_session_id() string {
	bytes := rand.bytes(8) or { return 'session-fallback' }
	mut hex := ''
	for b in bytes {
		hex += '${b:02x}'
	}
	return hex
}

// describe_stream returns the SDP description for the given stream URL.
// Returns an error if the stream is not registered.
pub fn (s RtspServer) describe_stream(url string, cseq int) !RtspResponse {
	sdp := s.streams[url] or { return error('stream not found: ${url}') }
	return RtspResponse{
		status_code: 200
		cseq: cseq
		headers: {
			'Content-Type': 'application/sdp'
		}
		body: sdp
	}
}

// setup_session creates a new streaming session for the given URL with
// the specified transport parameters.
pub fn (mut s RtspServer) setup_session(url string, transport TransportSpec, cseq int) !RtspResponse {
	if url !in s.streams {
		return error('stream not found: ${url}')
	}
	session_id := generate_session_id()
	s.sessions[session_id] = Session{
		id: session_id
		url: url
		transport: transport
		state: .ready
	}
	return RtspResponse{
		status_code: 200
		cseq: cseq
		headers: {
			'Session':   session_id
			'Transport': format_transport(transport)
		}
	}
}

// play transitions a session to the Playing state.
pub fn (mut s RtspServer) play(session_id string, cseq int) !RtspResponse {
	if session_id !in s.sessions {
		return error('session not found: ${session_id}')
	}
	mut session := &s.sessions[session_id]
	if session.state != .ready && session.state != .recording {
		return error('session ${session_id} cannot play from state ${state_to_string(session.state)}')
	}
	session.state = .playing
	return RtspResponse{
		status_code: 200
		cseq: cseq
		headers: {
			'Session': session_id
		}
	}
}

// pause transitions a playing session to the Ready state.
pub fn (mut s RtspServer) pause(session_id string, cseq int) !RtspResponse {
	if session_id !in s.sessions {
		return error('session not found: ${session_id}')
	}
	mut session := &s.sessions[session_id]
	if session.state != .playing && session.state != .recording {
		return error('session ${session_id} cannot pause from state ${state_to_string(session.state)}')
	}
	session.state = .ready
	return RtspResponse{
		status_code: 200
		cseq: cseq
		headers: {
			'Session': session_id
		}
	}
}

// teardown ends a session and removes it from the server.
pub fn (mut s RtspServer) teardown(session_id string, cseq int) !RtspResponse {
	if session_id !in s.sessions {
		return error('session not found: ${session_id}')
	}
	s.sessions.delete(session_id)
	return RtspResponse{
		status_code: 200
		cseq: cseq
		headers: {
			'Session': session_id
		}
	}
}
