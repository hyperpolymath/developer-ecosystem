// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// ospf_test -- Protocol conformance tests for v_ospf.
// Covers router creation, area management, interface addition, Hello
// processing, LSA installation, SPF calculation, and routing table generation.
module v_ospf

// test_packet_type_to_string verifies human-readable labels for all
// OSPF packet types.
fn test_packet_type_to_string() {
	assert packet_type_to_string(.hello) == 'Hello'
	assert packet_type_to_string(.db_description) == 'Database Description'
	assert packet_type_to_string(.link_state_request) == 'Link State Request'
	assert packet_type_to_string(.link_state_update) == 'Link State Update'
	assert packet_type_to_string(.link_state_ack) == 'Link State Acknowledgement'
}

// test_lsa_type_to_string verifies human-readable labels for all LSA types.
fn test_lsa_type_to_string() {
	assert lsa_type_to_string(.router) == 'Router LSA'
	assert lsa_type_to_string(.network) == 'Network LSA'
	assert lsa_type_to_string(.summary) == 'Summary LSA'
	assert lsa_type_to_string(.external) == 'AS External LSA'
}

// test_new_router verifies that a new router initialises correctly.
fn test_new_router() {
	r := new_router('1.1.1.1')
	assert r.router_id == '1.1.1.1'
	assert r.area_count() == 0
	assert r.total_lsa_count() == 0
}

// test_add_area verifies area addition.
fn test_add_area() {
	mut r := new_router('1.1.1.1')
	r.add_area(Area{
		id: '0.0.0.0'
	})
	assert r.area_count() == 1
	found := r.find_area('0.0.0.0')!
	assert found.id == '0.0.0.0'
}

// test_find_area_missing verifies error for unknown area.
fn test_find_area_missing() {
	r := new_router('1.1.1.1')
	r.find_area('1.2.3.4') or {
		assert err.msg().contains('area not found')
		return
	}
	assert false, 'expected error for missing area'
}

// test_add_interface verifies interface addition to an area.
fn test_add_interface() {
	mut r := new_router('1.1.1.1')
	r.add_area(Area{
		id: '0.0.0.0'
	})
	r.add_interface(Interface{
		name: 'eth0'
		ip_address: '10.0.0.1'
		mask: 24
		cost: 10
		area_id: '0.0.0.0'
	})!
	area := r.find_area('0.0.0.0')!
	assert area.interfaces.len == 1
	assert area.interfaces[0].name == 'eth0'
}

// test_add_interface_bad_area verifies error for wrong area.
fn test_add_interface_bad_area() {
	mut r := new_router('1.1.1.1')
	r.add_interface(Interface{
		name: 'eth0'
		ip_address: '10.0.0.1'
		mask: 24
		area_id: 'nonexistent'
	}) or {
		assert err.msg().contains('area not found')
		return
	}
	assert false, 'expected error for missing area'
}

// test_process_hello_new_neighbor verifies that a new neighbor is added
// in Init state.
fn test_process_hello_new_neighbor() {
	mut r := new_router('1.1.1.1')
	r.add_area(Area{
		id: '0.0.0.0'
	})
	r.process_hello('0.0.0.0', '2.2.2.2', '10.0.0.2', 1)!
	area := r.find_area('0.0.0.0')!
	assert area.neighbors.len == 1
	assert area.neighbors[0].router_id == '2.2.2.2'
	assert area.neighbors[0].state == .init
}

// test_process_hello_advance_state verifies that a second Hello advances
// a neighbor from Init to TwoWay.
fn test_process_hello_advance_state() {
	mut r := new_router('1.1.1.1')
	r.add_area(Area{
		id: '0.0.0.0'
	})
	r.process_hello('0.0.0.0', '2.2.2.2', '10.0.0.2', 1)!
	r.process_hello('0.0.0.0', '2.2.2.2', '10.0.0.2', 1)!
	area := r.find_area('0.0.0.0')!
	assert area.neighbors.len == 1
	assert area.neighbors[0].state == .two_way
}

// test_install_lsa verifies LSA installation and replacement.
fn test_install_lsa() {
	mut r := new_router('1.1.1.1')
	r.add_area(Area{
		id: '0.0.0.0'
	})
	r.install_lsa('0.0.0.0', Lsa{
		lsa_type: .router
		link_state_id: '1.1.1.1'
		advertising_router: '1.1.1.1'
		sequence_number: 1
		metric: 10
		links: ['2.2.2.2']
	})!
	assert r.total_lsa_count() == 1

	// Replace with higher sequence number
	r.install_lsa('0.0.0.0', Lsa{
		lsa_type: .router
		link_state_id: '1.1.1.1'
		advertising_router: '1.1.1.1'
		sequence_number: 2
		metric: 5
		links: ['2.2.2.2', '3.3.3.3']
	})!
	assert r.total_lsa_count() == 1 // replaced, not added
}

// test_calculate_spf verifies Dijkstra SPF computation on a simple
// three-node topology.
fn test_calculate_spf() {
	mut r := new_router('1.1.1.1')
	r.add_area(Area{
		id: '0.0.0.0'
	})
	// Topology: 1.1.1.1 --10--> 2.2.2.2 --5--> 3.3.3.3
	r.install_lsa('0.0.0.0', Lsa{
		lsa_type: .router
		link_state_id: '1.1.1.1'
		advertising_router: '1.1.1.1'
		sequence_number: 1
		metric: 10
		links: ['2.2.2.2']
	})!
	r.install_lsa('0.0.0.0', Lsa{
		lsa_type: .router
		link_state_id: '2.2.2.2'
		advertising_router: '2.2.2.2'
		sequence_number: 1
		metric: 5
		links: ['3.3.3.3']
	})!

	r.calculate_spf('0.0.0.0')!
	table := r.get_routing_table()
	assert table.len == 2

	// Find route to 3.3.3.3 -- should go via 2.2.2.2 with cost 15
	for entry in table {
		if entry.destination == '3.3.3.3' {
			assert entry.next_hop == '2.2.2.2'
			assert entry.cost == 15
		}
	}
}

// test_get_routing_table_empty verifies empty table for new router.
fn test_get_routing_table_empty() {
	r := new_router('1.1.1.1')
	assert r.get_routing_table().len == 0
}
