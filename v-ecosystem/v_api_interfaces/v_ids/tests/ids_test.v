// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_ids.
// Validates engine creation, rule management, packet processing,
// alert generation, and statistics tracking.
module main

import v_ids

// test_new_engine_creates_empty verifies that a new IDS engine has
// no rules, alerts, or stats.
fn test_new_engine_creates_empty() {
	engine := v_ids.new_engine('test-ids')
	assert engine.name == 'test-ids'
	assert engine.rules.len == 0
	assert engine.alerts.len == 0
	assert engine.stats.packets_processed == 0
}

// test_add_rule verifies that rules can be added to the engine.
fn test_add_rule() {
	mut engine := v_ids.new_engine('test-ids')
	rule := v_ids.Rule{
		id: 'SID-1000001'
		severity: .high
		action: .alert
		pattern: '/etc/passwd'
		protocol: .tcp
		message: 'Possible path traversal'
	}
	engine.add_rule(rule) or {
		assert false, 'add_rule failed: ${err}'
		return
	}
	assert engine.rules.len == 1
	assert engine.rules[0].id == 'SID-1000001'
}

// test_add_rule_duplicate_returns_error verifies that duplicate rule
// IDs are rejected.
fn test_add_rule_duplicate_returns_error() {
	mut engine := v_ids.new_engine('test-ids')
	rule := v_ids.Rule{
		id: 'SID-001'
		severity: .medium
		action: .alert
		pattern: 'test'
		protocol: .any
		message: 'Test'
	}
	engine.add_rule(rule) or { return }
	engine.add_rule(rule) or {
		assert err.msg().contains('duplicate')
		return
	}
	assert false, 'expected error for duplicate rule'
}

// test_remove_rule verifies that rules can be removed by ID.
fn test_remove_rule() {
	mut engine := v_ids.new_engine('test-ids')
	engine.add_rule(v_ids.Rule{
		id: 'SID-001'
		severity: .low
		action: .log
		pattern: 'test'
		protocol: .any
		message: 'Test'
	}) or { return }
	engine.remove_rule('SID-001') or {
		assert false, 'remove failed: ${err}'
		return
	}
	assert engine.rules.len == 0
}

// test_remove_rule_nonexistent_returns_error verifies that removing
// a nonexistent rule fails.
fn test_remove_rule_nonexistent_returns_error() {
	mut engine := v_ids.new_engine('test-ids')
	engine.remove_rule('SID-999') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for nonexistent rule'
}

// test_load_rules verifies that load_rules replaces existing rules.
fn test_load_rules() {
	mut engine := v_ids.new_engine('test-ids')
	engine.add_rule(v_ids.Rule{
		id: 'old'
		severity: .info
		action: .pass
		protocol: .any
		message: 'Old rule'
	}) or { return }
	engine.load_rules([
		v_ids.Rule{
			id: 'new-1'
			severity: .high
			action: .alert
			pattern: 'malware'
			protocol: .tcp
			message: 'Malware detected'
		},
		v_ids.Rule{
			id: 'new-2'
			severity: .critical
			action: .drop
			pattern: 'exploit'
			protocol: .any
			message: 'Exploit attempt'
		},
	])
	assert engine.rules.len == 2
	assert engine.rules[0].id == 'new-1'
}

// test_process_packet_matching_rule verifies that a matching rule
// generates an alert.
fn test_process_packet_matching_rule() {
	mut engine := v_ids.new_engine('test-ids')
	engine.add_rule(v_ids.Rule{
		id: 'SID-100'
		severity: .critical
		action: .alert
		pattern: 'DROP TABLE'
		protocol: .tcp
		message: 'SQL injection attempt'
	}) or { return }
	packet := v_ids.PacketData{
		src_addr: '10.0.0.1'
		dst_addr: '10.0.0.2'
		src_port: 54321
		dst_port: 3306
		protocol: .tcp
		payload: "SELECT * FROM users; DROP TABLE users;--"
	}
	action := engine.process_packet(packet)
	assert action == .alert
	alerts := engine.get_alerts()
	assert alerts.len == 1
	assert alerts[0].rule_id == 'SID-100'
	assert alerts[0].severity == .critical
	assert alerts[0].src_addr == '10.0.0.1'
}

// test_process_packet_no_match verifies that packets not matching any
// rule receive the pass action.
fn test_process_packet_no_match() {
	mut engine := v_ids.new_engine('test-ids')
	engine.add_rule(v_ids.Rule{
		id: 'SID-100'
		severity: .high
		action: .alert
		pattern: 'malicious'
		protocol: .tcp
		message: 'Bad traffic'
	}) or { return }
	packet := v_ids.PacketData{
		src_addr: '10.0.0.1'
		dst_addr: '10.0.0.2'
		protocol: .tcp
		payload: 'normal traffic'
	}
	action := engine.process_packet(packet)
	assert action == .pass
	assert engine.get_alerts().len == 0
}

// test_process_packet_drop_action verifies that drop rules increment
// the dropped counter.
fn test_process_packet_drop_action() {
	mut engine := v_ids.new_engine('test-ids')
	engine.add_rule(v_ids.Rule{
		id: 'SID-200'
		severity: .critical
		action: .drop
		pattern: 'exploit'
		protocol: .any
		message: 'Exploit blocked'
	}) or { return }
	packet := v_ids.PacketData{
		src_addr: '203.0.113.1'
		dst_addr: '10.0.0.1'
		protocol: .udp
		payload: 'exploit-payload-here'
	}
	action := engine.process_packet(packet)
	assert action == .drop
	stats := engine.get_stats()
	assert stats.packets_dropped == 1
	assert stats.packets_processed == 1
}

// test_process_packet_disabled_rule_skipped verifies that disabled
// rules do not match.
fn test_process_packet_disabled_rule_skipped() {
	mut engine := v_ids.new_engine('test-ids')
	mut rule := v_ids.Rule{
		id: 'SID-300'
		severity: .high
		action: .alert
		pattern: 'attack'
		protocol: .any
		message: 'Attack detected'
	}
	rule.enabled = false
	engine.add_rule(rule) or { return }
	packet := v_ids.PacketData{
		src_addr: '10.0.0.1'
		dst_addr: '10.0.0.2'
		protocol: .tcp
		payload: 'attack string here'
	}
	action := engine.process_packet(packet)
	assert action == .pass
}

// test_process_packet_protocol_filter verifies that rules only match
// the specified protocol.
fn test_process_packet_protocol_filter() {
	mut engine := v_ids.new_engine('test-ids')
	engine.add_rule(v_ids.Rule{
		id: 'SID-400'
		severity: .medium
		action: .alert
		pattern: 'test'
		protocol: .tcp
		message: 'TCP only'
	}) or { return }
	// UDP packet should not match a TCP rule.
	packet := v_ids.PacketData{
		src_addr: '10.0.0.1'
		dst_addr: '10.0.0.2'
		protocol: .udp
		payload: 'test data'
	}
	action := engine.process_packet(packet)
	assert action == .pass
}

// test_process_packet_src_filter verifies source address filtering.
fn test_process_packet_src_filter() {
	mut engine := v_ids.new_engine('test-ids')
	engine.add_rule(v_ids.Rule{
		id: 'SID-500'
		severity: .high
		action: .drop
		pattern: 'scan'
		protocol: .any
		src: '192.168.1.0/24'
		message: 'Internal scan detected'
	}) or { return }
	// Packet from within the subnet should match.
	packet_in := v_ids.PacketData{
		src_addr: '192.168.1.50'
		dst_addr: '10.0.0.1'
		protocol: .tcp
		payload: 'port scan attempt'
	}
	assert engine.process_packet(packet_in) == .drop
	// Packet from outside should not match.
	packet_out := v_ids.PacketData{
		src_addr: '192.168.2.50'
		dst_addr: '10.0.0.1'
		protocol: .tcp
		payload: 'port scan attempt'
	}
	assert engine.process_packet(packet_out) == .pass
}

// test_get_stats verifies cumulative statistics.
fn test_get_stats() {
	mut engine := v_ids.new_engine('test-ids')
	engine.add_rule(v_ids.Rule{
		id: 'SID-600'
		severity: .info
		action: .alert
		pattern: 'ping'
		protocol: .icmp
		message: 'ICMP ping'
	}) or { return }
	// Process several packets.
	for _ in 0 .. 3 {
		engine.process_packet(v_ids.PacketData{
			src_addr: '10.0.0.1'
			dst_addr: '10.0.0.2'
			protocol: .icmp
			payload: 'ping request'
		})
	}
	engine.process_packet(v_ids.PacketData{
		src_addr: '10.0.0.1'
		dst_addr: '10.0.0.2'
		protocol: .tcp
		payload: 'normal traffic'
	})
	stats := engine.get_stats()
	assert stats.packets_processed == 4
	assert stats.alerts_generated == 3
}

// test_payload_excerpt_truncation verifies that long payloads are
// truncated in alert excerpts.
fn test_payload_excerpt_truncation() {
	mut engine := v_ids.new_engine('test-ids')
	engine.add_rule(v_ids.Rule{
		id: 'SID-700'
		severity: .high
		action: .alert
		pattern: 'evil'
		protocol: .any
		message: 'Evil detected'
	}) or { return }
	long_payload := 'evil' + 'A'.repeat(200)
	engine.process_packet(v_ids.PacketData{
		src_addr: '10.0.0.1'
		dst_addr: '10.0.0.2'
		protocol: .tcp
		payload: long_payload
	})
	alerts := engine.get_alerts()
	assert alerts.len == 1
	assert alerts[0].payload_excerpt.len == 64
}
