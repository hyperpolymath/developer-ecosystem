// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_ospf -- Open Shortest Path First (OSPF) router, area management, and SPF
// calculation for the V-Ecosystem.
// Maps to proven-servers/protocols/proven-ospf.
// Implements link-state database, Dijkstra shortest-path-first computation,
// and routing table generation per RFC 2328.
module v_ospf

// PacketType enumerates the OSPF packet types defined in RFC 2328 section A.3.
pub enum PacketType as u8 {
	hello              = 1
	db_description     = 2
	link_state_request = 3
	link_state_update  = 4
	link_state_ack     = 5
}

// packet_type_to_string returns the human-readable label for a PacketType.
pub fn packet_type_to_string(pt PacketType) string {
	return match pt {
		.hello { 'Hello' }
		.db_description { 'Database Description' }
		.link_state_request { 'Link State Request' }
		.link_state_update { 'Link State Update' }
		.link_state_ack { 'Link State Acknowledgement' }
	}
}

// LsaType enumerates the Link State Advertisement types per RFC 2328 section 12.
pub enum LsaType as u8 {
	router   = 1
	network  = 2
	summary  = 3
	external = 5
}

// lsa_type_to_string returns the human-readable label for an LsaType.
pub fn lsa_type_to_string(lt LsaType) string {
	return match lt {
		.router { 'Router LSA' }
		.network { 'Network LSA' }
		.summary { 'Summary LSA' }
		.external { 'AS External LSA' }
	}
}

// NeighborState tracks the OSPF neighbor state machine per RFC 2328 section 10.1.
pub enum NeighborState as u8 {
	down      = 0
	init      = 1
	two_way   = 2
	exstart   = 3
	exchange  = 4
	loading   = 5
	full      = 6
}

// Lsa represents a Link State Advertisement in the LSDB.
pub struct Lsa {
pub:
	// lsa_type identifies the kind of LSA.
	lsa_type LsaType
	// link_state_id is the identifier for this LSA (typically a router or network IP).
	link_state_id string
	// advertising_router is the router ID of the originator.
	advertising_router string
	// sequence_number is the LSA sequence number for freshness comparison.
	sequence_number u32
	// metric is the cost associated with this link/route.
	metric u32
	// links contains the connected link destinations (router IDs or network IDs).
	links []string
}

// Interface represents an OSPF-enabled network interface.
pub struct Interface {
pub:
	// name is the interface name (e.g. "eth0").
	name string
	// ip_address is the IP address assigned to this interface.
	ip_address string
	// mask is the network mask length in bits.
	mask u8
	// cost is the OSPF cost metric for this interface.
	cost u32 = 1
	// area_id is the OSPF area this interface belongs to.
	area_id string
}

// Neighbor represents an OSPF neighbor discovered via Hello packets.
pub struct Neighbor {
pub:
	// router_id is the neighbor's OSPF router identifier.
	router_id string
	// ip_address is the neighbor's interface IP.
	ip_address string
	// priority is the router priority for DR/BDR election.
	priority u8
pub mut:
	// state is the current adjacency state with this neighbor.
	state NeighborState
}

// Area represents an OSPF area containing interfaces and a link-state database.
pub struct Area {
pub:
	// id is the area identifier (e.g. "0.0.0.0" for backbone).
	id string
pub mut:
	// interfaces are the OSPF-enabled interfaces in this area.
	interfaces []Interface
	// lsa_db is the link-state database for this area.
	lsa_db []Lsa
	// neighbors are the OSPF neighbors discovered in this area.
	neighbors []Neighbor
}

// RoutingEntry represents a single entry in the computed OSPF routing table.
pub struct RoutingEntry {
pub:
	// destination is the network prefix.
	destination string
	// mask is the prefix length in bits.
	mask u8
	// next_hop is the next-hop IP address.
	next_hop string
	// cost is the total path cost to reach this destination.
	cost u32
	// area_id is the area through which this route was learned.
	area_id string
}

// SpfNode represents a node in the SPF (Dijkstra) computation graph.
struct SpfNode {
mut:
	// router_id is the identifier for this node.
	router_id string
	// cost is the shortest known cost to reach this node.
	cost u32 = 0xFFFFFFFF
	// predecessor is the previous node in the shortest path.
	predecessor string
	// visited indicates whether this node has been finalised.
	visited bool
}

// OspfRouter holds the state for an OSPF router including its identity,
// areas, and the computed routing table.
pub struct OspfRouter {
pub:
	// router_id is this router's OSPF identifier.
	router_id string
pub mut:
	// areas contains all OSPF areas configured on this router.
	areas []Area
	// routing_table holds the computed routing entries.
	routing_table []RoutingEntry
}

// new_router creates a new OspfRouter with the given router identifier.
pub fn new_router(router_id string) &OspfRouter {
	return &OspfRouter{
		router_id: router_id
	}
}

// add_area registers a new OSPF area with the router.
pub fn (mut r OspfRouter) add_area(area Area) {
	r.areas << area
}

// find_area looks up an area by its identifier. Returns an error if not found.
pub fn (r OspfRouter) find_area(area_id string) !&Area {
	for i, _ in r.areas {
		if r.areas[i].id == area_id {
			return unsafe { &r.areas[i] }
		}
	}
	return error('area not found: ${area_id}')
}

// add_interface adds a network interface to the appropriate area.
// Returns an error if the referenced area does not exist.
pub fn (mut r OspfRouter) add_interface(iface Interface) ! {
	for i, _ in r.areas {
		if r.areas[i].id == iface.area_id {
			r.areas[i].interfaces << iface
			return
		}
	}
	return error('area not found for interface: ${iface.area_id}')
}

// process_hello handles an incoming Hello packet from a neighbor.
// If the neighbor is new, it is added in Init state. If already known,
// its state is advanced to TwoWay if still in Init.
// TODO: Network I/O -- receive Hello packets from multicast group 224.0.0.5.
pub fn (mut r OspfRouter) process_hello(area_id string, neighbor_id string, neighbor_ip string, priority u8) ! {
	for i, _ in r.areas {
		if r.areas[i].id != area_id {
			continue
		}
		// Check if neighbor already known
		for j, _ in r.areas[i].neighbors {
			if r.areas[i].neighbors[j].router_id == neighbor_id {
				if r.areas[i].neighbors[j].state == .init {
					r.areas[i].neighbors[j].state = .two_way
				}
				return
			}
		}
		// New neighbor
		r.areas[i].neighbors << Neighbor{
			router_id: neighbor_id
			ip_address: neighbor_ip
			priority: priority
			state: .init
		}
		return
	}
	return error('area not found: ${area_id}')
}

// install_lsa adds or updates an LSA in the specified area's link-state
// database. An LSA with a higher sequence number replaces an older one.
pub fn (mut r OspfRouter) install_lsa(area_id string, lsa Lsa) ! {
	for i, _ in r.areas {
		if r.areas[i].id != area_id {
			continue
		}
		// Check for existing LSA to replace
		for j, existing in r.areas[i].lsa_db {
			if existing.link_state_id == lsa.link_state_id
				&& existing.advertising_router == lsa.advertising_router {
				if lsa.sequence_number > existing.sequence_number {
					r.areas[i].lsa_db[j] = lsa
				}
				return
			}
		}
		r.areas[i].lsa_db << lsa
		return
	}
	return error('area not found: ${area_id}')
}

// calculate_spf runs the Dijkstra shortest-path-first algorithm on the
// given area's link-state database, starting from this router. Populates
// the router's routing table with the results.
pub fn (mut r OspfRouter) calculate_spf(area_id string) ! {
	area := r.find_area(area_id)!

	// Build node set from LSAs
	mut nodes := map[string]SpfNode{}
	for lsa in area.lsa_db {
		if lsa.link_state_id !in nodes {
			nodes[lsa.link_state_id] = SpfNode{
				router_id: lsa.link_state_id
			}
		}
		for link in lsa.links {
			if link !in nodes {
				nodes[link] = SpfNode{
					router_id: link
				}
			}
		}
	}

	// Set root cost to zero
	if r.router_id in nodes {
		nodes[r.router_id] = SpfNode{
			...nodes[r.router_id]
			cost: 0
		}
	} else {
		return error('router ${r.router_id} not in LSDB for area ${area_id}')
	}

	// Dijkstra main loop
	for _ in 0 .. nodes.len {
		// Find unvisited node with lowest cost
		mut min_cost := u32(0xFFFFFFFF)
		mut current := ''
		for id, node in nodes {
			if !node.visited && node.cost < min_cost {
				min_cost = node.cost
				current = id
			}
		}
		if current == '' {
			break
		}
		nodes[current] = SpfNode{
			...nodes[current]
			visited: true
		}

		// Relax edges from current node
		for lsa in area.lsa_db {
			if lsa.link_state_id != current {
				continue
			}
			for link in lsa.links {
				new_cost := min_cost + lsa.metric
				if new_cost < nodes[link].cost {
					nodes[link] = SpfNode{
						...nodes[link]
						cost: new_cost
						predecessor: current
					}
				}
			}
		}
	}

	// Build routing table from SPF results
	mut new_entries := []RoutingEntry{}
	for id, node in nodes {
		if id == r.router_id || !node.visited {
			continue
		}
		// Trace back to find next hop
		mut hop := id
		for nodes[hop].predecessor != r.router_id && nodes[hop].predecessor != '' {
			hop = nodes[hop].predecessor
		}
		new_entries << RoutingEntry{
			destination: id
			mask: 32
			next_hop: hop
			cost: node.cost
			area_id: area_id
		}
	}
	r.routing_table = new_entries
}

// get_routing_table returns the current routing table.
pub fn (r OspfRouter) get_routing_table() []RoutingEntry {
	return r.routing_table
}

// area_count returns the number of configured areas.
pub fn (r OspfRouter) area_count() int {
	return r.areas.len
}

// total_lsa_count returns the total number of LSAs across all areas.
pub fn (r OspfRouter) total_lsa_count() int {
	mut count := 0
	for area in r.areas {
		count += area.lsa_db.len
	}
	return count
}
