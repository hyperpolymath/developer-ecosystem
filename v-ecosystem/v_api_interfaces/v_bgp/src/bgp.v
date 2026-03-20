// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_bgp -- Border Gateway Protocol (BGP-4) session management, route
// announcement, withdrawal, and best-path selection for the V-Ecosystem.
// Maps to proven-servers/protocols/proven-bgp.
// Implements path attribute handling, peer state tracking, and policy
// application per RFC 4271.
module v_bgp

import time

// MessageType enumerates the BGP message types defined in RFC 4271 section 4.
pub enum MessageType as u8 {
	open           = 1
	update         = 2
	notification   = 3
	keepalive      = 4
	route_refresh  = 5
}

// message_type_to_string returns the human-readable label for a MessageType.
pub fn message_type_to_string(mt MessageType) string {
	return match mt {
		.open { 'OPEN' }
		.update { 'UPDATE' }
		.notification { 'NOTIFICATION' }
		.keepalive { 'KEEPALIVE' }
		.route_refresh { 'ROUTE-REFRESH' }
	}
}

// Origin enumerates the ORIGIN path attribute values per RFC 4271 section 4.3.
pub enum Origin as u8 {
	igp        = 0
	egp        = 1
	incomplete = 2
}

// origin_to_string returns the human-readable label for an Origin value.
pub fn origin_to_string(o Origin) string {
	return match o {
		.igp { 'IGP' }
		.egp { 'EGP' }
		.incomplete { 'INCOMPLETE' }
	}
}

// PathAttribute represents a single BGP path attribute attached to a route
// announcement. Each variant carries the relevant data for that attribute type.
pub struct PathAttribute {
pub:
	// origin is the ORIGIN attribute (IGP, EGP, or INCOMPLETE).
	origin Origin
	// as_path is the ordered list of AS numbers the route has traversed.
	as_path []u32
	// next_hop is the IP address of the next-hop router.
	next_hop string
	// med is the Multi-Exit Discriminator (0 if unset).
	med u32
	// local_pref is the LOCAL_PREF value (default 100).
	local_pref u32 = 100
	// communities is the list of BGP community values (RFC 1997).
	communities []u32
}

// Route represents a BGP route with its network prefix, mask length,
// associated path attributes, and the next-hop address.
pub struct Route {
pub:
	// prefix is the network prefix (e.g. "10.0.0.0").
	prefix string
	// mask is the prefix length in bits (e.g. 24 for /24).
	mask u8
	// attributes holds the path attributes for this route.
	attributes PathAttribute
	// next_hop is the resolved next-hop IP address.
	next_hop string
}

// PeerState tracks the BGP finite state machine states per RFC 4271 section 8.
pub enum PeerState as u8 {
	idle         = 0
	connect      = 1
	active       = 2
	open_sent    = 3
	open_confirm = 4
	established  = 5
}

// peer_state_to_string returns the human-readable label for a PeerState.
pub fn peer_state_to_string(ps PeerState) string {
	return match ps {
		.idle { 'Idle' }
		.connect { 'Connect' }
		.active { 'Active' }
		.open_sent { 'OpenSent' }
		.open_confirm { 'OpenConfirm' }
		.established { 'Established' }
	}
}

// Peer represents a BGP peer (neighbor) with its address, autonomous system
// number, current FSM state, and negotiated hold time.
pub struct Peer {
pub:
	// addr is the IP address of the peer.
	addr string
	// asn is the peer's autonomous system number.
	asn u32
	// hold_time is the negotiated hold time in seconds.
	hold_time u16 = 90
pub mut:
	// state is the current FSM state of the peering session.
	state PeerState
}

// PolicyAction defines what to do when a route matches a policy rule.
pub enum PolicyAction as u8 {
	accept = 0
	reject = 1
	modify = 2
}

// PolicyRule represents a single BGP route policy rule that matches
// routes by prefix and optionally modifies their attributes.
pub struct PolicyRule {
pub:
	// name is a human-readable identifier for this policy rule.
	name string
	// match_prefix is the network prefix to match (empty = match all).
	match_prefix string
	// match_mask is the prefix length to match (0 = match all).
	match_mask u8
	// action determines what happens when the rule matches.
	action PolicyAction
	// set_local_pref overrides LOCAL_PREF when action is modify.
	set_local_pref ?u32
	// set_med overrides MED when action is modify.
	set_med ?u32
}

// BgpSession holds the state for a BGP session including the local router
// identity, peers, the routing information base (RIB), and policy rules.
pub struct BgpSession {
pub:
	// local_asn is this router's autonomous system number.
	local_asn u32
	// router_id is the BGP router identifier (typically an IPv4 address).
	router_id string
pub mut:
	// peers contains all configured BGP peers.
	peers []Peer
	// rib is the Routing Information Base: all routes learned and local.
	rib []Route
	// policies contains the route policy rules applied to updates.
	policies []PolicyRule
	// started_at records when the session was created.
	started_at ?time.Time
}

// new_session creates a new BgpSession with the given local AS number and
// router identifier. The session starts with an empty RIB and no peers.
pub fn new_session(local_asn u32, router_id string) &BgpSession {
	return &BgpSession{
		local_asn: local_asn
		router_id: router_id
		started_at: time.now()
	}
}

// add_peer registers a new BGP peer with the session. The peer starts
// in the Idle state.
pub fn (mut s BgpSession) add_peer(addr string, asn u32, hold_time u16) {
	s.peers << Peer{
		addr: addr
		asn: asn
		hold_time: hold_time
		state: .idle
	}
}

// find_peer looks up a peer by IP address. Returns the peer or an error
// if no peer with that address is configured.
pub fn (s BgpSession) find_peer(addr string) !&Peer {
	for i, _ in s.peers {
		if s.peers[i].addr == addr {
			return unsafe { &s.peers[i] }
		}
	}
	return error('peer not found: ${addr}')
}

// announce_route adds a route to the RIB and marks it for advertisement
// to all established peers.
// TODO: Network I/O -- send UPDATE messages to established peers.
pub fn (mut s BgpSession) announce_route(route Route) {
	s.rib << route
}

// withdraw_route removes a route matching the given prefix and mask from
// the RIB.
// TODO: Network I/O -- send UPDATE with withdrawn routes to peers.
pub fn (mut s BgpSession) withdraw_route(prefix string, mask u8) bool {
	original_len := s.rib.len
	s.rib = s.rib.filter(it.prefix != prefix || it.mask != mask)
	return s.rib.len < original_len
}

// process_update handles an incoming UPDATE message by adding or updating
// routes in the RIB. Applies policy rules before insertion.
pub fn (mut s BgpSession) process_update(announced []Route, withdrawn []Route) {
	// Process withdrawals first
	for w in withdrawn {
		s.withdraw_route(w.prefix, w.mask)
	}
	// Process announcements through policy
	for route in announced {
		action := s.apply_policy(route)
		match action {
			.accept {
				s.rib << route
			}
			.modify {
				modified := s.modify_route(route)
				s.rib << modified
			}
			.reject {}
		}
	}
}

// apply_policy evaluates all policy rules against a route and returns the
// action for the first matching rule. Returns accept if no rule matches.
pub fn (s BgpSession) apply_policy(route Route) PolicyAction {
	for policy in s.policies {
		if policy.match_prefix.len == 0 || (route.prefix == policy.match_prefix
			&& route.mask == policy.match_mask) {
			return policy.action
		}
	}
	return .accept
}

// modify_route applies modification policies to a route, returning a new
// route with adjusted attributes.
fn (s BgpSession) modify_route(route Route) Route {
	mut new_lp := route.attributes.local_pref
	mut new_med := route.attributes.med
	for policy in s.policies {
		if policy.action != .modify {
			continue
		}
		if policy.match_prefix.len == 0 || (route.prefix == policy.match_prefix
			&& route.mask == policy.match_mask) {
			if lp := policy.set_local_pref {
				new_lp = lp
			}
			if med := policy.set_med {
				new_med = med
			}
		}
	}
	return Route{
		...route
		attributes: PathAttribute{
			...route.attributes
			local_pref: new_lp
			med: new_med
		}
	}
}

// best_path_selection selects the best route for a given prefix/mask from
// the RIB using the standard BGP decision process:
// 1. Highest LOCAL_PREF
// 2. Shortest AS_PATH
// 3. Lowest origin type (IGP < EGP < INCOMPLETE)
// 4. Lowest MED
// Returns the best route or an error if no routes match.
pub fn (s BgpSession) best_path_selection(prefix string, mask u8) !Route {
	candidates := s.rib.filter(it.prefix == prefix && it.mask == mask)
	if candidates.len == 0 {
		return error('no routes for ${prefix}/${mask}')
	}
	mut best := candidates[0]
	for i := 1; i < candidates.len; i++ {
		candidate := candidates[i]
		// Step 1: Highest LOCAL_PREF wins
		if candidate.attributes.local_pref > best.attributes.local_pref {
			best = candidate
			continue
		}
		if candidate.attributes.local_pref < best.attributes.local_pref {
			continue
		}
		// Step 2: Shortest AS_PATH wins
		if candidate.attributes.as_path.len < best.attributes.as_path.len {
			best = candidate
			continue
		}
		if candidate.attributes.as_path.len > best.attributes.as_path.len {
			continue
		}
		// Step 3: Lowest origin type wins (IGP=0, EGP=1, INCOMPLETE=2)
		if u8(candidate.attributes.origin) < u8(best.attributes.origin) {
			best = candidate
			continue
		}
		if u8(candidate.attributes.origin) > u8(best.attributes.origin) {
			continue
		}
		// Step 4: Lowest MED wins
		if candidate.attributes.med < best.attributes.med {
			best = candidate
		}
	}
	return best
}

// add_policy appends a policy rule to the session's policy list.
pub fn (mut s BgpSession) add_policy(rule PolicyRule) {
	s.policies << rule
}

// rib_size returns the number of routes currently in the RIB.
pub fn (s BgpSession) rib_size() int {
	return s.rib.len
}

// peer_count returns the number of configured peers.
pub fn (s BgpSession) peer_count() int {
	return s.peers.len
}

// established_peers returns the count of peers in the Established state.
pub fn (s BgpSession) established_peers() int {
	return s.peers.filter(it.state == .established).len
}
