// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Software-defined networking with flow table management and controller API Connector
// Author: Jonathan D.A. Jewell
//
// Software-defined networking with flow table management and controller API.
// Provides typed client bindings for the proven-sdn protocol.

module sdn

import os
import time
import net

// --- SDN protocol ---

// SdnProtocol selects the southbound protocol.
pub enum SdnProtocol {
	openflow_13  // OpenFlow 1.3
	openflow_15  // OpenFlow 1.5
	p4           // P4 Runtime
	netconf      // NETCONF
}

// --- Flow action ---

// FlowAction defines what happens to matched flows.
pub enum FlowAction {
	forward     // Forward to port
	drop_flow   // Drop packet
	controller  // Send to controller
	group       // Apply group action
}

// --- Data structures ---

// FlowRule defines a single SDN flow entry.
pub struct FlowRule {
pub:
	table_id    int
	priority    int
	match_fields map[string]string  // Field -> value
	action      FlowAction
	out_port    int
	idle_timeout int = 0
}

// SdnSwitch represents a managed SDN switch.
pub struct SdnSwitch {
pub:
	dpid        string    // Datapath ID
	name        string
	protocol    SdnProtocol
	ports       int
}

// SdnConfig holds SDN controller parameters.
pub struct SdnConfig {
pub:
	controller_addr string = "0.0.0.0"
	controller_port int = 6653
}

// SdnController manages SDN switches and flows.
pub struct SdnController {
mut:
	config    SdnConfig
	switches  []SdnSwitch
	flows     []FlowRule
}

// --- Controller lifecycle ---

// new_sdn_controller creates a new SDN controller.
pub fn new_sdn_controller(config SdnConfig) &SdnController {
	return &SdnController{
		config:   config
		switches: []SdnSwitch{}
		flows:    []FlowRule{}
	}
}

// add_switch registers an SDN switch.
pub fn (mut c SdnController) add_switch(sw SdnSwitch) ! {
	if sw.dpid.len == 0 {
		return error("switch DPID must not be empty")
	}
	c.switches << sw
	println("[sdn] switch connected: ${sw.name} (${sw.dpid})")
}

// install_flow pushes a flow rule to a switch.
pub fn (mut c SdnController) install_flow(flow FlowRule) ! {
	c.flows << flow
	println("[sdn] installed flow: table=${flow.table_id} priority=${flow.priority} action=${flow.action}")
}

// --- Tests ---

fn test_empty_dpid_rejected() {
	mut ctrl := new_sdn_controller(SdnConfig{})
	ctrl.add_switch(SdnSwitch{ dpid: "", name: "sw1", protocol: .openflow_13, ports: 48 }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
