// SPDX-License-Identifier: PMPL-1.0-or-later
//
// policy.v — Policy Gate Middleware
//
// Phase 1: Permissive gate — all requests allowed. If the X-Api-Key
// header is present, it is validated for format and logged. If absent,
// the request proceeds but is marked as "anonymous" in the audit log.
//
// Phase 2+ will add per-module entitlements (e.g., "telemetry:read",
// "routes:write") and reject unauthorised requests.

module main

import time

// AccessLevel categorises the caller's authentication status.
pub enum AccessLevel {
	anonymous       // No API key provided
	authenticated   // Valid API key format
	invalid         // Malformed API key
}

// PolicyDecision captures the result of evaluating a request against
// the policy gate. Every decision is recorded in the Redis audit log.
pub struct PolicyDecision {
pub:
	allowed      bool
	access_level AccessLevel
	api_key      string        // Redacted key (first 8 chars + "...")
	module_name  string        // Which API module was requested
	timestamp    string        // RFC 3339
	reason       string        // Human-readable explanation
}

// AuditEvent represents a single entry in the Redis audit log.
// Matches the protobuf AuditEvent message and the Idris2 ABI type.
pub struct AuditEvent {
pub:
	event_id   string
	valid_time string
	tx_time    string
	severity   string
	message    string
	tags       []string
}

// evaluate_policy checks the request against the policy gate.
//
// Phase 1 behaviour:
//   - All requests are allowed regardless of API key presence
//   - API keys are validated for format (minimum 16 chars, alphanumeric + hyphen)
//   - Missing keys result in "anonymous" access level
//   - Invalid format keys are logged but still allowed (Phase 1 permissive)
//
// Returns a PolicyDecision that should be recorded in the audit log.
pub fn evaluate_policy(api_key string, module_name string) PolicyDecision {
	now := time.now().format_rfc3339()

	// No API key provided — anonymous access
	if api_key.len == 0 {
		return PolicyDecision{
			allowed:      true
			access_level: .anonymous
			api_key:      ''
			module_name:  module_name
			timestamp:    now
			reason:       'Phase 1 permissive: anonymous access allowed'
		}
	}

	// Validate API key format: minimum 16 characters, alphanumeric + hyphen
	is_valid := api_key.len >= 16 && api_key.bytes().all(fn (b u8) bool {
		return (b >= `a` && b <= `z`) || (b >= `A` && b <= `Z`) || (b >= `0` && b <= `9`) || b == `-`
	})

	redacted := if api_key.len >= 8 {
		api_key[..8] + '...'
	} else {
		api_key + '...'
	}

	if is_valid {
		return PolicyDecision{
			allowed:      true
			access_level: .authenticated
			api_key:      redacted
			module_name:  module_name
			timestamp:    now
			reason:       'Valid API key authenticated'
		}
	}

	// Invalid format but still allowed in Phase 1
	return PolicyDecision{
		allowed:      true
		access_level: .invalid
		api_key:      redacted
		module_name:  module_name
		timestamp:    now
		reason:       'Phase 1 permissive: invalid key format but access allowed'
	}
}

// policy_context_string returns a deterministic string representation
// of the current policy rules, used as input to the proof envelope's
// policy_hash field. This ensures policy changes are detectable.
pub fn policy_context_string(module_name string) string {
	return 'aerie-policy-v1:phase1-permissive:module=${module_name}:entitlements=all'
}

// decision_to_audit_event converts a PolicyDecision into an AuditEvent
// suitable for storage in the Redis audit log.
pub fn decision_to_audit_event(decision PolicyDecision, query_id string) AuditEvent {
	severity := match decision.access_level {
		.anonymous { 'info' }
		.authenticated { 'info' }
		.invalid { 'warning' }
	}

	mut tags := ['policy-gate', 'phase-1', decision.module_name]
	match decision.access_level {
		.anonymous { tags << 'anonymous' }
		.authenticated { tags << 'authenticated' }
		.invalid { tags << 'invalid-key' }
	}

	return AuditEvent{
		event_id:   query_id
		valid_time: decision.timestamp
		tx_time:    decision.timestamp
		severity:   severity
		message:    '${decision.reason} [module=${decision.module_name}]'
		tags:       tags
	}
}
