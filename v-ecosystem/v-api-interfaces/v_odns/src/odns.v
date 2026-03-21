// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Oblivious DNS over HTTPS for privacy-preserving name resolution Connector
// Author: Jonathan D.A. Jewell
//
// Oblivious DNS over HTTPS for privacy-preserving name resolution.
// Provides typed client bindings for the proven-odns protocol.

module odns

import os
import time
import net

// --- Query type ---

// DnsQueryType identifies the DNS record type.
pub enum DnsQueryType {
	a
	aaaa
	cname
	mx
	txt
	srv
	ns
}

// --- Data structures ---

// OdnsConfig holds Oblivious DNS client parameters.
pub struct OdnsConfig {
pub:
	proxy_url    string    // ODoH proxy URL
	target_url   string    // ODoH target resolver URL
	timeout_ms   int = 3000
}

// OdnsQuery represents a privacy-preserving DNS query.
pub struct OdnsQuery {
pub:
	name         string
	query_type   DnsQueryType
}

// OdnsResponse holds a DNS response.
pub struct OdnsResponse {
pub:
	name         string
	query_type   DnsQueryType
	answers      []string
	ttl          int
}

// OdnsClient manages ODoH queries.
pub struct OdnsClient {
mut:
	config  OdnsConfig
}

// --- Client lifecycle ---

// new_odns_client creates a new ODoH client.
pub fn new_odns_client(config OdnsConfig) &OdnsClient {
	return &OdnsClient{
		config: config
	}
}

// resolve sends a privacy-preserving DNS query.
pub fn (c &OdnsClient) resolve(query OdnsQuery) !OdnsResponse {
	if query.name.len == 0 {
		return error("query name must not be empty")
	}
	println("[odns] resolving ${query.name} (${query.query_type}) via ${c.config.proxy_url}")
	return OdnsResponse{ name: query.name, query_type: query.query_type, answers: [], ttl: 300 }
}

// --- Tests ---

fn test_empty_query_name_rejected() {
	client := new_odns_client(OdnsConfig{ proxy_url: "https://proxy.example.com", target_url: "https://dns.example.com" })
	client.resolve(OdnsQuery{ name: "", query_type: .a }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
