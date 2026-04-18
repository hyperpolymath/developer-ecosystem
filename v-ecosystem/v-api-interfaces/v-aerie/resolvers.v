// SPDX-License-Identifier: PMPL-1.0-or-later
//
// resolvers.v — GraphQL and gRPC Resolver Implementations
//
// Implements the AerieGraphQLService interface (from schema.gql.v) and
// the AerieService interface (from aerie.pb.v). Both interfaces resolve
// to the same underlying service clients (LibreSpeed, Hyperglass, Redis,
// SmokePing, VerisimDB) and wrap all responses in proof envelopes.
//
// The triple-mount architecture means the same business logic serves:
//   - GraphQL queries via POST /graphql
//   - gRPC calls via port 4001
//   - REST endpoints via GET /api/v1/*
//
// This module provides the shared resolution logic used by all three.

module main

import time

// resolve_telemetry fetches telemetry data from LibreSpeed,
// wraps it in a proof envelope, and returns the complete JSON response.
//
// Used by:
//   - GraphQL: telemetrySnapshot query
//   - gRPC: GetTelemetrySnapshot RPC
//   - REST: GET /api/v1/telemetry
pub fn resolve_telemetry(mut redis RedisClient, policy PolicyDecision) string {
	// Check cache first (TTL: 30 seconds for telemetry)
	cached := redis.get_cached('telemetry')
	if cached.len > 0 {
		return cached
	}

	// Query LibreSpeed probe
	payload := get_telemetry()
	data_json := telemetry_payload_to_json(payload)

	// Wrap in proof envelope
	policy_ctx := policy_context_string('telemetry')
	result := wrap_body_with_proof(data_json, policy_ctx)

	// Cache the result for 30 seconds
	redis.cache_result('telemetry', result, 30)

	// Log the audit event
	audit := decision_to_audit_event(policy, policy.module_name)
	redis.log_audit(audit)

	return result
}

// resolve_route_forensics fetches BGP route data from Hyperglass for
// the given target, wraps it in a proof envelope, and returns JSON.
//
// Used by:
//   - GraphQL: routeForensicsSnapshot(target) query
//   - gRPC: GetRouteForensicsSnapshot RPC
//   - REST: GET /api/v1/routes?target=<ip>
pub fn resolve_route_forensics(target string, mut redis RedisClient, policy PolicyDecision) string {
	// Check cache first (TTL: 60 seconds for route data)
	cache_key := 'routes:${target}'
	cached := redis.get_cached(cache_key)
	if cached.len > 0 {
		return cached
	}

	// Query Hyperglass probe
	payload := get_route_forensics(target)
	data_json := route_forensics_to_json(payload)

	// Wrap in proof envelope
	policy_ctx := policy_context_string('routes')
	result := wrap_body_with_proof(data_json, policy_ctx)

	// Cache the result for 60 seconds
	redis.cache_result(cache_key, result, 60)

	// Log the audit event
	audit := decision_to_audit_event(policy, policy.module_name)
	redis.log_audit(audit)

	return result
}

// resolve_audit retrieves recent audit events from the Redis log,
// wraps them in a proof envelope, and returns JSON.
//
// Used by:
//   - GraphQL: auditSnapshot(limit) query
//   - gRPC: GetAuditSnapshot RPC
//   - REST: GET /api/v1/audit?limit=<n>
pub fn resolve_audit(limit int, mut redis RedisClient, policy PolicyDecision) string {
	// Audit data is never cached — always fresh
	events := redis.get_audit_log(limit)

	// Build the events JSON array
	events_json := '[${events.join(",")}]'
	data_json := '{"events":${events_json}}'

	// Wrap in proof envelope
	policy_ctx := policy_context_string('audit')
	result := wrap_body_with_proof(data_json, policy_ctx)

	// Log this audit access too
	audit := decision_to_audit_event(policy, policy.module_name)
	redis.log_audit(audit)

	return result
}

// resolve_temporal_audit queries VerisimDB for bitemporal audit data.
// Supports three query modes:
//   - as_of:   "What was the audit state at time T?"
//   - between: "What events occurred between T1 and T2?"
//   - history: "Full history of event X"
//
// Used by:
//   - GraphQL: temporalAuditSnapshot(mode, ...) query
//   - gRPC:    GetTemporalAuditSnapshot RPC
//   - REST:    GET /api/v1/audit/temporal?mode=as_of&time=...
//
// The resolver wraps VerisimDB responses in a proof envelope and
// logs access to both Redis (hot) and VerisimDB (cold) via dual_log_audit.
pub fn resolve_temporal_audit(mode string, params map[string]string, mut redis RedisClient, verisimdb VerisimDBClient, policy PolicyDecision) string {
	events := match mode {
		'as_of' {
			as_of_time := params['time'] or { time.now().format_rfc3339() }
			limit := (params['limit'] or { '50' }).int()
			verisimdb.query_as_of(as_of_time, limit)
		}
		'between' {
			start := params['start'] or { '' }
			end := params['end'] or { '' }
			limit := (params['limit'] or { '50' }).int()
			if start.len == 0 || end.len == 0 {
				return '{"error":"between mode requires start and end parameters"}'
			}
			verisimdb.query_between(start, end, limit)
		}
		'history' {
			event_id := params['event_id'] or { '' }
			if event_id.len == 0 {
				return '{"error":"history mode requires event_id parameter"}'
			}
			verisimdb.query_history(event_id)
		}
		else {
			return '{"error":"Unknown temporal mode: ${mode}","available":["as_of","between","history"]}'
		}
	}

	// Build the response JSON with mode and events array
	events_json := '[${events.join(",")}]'
	data_json := '{"mode":"${mode}","events":${events_json}}'

	// Wrap in proof envelope
	policy_ctx := policy_context_string('temporal_audit')
	result := wrap_body_with_proof(data_json, policy_ctx)

	// Log access to both tiers
	audit := decision_to_audit_event(policy, policy.module_name)
	dual_log_audit(mut redis, verisimdb, audit)

	return result
}

// resolve_smokeping fetches latency/jitter data from SmokePing,
// wraps it in a proof envelope, and returns JSON.
//
// Used by:
//   - GraphQL: smokePingSnapshot(target) query
//   - gRPC: GetSmokePingSnapshot RPC
//   - REST: GET /api/v1/smokeping?target=<host>
pub fn resolve_smokeping(target string, mut redis RedisClient, policy PolicyDecision) string {
	// Check cache first (TTL: 120 seconds for smokeping — data changes slowly)
	cache_key := 'smokeping:${target}'
	cached := redis.get_cached(cache_key)
	if cached.len > 0 {
		return cached
	}

	// Query SmokePing probe
	payload := get_smokeping_data(target)
	data_json := smokeping_payload_to_json(payload)

	// Wrap in proof envelope
	policy_ctx := policy_context_string('smokeping')
	result := wrap_body_with_proof(data_json, policy_ctx)

	// Cache for 120 seconds (smoke chart data updates every ~5 minutes)
	redis.cache_result(cache_key, result, 120)

	// Log audit event
	audit := decision_to_audit_event(policy, policy.module_name)
	redis.log_audit(audit)

	return result
}

// resolve_graphql_query parses a GraphQL query string and dispatches
// to the appropriate resolver. Supports the root queries defined in
// schema.graphql: telemetrySnapshot, routeForensicsSnapshot,
// auditSnapshot, smokePingSnapshot.
//
// This is a simplified GraphQL executor sufficient for Phase 1.
// Phase 2+ may integrate a full GraphQL parser from the v-ecosystem.
pub fn resolve_graphql_query(query string, mut redis RedisClient, policy PolicyDecision) string {
	// Extract the operation name from the query
	if query.contains('telemetrySnapshot') {
		return resolve_telemetry(mut redis, policy)
	}
	if query.contains('routeForensicsSnapshot') {
		// Extract target argument
		target := extract_string_arg(query, 'target')
		if target.len == 0 {
			return '{"errors":[{"message":"routeForensicsSnapshot requires a target argument"}]}'
		}
		return resolve_route_forensics(target, mut redis, policy)
	}
	// temporalAuditSnapshot must be checked BEFORE auditSnapshot to avoid
	// false match (auditSnapshot is a substring of temporalAuditSnapshot)
	if query.contains('temporalAuditSnapshot') {
		mode := extract_string_arg(query, 'mode')
		if mode.len == 0 {
			return '{"errors":[{"message":"temporalAuditSnapshot requires mode argument (as_of, between, history)"}]}'
		}
		mut params := map[string]string{}
		params['time'] = extract_string_arg(query, 'time')
		params['start'] = extract_string_arg(query, 'start')
		params['end'] = extract_string_arg(query, 'end')
		params['event_id'] = extract_string_arg(query, 'eventId')
		limit_val := extract_int_arg(query, 'limit')
		if limit_val > 0 {
			params['limit'] = '${limit_val}'
		}
		verisimdb := new_verisimdb_client()
		return resolve_temporal_audit(mode, params, mut redis, verisimdb, policy)
	}
	if query.contains('auditSnapshot') {
		// Extract limit argument (default 50)
		limit_str := extract_int_arg(query, 'limit')
		limit := if limit_str > 0 { limit_str } else { 50 }
		return resolve_audit(limit, mut redis, policy)
	}
	if query.contains('smokePingSnapshot') {
		target := extract_string_arg(query, 'target')
		if target.len == 0 {
			return '{"errors":[{"message":"smokePingSnapshot requires a target argument"}]}'
		}
		return resolve_smokeping(target, mut redis, policy)
	}

	return '{"errors":[{"message":"Unknown query. Available: telemetrySnapshot, routeForensicsSnapshot(target), auditSnapshot(limit), temporalAuditSnapshot(mode, time, start, end, eventId, limit), smokePingSnapshot(target)"}]}'
}

// extract_string_arg extracts a string argument value from a GraphQL query.
// Looks for patterns like: argName: "value" or argName:"value"
fn extract_string_arg(query string, arg_name string) string {
	// Find the argument in the query string
	patterns := ['${arg_name}: "', '${arg_name}:"']
	for pattern in patterns {
		idx := query.index(pattern) or { continue }
		start := idx + pattern.len
		end := query.index_after('"', start) or { continue }
		if end > start {
			return query[start..end]
		}
	}
	return ''
}

// extract_int_arg extracts an integer argument value from a GraphQL query.
// Looks for patterns like: argName: 42 or argName:42
fn extract_int_arg(query string, arg_name string) int {
	patterns := ['${arg_name}: ', '${arg_name}:']
	for pattern in patterns {
		idx := query.index(pattern) or { continue }
		start := idx + pattern.len
		mut end := start
		for end < query.len && query[end] >= `0` && query[end] <= `9` {
			end++
		}
		if end > start {
			return query[start..end].int()
		}
	}
	return 0
}
