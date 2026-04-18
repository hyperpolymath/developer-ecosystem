// SPDX-License-Identifier: PMPL-1.0-or-later
//
// verisimdb_client.v — VerisimDB Bitemporal Client for Forensic Audit Storage
//
// Provides bitemporal storage for audit events. Each event has:
//   - valid_time:       when the event occurred (wall clock at event creation)
//   - transaction_time: when the event was persisted to VerisimDB
//
// This enables temporal forensics queries:
//   - "What did we know at time T?"  (as-of query)
//   - "What changed between T1 and T2?"  (between query)
//   - "Full history of entity X"  (history query)
//
// VerisimDB runs as a sidecar container in the aerie-net network.
// Uses HTTP REST API on port 8084 (default).
//
// Architecture note:
//   Redis remains the hot cache for recent audit events (LTRIM'd to 10000).
//   VerisimDB is the cold store with full bitemporal history — no LTRIM,
//   no expiry. Together they form a two-tier audit pipeline:
//     1. Redis: fast, bounded, ephemeral (operational monitoring)
//     2. VerisimDB: permanent, bitemporal, forensic (regulatory/legal)
//
// Failure handling:
//   All VerisimDB operations are fire-and-forget. If VerisimDB is
//   unreachable, the gateway logs a warning to stderr and continues
//   serving requests normally. The Redis audit log is unaffected.
//   This ensures the gateway never blocks or crashes due to the
//   cold store being unavailable.

module main

import net.http
import os
import x.json2

// VerisimDBClient holds connection configuration for the VerisimDB
// HTTP REST API. Unlike RedisClient, this uses HTTP (not raw TCP),
// so no persistent connection is maintained — each request is
// independent. This trades throughput for simplicity and resilience.
pub struct VerisimDBClient {
	base_url string  // e.g. "http://verisimdb:8084"
}

// new_verisimdb_client creates a VerisimDBClient from the VERISIMDB_URL
// environment variable. Falls back to http://verisimdb:8084 if unset.
//
// The URL should include the protocol and port but NO trailing slash:
//   VERISIMDB_URL=http://verisimdb:8084
//
// In development, point to localhost:
//   VERISIMDB_URL=http://localhost:8084
pub fn new_verisimdb_client() VerisimDBClient {
	mut url := os.getenv('VERISIMDB_URL')
	if url.len == 0 {
		url = 'http://verisimdb:8084'
	}
	// Strip trailing slash if present to avoid double-slash in URLs
	if url.ends_with('/') {
		url = url[..url.len - 1]
	}
	return VerisimDBClient{
		base_url: url
	}
}

// store_audit persists an AuditEvent to VerisimDB's bitemporal store.
//
// The event's valid_time and tx_time are sent as bitemporal coordinates:
//   - valid_time is preserved from the original event (when it happened)
//   - transaction_time is set by VerisimDB upon receipt (when it was stored)
//
// This is fire-and-forget: errors are logged to stderr but never
// propagated to the caller. The gateway must not block or fail if
// VerisimDB is unavailable — Redis remains the primary audit log.
//
// HTTP request:
//   POST /api/v1/events
//   Content-Type: application/json
//   Body: {"event_id": "...", "valid_time": "...", ...}
pub fn (c VerisimDBClient) store_audit(event AuditEvent) {
	event_json := audit_event_to_json(event)
	url := '${c.base_url}/api/v1/events'

	http.post(url, event_json) or {
		eprintln('[aerie] verisimdb: store_audit failed (${c.base_url}): ${err}')
		return
	}
}

// query_as_of retrieves audit events as they were known at a specific
// point in time. This answers: "What was the audit state at time T?"
//
// The as_of_time should be an RFC 3339 timestamp (e.g. "2026-02-28T12:00:00Z").
// VerisimDB returns only events whose transaction_time <= as_of_time,
// giving a consistent historical snapshot.
//
// Parameters:
//   as_of_time: RFC 3339 timestamp for the point-in-time query
//   limit:      maximum number of events to return (capped server-side)
//
// Returns: array of JSON event strings, or empty array on error
pub fn (c VerisimDBClient) query_as_of(as_of_time string, limit int) []string {
	url := '${c.base_url}/api/v1/events?as_of=${as_of_time}&limit=${limit}'

	response := http.get(url) or {
		eprintln('[aerie] verisimdb: query_as_of failed (${c.base_url}): ${err}')
		return []
	}

	if response.status_code != 200 {
		eprintln('[aerie] verisimdb: query_as_of returned status ${response.status_code}')
		return []
	}

	return parse_verisimdb_response(response.body)
}

// query_between retrieves audit events that occurred within a time
// range. This answers: "What happened between T1 and T2?"
//
// Both start and end should be RFC 3339 timestamps. VerisimDB returns
// events whose valid_time falls within [start, end], ordered by
// valid_time ascending.
//
// Parameters:
//   start: RFC 3339 timestamp for range start (inclusive)
//   end:   RFC 3339 timestamp for range end (inclusive)
//   limit: maximum number of events to return
//
// Returns: array of JSON event strings, or empty array on error
pub fn (c VerisimDBClient) query_between(start string, end string, limit int) []string {
	url := '${c.base_url}/api/v1/events?start=${start}&end=${end}&limit=${limit}'

	response := http.get(url) or {
		eprintln('[aerie] verisimdb: query_between failed (${c.base_url}): ${err}')
		return []
	}

	if response.status_code != 200 {
		eprintln('[aerie] verisimdb: query_between returned status ${response.status_code}')
		return []
	}

	return parse_verisimdb_response(response.body)
}

// query_history retrieves the full bitemporal history of a specific
// audit event by its ID. This answers: "What is the complete lineage
// of event X?"
//
// The history includes all versions of the event across both valid
// and transaction time, enabling forensic reconstruction of how
// the event was recorded and any corrections applied.
//
// Parameters:
//   event_id: the UUID of the event to trace
//
// Returns: array of JSON event strings (all versions), or empty on error
pub fn (c VerisimDBClient) query_history(event_id string) []string {
	url := '${c.base_url}/api/v1/events/${event_id}/history'

	response := http.get(url) or {
		eprintln('[aerie] verisimdb: query_history failed (${c.base_url}): ${err}')
		return []
	}

	if response.status_code != 200 {
		eprintln('[aerie] verisimdb: query_history returned status ${response.status_code}')
		return []
	}

	return parse_verisimdb_response(response.body)
}

// parse_verisimdb_response extracts individual event JSON strings
// from a VerisimDB API response body.
//
// Expected response format from VerisimDB:
//   {"events": [{...}, {...}, ...]}
//
// Each event object is re-serialised to a JSON string and returned
// as an element of the result array. If the response cannot be parsed,
// the entire body is returned as a single-element array (graceful
// degradation — the caller still gets data, just not neatly split).
fn parse_verisimdb_response(body string) []string {
	mut results := []string{}

	// Attempt to parse as {"events": [...]}
	parsed := json2.decode[json2.Any](body) or {
		// Cannot parse — return body as-is in a single-element array
		if body.len > 0 {
			return [body]
		}
		return results
	}

	obj := parsed.as_map()
	events_any := obj['events'] or {
		// No "events" key — return body as-is
		if body.len > 0 {
			return [body]
		}
		return results
	}

	events_arr := events_any.as_array()
	for event in events_arr {
		// Re-encode each event as a JSON string
		results << event.str()
	}

	return results
}

// dual_log_audit writes an audit event to both Redis (hot cache) and
// VerisimDB (cold bitemporal store). This is the recommended way to
// log audit events in resolvers — it ensures both tiers receive the
// event without the resolver needing to know about the two-tier
// architecture.
//
// Redis write is synchronous (fast, local network).
// VerisimDB write is fire-and-forget (may be slow, may fail).
//
// Usage in resolvers:
//   audit := decision_to_audit_event(policy, policy.module_name)
//   dual_log_audit(mut redis, verisimdb, audit)
pub fn dual_log_audit(mut redis RedisClient, verisimdb VerisimDBClient, event AuditEvent) {
	// Primary: Redis hot cache (bounded, fast)
	redis.log_audit(event)

	// Secondary: VerisimDB cold store (permanent, bitemporal)
	// Fire-and-forget — errors logged to stderr, never block the pipeline
	verisimdb.store_audit(event)
}
