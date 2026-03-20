// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// bgp_test -- Protocol conformance tests for v_bgp.
// Covers session creation, route announcement/withdrawal, best-path
// selection, peer management, and policy application.
module v_bgp

// test_message_type_to_string verifies human-readable labels for all
// BGP message types.
fn test_message_type_to_string() {
	assert message_type_to_string(.open) == 'OPEN'
	assert message_type_to_string(.update) == 'UPDATE'
	assert message_type_to_string(.notification) == 'NOTIFICATION'
	assert message_type_to_string(.keepalive) == 'KEEPALIVE'
	assert message_type_to_string(.route_refresh) == 'ROUTE-REFRESH'
}

// test_origin_to_string verifies human-readable labels for ORIGIN values.
fn test_origin_to_string() {
	assert origin_to_string(.igp) == 'IGP'
	assert origin_to_string(.egp) == 'EGP'
	assert origin_to_string(.incomplete) == 'INCOMPLETE'
}

// test_peer_state_to_string verifies human-readable labels for all peer states.
fn test_peer_state_to_string() {
	assert peer_state_to_string(.idle) == 'Idle'
	assert peer_state_to_string(.connect) == 'Connect'
	assert peer_state_to_string(.active) == 'Active'
	assert peer_state_to_string(.open_sent) == 'OpenSent'
	assert peer_state_to_string(.open_confirm) == 'OpenConfirm'
	assert peer_state_to_string(.established) == 'Established'
}

// test_new_session verifies that a new session initialises with empty
// RIB and no peers.
fn test_new_session() {
	s := new_session(65000, '10.0.0.1')
	assert s.local_asn == 65000
	assert s.router_id == '10.0.0.1'
	assert s.rib_size() == 0
	assert s.peer_count() == 0
}

// test_add_peer verifies peer addition and default state.
fn test_add_peer() {
	mut s := new_session(65000, '10.0.0.1')
	s.add_peer('10.0.0.2', 65001, 90)
	assert s.peer_count() == 1
	assert s.peers[0].addr == '10.0.0.2'
	assert s.peers[0].asn == 65001
	assert s.peers[0].state == .idle
}

// test_announce_route verifies that announcing a route adds it to the RIB.
fn test_announce_route() {
	mut s := new_session(65000, '10.0.0.1')
	route := Route{
		prefix: '10.1.0.0'
		mask: 24
		attributes: PathAttribute{
			origin: .igp
			as_path: [u32(65000)]
			next_hop: '10.0.0.1'
		}
		next_hop: '10.0.0.1'
	}
	s.announce_route(route)
	assert s.rib_size() == 1
	assert s.rib[0].prefix == '10.1.0.0'
}

// test_withdraw_route verifies that withdrawing a route removes it from the RIB.
fn test_withdraw_route() {
	mut s := new_session(65000, '10.0.0.1')
	s.announce_route(Route{
		prefix: '10.1.0.0'
		mask: 24
		attributes: PathAttribute{
			origin: .igp
			as_path: [u32(65000)]
			next_hop: '10.0.0.1'
		}
		next_hop: '10.0.0.1'
	})
	assert s.rib_size() == 1
	removed := s.withdraw_route('10.1.0.0', 24)
	assert removed == true
	assert s.rib_size() == 0
}

// test_withdraw_nonexistent verifies that withdrawing a missing route
// returns false.
fn test_withdraw_nonexistent() {
	mut s := new_session(65000, '10.0.0.1')
	removed := s.withdraw_route('10.1.0.0', 24)
	assert removed == false
}

// test_best_path_selection_local_pref verifies that highest LOCAL_PREF wins.
fn test_best_path_selection_local_pref() {
	mut s := new_session(65000, '10.0.0.1')
	s.announce_route(Route{
		prefix: '10.1.0.0'
		mask: 24
		attributes: PathAttribute{
			origin: .igp
			as_path: [u32(65001)]
			next_hop: '10.0.0.2'
			local_pref: 100
		}
		next_hop: '10.0.0.2'
	})
	s.announce_route(Route{
		prefix: '10.1.0.0'
		mask: 24
		attributes: PathAttribute{
			origin: .igp
			as_path: [u32(65002)]
			next_hop: '10.0.0.3'
			local_pref: 200
		}
		next_hop: '10.0.0.3'
	})
	best := s.best_path_selection('10.1.0.0', 24)!
	assert best.next_hop == '10.0.0.3'
	assert best.attributes.local_pref == 200
}

// test_best_path_selection_as_path_length verifies that shorter AS_PATH wins
// when LOCAL_PREF is equal.
fn test_best_path_selection_as_path_length() {
	mut s := new_session(65000, '10.0.0.1')
	s.announce_route(Route{
		prefix: '10.2.0.0'
		mask: 24
		attributes: PathAttribute{
			origin: .igp
			as_path: [u32(65001), 65002, 65003]
			next_hop: '10.0.0.2'
			local_pref: 100
		}
		next_hop: '10.0.0.2'
	})
	s.announce_route(Route{
		prefix: '10.2.0.0'
		mask: 24
		attributes: PathAttribute{
			origin: .igp
			as_path: [u32(65004)]
			next_hop: '10.0.0.4'
			local_pref: 100
		}
		next_hop: '10.0.0.4'
	})
	best := s.best_path_selection('10.2.0.0', 24)!
	assert best.next_hop == '10.0.0.4'
	assert best.attributes.as_path.len == 1
}

// test_best_path_selection_no_routes verifies error for missing prefix.
fn test_best_path_selection_no_routes() {
	s := new_session(65000, '10.0.0.1')
	s.best_path_selection('10.99.0.0', 24) or {
		assert err.msg().contains('no routes')
		return
	}
	assert false, 'expected error for missing routes'
}

// test_apply_policy_reject verifies that a reject policy blocks routes.
fn test_apply_policy_reject() {
	mut s := new_session(65000, '10.0.0.1')
	s.add_policy(PolicyRule{
		name: 'block-10.5'
		match_prefix: '10.5.0.0'
		match_mask: 24
		action: .reject
	})
	route := Route{
		prefix: '10.5.0.0'
		mask: 24
		attributes: PathAttribute{
			origin: .igp
			as_path: [u32(65001)]
			next_hop: '10.0.0.2'
		}
		next_hop: '10.0.0.2'
	}
	s.process_update([route], [])
	assert s.rib_size() == 0
}

// test_process_update_accept verifies that accepted routes are added to RIB.
fn test_process_update_accept() {
	mut s := new_session(65000, '10.0.0.1')
	route := Route{
		prefix: '10.6.0.0'
		mask: 24
		attributes: PathAttribute{
			origin: .igp
			as_path: [u32(65001)]
			next_hop: '10.0.0.2'
		}
		next_hop: '10.0.0.2'
	}
	s.process_update([route], [])
	assert s.rib_size() == 1
}

// test_established_peers verifies counting of established peers.
fn test_established_peers() {
	mut s := new_session(65000, '10.0.0.1')
	s.add_peer('10.0.0.2', 65001, 90)
	s.add_peer('10.0.0.3', 65002, 90)
	assert s.established_peers() == 0
	s.peers[0].state = .established
	assert s.established_peers() == 1
}
