// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_sdn -- Software-Defined Networking (SDN) controller with flow table
// management, priority-based packet matching, and topology discovery for
// the V-Ecosystem.
// Maps to proven-servers/protocols/proven-sdn.
// Provides flow rule installation/removal, multi-field packet matching,
// and per-flow statistics tracking.
module sdn

import time

// FlowAction enumerates the actions that can be applied to a matched packet
// in the SDN data plane.
pub enum FlowAction as u8 {
	forward    = 0
	drop       = 1
	flood      = 2
	controller = 3
	set_field  = 4
	push_vlan  = 5
	pop_vlan   = 6
}

// flow_action_to_string returns the human-readable label for a FlowAction.
pub fn flow_action_to_string(fa FlowAction) string {
	return match fa {
		.forward { 'FORWARD' }
		.drop { 'DROP' }
		.flood { 'FLOOD' }
		.controller { 'CONTROLLER' }
		.set_field { 'SET_FIELD' }
		.push_vlan { 'PUSH_VLAN' }
		.pop_vlan { 'POP_VLAN' }
	}
}

// MatchField represents a single field matcher within a flow rule. Each
// field identifies one header aspect to match against incoming packets.
pub enum MatchField as u8 {
	in_port  = 0
	eth_src  = 1
	eth_dst  = 2
	ip_src   = 3
	ip_dst   = 4
	tcp_src  = 5
	tcp_dst  = 6
	protocol = 7
}

// match_field_to_string returns the human-readable label for a MatchField.
pub fn match_field_to_string(mf MatchField) string {
	return match mf {
		.in_port { 'IN_PORT' }
		.eth_src { 'ETH_SRC' }
		.eth_dst { 'ETH_DST' }
		.ip_src { 'IP_SRC' }
		.ip_dst { 'IP_DST' }
		.tcp_src { 'TCP_SRC' }
		.tcp_dst { 'TCP_DST' }
		.protocol { 'PROTOCOL' }
	}
}

// FieldMatch pairs a MatchField with the value to match against.
pub struct FieldMatch {
pub:
	// field identifies which header field to examine.
	field MatchField
	// value is the string representation of the match value.
	value string
}

// FlowRule defines a single forwarding rule in the flow table. Rules are
// evaluated by priority (highest first), and the first matching rule's
// actions are applied to the packet.
pub struct FlowRule {
pub:
	// priority determines evaluation order (higher = earlier).
	priority u16
	// match_fields lists the header fields and values to match.
	match_fields []FieldMatch
	// actions lists the actions to apply when the rule matches.
	actions []FlowAction
	// timeout is the idle timeout in seconds (0 = permanent).
	timeout u32
	// cookie is an opaque controller-assigned identifier.
	cookie u64
pub mut:
	// packet_count tracks how many packets matched this rule.
	packet_count u64
	// byte_count tracks how many bytes matched this rule.
	byte_count u64
	// installed_at records when this rule was added.
	installed_at ?time.Time
}

// Packet represents a simplified network packet for matching purposes.
pub struct Packet {
pub:
	// in_port is the ingress port number.
	in_port string
	// eth_src is the source MAC address.
	eth_src string
	// eth_dst is the destination MAC address.
	eth_dst string
	// ip_src is the source IP address.
	ip_src string
	// ip_dst is the destination IP address.
	ip_dst string
	// tcp_src is the source TCP port.
	tcp_src string
	// tcp_dst is the destination TCP port.
	tcp_dst string
	// protocol is the IP protocol number as a string.
	protocol string
	// size is the packet size in bytes.
	size u64
}

// FlowTable holds an ordered set of flow rules for a single SDN switch.
pub struct FlowTable {
pub:
	// table_id identifies this flow table.
	table_id u8
pub mut:
	// rules contains the flow rules, kept sorted by descending priority.
	rules []FlowRule
}

// TopologyLink represents a link between two switches in the SDN topology.
pub struct TopologyLink {
pub:
	// src_switch is the source switch identifier.
	src_switch string
	// src_port is the port on the source switch.
	src_port string
	// dst_switch is the destination switch identifier.
	dst_switch string
	// dst_port is the port on the destination switch.
	dst_port string
	// bandwidth is the link capacity in Mbps.
	bandwidth u32
}

// FlowTableStats holds aggregate statistics for a flow table.
pub struct FlowTableStats {
pub:
	// table_id is the flow table identifier.
	table_id u8
	// rule_count is the number of installed rules.
	rule_count int
	// total_packets is the sum of all rule packet counts.
	total_packets u64
	// total_bytes is the sum of all rule byte counts.
	total_bytes u64
}

// SdnController manages one or more flow tables and the network topology.
pub struct SdnController {
pub:
	// controller_id is a unique identifier for this controller.
	controller_id string
pub mut:
	// tables contains the flow tables managed by this controller.
	tables []FlowTable
	// topology contains the discovered network links.
	topology []TopologyLink
}

// new_controller creates a new SdnController with the given identifier
// and a single default flow table (table 0).
pub fn new_controller(controller_id string) &SdnController {
	return &SdnController{
		controller_id: controller_id
		tables: [FlowTable{
			table_id: 0
		}]
	}
}

// add_flow installs a flow rule into the specified table. Rules are kept
// sorted by descending priority. Returns an error if the table does not exist.
pub fn (mut c SdnController) add_flow(table_id u8, rule FlowRule) ! {
	for i, _ in c.tables {
		if c.tables[i].table_id == table_id {
			mut new_rule := rule
			new_rule.installed_at = time.now()
			// Insert in priority order (descending)
			mut inserted := false
			for j, existing in c.tables[i].rules {
				if new_rule.priority > existing.priority {
					c.tables[i].rules.insert(j, new_rule)
					inserted = true
					break
				}
			}
			if !inserted {
				c.tables[i].rules << new_rule
			}
			return
		}
	}
	return error('flow table not found: ${table_id}')
}

// remove_flow removes a flow rule by its cookie from the specified table.
// Returns true if a rule was removed.
pub fn (mut c SdnController) remove_flow(table_id u8, cookie u64) !bool {
	for i, _ in c.tables {
		if c.tables[i].table_id == table_id {
			original_len := c.tables[i].rules.len
			c.tables[i].rules = c.tables[i].rules.filter(it.cookie != cookie)
			return c.tables[i].rules.len < original_len
		}
	}
	return error('flow table not found: ${table_id}')
}

// match_packet evaluates a packet against the rules in the specified flow
// table, returning the actions from the first (highest-priority) matching
// rule. Returns an empty action list if no rule matches.
pub fn (mut c SdnController) match_packet(table_id u8, pkt Packet) ![]FlowAction {
	for ti, _ in c.tables {
		if c.tables[ti].table_id != table_id {
			continue
		}
		for ri, _ in c.tables[ti].rules {
			if packet_matches_rule(pkt, c.tables[ti].rules[ri]) {
				c.tables[ti].rules[ri].packet_count++
				c.tables[ti].rules[ri].byte_count += pkt.size
				return c.tables[ti].rules[ri].actions
			}
		}
		return []FlowAction{}
	}
	return error('flow table not found: ${table_id}')
}

// packet_matches_rule checks whether a packet satisfies all match fields
// in a flow rule. All fields must match for the rule to apply.
fn packet_matches_rule(pkt Packet, rule FlowRule) bool {
	for fm in rule.match_fields {
		pkt_val := match fm.field {
			.in_port { pkt.in_port }
			.eth_src { pkt.eth_src }
			.eth_dst { pkt.eth_dst }
			.ip_src { pkt.ip_src }
			.ip_dst { pkt.ip_dst }
			.tcp_src { pkt.tcp_src }
			.tcp_dst { pkt.tcp_dst }
			.protocol { pkt.protocol }
		}
		if pkt_val != fm.value {
			return false
		}
	}
	return true
}

// get_stats returns aggregate statistics for the specified flow table.
pub fn (c SdnController) get_stats(table_id u8) !FlowTableStats {
	for table in c.tables {
		if table.table_id == table_id {
			mut total_pkts := u64(0)
			mut total_bytes := u64(0)
			for rule in table.rules {
				total_pkts += rule.packet_count
				total_bytes += rule.byte_count
			}
			return FlowTableStats{
				table_id: table_id
				rule_count: table.rules.len
				total_packets: total_pkts
				total_bytes: total_bytes
			}
		}
	}
	return error('flow table not found: ${table_id}')
}

// topology_discovery adds a link to the known topology.
// TODO: Network I/O -- use LLDP or OpenFlow discovery to find links.
pub fn (mut c SdnController) topology_discovery(link TopologyLink) {
	// Check for duplicate links
	for existing in c.topology {
		if existing.src_switch == link.src_switch && existing.src_port == link.src_port
			&& existing.dst_switch == link.dst_switch && existing.dst_port == link.dst_port {
			return
		}
	}
	c.topology << link
}

// add_table creates a new flow table with the given ID.
pub fn (mut c SdnController) add_table(table_id u8) {
	for table in c.tables {
		if table.table_id == table_id {
			return
		}
	}
	c.tables << FlowTable{
		table_id: table_id
	}
}

// table_count returns the number of flow tables.
pub fn (c SdnController) table_count() int {
	return c.tables.len
}
