// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_ids — Intrusion Detection System protocol types and engine.
// Maps to proven-servers/protocols/proven-ids.
//
// Provides rule management, packet processing, alert generation, and
// detection statistics. Supports signature, anomaly, stateful, and
// protocol-level detection. Network I/O is stubbed with TODO markers;
// all type definitions and logic are real.
module ids

import time

// Severity classifies the importance of an IDS alert or rule.
pub enum Severity {
	critical
	high
	medium
	low
	info
}

// AlertType classifies how the alert was generated.
pub enum AlertType {
	signature
	anomaly
	stateful
	protocol
}

// RuleAction defines the action taken when a rule matches.
pub enum RuleAction {
	alert
	drop
	reject
	log
	pass
}

// Protocol specifies the network protocol a rule applies to.
pub enum Protocol {
	tcp
	udp
	icmp
	any
}

// Rule represents a single IDS detection rule with match criteria
// and an action to take on match.
pub struct Rule {
pub:
	// id is a unique identifier for this rule (e.g. "SID-1000001").
	id string
	// severity classifies the rule's importance.
	severity Severity
	// action defines what to do when the rule matches.
	action RuleAction
	// pattern is the byte pattern or regex to match in packet payloads.
	pattern string
	// protocol specifies which protocol this rule applies to.
	protocol Protocol
	// src is the source address filter (CIDR or empty for any).
	src string
	// dst is the destination address filter (CIDR or empty for any).
	dst string
	// message is a human-readable description of the threat.
	message string
pub mut:
	// enabled controls whether this rule is active.
	enabled bool = true
	// hit_count tracks how many times this rule has matched.
	hit_count int
}

// Alert represents a single IDS alert generated when a rule matches
// network traffic.
pub struct Alert {
pub:
	// rule_id identifies the rule that triggered this alert.
	rule_id string
	// severity is the alert severity.
	severity Severity
	// alert_type classifies the detection method.
	alert_type AlertType
	// timestamp is when the alert was generated.
	timestamp time.Time
	// src_addr is the source IP address of the triggering packet.
	src_addr string
	// dst_addr is the destination IP address.
	dst_addr string
	// payload_excerpt is a truncated excerpt of the matched payload.
	payload_excerpt string
}

// PacketData represents a network packet for IDS processing.
pub struct PacketData {
pub:
	// src_addr is the packet's source IP address.
	src_addr string
	// src_port is the packet's source port.
	src_port int
	// dst_addr is the packet's destination IP address.
	dst_addr string
	// dst_port is the packet's destination port.
	dst_port int
	// protocol is the packet's network protocol.
	protocol Protocol
	// payload is the packet's payload data.
	payload string
}

// EngineStats tracks IDS engine processing statistics.
pub struct EngineStats {
pub mut:
	// packets_processed is the total number of packets analysed.
	packets_processed int
	// alerts_generated is the total number of alerts raised.
	alerts_generated int
	// packets_dropped is the count of packets matched by drop rules.
	packets_dropped int
	// packets_passed is the count of packets that matched no rules.
	packets_passed int
}

// IdsEngine is the main Intrusion Detection System engine. It manages
// rules, processes packets, and generates alerts.
pub struct IdsEngine {
pub:
	// name identifies this IDS engine instance.
	name string
pub mut:
	// rules is the list of detection rules.
	rules []Rule
	// alerts is the list of generated alerts.
	alerts []Alert
	// stats tracks engine processing statistics.
	stats EngineStats
}

// new_engine creates a new IDS engine with the given name and no rules.
pub fn new_engine(name string) &IdsEngine {
	return &IdsEngine{
		name: name
		rules: []Rule{}
		alerts: []Alert{}
		stats: EngineStats{}
	}
}

// load_rules replaces the engine's rule set with the provided rules.
// Existing rules are discarded; alerts and stats are preserved.
pub fn (mut e IdsEngine) load_rules(rules []Rule) {
	e.rules = rules.clone()
}

// add_rule appends a single rule to the engine. Returns an error if
// a rule with the same id already exists.
pub fn (mut e IdsEngine) add_rule(rule Rule) ! {
	for existing in e.rules {
		if existing.id == rule.id {
			return error('duplicate rule id: ${rule.id}')
		}
	}
	e.rules << rule
}

// remove_rule deletes a rule by id. Returns an error if the rule is
// not found.
pub fn (mut e IdsEngine) remove_rule(rule_id string) ! {
	mut found := false
	e.rules = e.rules.filter(fn [rule_id, mut found] (r Rule) bool {
		if r.id == rule_id {
			unsafe {
				found = true
			}
			return false
		}
		return true
	})
	if !found {
		return error('rule not found: ${rule_id}')
	}
}

// process_packet evaluates a packet against all enabled rules. If a
// rule matches, an alert is generated and the rule action is returned.
// Returns .pass if no rule matched.
pub fn (mut e IdsEngine) process_packet(packet PacketData) RuleAction {
	e.stats.packets_processed += 1
	for mut rule in e.rules {
		if !rule.enabled {
			continue
		}
		if matches_rule(rule, packet) {
			rule.hit_count += 1
			// Generate an alert for all actions except pass.
			if rule.action != .pass {
				excerpt := if packet.payload.len > 64 {
					packet.payload[..64]
				} else {
					packet.payload
				}
				alert := Alert{
					rule_id: rule.id
					severity: rule.severity
					alert_type: .signature
					timestamp: time.now()
					src_addr: packet.src_addr
					dst_addr: packet.dst_addr
					payload_excerpt: excerpt
				}
				e.alerts << alert
				e.stats.alerts_generated += 1
			}
			match rule.action {
				.drop {
					e.stats.packets_dropped += 1
					return .drop
				}
				.reject {
					e.stats.packets_dropped += 1
					return .reject
				}
				.alert { return .alert }
				.log { return .log }
				.pass {
					e.stats.packets_passed += 1
					return .pass
				}
			}
		}
	}
	e.stats.packets_passed += 1
	return .pass
}

// get_alerts returns a copy of all alerts generated by the engine.
pub fn (e IdsEngine) get_alerts() []Alert {
	return e.alerts
}

// get_stats returns the current engine statistics.
pub fn (e IdsEngine) get_stats() EngineStats {
	return e.stats
}

// matches_rule checks whether a packet matches a single IDS rule.
fn matches_rule(rule Rule, packet PacketData) bool {
	// Protocol must match (or rule is .any).
	if rule.protocol != .any && rule.protocol != packet.protocol {
		return false
	}
	// Source address filter.
	if rule.src.len > 0 && !addr_matches(packet.src_addr, rule.src) {
		return false
	}
	// Destination address filter.
	if rule.dst.len > 0 && !addr_matches(packet.dst_addr, rule.dst) {
		return false
	}
	// Pattern match against payload.
	if rule.pattern.len > 0 && !packet.payload.contains(rule.pattern) {
		return false
	}
	return true
}

// addr_matches checks if a packet address matches a rule filter.
// Supports exact match and simple CIDR prefix match.
fn addr_matches(packet_addr string, rule_addr string) bool {
	if rule_addr.contains('/') {
		// Simple CIDR: compare up to the prefix boundary.
		parts := rule_addr.split('/')
		if parts.len != 2 {
			return false
		}
		network := parts[0]
		prefix_len := parts[1].int()
		return cidr_contains(network, prefix_len, packet_addr)
	}
	return packet_addr == rule_addr
}

// cidr_contains checks whether an IPv4 address falls within a CIDR
// range.
fn cidr_contains(network string, prefix_len int, addr string) bool {
	net_parts := network.split('.')
	addr_parts := addr.split('.')
	if net_parts.len != 4 || addr_parts.len != 4 {
		return false
	}
	mut net_int := u32(0)
	mut addr_int := u32(0)
	for i in 0 .. 4 {
		net_int = (net_int << 8) | u32(net_parts[i].int())
		addr_int = (addr_int << 8) | u32(addr_parts[i].int())
	}
	mask := if prefix_len == 0 { u32(0) } else { ~(u32(0xFFFFFFFF) >> u32(prefix_len)) }
	return (net_int & mask) == (addr_int & mask)
}
