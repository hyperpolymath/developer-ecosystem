// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// rtsp_test -- Protocol conformance tests for v_rtsp.
// Covers method labels, transport parsing/formatting, session lifecycle,
// and server operations.
module v_rtsp

// test_method_to_string verifies RTSP wire keywords for all methods.
fn test_method_to_string() {
	assert method_to_string(.describe) == 'DESCRIBE'
	assert method_to_string(.announce) == 'ANNOUNCE'
	assert method_to_string(.setup) == 'SETUP'
	assert method_to_string(.play) == 'PLAY'
	assert method_to_string(.pause) == 'PAUSE'
	assert method_to_string(.teardown) == 'TEARDOWN'
	assert method_to_string(.get_parameter) == 'GET_PARAMETER'
	assert method_to_string(.set_parameter) == 'SET_PARAMETER'
	assert method_to_string(.record) == 'RECORD'
	assert method_to_string(.options) == 'OPTIONS'
}

// test_state_to_string verifies session state labels.
fn test_state_to_string() {
	assert state_to_string(.init) == 'Init'
	assert state_to_string(.ready) == 'Ready'
	assert state_to_string(.playing) == 'Playing'
	assert state_to_string(.recording) == 'Recording'
}

// test_parse_transport verifies transport header parsing.
fn test_parse_transport() {
	ts := parse_transport('RTP/AVP;unicast;client_port=8000-8001;server_port=9000-9001;ssrc=ABCD1234')!
	assert ts.protocol == 'RTP'
	assert ts.profile == 'AVP'
	assert ts.unicast == true
	assert ts.client_port == 8000
	assert ts.server_port == 9000
	assert ts.ssrc == 'ABCD1234'
}

// test_parse_transport_multicast verifies multicast transport parsing.
fn test_parse_transport_multicast() {
	ts := parse_transport('RTP/AVP;multicast;client_port=5000')!
	assert ts.unicast == false
	assert ts.client_port == 5000
}

// test_parse_transport_empty verifies rejection of empty header.
fn test_parse_transport_empty() {
	parse_transport('') or {
		assert err.msg().contains('empty')
		return
	}
	assert false, 'expected error for empty transport'
}

// test_format_transport verifies transport header serialisation.
fn test_format_transport() {
	ts := TransportSpec{
		protocol: 'RTP'
		profile: 'AVP'
		unicast: true
		client_port: 8000
		server_port: 9000
		ssrc: 'ABCD1234'
	}
	formatted := format_transport(ts)
	assert formatted.contains('RTP/AVP')
	assert formatted.contains('unicast')
	assert formatted.contains('client_port=8000-8001')
	assert formatted.contains('server_port=9000-9001')
	assert formatted.contains('ssrc=ABCD1234')
}

// test_parse_format_transport_roundtrip verifies transport roundtrip.
fn test_parse_format_transport_roundtrip() {
	original := 'RTP/AVP;unicast;client_port=8000-8001;server_port=9000-9001;ssrc=DEAD'
	parsed := parse_transport(original)!
	formatted := format_transport(parsed)
	reparsed := parse_transport(formatted)!
	assert reparsed.protocol == parsed.protocol
	assert reparsed.profile == parsed.profile
	assert reparsed.unicast == parsed.unicast
	assert reparsed.client_port == parsed.client_port
	assert reparsed.server_port == parsed.server_port
	assert reparsed.ssrc == parsed.ssrc
}

// helper_server creates a server with one registered stream.
fn helper_server() &RtspServer {
	mut server := new_server(554)
	server.streams['rtsp://example.com/stream1'] = 'v=0\r\nm=video 0 RTP/AVP 96\r\n'
	return server
}

// test_describe_stream verifies stream description retrieval.
fn test_describe_stream() {
	server := helper_server()
	resp := server.describe_stream('rtsp://example.com/stream1', 1)!
	assert resp.status_code == 200
	assert resp.cseq == 1
	assert resp.headers['Content-Type'] == 'application/sdp'
	assert resp.body.contains('m=video')
}

// test_describe_stream_not_found verifies error for missing stream.
fn test_describe_stream_not_found() {
	server := helper_server()
	server.describe_stream('rtsp://example.com/missing', 1) or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing stream'
}

// test_setup_session verifies session creation.
fn test_setup_session() {
	mut server := helper_server()
	transport := TransportSpec{
		protocol: 'RTP'
		profile: 'AVP'
		unicast: true
		client_port: 8000
	}
	resp := server.setup_session('rtsp://example.com/stream1', transport, 2)!
	assert resp.status_code == 200
	assert resp.cseq == 2
	assert 'Session' in resp.headers
	session_id := resp.headers['Session']
	assert session_id in server.sessions
	assert server.sessions[session_id].state == .ready
}

// test_play verifies transition to playing state.
fn test_play() {
	mut server := helper_server()
	transport := TransportSpec{ protocol: 'RTP', profile: 'AVP', unicast: true }
	setup_resp := server.setup_session('rtsp://example.com/stream1', transport, 1)!
	session_id := setup_resp.headers['Session']
	resp := server.play(session_id, 2)!
	assert resp.status_code == 200
	assert server.sessions[session_id].state == .playing
}

// test_pause verifies transition from playing to ready.
fn test_pause() {
	mut server := helper_server()
	transport := TransportSpec{ protocol: 'RTP', profile: 'AVP', unicast: true }
	setup_resp := server.setup_session('rtsp://example.com/stream1', transport, 1)!
	session_id := setup_resp.headers['Session']
	_ := server.play(session_id, 2)!
	resp := server.pause(session_id, 3)!
	assert resp.status_code == 200
	assert server.sessions[session_id].state == .ready
}

// test_teardown verifies session removal.
fn test_teardown() {
	mut server := helper_server()
	transport := TransportSpec{ protocol: 'RTP', profile: 'AVP', unicast: true }
	setup_resp := server.setup_session('rtsp://example.com/stream1', transport, 1)!
	session_id := setup_resp.headers['Session']
	resp := server.teardown(session_id, 2)!
	assert resp.status_code == 200
	assert session_id !in server.sessions
}

// test_play_not_ready verifies error for playing from wrong state.
fn test_play_not_ready() {
	mut server := helper_server()
	transport := TransportSpec{ protocol: 'RTP', profile: 'AVP', unicast: true }
	setup_resp := server.setup_session('rtsp://example.com/stream1', transport, 1)!
	session_id := setup_resp.headers['Session']
	_ := server.play(session_id, 2)!
	// Already playing, can't play again
	server.play(session_id, 3) or {
		assert err.msg().contains('cannot play')
		return
	}
	assert false, 'expected error for playing from Playing state'
}

// test_session_not_found verifies error for missing session.
fn test_session_not_found() {
	mut server := helper_server()
	server.play('nonexistent', 1) or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing session'
}
