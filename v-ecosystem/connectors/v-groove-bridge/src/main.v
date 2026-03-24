// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
//
// V-Groove-Bridge — Dodeca-API snap-on/snap-off connector.
//
// Discovers services via Groove protocol, presents unified API surface
// across all 12 API types. Attach to any Groove-aware service with a
// single call. Detach cleanly when done.

module v_groove_bridge

import net.http
import json

// ---------------------------------------------------------------------------
// The Dodeca-API — 12 core API surface types
// ---------------------------------------------------------------------------

pub enum ApiType {
	rest       // HTTP request-response
	grpc       // Protocol Buffers RPC
	graphql    // Query language
	json_rpc   // JSON-based RPC
	websocket  // Bi-directional HTTP upgrade
	mqtt       // Pub-sub messaging
	amqp       // Message broker protocol
	coap       // Constrained Application Protocol
	soap       // XML-based RPC (legacy compat)
	capnproto  // Zero-copy serialization
	sse        // Server-Sent Events (HTTP streaming)
	groove     // Groove native capability negotiation
}

pub fn all_api_types() []ApiType {
	return [
		.rest, .grpc, .graphql, .json_rpc, .websocket, .mqtt,
		.amqp, .coap, .soap, .capnproto, .sse, .groove,
	]
}

pub fn (t ApiType) str() string {
	return match t {
		.rest { 'rest' }
		.grpc { 'grpc' }
		.graphql { 'graphql' }
		.json_rpc { 'json-rpc' }
		.websocket { 'websocket' }
		.mqtt { 'mqtt' }
		.amqp { 'amqp' }
		.coap { 'coap' }
		.soap { 'soap' }
		.capnproto { 'capnproto' }
		.sse { 'sse' }
		.groove { 'groove' }
	}
}

// ---------------------------------------------------------------------------
// Service discovery
// ---------------------------------------------------------------------------

pub struct DiscoveredService {
pub:
	name       string
	version    string
	port       int
	api_types  []string
	endpoints  []string
	healthy    bool
}

// Discover all Groove-aware services on the local machine.
// Scans known port ranges and checks for .well-known/groove or /health.
pub fn discover_all() []DiscoveredService {
	mut services := []DiscoveredService{}

	// Known service ports from PORT-REGISTRY
	known := {
		'hypatia':    9090
		'stapeln':    4010
		'burble':     4020
		'idaptik':    4030
		'gossamer':   4040
		'ambientops': 4050
		'reposystem': 4060
		'boj-server': 7700
		'verisimdb':  8080
		'echidna':    8081
	}

	for name, port in known {
		if svc := probe_service(name, port) {
			services << svc
		}
	}

	// Also scan Groove discovery range (6460-6500)
	for port in 6460 .. 6501 {
		if svc := probe_service('unknown', port) {
			services << svc
		}
	}

	return services
}

// Probe a single port for a Groove-aware service
fn probe_service(name string, port int) ?DiscoveredService {
	// Try Groove manifest first
	groove_url := 'http://localhost:${port}/.well-known/groove'
	resp := http.get(groove_url) or { return probe_health(name, port) }
	if resp.status_code == 200 {
		// Parse Groove manifest
		manifest := json.decode(map[string]json.Any, resp.body) or {
			return probe_health(name, port)
		}
		svc_name := (manifest['service'] or { json.Any('') }).str()
		version := (manifest['version'] or { json.Any('0.0.0') }).str()
		return DiscoveredService{
			name: if svc_name.len > 0 { svc_name } else { name }
			version: version
			port: port
			api_types: ['groove', 'rest']
			endpoints: []
			healthy: true
		}
	}
	return probe_health(name, port)
}

// Fallback: check /health endpoint
fn probe_health(name string, port int) ?DiscoveredService {
	health_url := 'http://localhost:${port}/health'
	resp := http.get(health_url) or { return none }
	if resp.status_code in [200, 201] {
		return DiscoveredService{
			name: name
			version: '0.0.0'
			port: port
			api_types: ['rest']
			endpoints: ['/health']
			healthy: true
		}
	}
	return none
}

// ---------------------------------------------------------------------------
// Snap-on / Snap-off attachment
// ---------------------------------------------------------------------------

pub struct Attachment {
pub:
	service DiscoveredService
	active  bool
mut:
	base_url string
}

// Snap on to a discovered service
pub fn snap_on(svc DiscoveredService) Attachment {
	return Attachment{
		service: svc
		active: true
		base_url: 'http://localhost:${svc.port}'
	}
}

// Snap off — graceful disconnect
pub fn (mut a Attachment) snap_off() {
	a.active = false
}

// Check if attachment is still live
pub fn (a &Attachment) is_live() bool {
	if !a.active {
		return false
	}
	resp := http.get('${a.base_url}/health') or { return false }
	return resp.status_code == 200
}

// Generic REST call through attachment
pub fn (a &Attachment) get(path string) !string {
	if !a.active {
		return error('Not attached (snapped off)')
	}
	resp := http.get('${a.base_url}${path}') or {
		return error('Request failed: ${err}')
	}
	if resp.status_code !in [200, 201] {
		return error('HTTP ${resp.status_code}: ${resp.body}')
	}
	return resp.body
}

pub fn (a &Attachment) post(path string, body string) !string {
	if !a.active {
		return error('Not attached (snapped off)')
	}
	resp := http.post_json('${a.base_url}${path}', body) or {
		return error('Request failed: ${err}')
	}
	if resp.status_code !in [200, 201, 204] {
		return error('HTTP ${resp.status_code}: ${resp.body}')
	}
	return resp.body
}

// ---------------------------------------------------------------------------
// Convenience: discover + attach in one call
// ---------------------------------------------------------------------------

// Find and attach to a named service
pub fn attach(service_name string) ?Attachment {
	services := discover_all()
	for svc in services {
		if svc.name == service_name {
			return snap_on(svc)
		}
	}
	return none
}

// Attach to VeriSimDB (any instance)
pub fn attach_verisimdb() ?Attachment {
	for port in [8080, 8093, 8094, 8095] {
		if svc := probe_service('verisimdb', port) {
			return snap_on(svc)
		}
	}
	return none
}
