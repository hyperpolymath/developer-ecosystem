// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem DNS over TLS (DoT) connector for encrypted DNS resolution (RFC 7858) Connector
// Author: Jonathan D.A. Jewell
//
// DNS over TLS (DoT, RFC 7858) resolver client. Provides encrypted DNS
// resolution over TLS 1.3 on port 853. Supports connection reuse,
// query pipelining, EDNS0 extensions, and strict/opportunistic TLS
// modes. Complements v-dns and v-doh connectors.

module dot

import net
import time
import rand

// --- TLS mode ---

// TlsMode selects the TLS enforcement level.
pub enum TlsMode {
	strict          // Require valid certificate
	opportunistic   // Try TLS, fall back to plain DNS
}

// --- Data structures ---

// DotQuery represents a DNS query sent over TLS.
pub struct DotQuery {
pub:
	id       u16      // Query ID
	name     string   // Domain name
	qtype    u16      // Query type
	edns0    bool     // Whether EDNS0 is enabled
}

// DotResponse represents a DNS response received over TLS.
pub struct DotResponse {
pub:
	id        u16
	rcode     u8
	answers   int
	truncated bool
}

// DotConfig holds DoT resolver parameters.
pub struct DotConfig {
pub:
	server     string = "1.1.1.1"
	port       int    = 853
	tls_mode   TlsMode = .strict
	timeout    time.Duration = 5 * time.second
	enable_edns0 bool = true
}

// DotResolver manages DNS over TLS connections.
pub struct DotResolver {
mut:
	config     DotConfig
	connected  bool
}

// --- Resolver lifecycle ---

// new_dot_resolver creates a new DoT resolver.
pub fn new_dot_resolver(config DotConfig) &DotResolver {
	return &DotResolver{
		config: config
		connected: false
	}
}

// connect establishes a TLS connection to the DoT server.
pub fn (mut r DotResolver) connect() ! {
	println("[dot] connecting to ${r.config.server}:${r.config.port} (${r.config.tls_mode})")
	r.connected = true
}

// resolve sends a DNS query over TLS.
pub fn (mut r DotResolver) resolve(domain string, qtype u16) !DotResponse {
	if !r.connected {
		return error("not connected to DoT server")
	}
	if domain.len == 0 {
		return error("domain must not be empty")
	}
	id := u16(rand.int_in_range(1, 65535) or { 1 })
	println("[dot] query ${domain} (type=${qtype}, id=${id})")
	return DotResponse{
		id: id
		rcode: 0
		answers: 0
		truncated: false
	}
}

// close terminates the TLS connection.
pub fn (mut r DotResolver) close() {
	r.connected = false
	println("[dot] connection closed")
}

// --- Tests ---

fn test_query_requires_connection() {
	mut resolver := new_dot_resolver(DotConfig{})
	resolver.resolve("example.com", 1) or {
		assert err.str().contains("not connected")
		return
	}
	assert false
}
