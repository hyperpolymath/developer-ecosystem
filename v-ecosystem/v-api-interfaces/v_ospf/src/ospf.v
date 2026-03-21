// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Open Shortest Path First routing with area management and LSA handling Connector
// Author: Jonathan D.A. Jewell
//
// Open Shortest Path First routing with area management and LSA handling.
// Provides typed client bindings for the proven-ospf protocol.

module ospf

import os
import time
import net

// --- Area type ---

// OspfAreaType classifies the OSPF area.
pub enum OspfAreaType {
	normal
	stub
	totally_stubby
	nssa
}

// --- Neighbor state ---

// NeighborState tracks the OSPF adjacency state machine.
pub enum NeighborState {
	down
	init
	two_way
	exstart
	exchange
	loading
	full
}

// --- Data structures ---

// OspfArea defines an OSPF area.
pub struct OspfArea {
pub:
	area_id      string   // Dotted notation
	area_type    OspfAreaType
	interfaces   []string
}

// OspfNeighbor represents an OSPF neighbor.
pub struct OspfNeighbor {
pub:
	router_id    string
	address      string
	state        NeighborState
	area_id      string
}

// OspfConfig holds OSPF daemon parameters.
pub struct OspfConfig {
pub:
	router_id    string
	reference_bw int = 100000  // Reference bandwidth (Mbps)
}

// OspfManager manages OSPF areas and neighbors.
pub struct OspfManager {
mut:
	config     OspfConfig
	areas      []OspfArea
	neighbors  []OspfNeighbor
}

// --- Manager lifecycle ---

// new_ospf_manager creates a new OSPF manager.
pub fn new_ospf_manager(config OspfConfig) &OspfManager {
	return &OspfManager{
		config:    config
		areas:     []OspfArea{}
		neighbors: []OspfNeighbor{}
	}
}

// add_area registers an OSPF area.
pub fn (mut m OspfManager) add_area(area OspfArea) ! {
	if area.area_id.len == 0 {
		return error("area_id must not be empty")
	}
	m.areas << area
	println("[ospf] added area ${area.area_id} (${area.area_type})")
}

// get_neighbors returns neighbors in a given area.
pub fn (m &OspfManager) get_neighbors(area_id string) []OspfNeighbor {
	return m.neighbors.filter(it.area_id == area_id)
}

// --- Tests ---

fn test_empty_area_id_rejected() {
	mut mgr := new_ospf_manager(OspfConfig{ router_id: "1.1.1.1" })
	mgr.add_area(OspfArea{ area_id: "", area_type: .normal, interfaces: [] }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
