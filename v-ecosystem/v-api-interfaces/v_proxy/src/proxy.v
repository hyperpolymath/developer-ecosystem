// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Forward and reverse proxy with connection pooling and header rewriting Connector
// Author: Jonathan D.A. Jewell
//
// Forward and reverse proxy with connection pooling and header rewriting.
// Provides typed client bindings for the proven-proxy protocol.

module proxy

import os
import time
import net

// --- Proxy mode ---

// ProxyMode selects the proxy direction.
pub enum ProxyMode {
	forward      // Client-side proxy
	reverse      // Server-side proxy
	transparent  // Transparent intercept
}

// --- Data structures ---

// ProxyUpstream defines a backend upstream server.
pub struct ProxyUpstream {
pub:
	name        string
	address     string
	port        int
	weight      int = 1
	tls         bool = true
}

// HeaderRule defines a header rewriting rule.
pub struct HeaderRule {
pub:
	operation   string   // "add", "remove", "replace"
	header_name string
	value       string
}

// ProxyConfig holds proxy parameters.
pub struct ProxyConfig {
pub:
	mode         ProxyMode = .reverse
	listen_addr  string = "0.0.0.0"
	listen_port  int = 8080
	max_conns    int = 1024
}

// ProxyManager manages proxy upstreams and rules.
pub struct ProxyManager {
mut:
	config     ProxyConfig
	upstreams  []ProxyUpstream
	headers    []HeaderRule
}

// --- Manager lifecycle ---

// new_proxy_manager creates a new proxy manager.
pub fn new_proxy_manager(config ProxyConfig) &ProxyManager {
	return &ProxyManager{
		config:    config
		upstreams: []ProxyUpstream{}
		headers:   []HeaderRule{}
	}
}

// add_upstream registers a backend upstream.
pub fn (mut m ProxyManager) add_upstream(upstream ProxyUpstream) ! {
	if upstream.name.len == 0 {
		return error("upstream name must not be empty")
	}
	m.upstreams << upstream
	println("[proxy] added upstream: ${upstream.name} -> ${upstream.address}:${upstream.port}")
}

// add_header_rule adds a header rewriting rule.
pub fn (mut m ProxyManager) add_header_rule(rule HeaderRule) ! {
	if rule.header_name.len == 0 {
		return error("header_name must not be empty")
	}
	m.headers << rule
	println("[proxy] header rule: ${rule.operation} ${rule.header_name}")
}

// --- Tests ---

fn test_empty_upstream_name_rejected() {
	mut mgr := new_proxy_manager(ProxyConfig{})
	mgr.add_upstream(ProxyUpstream{ name: "", address: "localhost", port: 8080 }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
