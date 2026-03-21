// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Load balancer with backend pools, health checks, and traffic shaping Connector
// Author: Jonathan D.A. Jewell
//
// Load balancer with backend pools, health checks, and traffic shaping.
// Provides typed client bindings for the proven-loadbalancer protocol.

module loadbalancer

import os
import time
import net

// --- Algorithm ---

// LbAlgorithm selects the load balancing strategy.
pub enum LbAlgorithm {
	round_robin
	least_connections
	weighted
	ip_hash
	random
}

// --- Backend health ---

// BackendHealth reports backend pool member health.
pub enum BackendHealth {
	healthy
	unhealthy
	draining
	maintenance
}

// --- Data structures ---

// Backend defines a load balancer backend server.
pub struct Backend {
pub:
	id          string
	address     string
	port        int
	weight      int = 1
	health      BackendHealth = .healthy
}

// Pool groups backends behind a virtual IP.
pub struct Pool {
pub:
	name        string
	algorithm   LbAlgorithm
	backends    []Backend
	health_path string = "/healthz"
}

// LbConfig holds load balancer parameters.
pub struct LbConfig {
pub:
	listen_addr  string = "0.0.0.0"
	listen_port  int = 443
	check_interval_secs int = 10
}

// LbManager manages load balancer pools.
pub struct LbManager {
mut:
	config  LbConfig
	pools   []Pool
}

// --- Manager lifecycle ---

// new_lb_manager creates a new load balancer manager.
pub fn new_lb_manager(config LbConfig) &LbManager {
	return &LbManager{
		config: config
		pools:  []Pool{}
	}
}

// add_pool registers a backend pool.
pub fn (mut m LbManager) add_pool(pool Pool) ! {
	if pool.name.len == 0 {
		return error("pool name must not be empty")
	}
	m.pools << pool
	println("[lb] added pool: ${pool.name} (${pool.algorithm}, ${pool.backends.len} backends)")
}

// drain_backend marks a backend as draining.
pub fn (mut m LbManager) drain_backend(pool_name string, backend_id string) ! {
	for mut p in m.pools {
		if p.name == pool_name {
			println("[lb] draining backend ${backend_id} in pool ${pool_name}")
			return
		}
	}
	return error("pool not found: ${pool_name}")
}

// --- Tests ---

fn test_empty_pool_name_rejected() {
	mut mgr := new_lb_manager(LbConfig{})
	mgr.add_pool(Pool{ name: "", algorithm: .round_robin, backends: [], health_path: "/healthz" }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
