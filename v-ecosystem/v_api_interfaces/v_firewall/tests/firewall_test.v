// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_firewall.
// Validates zone management, rule CRUD operations, packet evaluation,
// CIDR parsing, and priority ordering.
module main

import v_firewall
import time

// test_new_server_creates_empty verifies that a new firewall server
// has no zones or rulesets configured.
fn test_new_server_creates_empty() {
	server := v_firewall.new_server(9090)
	assert server.port == 9090
	assert server.zones.len == 0
	assert server.rulesets.len == 0
}

// test_add_zone verifies that zones can be added to the server.
fn test_add_zone() {
	mut server := v_firewall.new_server(9090)
	zone := v_firewall.Zone{
		name: 'public'
		interfaces: ['eth0', 'eth1']
		description: 'Public-facing network zone'
	}
	server.add_zone(zone)
	assert 'public' in server.zones
	assert server.zones['public'] or { return }.interfaces.len == 2
}

// test_add_rule_to_zone verifies that rules can be added to an
// existing zone.
fn test_add_rule_to_zone() {
	mut server := v_firewall.new_server(9090)
	server.add_zone(v_firewall.Zone{name: 'dmz'})
	rule := v_firewall.FirewallRule{
		id: 'rule-001'
		name: 'Allow SSH'
		direction: .inbound
		protocol: .tcp
		dest_port: 22
		action: .accept
		priority: 100
		state: .active
		created_at: time.now()
	}
	server.add_rule('dmz', rule) or {
		assert false, 'add_rule failed: ${err}'
		return
	}
	rules := server.list_rules('dmz')
	assert rules.len == 1
	assert rules[0].id == 'rule-001'
	assert rules[0].action == .accept
}

// test_add_rule_nonexistent_zone_returns_error verifies that adding
// a rule to a nonexistent zone fails.
fn test_add_rule_nonexistent_zone_returns_error() {
	mut server := v_firewall.new_server(9090)
	rule := v_firewall.FirewallRule{
		id: 'rule-001'
		name: 'Test'
		direction: .inbound
		protocol: .tcp
		action: .accept
		priority: 100
		state: .active
	}
	server.add_rule('nonexistent', rule) or {
		assert err.msg().contains('zone not found')
		return
	}
	assert false, 'expected error for nonexistent zone'
}

// test_add_duplicate_rule_returns_error verifies that adding a rule
// with a duplicate id fails.
fn test_add_duplicate_rule_returns_error() {
	mut server := v_firewall.new_server(9090)
	server.add_zone(v_firewall.Zone{name: 'test'})
	rule := v_firewall.FirewallRule{
		id: 'rule-001'
		name: 'Test'
		direction: .inbound
		protocol: .tcp
		action: .accept
		priority: 100
		state: .active
	}
	server.add_rule('test', rule) or {
		assert false, 'first add failed: ${err}'
		return
	}
	server.add_rule('test', rule) or {
		assert err.msg().contains('duplicate')
		return
	}
	assert false, 'expected error for duplicate rule'
}

// test_remove_rule verifies that rules can be removed from a zone.
fn test_remove_rule() {
	mut server := v_firewall.new_server(9090)
	server.add_zone(v_firewall.Zone{name: 'test'})
	server.add_rule('test', v_firewall.FirewallRule{
		id: 'rule-001'
		name: 'Test'
		direction: .inbound
		protocol: .tcp
		action: .accept
		priority: 100
		state: .active
	}) or { return }
	server.remove_rule('test', 'rule-001') or {
		assert false, 'remove failed: ${err}'
		return
	}
	assert server.list_rules('test').len == 0
}

// test_enable_disable_rule verifies rule state transitions.
fn test_enable_disable_rule() {
	mut server := v_firewall.new_server(9090)
	server.add_zone(v_firewall.Zone{name: 'test'})
	server.add_rule('test', v_firewall.FirewallRule{
		id: 'rule-001'
		name: 'Test'
		direction: .inbound
		protocol: .tcp
		action: .accept
		priority: 100
		state: .active
	}) or { return }
	server.disable_rule('test', 'rule-001') or {
		assert false, 'disable failed: ${err}'
		return
	}
	rules := server.list_rules('test')
	assert rules[0].state == .disabled

	server.enable_rule('test', 'rule-001') or {
		assert false, 'enable failed: ${err}'
		return
	}
	rules2 := server.list_rules('test')
	assert rules2[0].state == .active
}

// test_evaluate_matching_rule verifies that packet evaluation returns
// the correct action for a matching rule.
fn test_evaluate_matching_rule() {
	mut server := v_firewall.new_server(9090)
	server.add_zone(v_firewall.Zone{name: 'public'})
	server.add_rule('public', v_firewall.FirewallRule{
		id: 'allow-http'
		name: 'Allow HTTP'
		direction: .inbound
		protocol: .tcp
		dest_port: 80
		action: .accept
		priority: 100
		state: .active
	}) or { return }
	packet := v_firewall.PacketInfo{
		source_addr: '203.0.113.10'
		source_port: 54321
		dest_addr: '10.0.0.1'
		dest_port: 80
		protocol: .tcp
		direction: .inbound
	}
	result := server.evaluate(packet)
	assert result == .accept
}

// test_evaluate_no_match_returns_drop verifies that unmatched packets
// receive the default drop action.
fn test_evaluate_no_match_returns_drop() {
	mut server := v_firewall.new_server(9090)
	server.add_zone(v_firewall.Zone{name: 'public'})
	server.add_rule('public', v_firewall.FirewallRule{
		id: 'allow-http'
		name: 'Allow HTTP'
		direction: .inbound
		protocol: .tcp
		dest_port: 80
		action: .accept
		priority: 100
		state: .active
	}) or { return }
	packet := v_firewall.PacketInfo{
		source_addr: '203.0.113.10'
		source_port: 54321
		dest_addr: '10.0.0.1'
		dest_port: 443
		protocol: .tcp
		direction: .inbound
	}
	result := server.evaluate(packet)
	assert result == .drop
}

// test_evaluate_disabled_rule_skipped verifies that disabled rules
// are not matched during packet evaluation.
fn test_evaluate_disabled_rule_skipped() {
	mut server := v_firewall.new_server(9090)
	server.add_zone(v_firewall.Zone{name: 'test'})
	server.add_rule('test', v_firewall.FirewallRule{
		id: 'disabled-rule'
		name: 'Disabled'
		direction: .inbound
		protocol: .any
		action: .accept
		priority: 1
		state: .disabled
	}) or { return }
	packet := v_firewall.PacketInfo{
		source_addr: '10.0.0.1'
		source_port: 1234
		dest_addr: '10.0.0.2'
		dest_port: 80
		protocol: .tcp
		direction: .inbound
	}
	result := server.evaluate(packet)
	assert result == .drop
}

// test_evaluate_cidr_match verifies that CIDR source addresses are
// correctly matched during packet evaluation.
fn test_evaluate_cidr_match() {
	mut server := v_firewall.new_server(9090)
	server.add_zone(v_firewall.Zone{name: 'internal'})
	server.add_rule('internal', v_firewall.FirewallRule{
		id: 'allow-subnet'
		name: 'Allow 10.0.0.0/24'
		direction: .inbound
		protocol: .any
		source_addr: '10.0.0.0/24'
		action: .accept
		priority: 50
		state: .active
	}) or { return }
	// Packet from within the subnet should match.
	packet_in := v_firewall.PacketInfo{
		source_addr: '10.0.0.42'
		dest_addr: '192.168.1.1'
		dest_port: 80
		protocol: .tcp
		direction: .inbound
	}
	assert server.evaluate(packet_in) == .accept

	// Packet from outside the subnet should not match.
	packet_out := v_firewall.PacketInfo{
		source_addr: '10.0.1.42'
		dest_addr: '192.168.1.1'
		dest_port: 80
		protocol: .tcp
		direction: .inbound
	}
	assert server.evaluate(packet_out) == .drop
}

// test_parse_cidr_valid verifies parsing of a valid CIDR string.
fn test_parse_cidr_valid() {
	addr, prefix := v_firewall.parse_cidr('192.168.1.0/24') or {
		assert false, 'parse failed: ${err}'
		return
	}
	assert addr == '192.168.1.0'
	assert prefix == 24
}

// test_parse_cidr_no_slash_returns_error verifies that a plain IP
// without a prefix length produces an error.
fn test_parse_cidr_no_slash_returns_error() {
	v_firewall.parse_cidr('192.168.1.0') or {
		assert err.msg().contains('missing /')
		return
	}
	assert false, 'expected error for missing /'
}

// test_parse_cidr_invalid_prefix verifies rejection of out-of-range
// prefix lengths.
fn test_parse_cidr_invalid_prefix() {
	v_firewall.parse_cidr('10.0.0.0/200') or {
		assert err.msg().contains('invalid CIDR prefix')
		return
	}
	assert false, 'expected error for invalid prefix'
}

// test_priority_ordering verifies that rules with lower priority
// numbers are evaluated first.
fn test_priority_ordering() {
	mut server := v_firewall.new_server(9090)
	server.add_zone(v_firewall.Zone{name: 'test'})
	// Add high-priority drop rule.
	server.add_rule('test', v_firewall.FirewallRule{
		id: 'drop-all'
		name: 'Drop all'
		direction: .inbound
		protocol: .any
		action: .drop
		priority: 10
		state: .active
	}) or { return }
	// Add lower-priority accept rule.
	server.add_rule('test', v_firewall.FirewallRule{
		id: 'allow-http'
		name: 'Allow HTTP'
		direction: .inbound
		protocol: .tcp
		dest_port: 80
		action: .accept
		priority: 100
		state: .active
	}) or { return }
	// The drop rule (priority 10) should match first.
	packet := v_firewall.PacketInfo{
		source_addr: '10.0.0.1'
		dest_addr: '10.0.0.2'
		dest_port: 80
		protocol: .tcp
		direction: .inbound
	}
	assert server.evaluate(packet) == .drop
}

// test_list_rules_empty_zone verifies that listing rules for a
// nonexistent zone returns an empty list.
fn test_list_rules_empty_zone() {
	server := v_firewall.new_server(9090)
	rules := server.list_rules('nonexistent')
	assert rules.len == 0
}
