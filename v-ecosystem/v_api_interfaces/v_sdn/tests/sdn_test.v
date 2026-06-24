// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// sdn_test -- Protocol conformance tests for v_sdn.
// Covers controller creation, flow rule management, packet matching,
// statistics tracking, and topology discovery.
module v_sdn

// test_flow_action_to_string verifies human-readable labels for all
// SDN flow actions.
fn test_flow_action_to_string() {
	assert flow_action_to_string(.forward) == 'FORWARD'
	assert flow_action_to_string(.drop) == 'DROP'
	assert flow_action_to_string(.flood) == 'FLOOD'
	assert flow_action_to_string(.controller) == 'CONTROLLER'
	assert flow_action_to_string(.set_field) == 'SET_FIELD'
	assert flow_action_to_string(.push_vlan) == 'PUSH_VLAN'
	assert flow_action_to_string(.pop_vlan) == 'POP_VLAN'
}

// test_match_field_to_string verifies human-readable labels for all
// match field types.
fn test_match_field_to_string() {
	assert match_field_to_string(.in_port) == 'IN_PORT'
	assert match_field_to_string(.eth_src) == 'ETH_SRC'
	assert match_field_to_string(.ip_dst) == 'IP_DST'
	assert match_field_to_string(.protocol) == 'PROTOCOL'
}

// test_new_controller verifies controller creation with default table.
fn test_new_controller() {
	c := new_controller('ctrl-1')
	assert c.controller_id == 'ctrl-1'
	assert c.table_count() == 1
}

// test_add_flow verifies flow rule installation.
fn test_add_flow() {
	mut c := new_controller('ctrl-1')
	c.add_flow(0, FlowRule{
		priority: 100
		match_fields: [FieldMatch{
			field: .ip_dst
			value: '10.0.0.1'
		}]
		actions: [.forward]
		cookie: 1
	})!
	stats := c.get_stats(0)!
	assert stats.rule_count == 1
}

// test_add_flow_priority_order verifies that rules are stored in
// descending priority order.
fn test_add_flow_priority_order() {
	mut c := new_controller('ctrl-1')
	c.add_flow(0, FlowRule{
		priority: 50
		match_fields: []
		actions: [.drop]
		cookie: 1
	})!
	c.add_flow(0, FlowRule{
		priority: 200
		match_fields: []
		actions: [.forward]
		cookie: 2
	})!
	c.add_flow(0, FlowRule{
		priority: 100
		match_fields: []
		actions: [.controller]
		cookie: 3
	})!
	assert c.tables[0].rules[0].priority == 200
	assert c.tables[0].rules[1].priority == 100
	assert c.tables[0].rules[2].priority == 50
}

// test_remove_flow verifies flow rule removal by cookie.
fn test_remove_flow() {
	mut c := new_controller('ctrl-1')
	c.add_flow(0, FlowRule{
		priority: 100
		match_fields: []
		actions: [.forward]
		cookie: 42
	})!
	removed := c.remove_flow(0, 42)!
	assert removed == true
	stats := c.get_stats(0)!
	assert stats.rule_count == 0
}

// test_remove_flow_nonexistent verifies that removing a missing cookie
// returns false.
fn test_remove_flow_nonexistent() {
	mut c := new_controller('ctrl-1')
	removed := c.remove_flow(0, 999)!
	assert removed == false
}

// test_match_packet verifies single-field packet matching.
fn test_match_packet() {
	mut c := new_controller('ctrl-1')
	c.add_flow(0, FlowRule{
		priority: 100
		match_fields: [FieldMatch{
			field: .ip_dst
			value: '10.0.0.1'
		}]
		actions: [.forward]
		cookie: 1
	})!
	pkt := Packet{
		ip_dst: '10.0.0.1'
		size: 1500
	}
	actions := c.match_packet(0, pkt)!
	assert actions.len == 1
	assert actions[0] == .forward
}

// test_match_packet_multi_field verifies multi-field matching.
fn test_match_packet_multi_field() {
	mut c := new_controller('ctrl-1')
	c.add_flow(0, FlowRule{
		priority: 100
		match_fields: [
			FieldMatch{
				field: .ip_src
				value: '192.168.1.1'
			},
			FieldMatch{
				field: .tcp_dst
				value: '80'
			},
		]
		actions: [.forward]
		cookie: 1
	})!
	// Matching packet
	pkt := Packet{
		ip_src: '192.168.1.1'
		tcp_dst: '80'
		size: 100
	}
	actions := c.match_packet(0, pkt)!
	assert actions.len == 1

	// Non-matching packet (wrong source)
	pkt2 := Packet{
		ip_src: '10.0.0.1'
		tcp_dst: '80'
		size: 100
	}
	actions2 := c.match_packet(0, pkt2)!
	assert actions2.len == 0
}

// test_match_packet_stats verifies that packet/byte counters update
// on match.
fn test_match_packet_stats() {
	mut c := new_controller('ctrl-1')
	c.add_flow(0, FlowRule{
		priority: 100
		match_fields: []
		actions: [.forward]
		cookie: 1
	})!
	c.match_packet(0, Packet{ size: 1000 })!
	c.match_packet(0, Packet{ size: 500 })!
	stats := c.get_stats(0)!
	assert stats.total_packets == 2
	assert stats.total_bytes == 1500
}

// test_topology_discovery verifies link addition and deduplication.
fn test_topology_discovery() {
	mut c := new_controller('ctrl-1')
	link := TopologyLink{
		src_switch: 'sw1'
		src_port: 'p1'
		dst_switch: 'sw2'
		dst_port: 'p1'
		bandwidth: 1000
	}
	c.topology_discovery(link)
	assert c.topology.len == 1
	// Duplicate should not be added
	c.topology_discovery(link)
	assert c.topology.len == 1
}

// test_add_table verifies additional flow table creation.
fn test_add_table() {
	mut c := new_controller('ctrl-1')
	c.add_table(1)
	assert c.table_count() == 2
	// Duplicate should not add
	c.add_table(1)
	assert c.table_count() == 2
}

// test_get_stats_bad_table verifies error for unknown table.
fn test_get_stats_bad_table() {
	c := new_controller('ctrl-1')
	c.get_stats(99) or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing table'
}
