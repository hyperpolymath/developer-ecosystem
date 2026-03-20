// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_zerotrust — Zero Trust Architecture policy engine types.
// Maps to proven-servers/protocols/proven-zerotrust.
//
// Provides identity verification, device posture assessment, trust
// score calculation, policy evaluation, and audit logging. Network
// I/O is stubbed with TODO markers; all type definitions and logic
// are real.
module v_zerotrust

import time

// TrustLevel represents the calculated trust level for an identity
// and device combination.
pub enum TrustLevel {
	none
	low
	medium
	high
	full
}

// AccessDecision represents the outcome of a policy evaluation.
pub enum AccessDecision {
	allow
	deny
	challenge
	quarantine
}

// DevicePosture holds the security posture assessment of a device.
pub struct DevicePosture {
pub:
	// compliant indicates whether the device meets baseline security.
	compliant bool
	// os_version is the device's operating system version string.
	os_version string
	// encrypted indicates whether disk encryption is enabled.
	encrypted bool
	// antivirus indicates whether antivirus is installed and active.
	antivirus bool
	// last_checkin is the time of the last posture check.
	last_checkin time.Time
}

// Identity represents an authenticated user with their associated
// attributes and device posture.
pub struct Identity {
pub:
	// subject is the unique identifier for this identity (e.g. email).
	subject string
	// roles lists the roles assigned to this identity.
	roles []string
	// groups lists the groups this identity belongs to.
	groups []string
	// mfa_verified indicates whether multi-factor auth was completed.
	mfa_verified bool
	// device_posture is the security posture of the identity's device.
	device_posture DevicePosture
}

// Policy defines an access control policy for a resource.
pub struct Policy {
pub:
	// name is a human-readable name for this policy.
	name string
	// resource identifies the protected resource (e.g. URL path, service).
	resource string
	// required_trust is the minimum trust level needed for access.
	required_trust TrustLevel
	// conditions are additional conditions that must be satisfied.
	// Format: "key=value" strings evaluated against identity attributes.
	conditions []string
	// action is the decision to apply when conditions are not met.
	action AccessDecision
	// require_mfa specifies whether MFA is mandatory for this resource.
	require_mfa bool
}

// AuditEntry records a single access decision for audit compliance.
pub struct AuditEntry {
pub:
	// timestamp is when the decision was made.
	timestamp time.Time
	// subject is the identity that requested access.
	subject string
	// resource is the resource that was requested.
	resource string
	// decision is the access decision that was made.
	decision AccessDecision
	// trust_score is the calculated trust score at decision time.
	trust_score int
	// reason explains why the decision was made.
	reason string
}

// PolicyEngine is the Zero Trust policy engine. It manages policies,
// evaluates access requests, and maintains an audit log.
pub struct PolicyEngine {
pub:
	// name identifies this policy engine instance.
	name string
pub mut:
	// policies is the list of access control policies.
	policies []Policy
	// audit_log records all access decisions.
	audit_log []AuditEntry
}

// new_engine creates a new Zero Trust policy engine.
pub fn new_engine(name string) &PolicyEngine {
	return &PolicyEngine{
		name: name
		policies: []Policy{}
		audit_log: []AuditEntry{}
	}
}

// add_policy registers a new access control policy. Returns an error
// if a policy with the same name already exists.
pub fn (mut e PolicyEngine) add_policy(policy Policy) ! {
	if policy.name.len == 0 {
		return error('policy name must not be empty')
	}
	for existing in e.policies {
		if existing.name == policy.name {
			return error('duplicate policy name: ${policy.name}')
		}
	}
	e.policies << policy
}

// evaluate_access evaluates whether an identity should be granted
// access to a resource. Returns the access decision and logs the
// result.
pub fn (mut e PolicyEngine) evaluate_access(identity Identity, resource string) AccessDecision {
	trust_score := calculate_trust_score(identity)
	trust_level := score_to_level(trust_score)
	// Find applicable policies for this resource.
	mut decision := AccessDecision.deny
	mut reason := 'no matching policy'
	for policy in e.policies {
		if policy.resource != resource {
			continue
		}
		// Check MFA requirement.
		if policy.require_mfa && !identity.mfa_verified {
			decision = .challenge
			reason = 'MFA required for ${resource}'
			break
		}
		// Check trust level.
		if trust_level_value(trust_level) < trust_level_value(policy.required_trust) {
			decision = policy.action
			reason = 'insufficient trust level: ${trust_level} < ${policy.required_trust}'
			break
		}
		// Check conditions.
		conditions_met := evaluate_conditions(identity, policy.conditions)
		if !conditions_met {
			decision = policy.action
			reason = 'policy conditions not met'
			break
		}
		// All checks passed.
		decision = .allow
		reason = 'policy ${policy.name} satisfied'
		break
	}
	// Log the decision.
	e.audit_log << AuditEntry{
		timestamp: time.now()
		subject: identity.subject
		resource: resource
		decision: decision
		trust_score: trust_score
		reason: reason
	}
	return decision
}

// verify_identity checks whether an identity's attributes are valid
// and consistent. Returns an error describing any issues.
pub fn verify_identity(identity Identity) ! {
	if identity.subject.len == 0 {
		return error('identity subject must not be empty')
	}
	if identity.roles.len == 0 {
		return error('identity must have at least one role')
	}
	// TODO: Verify identity against an external IdP (e.g. OIDC, SAML).
	// This requires network I/O to the identity provider.
}

// assess_device evaluates a device's security posture and returns
// whether it meets the baseline compliance requirements.
pub fn assess_device(posture DevicePosture) bool {
	if !posture.compliant {
		return false
	}
	if !posture.encrypted {
		return false
	}
	// Check that the last checkin was within 24 hours.
	now := time.now()
	hours_since := (now.unix() - posture.last_checkin.unix()) / 3600
	if hours_since > 24 {
		return false
	}
	return true
}

// calculate_trust_score computes a numerical trust score (0-100) from
// an identity's attributes and device posture.
pub fn calculate_trust_score(identity Identity) int {
	mut score := 0
	// MFA adds significant trust.
	if identity.mfa_verified {
		score += 30
	}
	// Device posture contributes to trust.
	if identity.device_posture.compliant {
		score += 20
	}
	if identity.device_posture.encrypted {
		score += 15
	}
	if identity.device_posture.antivirus {
		score += 10
	}
	// Having roles demonstrates authorisation.
	if identity.roles.len > 0 {
		score += 15
	}
	// Group membership adds trust.
	if identity.groups.len > 0 {
		score += 10
	}
	// Cap at 100.
	if score > 100 {
		score = 100
	}
	return score
}

// audit_log returns a copy of the policy engine's audit log.
pub fn (e PolicyEngine) get_audit_log() []AuditEntry {
	return e.audit_log
}

// score_to_level converts a numerical trust score to a TrustLevel.
fn score_to_level(score int) TrustLevel {
	if score >= 90 {
		return .full
	}
	if score >= 70 {
		return .high
	}
	if score >= 50 {
		return .medium
	}
	if score >= 25 {
		return .low
	}
	return .none
}

// trust_level_value converts a TrustLevel to a comparable integer.
fn trust_level_value(level TrustLevel) int {
	return match level {
		.none { 0 }
		.low { 1 }
		.medium { 2 }
		.high { 3 }
		.full { 4 }
	}
}

// evaluate_conditions checks whether an identity satisfies all
// policy conditions. Conditions are "key=value" strings matched
// against identity roles and groups.
fn evaluate_conditions(identity Identity, conditions []string) bool {
	for condition in conditions {
		parts := condition.split('=')
		if parts.len != 2 {
			continue
		}
		key := parts[0]
		value := parts[1]
		match key {
			'role' {
				if value !in identity.roles {
					return false
				}
			}
			'group' {
				if value !in identity.groups {
					return false
				}
			}
			else {}
		}
	}
	return true
}
