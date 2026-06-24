// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_firewall — Firewall rule management protocol types.
// Maps to proven-servers/protocols/proven-firewall.
//
// Provides zone-based firewall rule management with packet evaluation,
// CIDR parsing, and an audit trail. Rules support TCP/UDP/ICMP with
// accept, drop, reject, log, and redirect actions. Priority ordering
// determines evaluation order within each zone.
module v_firewall

import time

// Action defines what happens to a packet matching a firewall rule.
pub enum Action {
	accept
	drop
	reject
	log
	redirect
}

// Protocol specifies the network protocol a rule applies to.
pub enum Protocol {
	tcp
	udp
	icmp
	any
}

// Direction specifies the traffic direction a rule applies to.
pub enum Direction {
	inbound
	outbound
	forward
}

// RuleState tracks whether a rule is currently enforced.
pub enum RuleState {
	active
	disabled
	pending
}

// FirewallRule represents a single firewall rule with match criteria
// and an action. Rules are evaluated by priority (lower = first) within
// their zone.
pub struct FirewallRule {
pub:
	// id is a unique identifier for this rule (e.g. "rule-001").
	id string
	// name is a human-readable name for the rule.
	name string
	// direction specifies inbound, outbound, or forwarded traffic.
	direction Direction
	// protocol specifies TCP, UDP, ICMP, or any.
	protocol Protocol
	// source_addr is the source IP or CIDR (empty = any).
	source_addr string
	// source_port is the source port or range (0 = any).
	source_port int
	// dest_addr is the destination IP or CIDR (empty = any).
	dest_addr string
	// dest_port is the destination port or range (0 = any).
	dest_port int
	// action defines what to do with matching packets.
	action Action
	// priority determines evaluation order (lower = evaluated first).
	priority int
	// description is an optional human-readable explanation.
	description string
	// created_at is the time the rule was created.
	created_at time.Time
pub mut:
	// state tracks whether the rule is active, disabled, or pending.
	state RuleState
}

// RuleSet is a named collection of firewall rules with a default
// policy applied when no rule matches.
pub struct RuleSet {
pub:
	// name identifies this rule set.
	name string
	// description explains the purpose of this rule set.
	description string
	// default_policy is applied when no rule in the set matches.
	default_policy Action = .drop
pub mut:
	// rules is the ordered list of firewall rules.
	rules []FirewallRule
}

// Zone represents a firewall zone associated with one or more network
// interfaces. Each zone has its own set of rules.
pub struct Zone {
pub:
	// name identifies this zone (e.g. "public", "internal", "dmz").
	name string
	// interfaces lists the network interfaces in this zone.
	interfaces []string
	// description explains the zone's purpose.
	description string
pub mut:
	// rules is the list of firewall rules applied to this zone.
	rules []FirewallRule
}

// PacketInfo holds the metadata of a network packet for evaluation
// against firewall rules.
pub struct PacketInfo {
pub:
	// source_addr is the packet's source IP address.
	source_addr string
	// source_port is the packet's source port.
	source_port int
	// dest_addr is the packet's destination IP address.
	dest_addr string
	// dest_port is the packet's destination port.
	dest_port int
	// protocol is the packet's protocol.
	protocol Protocol
	// direction is the packet's traffic direction.
	direction Direction
}

// FirewallServer is the main firewall management server. It manages
// zones, rule sets, and provides packet evaluation against the
// configured rule hierarchy.
pub struct FirewallServer {
pub:
	// port is the management API port.
	port int
	// audit_log is the path to the audit log file.
	audit_log string
pub mut:
	// zones maps zone names to Zone objects.
	zones map[string]Zone
	// rulesets maps rule set names to RuleSet objects.
	rulesets map[string]RuleSet
}

// new_server creates a new FirewallServer with the given management
// API port. No zones or rules are configured by default.
pub fn new_server(port int) &FirewallServer {
	return &FirewallServer{
		port: port
		zones: map[string]Zone{}
		rulesets: map[string]RuleSet{}
	}
}

// add_zone registers a new zone with the firewall server.
// If a zone with the same name already exists, it is replaced.
pub fn (mut s FirewallServer) add_zone(zone Zone) {
	s.zones[zone.name] = zone
}

// add_rule appends a firewall rule to the specified zone. Returns an
// error if the zone does not exist or if a rule with the same id
// already exists in the zone.
pub fn (mut s FirewallServer) add_rule(zone_name string, rule FirewallRule) ! {
	if zone_name !in s.zones {
		return error('zone not found: ${zone_name}')
	}
	mut zone := s.zones[zone_name] or { return error('zone not found: ${zone_name}') }
	// Check for duplicate rule ids.
	for existing in zone.rules {
		if existing.id == rule.id {
			return error('duplicate rule id: ${rule.id} in zone ${zone_name}')
		}
	}
	zone.rules << rule
	// Re-sort rules by priority (lower priority number = evaluated first).
	zone.rules.sort(a.priority < b.priority)
	s.zones[zone_name] = zone
}

// remove_rule deletes a rule by id from the specified zone. Returns
// an error if the zone or rule does not exist.
pub fn (mut s FirewallServer) remove_rule(zone_name string, rule_id string) ! {
	if zone_name !in s.zones {
		return error('zone not found: ${zone_name}')
	}
	mut zone := s.zones[zone_name] or { return error('zone not found: ${zone_name}') }
	mut found := false
	zone.rules = zone.rules.filter(fn [rule_id, mut found] (r FirewallRule) bool {
		if r.id == rule_id {
			unsafe {
				found = true
			}
			return false
		}
		return true
	})
	if !found {
		return error('rule not found: ${rule_id} in zone ${zone_name}')
	}
	s.zones[zone_name] = zone
}

// enable_rule sets a rule's state to Active. Returns an error if the
// zone or rule does not exist.
pub fn (mut s FirewallServer) enable_rule(zone_name string, rule_id string) ! {
	if zone_name !in s.zones {
		return error('zone not found: ${zone_name}')
	}
	mut zone := s.zones[zone_name] or { return error('zone not found: ${zone_name}') }
	mut found := false
	for mut rule in zone.rules {
		if rule.id == rule_id {
			rule.state = .active
			found = true
			break
		}
	}
	if !found {
		return error('rule not found: ${rule_id} in zone ${zone_name}')
	}
	s.zones[zone_name] = zone
}

// disable_rule sets a rule's state to Disabled. Returns an error if
// the zone or rule does not exist.
pub fn (mut s FirewallServer) disable_rule(zone_name string, rule_id string) ! {
	if zone_name !in s.zones {
		return error('zone not found: ${zone_name}')
	}
	mut zone := s.zones[zone_name] or { return error('zone not found: ${zone_name}') }
	mut found := false
	for mut rule in zone.rules {
		if rule.id == rule_id {
			rule.state = .disabled
			found = true
			break
		}
	}
	if !found {
		return error('rule not found: ${rule_id} in zone ${zone_name}')
	}
	s.zones[zone_name] = zone
}

// list_rules returns all firewall rules in the specified zone,
// ordered by priority.
pub fn (s FirewallServer) list_rules(zone_name string) []FirewallRule {
	zone := s.zones[zone_name] or { return []FirewallRule{} }
	return zone.rules
}

// evaluate checks a packet against all rules in all zones and returns
// the action of the first matching rule. If no rule matches, returns
// Action.drop as the default policy.
pub fn (s FirewallServer) evaluate(packet PacketInfo) Action {
	for _, zone in s.zones {
		for rule in zone.rules {
			if rule.state != .active {
				continue
			}
			if rule_matches(rule, packet) {
				return rule.action
			}
		}
	}
	return .drop
}

// rule_matches checks whether a packet matches a single firewall rule.
// Empty/zero fields in the rule act as wildcards.
fn rule_matches(rule FirewallRule, packet PacketInfo) bool {
	// Direction must match.
	if rule.direction != packet.direction {
		return false
	}
	// Protocol must match (or rule is .any).
	if rule.protocol != .any && rule.protocol != packet.protocol {
		return false
	}
	// Source address (if specified, must match or be in CIDR range).
	if rule.source_addr.len > 0 {
		if !addr_matches(packet.source_addr, rule.source_addr) {
			return false
		}
	}
	// Destination address.
	if rule.dest_addr.len > 0 {
		if !addr_matches(packet.dest_addr, rule.dest_addr) {
			return false
		}
	}
	// Source port (0 = any).
	if rule.source_port != 0 && rule.source_port != packet.source_port {
		return false
	}
	// Destination port (0 = any).
	if rule.dest_port != 0 && rule.dest_port != packet.dest_port {
		return false
	}
	return true
}

// addr_matches checks if a packet address matches a rule address.
// The rule address may be a plain IP or a CIDR range.
fn addr_matches(packet_addr string, rule_addr string) bool {
	if rule_addr.contains('/') {
		// CIDR match: compare the network prefix.
		addr, prefix_len := parse_cidr(rule_addr) or { return false }
		return cidr_contains(addr, prefix_len, packet_addr)
	}
	// Exact match.
	return packet_addr == rule_addr
}

// cidr_contains checks whether an IP address falls within a CIDR range.
// This is a simplified IPv4 implementation.
fn cidr_contains(network string, prefix_len int, addr string) bool {
	net_parts := network.split('.')
	addr_parts := addr.split('.')
	if net_parts.len != 4 || addr_parts.len != 4 {
		return false
	}
	// Convert to 32-bit integers.
	mut net_int := u32(0)
	mut addr_int := u32(0)
	for i in 0 .. 4 {
		net_int = (net_int << 8) | u32(net_parts[i].int())
		addr_int = (addr_int << 8) | u32(addr_parts[i].int())
	}
	// Create mask from prefix length.
	mask := if prefix_len == 0 { u32(0) } else { ~(u32(0xFFFFFFFF) >> u32(prefix_len)) }
	return (net_int & mask) == (addr_int & mask)
}

// parse_cidr splits a CIDR notation string (e.g. "192.168.1.0/24")
// into the address and prefix length. Returns an error if the format
// is invalid.
pub fn parse_cidr(addr string) !(string, int) {
	slash_idx := addr.index('/') or { return error('not a CIDR address: missing /') }
	ip := addr[..slash_idx]
	prefix_str := addr[slash_idx + 1..]
	prefix_len := prefix_str.int()
	if prefix_len < 0 || prefix_len > 128 {
		return error('invalid CIDR prefix length: ${prefix_len}')
	}
	// Validate IP has proper format.
	parts := ip.split('.')
	if parts.len != 4 {
		// Could be IPv6 — accept but don't validate further.
		return ip, prefix_len
	}
	for part in parts {
		val := part.int()
		if val < 0 || val > 255 {
			return error('invalid IP octet: ${part}')
		}
	}
	return ip, prefix_len
}
