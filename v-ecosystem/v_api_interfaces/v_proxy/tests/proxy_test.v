// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// proxy_test -- Protocol conformance tests for v_proxy.
// Covers server creation, rule management, backend addition/removal,
// load balancing strategies, request routing, and health check configuration.
module v_proxy

// test_strategy_to_string verifies human-readable labels for all
// load balancing strategies.
fn test_strategy_to_string() {
	assert strategy_to_string(.round_robin) == 'Round Robin'
	assert strategy_to_string(.least_connections) == 'Least Connections'
	assert strategy_to_string(.ip_hash) == 'IP Hash'
	assert strategy_to_string(.random) == 'Random'
	assert strategy_to_string(.weighted) == 'Weighted'
}

// test_backend_addr verifies the host:port string representation.
fn test_backend_addr() {
	b := Backend{
		host: '10.0.0.1'
		port: 8080
	}
	assert b.backend_addr() == '10.0.0.1:8080'
}

// test_new_server verifies server creation with correct defaults.
fn test_new_server() {
	s := new_server(8080)
	assert s.listen_port == 8080
	assert s.rule_count() == 0
}

// test_add_rule verifies rule addition.
fn test_add_rule() {
	mut s := new_server(8080)
	s.add_rule(ProxyRule{
		path_prefix: '/api'
		strategy: .round_robin
		backends: [
			Backend{
				host: '10.0.0.1'
				port: 3000
			},
		]
	})
	assert s.rule_count() == 1
}

// test_add_backend verifies backend addition to existing rule.
fn test_add_backend() {
	mut s := new_server(8080)
	s.add_rule(ProxyRule{
		path_prefix: '/api'
		strategy: .round_robin
	})
	s.add_backend('/api', Backend{
		host: '10.0.0.1'
		port: 3000
	})!
	assert s.rules[0].backends.len == 1
}

// test_add_backend_bad_prefix verifies error for missing rule.
fn test_add_backend_bad_prefix() {
	mut s := new_server(8080)
	s.add_backend('/missing', Backend{
		host: '10.0.0.1'
		port: 3000
	}) or {
		assert err.msg().contains('no rule')
		return
	}
	assert false, 'expected error for missing rule'
}

// test_remove_backend verifies backend removal.
fn test_remove_backend() {
	mut s := new_server(8080)
	s.add_rule(ProxyRule{
		path_prefix: '/api'
		strategy: .round_robin
		backends: [
			Backend{
				host: '10.0.0.1'
				port: 3000
			},
		]
	})
	removed := s.remove_backend('/api', '10.0.0.1', 3000)!
	assert removed == true
	assert s.rules[0].backends.len == 0
}

// test_healthy_backends verifies filtering of healthy backends.
fn test_healthy_backends() {
	rule := ProxyRule{
		path_prefix: '/test'
		strategy: .round_robin
		backends: [
			Backend{
				host: '10.0.0.1'
				port: 3000
				healthy: true
			},
			Backend{
				host: '10.0.0.2'
				port: 3000
				healthy: false
			},
			Backend{
				host: '10.0.0.3'
				port: 3000
				healthy: true
			},
		]
	}
	healthy := rule.healthy_backends()
	assert healthy.len == 2
	assert healthy[0] == 0
	assert healthy[1] == 2
}

// test_round_robin_selection verifies round-robin cycles through backends.
fn test_round_robin_selection() {
	mut s := new_server(8080)
	s.add_rule(ProxyRule{
		path_prefix: '/'
		strategy: .round_robin
		backends: [
			Backend{
				host: '10.0.0.1'
				port: 3000
			},
			Backend{
				host: '10.0.0.2'
				port: 3000
			},
		]
	})
	b1 := s.select_backend(0, '1.2.3.4')!
	b2 := s.select_backend(0, '1.2.3.4')!
	assert b1 != b2
}

// test_least_connections_selection verifies least-connections picks the
// backend with fewest active connections.
fn test_least_connections_selection() {
	mut s := new_server(8080)
	s.add_rule(ProxyRule{
		path_prefix: '/'
		strategy: .least_connections
		backends: [
			Backend{
				host: '10.0.0.1'
				port: 3000
				active_connections: 10
			},
			Backend{
				host: '10.0.0.2'
				port: 3000
				active_connections: 2
			},
		]
	})
	selected := s.select_backend(0, '1.2.3.4')!
	assert selected == 1 // 10.0.0.2 has fewer connections
}

// test_ip_hash_deterministic verifies that IP hash produces consistent
// results for the same client IP.
fn test_ip_hash_deterministic() {
	mut s := new_server(8080)
	s.add_rule(ProxyRule{
		path_prefix: '/'
		strategy: .ip_hash
		backends: [
			Backend{
				host: '10.0.0.1'
				port: 3000
			},
			Backend{
				host: '10.0.0.2'
				port: 3000
			},
			Backend{
				host: '10.0.0.3'
				port: 3000
			},
		]
	})
	b1 := s.select_backend(0, '192.168.1.100')!
	b2 := s.select_backend(0, '192.168.1.100')!
	assert b1 == b2
}

// test_handle_request verifies end-to-end request routing.
fn test_handle_request() {
	mut s := new_server(8080)
	s.add_rule(ProxyRule{
		path_prefix: '/api'
		strategy: .round_robin
		backends: [
			Backend{
				host: '10.0.0.1'
				port: 3000
			},
		]
	})
	resp := s.handle_request(ProxyRequest{
		path: '/api/users'
		client_ip: '1.2.3.4'
		method: 'GET'
	})!
	assert resp.status == 200
	assert resp.backend_addr == '10.0.0.1:3000'
	assert s.total_requests == 1
}

// test_handle_request_no_rule verifies error for unmatched path.
fn test_handle_request_no_rule() {
	mut s := new_server(8080)
	s.handle_request(ProxyRequest{
		path: '/unknown'
		client_ip: '1.2.3.4'
		method: 'GET'
	}) or {
		assert err.msg().contains('no matching rule')
		return
	}
	assert false, 'expected error for unmatched path'
}
