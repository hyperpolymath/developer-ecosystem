// SPDX-License-Identifier: PMPL-1.0-or-later
//
// main.v — Aerie Gateway: Triple-Mount API Server
//
// Serves up to three API protocols from a single gateway process:
//
//   1. GraphQL  — POST /graphql                        (port 4000)
//   2. REST     — GET  /api/v1/{telemetry,routes,audit,audit/temporal,smokeping} (port 4000)
//   3. gRPC     — binary protobuf                       (port 4001)
//
// Each protocol can be independently enabled or disabled via environment
// variables, allowing operators to reduce the attack surface by only
// exposing the protocols they actually use:
//
//   ENABLE_REST=true|false       (default: true)
//   ENABLE_GRAPHQL=true|false    (default: true)
//   ENABLE_GRPC=true|false       (default: true)
//
// Disabled protocols refuse connections immediately — no socket is
// opened, no port is bound, no attack surface exists.
//
// All responses are wrapped in a ProofEnvelope (SHA-256 hash in Phase 1,
// Ed448 signature in Phase 2+). The policy gate checks X-Api-Key headers
// and logs all access to the Redis audit trail.
//
// Backend services (in aerie-net container network):
//   - LibreSpeed  at LIBRESPEED_URL  (default http://librespeed:80)
//   - Hyperglass  at HYPERGLASS_URL  (default http://hyperglass:80)
//   - Redis       at REDIS_URL       (default redis://redis:6379)
//   - VerisimDB   at VERISIMDB_URL   (default http://verisimdb:8084)

module main

import os
import net
import net.http
import x.json2
import time

// ProtocolConfig holds the enabled/disabled state for each protocol.
// Read once at startup from environment variables — immutable thereafter.
struct ProtocolConfig {
pub:
	rest_enabled    bool
	graphql_enabled bool
	grpc_enabled    bool
}

// read_protocol_config reads ENABLE_REST, ENABLE_GRAPHQL, ENABLE_GRPC
// from the environment. All default to true (full triple-mount).
// Set any to "false" or "0" to disable that protocol entirely.
fn read_protocol_config() ProtocolConfig {
	return ProtocolConfig{
		rest_enabled:    env_bool('ENABLE_REST', true)
		graphql_enabled: env_bool('ENABLE_GRAPHQL', true)
		grpc_enabled:    env_bool('ENABLE_GRPC', true)
	}
}

// env_bool reads a boolean environment variable. Recognises "false",
// "0", and "no" as false (case-insensitive). Everything else
// (including unset) returns the provided default.
fn env_bool(name string, default_val bool) bool {
	val := os.getenv(name).to_lower()
	if val.len == 0 {
		return default_val
	}
	return val != 'false' && val != '0' && val != 'no'
}

// banner prints the startup banner to stdout showing which protocols
// are enabled and on which ports. Disabled protocols show as "disabled".
fn banner(http_port int, grpc_port int, cfg ProtocolConfig) {
	// Count active protocols for the title
	mut active := []string{}
	if cfg.graphql_enabled {
		active << 'GraphQL'
	}
	if cfg.grpc_enabled {
		active << 'gRPC'
	}
	if cfg.rest_enabled {
		active << 'REST'
	}

	proto_list := if active.len > 0 { active.join(' + ') } else { 'NONE (all disabled!)' }

	println('╔══════════════════════════════════════════════════════════╗')
	println('║          AERIE GATEWAY — ${proto_list:-31}║')
	println('╠══════════════════════════════════════════════════════════╣')

	// REST status
	if cfg.rest_enabled {
		println('║  REST            : port ${http_port:-5} ✓ ENABLED                 ║')
	} else {
		println('║  REST            : ✗ DISABLED (no socket bound)         ║')
	}

	// GraphQL status
	if cfg.graphql_enabled {
		println('║  GraphQL         : port ${http_port:-5} ✓ ENABLED                 ║')
	} else {
		println('║  GraphQL         : ✗ DISABLED (no socket bound)         ║')
	}

	// gRPC status
	if cfg.grpc_enabled {
		println('║  gRPC            : port ${grpc_port:-5} ✓ ENABLED                 ║')
	} else {
		println('║  gRPC            : ✗ DISABLED (no socket bound)         ║')
	}

	println('╠══════════════════════════════════════════════════════════╣')
	println('║  Proof mode      : light (SHA-256)                      ║')
	println('║  Policy gate     : Phase 1 (permissive)                 ║')
	println('║  Attack surface  : ${active.len}/3 protocols active                    ║')
	println('╚══════════════════════════════════════════════════════════╝')
}

fn main() {
	// Read configuration from environment
	mut http_port := os.getenv('PORT').int()
	if http_port == 0 {
		http_port = 4000
	}
	mut grpc_port := os.getenv('GRPC_PORT').int()
	if grpc_port == 0 {
		grpc_port = 4001
	}

	cfg := read_protocol_config()
	banner(http_port, grpc_port, cfg)

	// Initialise Redis client (lazy connection).
	// Heap-allocated so it can be shared by reference across threads.
	mut redis := &RedisClient{
		...new_redis_client()
	}

	// Initialise VerisimDB client (HTTP REST, fire-and-forget)
	verisimdb := new_verisimdb_client()

	// Determine whether we need the HTTP server at all
	http_needed := cfg.rest_enabled || cfg.graphql_enabled

	// Start gRPC listener in a background thread (only if enabled).
	// The redis parameter is passed as a heap reference (&RedisClient)
	// so that spawn can safely share it across threads.
	if cfg.grpc_enabled {
		println('[aerie] Starting gRPC listener on :${grpc_port}')
		spawn grpc_listener(grpc_port, mut redis)
	} else {
		println('[aerie] gRPC DISABLED — port ${grpc_port} not bound')
	}

	// Start HTTP server (only if REST or GraphQL is enabled).
	// V 0.5.0 uses `addr` (string) instead of `port` (int) in http.Server.
	if http_needed {
		println('[aerie] Starting HTTP server on :${http_port}')
		verbs := new_verb_governor()
		mut server := http.Server{
			addr: ':${http_port}'
			handler: AerieHandler{
				redis:     redis
				config:    cfg
				verbs:     verbs
				verisimdb: verisimdb
			}
		}
		server.listen_and_serve()
	} else {
		println('[aerie] REST and GraphQL both DISABLED — port ${http_port} not bound')
		// If only gRPC is enabled, block the main thread so the process
		// stays alive for the gRPC background thread
		if cfg.grpc_enabled {
			println('[aerie] Main thread idle (gRPC-only mode)')
			for {
				time.sleep(60 * time.second)
			}
		} else {
			eprintln('[aerie] WARNING: All protocols disabled — gateway has nothing to serve')
		}
	}
}

// AerieHandler dispatches HTTP requests to the appropriate handler
// based on the URL path and protocol configuration. Verb governance
// is enforced before any routing — disallowed methods are rejected
// (or stealth-404'd) before reaching the resolver layer.
struct AerieHandler {
mut:
	redis     &RedisClient
	config    ProtocolConfig
	verbs     VerbGovernor
	verisimdb VerisimDBClient
}

// handle processes an incoming HTTP request through the policy gate,
// checks protocol enablement, dispatches to the appropriate resolver,
// and returns the response with CORS and content-type headers.
fn (mut h AerieHandler) handle(req http.Request) http.Response {
	// Extract API key from header for policy gate
	api_key := req.header.get_custom('X-Api-Key') or { '' }

	// Determine which module is being accessed
	module_name := match true {
		req.url.starts_with('/graphql') { 'graphql' }
		req.url.starts_with('/api/v1/telemetry') { 'telemetry' }
		req.url.starts_with('/api/v1/routes') { 'routes' }
		req.url.starts_with('/api/v1/audit/temporal') { 'temporal_audit' }
		req.url.starts_with('/api/v1/audit') { 'audit' }
		req.url.starts_with('/api/v1/smokeping') { 'smokeping' }
		req.url.starts_with('/api/v1/health') { 'health' }
		else { 'unknown' }
	}

	// Evaluate policy
	policy := evaluate_policy(api_key, module_name)

	// Response headers: CORS, security, and connection management.
	// Force Connection: close to prevent clients holding threads open
	// indefinitely via keep-alive. Each request gets a fresh connection.
	mut headers := http.new_header(
		key: .content_type
		value: 'application/json'
	)
	headers.add_custom('Connection', 'close') or {}
	headers.add_custom('Access-Control-Allow-Origin', '*') or {}
	headers.add_custom('Access-Control-Allow-Headers', 'Content-Type, X-Api-Key') or {}
	headers.add_custom('Access-Control-Allow-Methods', 'GET, POST, OPTIONS') or {}
	headers.add_custom('X-Aerie-Proof-Type', 'light') or {}
	// Security headers — prevent MIME sniffing, clickjacking, XSS reflection
	headers.add_custom('X-Content-Type-Options', 'nosniff') or {}
	headers.add_custom('X-Frame-Options', 'DENY') or {}
	headers.add_custom('X-XSS-Protection', '0') or {}
	headers.add_custom('Referrer-Policy', 'no-referrer') or {}
	headers.add_custom('Cache-Control', 'no-store') or {}

	// Verb governance — enforce allowed HTTP methods per route.
	// This runs BEFORE the policy gate so disallowed verbs never
	// reach any business logic. Stealth mode returns 404 so
	// attackers cannot distinguish denied from non-existent.
	verb_decision := h.verbs.check(req.method.str(), req.url)
	if !verb_decision.allowed {
		// Log the denied verb attempt
		denied_audit := AuditEvent{
			event_id:   generate_uuid_v4()
			valid_time: time.now().format_rfc3339()
			tx_time:    time.now().format_rfc3339()
			severity:   'warning'
			message:    'Verb denied: ${verb_decision.verb} on ${req.url} [rule=${verb_decision.rule_name}, stealth=${verb_decision.stealth}]'
			tags:       ['verb-governance', 'denied', verb_decision.verb.to_lower()]
		}
		h.redis.log_audit(denied_audit)

		// Timing side-channel mitigation: sleep a random 1-8ms before
		// returning stealth 404s. This makes denied responses statistically
		// indistinguishable from genuine responses, even over thousands
		// of samples. Without this, denials return in <0.1ms while real
		// responses take 2-10ms — trivially detectable.
		if verb_decision.stealth {
			h.verbs.stealth_delay()
		}

		return http.Response{
			status_code: verb_decision.denial_status_code()
			body:        verb_decision.denial_body(h.config)
			header:      headers
		}
	}

	// Handle CORS preflight (verb governor already approved OPTIONS above)
	if req.method == .options {
		return http.Response{
			status_code: 204
			header:      headers
		}
	}

	// Policy gate — Phase 1 always allows, but log the decision
	if !policy.allowed {
		return http.Response{
			status_code: 403
			body:        '{"error":"Access denied","reason":"${policy.reason}"}'
			header:      headers
		}
	}

	// Check protocol enablement before routing
	if req.url.starts_with('/graphql') && !h.config.graphql_enabled {
		return http.Response{
			status_code: 404
			body:        '{"error":"GraphQL protocol is disabled","hint":"Set ENABLE_GRAPHQL=true to enable"}'
			header:      headers
		}
	}
	if req.url.starts_with('/api/v1/') && !req.url.starts_with('/api/v1/health') && !h.config.rest_enabled {
		return http.Response{
			status_code: 404
			body:        '{"error":"REST protocol is disabled","hint":"Set ENABLE_REST=true to enable"}'
			header:      headers
		}
	}

	// Route to handler
	body := match true {
		req.url.starts_with('/graphql') {
			handle_graphql_request(req, mut h.redis, policy)
		}
		req.url.starts_with('/api/v1/telemetry') {
			resolve_telemetry(mut h.redis, policy)
		}
		req.url.starts_with('/api/v1/routes') {
			handle_routes_request(req, mut h.redis, policy)
		}
		req.url.starts_with('/api/v1/audit/temporal') {
			handle_temporal_audit_request(req, mut h.redis, h.verisimdb, policy)
		}
		req.url.starts_with('/api/v1/audit') {
			handle_audit_request(req, mut h.redis, policy)
		}
		req.url.starts_with('/api/v1/smokeping') {
			handle_smokeping_request(req, mut h.redis, policy)
		}
		req.url.starts_with('/api/v1/health') {
			health_check(h.config)
		}
		else {
			not_found_response(h.config)
		}
	}

	status := if req.url.starts_with('/api/v1/health') || body.contains('"error"') == false {
		200
	} else if body.contains('"Not found"') {
		404
	} else {
		200
	}

	return http.Response{
		status_code: status
		body:        body
		header:      headers
	}
}

// handle_graphql_request parses the GraphQL request body and dispatches
// to the resolver. Supports both application/json and raw query bodies.
fn handle_graphql_request(req http.Request, mut redis RedisClient, policy PolicyDecision) string {
	if req.method != .post {
		return '{"errors":[{"message":"GraphQL endpoint requires POST method"}]}'
	}

	// Parse the request body to extract the query string
	query := extract_graphql_query(req.data)
	if query.len == 0 {
		return '{"errors":[{"message":"Missing query field in request body"}]}'
	}

	return resolve_graphql_query(query, mut redis, policy)
}

// extract_graphql_query pulls the "query" field from a JSON request body.
// Handles standard GraphQL-over-HTTP format: {"query": "...", "variables": {...}}
fn extract_graphql_query(body string) string {
	parsed := json2.decode[json2.Any](body) or { return body }
	obj := parsed.as_map()
	query_any := obj['query'] or { return body }
	return query_any.str()
}

// handle_routes_request extracts the target query parameter and
// dispatches to the route forensics resolver.
fn handle_routes_request(req http.Request, mut redis RedisClient, policy PolicyDecision) string {
	// Extract target from query string: /api/v1/routes?target=1.2.3.4
	target := extract_query_param(req.url, 'target')
	if target.len == 0 {
		return '{"error":"Missing required query parameter: target","usage":"/api/v1/routes?target=<ip_or_hostname>"}'
	}
	return resolve_route_forensics(target, mut redis, policy)
}

// handle_audit_request extracts the limit query parameter and
// dispatches to the audit resolver.
fn handle_audit_request(req http.Request, mut redis RedisClient, policy PolicyDecision) string {
	limit_str := extract_query_param(req.url, 'limit')
	limit := if limit_str.len > 0 { limit_str.int() } else { 50 }
	return resolve_audit(limit, mut redis, policy)
}

// handle_smokeping_request extracts the target query parameter and
// dispatches to the SmokePing resolver for latency/jitter data.
fn handle_smokeping_request(req http.Request, mut redis RedisClient, policy PolicyDecision) string {
	target := extract_query_param(req.url, 'target')
	if target.len == 0 {
		return '{"error":"Missing required query parameter: target","usage":"/api/v1/smokeping?target=<hostname_or_ip>"}'
	}
	return resolve_smokeping(target, mut redis, policy)
}

// handle_temporal_audit_request extracts temporal query parameters and
// dispatches to the VerisimDB bitemporal audit resolver.
//
// Query parameters:
//   mode:     required — "as_of", "between", or "history"
//   time:     for as_of mode — RFC 3339 timestamp
//   start:    for between mode — RFC 3339 range start
//   end:      for between mode — RFC 3339 range end
//   event_id: for history mode — UUID of the event to trace
//   limit:    maximum events to return (default 50)
//
// Examples:
//   /api/v1/audit/temporal?mode=as_of&time=2026-02-28T12:00:00Z
//   /api/v1/audit/temporal?mode=between&start=2026-02-01T00:00:00Z&end=2026-02-28T23:59:59Z
//   /api/v1/audit/temporal?mode=history&event_id=550e8400-e29b-41d4-a716-446655440000
fn handle_temporal_audit_request(req http.Request, mut redis RedisClient, verisimdb VerisimDBClient, policy PolicyDecision) string {
	mode := extract_query_param(req.url, 'mode')
	if mode.len == 0 {
		return '{"error":"Missing required query parameter: mode","usage":"/api/v1/audit/temporal?mode=as_of&time=2026-02-28T12:00:00Z","available_modes":["as_of","between","history"]}'
	}
	mut params := map[string]string{}
	params['time'] = extract_query_param(req.url, 'time')
	params['start'] = extract_query_param(req.url, 'start')
	params['end'] = extract_query_param(req.url, 'end')
	params['event_id'] = extract_query_param(req.url, 'event_id')
	limit_str := extract_query_param(req.url, 'limit')
	if limit_str.len > 0 {
		params['limit'] = limit_str
	}
	return resolve_temporal_audit(mode, params, mut redis, verisimdb, policy)
}

// extract_query_param extracts a named parameter from a URL query string.
// Returns empty string if the parameter is not found.
fn extract_query_param(url string, name string) string {
	query_start := url.index('?') or { return '' }
	query := url[query_start + 1..]
	pairs := query.split('&')
	for pair in pairs {
		kv := pair.split('=')
		if kv.len == 2 && kv[0] == name {
			return kv[1]
		}
	}
	return ''
}

// health_check returns the gateway health status including which
// protocols are currently enabled, verb governance status, and
// attack surface metrics. Always accessible regardless of protocol
// toggles (operators need it to verify configuration).
//
// Influenced by hybrid-automation-router's health checker pattern:
// report backend availability alongside gateway status.
fn health_check(cfg ProtocolConfig) string {
	now := time.now().format_rfc3339()
	mut active := 0
	if cfg.rest_enabled {
		active++
	}
	if cfg.graphql_enabled {
		active++
	}
	if cfg.grpc_enabled {
		active++
	}

	// Count bound ports (attack surface metric)
	mut bound_ports := 0
	if cfg.rest_enabled || cfg.graphql_enabled {
		bound_ports++
	}
	if cfg.grpc_enabled {
		bound_ports++
	}

	return '{"status":"healthy","service":"aerie-gateway","version":"0.3.0","timestamp":"${now}","protocols":{"rest":${cfg.rest_enabled},"graphql":${cfg.graphql_enabled},"grpc":${cfg.grpc_enabled}},"active_protocols":${active},"bound_ports":${bound_ports},"verb_governance":true,"stealth_mode":true,"proof_mode":"light","policy_phase":1}'
}

// not_found_response lists only the endpoints that are currently enabled,
// so disabled protocols are not advertised.
fn not_found_response(cfg ProtocolConfig) string {
	mut endpoints := []string{}
	if cfg.graphql_enabled {
		endpoints << '"/graphql"'
	}
	if cfg.rest_enabled {
		endpoints << '"/api/v1/telemetry"'
		endpoints << '"/api/v1/routes"'
		endpoints << '"/api/v1/audit"'
		endpoints << '"/api/v1/audit/temporal"'
		endpoints << '"/api/v1/smokeping"'
	}
	endpoints << '"/api/v1/health"'
	return '{"error":"Not found","available_endpoints":[${endpoints.join(",")}]}'
}

//==============================================================================
// gRPC Listener (Phase 1 — Simplified Binary Protocol)
//==============================================================================

// grpc_listener starts a TCP listener for gRPC connections on the
// specified port. Only called when ENABLE_GRPC=true. When disabled,
// no socket is bound and port 4001 is completely closed — zero attack
// surface for the gRPC protocol.
//
// Phase 1 implements a simplified binary protocol that accepts
// length-prefixed JSON requests and returns length-prefixed JSON
// responses. A full HTTP/2 + gRPC implementation is planned for Phase 2.
fn grpc_listener(port int, mut redis &RedisClient) {
	mut listener := net.listen_tcp(.ip, '0.0.0.0:${port}') or {
		eprintln('[aerie] gRPC: failed to bind port ${port}: ${err}')
		return
	}
	println('[aerie] gRPC listener ready on :${port}')

	for {
		mut conn := listener.accept() or {
			eprintln('[aerie] gRPC: accept error: ${err}')
			continue
		}
		spawn handle_grpc_connection(mut conn, mut redis)
	}
}

// handle_grpc_connection processes a single gRPC client connection.
//
// Phase 1 protocol (simplified, non-HTTP/2):
//   Request:  4-byte length prefix (big-endian) + JSON body
//   Response: 4-byte length prefix (big-endian) + JSON body
//
// The JSON body contains a "method" field mapping to AerieService RPCs:
//   {"method": "GetTelemetrySnapshot"}
//   {"method": "GetRouteForensicsSnapshot", "target": "1.2.3.4"}
//   {"method": "GetAuditSnapshot", "limit": 50}
//
// Phase 2 will implement proper HTTP/2 framing and protobuf serialisation.
fn handle_grpc_connection(mut conn net.TcpConn, mut redis &RedisClient) {
	defer { conn.close() or {} }

	// Set read timeout to 30 seconds — prevents clients from holding
	// a connection open indefinitely (slowloris-style attacks).
	conn.set_read_timeout(30 * time.second)

	// Read length prefix (4 bytes, big-endian)
	mut len_buf := []u8{len: 4}
	conn.read(mut len_buf) or {
		eprintln('[aerie] gRPC: failed to read length prefix')
		return
	}
	msg_len := int(u32(len_buf[0]) << 24 | u32(len_buf[1]) << 16 | u32(len_buf[2]) << 8 | u32(len_buf[3]))

	if msg_len <= 0 || msg_len > 65536 {
		eprintln('[aerie] gRPC: invalid message length ${msg_len}')
		return
	}

	// Read message body
	mut body_buf := []u8{len: msg_len}
	conn.read(mut body_buf) or {
		eprintln('[aerie] gRPC: failed to read message body')
		return
	}
	body := body_buf.bytestr()

	// Parse JSON request
	parsed := json2.decode[json2.Any](body) or {
		send_grpc_response(mut conn, '{"error":"Invalid JSON"}')
		return
	}
	obj := parsed.as_map()
	method := (obj['method'] or { json2.Any('') }).str()

	// Apply policy gate
	policy := evaluate_policy('', 'grpc:${method}')

	// Dispatch to resolver
	response := match method {
		'GetTelemetrySnapshot' {
			resolve_telemetry(mut redis, policy)
		}
		'GetRouteForensicsSnapshot' {
			target := (obj['target'] or { json2.Any('') }).str()
			if target.len == 0 {
				'{"error":"target field required"}'
			} else {
				resolve_route_forensics(target, mut redis, policy)
			}
		}
		'GetAuditSnapshot' {
			limit := (obj['limit'] or { json2.Any(50) }).int()
			resolve_audit(limit, mut redis, policy)
		}
		'GetSmokePingSnapshot' {
			target := (obj['target'] or { json2.Any('') }).str()
			if target.len == 0 {
				'{"error":"target field required"}'
			} else {
				resolve_smokeping(target, mut redis, policy)
			}
		}
		'GetTemporalAuditSnapshot' {
			mode := (obj['mode'] or { json2.Any('') }).str()
			if mode.len == 0 {
				'{"error":"mode field required (as_of, between, history)"}'
			} else {
				mut params := map[string]string{}
				params['time'] = (obj['time'] or { json2.Any('') }).str()
				params['start'] = (obj['start'] or { json2.Any('') }).str()
				params['end'] = (obj['end'] or { json2.Any('') }).str()
				params['event_id'] = (obj['event_id'] or { json2.Any('') }).str()
				limit := (obj['limit'] or { json2.Any(50) }).int()
				params['limit'] = '${limit}'
				verisimdb := new_verisimdb_client()
				resolve_temporal_audit(mode, params, mut redis, verisimdb, policy)
			}
		}
		else {
			'{"error":"Unknown method: ${method}","available":["GetTelemetrySnapshot","GetRouteForensicsSnapshot","GetAuditSnapshot","GetSmokePingSnapshot","GetTemporalAuditSnapshot"]}'
		}
	}

	send_grpc_response(mut conn, response)
}

// send_grpc_response writes a length-prefixed JSON response back to the
// gRPC client connection.
fn send_grpc_response(mut conn net.TcpConn, body string) {
	length := body.len
	mut header := []u8{len: 4}
	header[0] = u8(length >> 24)
	header[1] = u8(length >> 16)
	header[2] = u8(length >> 8)
	header[3] = u8(length)

	conn.write(header) or {
		eprintln('[aerie] gRPC: failed to write response header')
		return
	}
	conn.write(body.bytes()) or {
		eprintln('[aerie] gRPC: failed to write response body')
	}
}
