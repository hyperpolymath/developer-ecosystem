// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// bfd_test -- Protocol conformance tests for v_bfd.
// Covers server creation, session lifecycle, state machine transitions,
// interval negotiation, detection time computation, and admin-down.
module v_bfd

// test_session_state_to_string verifies human-readable labels for all
// BFD session states.
fn test_session_state_to_string() {
	assert session_state_to_string(.admin_down) == 'AdminDown'
	assert session_state_to_string(.down) == 'Down'
	assert session_state_to_string(.init) == 'Init'
	assert session_state_to_string(.up) == 'Up'
}

// test_diagnostic_to_string verifies human-readable labels for all
// BFD diagnostic codes.
fn test_diagnostic_to_string() {
	assert diagnostic_to_string(.none) == 'No Diagnostic'
	assert diagnostic_to_string(.control_expired) == 'Control Detection Time Expired'
	assert diagnostic_to_string(.echo_failed) == 'Echo Function Failed'
	assert diagnostic_to_string(.neighbor_down) == 'Neighbor Signaled Session Down'
	assert diagnostic_to_string(.forwarding_reset) == 'Forwarding Plane Reset'
	assert diagnostic_to_string(.path_down) == 'Path Down'
}

// test_new_server verifies server creation with correct defaults.
fn test_new_server() {
	s := new_server(3784)
	assert s.listen_port == 3784
	assert s.session_count() == 0
}

// test_create_session verifies session creation with correct parameters.
fn test_create_session() {
	mut s := new_server(3784)
	disc := s.create_session('10.0.0.2', 500_000, 500_000, 3)
	assert disc == 1
	assert s.session_count() == 1
	session := s.find_session(disc)!
	assert session.remote_addr == '10.0.0.2'
	assert session.state == .down
	assert session.detect_mult == 3
}

// test_state_transition_down_to_init verifies that receiving Down from
// remote transitions local from Down to Init.
fn test_state_transition_down_to_init() {
	mut s := new_server(3784)
	disc := s.create_session('10.0.0.2', 1_000_000, 1_000_000, 3)
	s.process_packet(disc, 100, .down, .none)!
	state, _ := s.get_session_state(disc)!
	assert state == .init
}

// test_state_transition_down_to_up verifies that receiving Init from
// remote transitions local from Down to Up.
fn test_state_transition_down_to_up() {
	mut s := new_server(3784)
	disc := s.create_session('10.0.0.2', 1_000_000, 1_000_000, 3)
	s.process_packet(disc, 100, .init, .none)!
	state, _ := s.get_session_state(disc)!
	assert state == .up
}

// test_state_transition_init_to_up verifies that receiving Init or Up
// from remote transitions local from Init to Up.
fn test_state_transition_init_to_up() {
	mut s := new_server(3784)
	disc := s.create_session('10.0.0.2', 1_000_000, 1_000_000, 3)
	// First: Down -> Init
	s.process_packet(disc, 100, .down, .none)!
	// Then: Init -> Up
	s.process_packet(disc, 100, .init, .none)!
	state, _ := s.get_session_state(disc)!
	assert state == .up
}

// test_state_transition_up_to_down verifies that receiving Down from
// remote transitions local from Up to Down with neighbor_down diagnostic.
fn test_state_transition_up_to_down() {
	mut s := new_server(3784)
	disc := s.create_session('10.0.0.2', 1_000_000, 1_000_000, 3)
	// Get to Up state
	s.process_packet(disc, 100, .init, .none)!
	state1, _ := s.get_session_state(disc)!
	assert state1 == .up
	// Remote goes down
	s.process_packet(disc, 100, .down, .path_down)!
	state2, diag := s.get_session_state(disc)!
	assert state2 == .down
	assert diag == .neighbor_down
}

// test_detection_time verifies detection time calculation.
fn test_detection_time() {
	session := BfdSession{
		local_disc: 1
		remote_addr: '10.0.0.2'
		detect_mult: 3
		local_min_tx: 1_000_000
		remote_min_rx: 500_000
	}
	// Detection time = 3 * max(1_000_000, 500_000) = 3_000_000
	assert session.detection_time() == 3_000_000
}

// test_set_intervals verifies interval update and renegotiation.
fn test_set_intervals() {
	mut s := new_server(3784)
	disc := s.create_session('10.0.0.2', 1_000_000, 1_000_000, 3)
	s.set_intervals(disc, 500_000, 300_000)!
	session := s.find_session(disc)!
	assert session.desired_min_tx == 500_000
	assert session.required_min_rx == 300_000
}

// test_admin_down verifies that admin_down forces a session to AdminDown.
fn test_admin_down() {
	mut s := new_server(3784)
	disc := s.create_session('10.0.0.2', 1_000_000, 1_000_000, 3)
	s.admin_down(disc)!
	state, _ := s.get_session_state(disc)!
	assert state == .admin_down
}

// test_find_session_missing verifies error for unknown discriminator.
fn test_find_session_missing() {
	s := new_server(3784)
	s.find_session(999) or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing session'
}

// test_multiple_sessions verifies managing multiple concurrent sessions.
fn test_multiple_sessions() {
	mut s := new_server(3784)
	d1 := s.create_session('10.0.0.2', 1_000_000, 1_000_000, 3)
	d2 := s.create_session('10.0.0.3', 500_000, 500_000, 5)
	assert s.session_count() == 2
	assert d1 != d2
}
