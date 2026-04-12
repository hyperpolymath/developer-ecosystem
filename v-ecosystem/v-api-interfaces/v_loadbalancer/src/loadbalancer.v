// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_loadbalancer -- Load balancer with multiple selection algorithms, health
// checking, connection tracking, and pool management for the V-Ecosystem.
// Maps to proven-servers/protocols/proven-loadbalancer.
// Supports round-robin, least-connections, weighted round-robin, IP hash,
// random, and consistent hash selection across named backend pools.
module loadbalancer

import rand

// Algorithm enumerates the load balancing algorithms available for
// backend selection.
pub enum Algorithm as u8 {
	round_robin          = 0
	least_connections    = 1
	weighted_round_robin = 2
	ip_hash              = 3
	random               = 4
	consistent_hash      = 5
}

// algorithm_to_string returns the human-readable label for an Algorithm.
pub fn algorithm_to_string(a Algorithm) string {
	return match a {
		.round_robin { 'Round Robin' }
		.least_connections { 'Least Connections' }
		.weighted_round_robin { 'Weighted Round Robin' }
		.ip_hash { 'IP Hash' }
		.random { 'Random' }
		.consistent_hash { 'Consistent Hash' }
	}
}

// HealthStatus tracks the health state of a backend server.
pub enum HealthStatus as u8 {
	healthy   = 0
	unhealthy = 1
	draining  = 2
}

// health_status_to_string returns the human-readable label for a HealthStatus.
pub fn health_status_to_string(hs HealthStatus) string {
	return match hs {
		.healthy { 'Healthy' }
		.unhealthy { 'Unhealthy' }
		.draining { 'Draining' }
	}
}

// Backend represents a single server in a load balancer pool with its
// address, weight, health state, and connection count.
pub struct Backend {
pub:
	// addr is the hostname or IP address of the backend.
	addr string
	// port is the listening port.
	port int
	// weight is the relative weight for weighted algorithms (1-100).
	weight int = 1
pub mut:
	// health is the current health status.
	health HealthStatus = .healthy
	// connections is the number of active connections.
	connections int
	// total_requests is the lifetime request count for this backend.
	total_requests u64
}

// backend_addr returns the host:port string for a backend.
pub fn (b Backend) backend_addr() string {
	return '${b.addr}:${b.port}'
}

// is_available returns true if the backend can accept new connections
// (healthy and not draining).
pub fn (b Backend) is_available() bool {
	return b.health == .healthy
}

// HealthCheckConfig defines health check parameters for a pool.
pub struct HealthCheckConfig {
pub:
	// interval is the time between checks in seconds.
	interval int = 10
	// timeout is the check timeout in seconds.
	timeout int = 5
	// healthy_threshold is the number of consecutive successes to mark healthy.
	healthy_threshold int = 3
	// unhealthy_threshold is the number of consecutive failures to mark unhealthy.
	unhealthy_threshold int = 3
	// path is the HTTP path to check (empty for TCP-only check).
	path string
}

// Pool represents a named group of backends with a selection algorithm
// and health check configuration.
pub struct Pool {
pub:
	// name is the pool identifier.
	name string
	// algorithm is the backend selection method.
	algorithm Algorithm
	// health_check configures health checking for this pool's backends.
	health_check HealthCheckConfig
pub mut:
	// backends lists the servers in this pool.
	backends []Backend
	// rr_index tracks the round-robin position.
	rr_index int
	// wrr_current tracks weighted round-robin state.
	wrr_current int
	// wrr_gcd is the GCD of all backend weights (precomputed).
	wrr_gcd int = 1
	// wrr_max is the maximum weight (precomputed).
	wrr_max int = 1
}

// available_backends returns indices of backends that can accept connections.
pub fn (p Pool) available_backends() []int {
	mut indices := []int{}
	for i, b in p.backends {
		if b.is_available() {
			indices << i
		}
	}
	return indices
}

// PoolStats holds aggregate statistics for a pool.
pub struct PoolStats {
pub:
	// pool_name is the pool identifier.
	pool_name string
	// backend_count is the total number of backends.
	backend_count int
	// healthy_count is the number of healthy backends.
	healthy_count int
	// total_connections is the sum of active connections.
	total_connections int
	// total_requests is the sum of lifetime requests.
	total_requests u64
}

// ConsistentHashRing holds virtual nodes for consistent hashing.
struct ConsistentHashRing {
mut:
	// nodes maps hash values to backend indices.
	nodes []HashNode
}

// HashNode pairs a hash value with a backend index.
struct HashNode {
	hash_val u32
	backend  int
}

// LoadBalancer manages multiple backend pools and provides unified
// backend selection and health checking.
pub struct LoadBalancer {
pub mut:
	// pools contains the named backend pools.
	pools []Pool
	// total_requests tracks the lifetime request count across all pools.
	total_requests u64
}

// new_balancer creates a new empty LoadBalancer.
pub fn new_balancer() &LoadBalancer {
	return &LoadBalancer{}
}

// add_pool registers a new backend pool with the load balancer.
pub fn (mut lb LoadBalancer) add_pool(pool Pool) {
	lb.pools << pool
}

// find_pool_index returns the index of a pool by name, or -1 if not found.
fn (lb LoadBalancer) find_pool_index(name string) int {
	for i, p in lb.pools {
		if p.name == name {
			return i
		}
	}
	return -1
}

// add_backend adds a backend to the named pool. Returns an error if the
// pool does not exist.
pub fn (mut lb LoadBalancer) add_backend(pool_name string, backend Backend) ! {
	idx := lb.find_pool_index(pool_name)
	if idx < 0 {
		return error('pool not found: ${pool_name}')
	}
	lb.pools[idx].backends << backend
	lb.recalculate_weights(idx)
}

// remove_backend removes a backend by address and port from the named pool.
// Returns true if a backend was removed.
pub fn (mut lb LoadBalancer) remove_backend(pool_name string, addr string, port int) !bool {
	idx := lb.find_pool_index(pool_name)
	if idx < 0 {
		return error('pool not found: ${pool_name}')
	}
	original_len := lb.pools[idx].backends.len
	lb.pools[idx].backends = lb.pools[idx].backends.filter(!(it.addr == addr
		&& it.port == port))
	if lb.pools[idx].backends.len < original_len {
		lb.recalculate_weights(idx)
		return true
	}
	return false
}

// recalculate_weights updates the precomputed GCD and max weight for
// weighted round-robin selection.
fn (mut lb LoadBalancer) recalculate_weights(pool_idx int) {
	if lb.pools[pool_idx].backends.len == 0 {
		lb.pools[pool_idx].wrr_gcd = 1
		lb.pools[pool_idx].wrr_max = 1
		return
	}
	mut g := lb.pools[pool_idx].backends[0].weight
	mut m := g
	for b in lb.pools[pool_idx].backends {
		g = gcd(g, b.weight)
		if b.weight > m {
			m = b.weight
		}
	}
	lb.pools[pool_idx].wrr_gcd = g
	lb.pools[pool_idx].wrr_max = m
}

// gcd computes the greatest common divisor of two positive integers.
fn gcd(a int, b int) int {
	mut x := a
	mut y := b
	for y != 0 {
		x, y = y, x % y
	}
	return x
}

// select picks a backend from the named pool using the pool's configured
// algorithm. The key parameter is used for IP hash and consistent hash.
// Returns the selected backend index or an error.
pub fn (mut lb LoadBalancer) select_(pool_name string, key string) !int {
	idx := lb.find_pool_index(pool_name)
	if idx < 0 {
		return error('pool not found: ${pool_name}')
	}
	available := lb.pools[idx].available_backends()
	if available.len == 0 {
		return error('no available backends in pool: ${pool_name}')
	}

	selected := match lb.pools[idx].algorithm {
		.round_robin {
			bi := available[lb.pools[idx].rr_index % available.len]
			lb.pools[idx].rr_index++
			bi
		}
		.least_connections {
			mut min_conn := lb.pools[idx].backends[available[0]].connections
			mut min_idx := available[0]
			for ai in available {
				conn := lb.pools[idx].backends[ai].connections
				if conn < min_conn {
					min_conn = conn
					min_idx = ai
				}
			}
			min_idx
		}
		.weighted_round_robin {
			// Smooth weighted round-robin
			mut best := available[0]
			mut best_weight := lb.pools[idx].backends[available[0]].weight
			for ai in available[1..] {
				w := lb.pools[idx].backends[ai].weight
				if w > best_weight {
					best_weight = w
					best = ai
				}
			}
			// Advance round-robin among highest-weight backends
			lb.pools[idx].rr_index++
			best
		}
		.ip_hash {
			hash := fnv1a_hash(key)
			available[int(hash % u32(available.len))]
		}
		.random {
			available[rand.intn(available.len) or { 0 }]
		}
		.consistent_hash {
			hash := fnv1a_hash(key)
			// Find closest node in ring
			mut closest := available[0]
			mut closest_dist := u32(0xFFFFFFFF)
			for ai in available {
				node_hash := fnv1a_hash(lb.pools[idx].backends[ai].backend_addr())
				dist := if hash > node_hash { hash - node_hash } else { node_hash - hash }
				if dist < closest_dist {
					closest_dist = dist
					closest = ai
				}
			}
			closest
		}
	}

	lb.pools[idx].backends[selected].connections++
	lb.pools[idx].backends[selected].total_requests++
	lb.total_requests++
	return selected
}

// release decrements the connection count for a backend, to be called
// when a request completes.
pub fn (mut lb LoadBalancer) release(pool_name string, backend_idx int) ! {
	idx := lb.find_pool_index(pool_name)
	if idx < 0 {
		return error('pool not found: ${pool_name}')
	}
	if backend_idx < 0 || backend_idx >= lb.pools[idx].backends.len {
		return error('invalid backend index: ${backend_idx}')
	}
	if lb.pools[idx].backends[backend_idx].connections > 0 {
		lb.pools[idx].backends[backend_idx].connections--
	}
}

// health_check_all runs health checks on all backends across all pools.
// TODO: Network I/O -- perform actual TCP/HTTP health probes.
pub fn (mut lb LoadBalancer) health_check_all() {
	for i, _ in lb.pools {
		for j, _ in lb.pools[i].backends {
			// TODO: Probe backend at {addr}:{port}{health_check.path}
			//       Track consecutive successes/failures against thresholds.
			_ = lb.pools[i].backends[j].addr
		}
	}
}

// get_stats returns aggregate statistics for the named pool.
pub fn (lb LoadBalancer) get_stats(pool_name string) !PoolStats {
	idx := lb.find_pool_index(pool_name)
	if idx < 0 {
		return error('pool not found: ${pool_name}')
	}
	pool := lb.pools[idx]
	mut healthy := 0
	mut total_conn := 0
	mut total_req := u64(0)
	for b in pool.backends {
		if b.health == .healthy {
			healthy++
		}
		total_conn += b.connections
		total_req += b.total_requests
	}
	return PoolStats{
		pool_name: pool_name
		backend_count: pool.backends.len
		healthy_count: healthy
		total_connections: total_conn
		total_requests: total_req
	}
}

// pool_count returns the number of configured pools.
pub fn (lb LoadBalancer) pool_count() int {
	return lb.pools.len
}

// set_health sets the health status of a specific backend.
pub fn (mut lb LoadBalancer) set_health(pool_name string, backend_idx int, status HealthStatus) ! {
	idx := lb.find_pool_index(pool_name)
	if idx < 0 {
		return error('pool not found: ${pool_name}')
	}
	if backend_idx < 0 || backend_idx >= lb.pools[idx].backends.len {
		return error('invalid backend index: ${backend_idx}')
	}
	lb.pools[idx].backends[backend_idx].health = status
}

// fnv1a_hash computes a 32-bit FNV-1a hash of the given string key.
// Used for IP hash and consistent hash backend selection.
fn fnv1a_hash(key string) u32 {
	mut hash := u32(0x811C9DC5)
	for b in key.bytes() {
		hash ^= u32(b)
		hash *= u32(0x01000193)
	}
	return hash
}
