// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_proxy -- Reverse proxy with configurable load balancing strategies,
// health checking, and rule-based routing for the V-Ecosystem.
// Maps to proven-servers/protocols/proven-proxy.
// Implements backend selection via round-robin, least-connections, IP hash,
// random, and weighted strategies with per-backend health checking.
module v_proxy

import rand
import time

// LoadBalanceStrategy enumerates the available backend selection algorithms
// for distributing requests across backends.
pub enum LoadBalanceStrategy as u8 {
	round_robin       = 0
	least_connections = 1
	ip_hash           = 2
	random            = 3
	weighted          = 4
}

// strategy_to_string returns the human-readable label for a LoadBalanceStrategy.
pub fn strategy_to_string(s LoadBalanceStrategy) string {
	return match s {
		.round_robin { 'Round Robin' }
		.least_connections { 'Least Connections' }
		.ip_hash { 'IP Hash' }
		.random { 'Random' }
		.weighted { 'Weighted' }
	}
}

// Backend represents a single upstream server behind the proxy.
pub struct Backend {
pub:
	// host is the hostname or IP address of the backend.
	host string
	// port is the listening port of the backend.
	port int
	// weight is the relative weight for weighted load balancing (1-100).
	weight int = 1
pub mut:
	// healthy indicates whether this backend is currently passing health checks.
	healthy bool = true
	// active_connections tracks the number of in-flight requests.
	active_connections int
}

// backend_addr returns the host:port string for a backend.
pub fn (b Backend) backend_addr() string {
	return '${b.host}:${b.port}'
}

// HealthCheck defines the health checking parameters for a proxy rule's
// backends.
pub struct HealthCheck {
pub:
	// interval is the time between health checks in seconds.
	interval int = 30
	// path is the HTTP path to probe (e.g. "/health").
	path string = '/health'
	// expected_status is the HTTP status code that indicates health.
	expected_status int = 200
	// timeout is the health check timeout in seconds.
	timeout int = 5
}

// ProxyRule defines a routing rule that maps request paths to a set of
// backends using a specified load balancing strategy.
pub struct ProxyRule {
pub:
	// path_prefix is the URL path prefix to match (e.g. "/api").
	path_prefix string
	// strategy is the load balancing algorithm to use.
	strategy LoadBalanceStrategy
	// timeout is the request timeout in seconds.
	timeout int = 30
	// retries is the number of retry attempts on failure.
	retries int = 1
	// health_check defines the health checking configuration.
	health_check HealthCheck
pub mut:
	// backends lists the upstream servers for this rule.
	backends []Backend
	// rr_index tracks the round-robin position for this rule.
	rr_index int
}

// healthy_backends returns only the backends currently marked as healthy.
pub fn (r ProxyRule) healthy_backends() []int {
	mut indices := []int{}
	for i, b in r.backends {
		if b.healthy {
			indices << i
		}
	}
	return indices
}

// ProxyRequest represents a simplified incoming HTTP request for routing.
pub struct ProxyRequest {
pub:
	// path is the request URL path.
	path string
	// client_ip is the IP address of the client.
	client_ip string
	// method is the HTTP method (GET, POST, etc.).
	method string
}

// ProxyResponse represents a simplified response from a backend.
pub struct ProxyResponse {
pub:
	// status is the HTTP status code.
	status int
	// backend_addr is the address of the backend that handled the request.
	backend_addr string
	// latency_ms is the response time in milliseconds.
	latency_ms int
}

// ProxyServer manages routing rules and delegates incoming requests to
// the appropriate backend pool.
pub struct ProxyServer {
pub:
	// listen_port is the port the proxy listens on.
	listen_port int
pub mut:
	// rules contains the routing rules in evaluation order.
	rules []ProxyRule
	// total_requests tracks the total number of handled requests.
	total_requests u64
}

// new_server creates a new ProxyServer listening on the given port.
pub fn new_server(port int) &ProxyServer {
	return &ProxyServer{
		listen_port: port
	}
}

// add_rule adds a routing rule to the proxy. Rules are evaluated in
// insertion order; the first matching rule handles the request.
pub fn (mut s ProxyServer) add_rule(rule ProxyRule) {
	s.rules << rule
}

// add_backend adds a backend to the specified rule (identified by path prefix).
// Returns an error if no rule with that prefix exists.
pub fn (mut s ProxyServer) add_backend(path_prefix string, backend Backend) ! {
	for i, _ in s.rules {
		if s.rules[i].path_prefix == path_prefix {
			s.rules[i].backends << backend
			return
		}
	}
	return error('no rule for path prefix: ${path_prefix}')
}

// remove_backend removes a backend by host:port from the specified rule.
// Returns true if a backend was removed.
pub fn (mut s ProxyServer) remove_backend(path_prefix string, host string, port int) !bool {
	for i, _ in s.rules {
		if s.rules[i].path_prefix == path_prefix {
			original_len := s.rules[i].backends.len
			s.rules[i].backends = s.rules[i].backends.filter(!(it.host == host
				&& it.port == port))
			return s.rules[i].backends.len < original_len
		}
	}
	return error('no rule for path prefix: ${path_prefix}')
}

// find_rule finds the first rule whose path prefix matches the request path.
fn (s ProxyServer) find_rule_index(path string) ?int {
	for i, rule in s.rules {
		if path.starts_with(rule.path_prefix) {
			return i
		}
	}
	return none
}

// select_backend chooses a backend from the given rule according to its
// load balancing strategy. Returns the backend index or an error.
pub fn (mut s ProxyServer) select_backend(rule_index int, client_ip string) !int {
	if rule_index < 0 || rule_index >= s.rules.len {
		return error('invalid rule index: ${rule_index}')
	}
	healthy := s.rules[rule_index].healthy_backends()
	if healthy.len == 0 {
		return error('no healthy backends for ${s.rules[rule_index].path_prefix}')
	}

	return match s.rules[rule_index].strategy {
		.round_robin {
			idx := healthy[s.rules[rule_index].rr_index % healthy.len]
			s.rules[rule_index].rr_index++
			idx
		}
		.least_connections {
			mut min_conn := s.rules[rule_index].backends[healthy[0]].active_connections
			mut min_idx := healthy[0]
			for hi in healthy {
				conn := s.rules[rule_index].backends[hi].active_connections
				if conn < min_conn {
					min_conn = conn
					min_idx = hi
				}
			}
			min_idx
		}
		.ip_hash {
			mut hash := u32(0)
			for b in client_ip.bytes() {
				hash = hash * 31 + u32(b)
			}
			healthy[int(hash % u32(healthy.len))]
		}
		.random {
			healthy[rand.intn(healthy.len) or { 0 }]
		}
		.weighted {
			// Weighted selection proportional to backend weight
			mut total_weight := 0
			for hi in healthy {
				total_weight += s.rules[rule_index].backends[hi].weight
			}
			mut target := rand.intn(total_weight) or { 0 }
			mut selected := healthy[0]
			for hi in healthy {
				target -= s.rules[rule_index].backends[hi].weight
				if target < 0 {
					selected = hi
					break
				}
			}
			selected
		}
	}
}

// handle_request routes an incoming request to the appropriate backend.
// Returns a ProxyResponse or an error if no rule matches or no backend
// is available.
// TODO: Network I/O -- actually proxy the HTTP request to the selected backend.
pub fn (mut s ProxyServer) handle_request(req ProxyRequest) !ProxyResponse {
	rule_idx := s.find_rule_index(req.path) or {
		return error('no matching rule for path: ${req.path}')
	}
	backend_idx := s.select_backend(rule_idx, req.client_ip)!
	s.rules[rule_idx].backends[backend_idx].active_connections++
	s.total_requests++

	addr := s.rules[rule_idx].backends[backend_idx].backend_addr()
	// TODO: Forward request to backend and return actual response.
	//       For now, return a placeholder 200 OK.
	s.rules[rule_idx].backends[backend_idx].active_connections--
	return ProxyResponse{
		status: 200
		backend_addr: addr
		latency_ms: 0
	}
}

// health_check runs health checks on all backends for a given rule.
// TODO: Network I/O -- actually HTTP GET the health check path.
pub fn (mut s ProxyServer) health_check(path_prefix string) ! {
	for i, _ in s.rules {
		if s.rules[i].path_prefix == path_prefix {
			for j, _ in s.rules[i].backends {
				// TODO: HTTP GET http://{host}:{port}{health_check.path}
				//       Compare status code with expected_status.
				//       For now, maintain current health state.
				_ = s.rules[i].backends[j].host
			}
			return
		}
	}
	return error('no rule for path prefix: ${path_prefix}')
}

// rule_count returns the number of configured routing rules.
pub fn (s ProxyServer) rule_count() int {
	return s.rules.len
}
