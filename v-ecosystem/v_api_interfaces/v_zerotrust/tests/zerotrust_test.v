// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_zerotrust.
// Validates policy engine creation, policy management, access evaluation,
// identity verification, device assessment, and trust scoring.
module main

import v_zerotrust
import time

// test_new_engine_creates_empty verifies that a new policy engine has
// no policies or audit entries.
fn test_new_engine_creates_empty() {
	engine := v_zerotrust.new_engine('test-zt')
	assert engine.name == 'test-zt'
	assert engine.policies.len == 0
	assert engine.audit_log.len == 0
}

// test_add_policy verifies that policies can be added.
fn test_add_policy() {
	mut engine := v_zerotrust.new_engine('test-zt')
	engine.add_policy(v_zerotrust.Policy{
		name: 'api-access'
		resource: '/api/data'
		required_trust: .medium
		action: .deny
	}) or {
		assert false, 'add_policy failed: ${err}'
		return
	}
	assert engine.policies.len == 1
}

// test_add_policy_empty_name_returns_error verifies that empty names
// are rejected.
fn test_add_policy_empty_name_returns_error() {
	mut engine := v_zerotrust.new_engine('test-zt')
	engine.add_policy(v_zerotrust.Policy{
		resource: '/api'
		required_trust: .low
		action: .deny
	}) or {
		assert err.msg().contains('must not be empty')
		return
	}
	assert false, 'expected error for empty name'
}

// test_add_policy_duplicate_returns_error verifies that duplicate
// policy names are rejected.
fn test_add_policy_duplicate_returns_error() {
	mut engine := v_zerotrust.new_engine('test-zt')
	engine.add_policy(v_zerotrust.Policy{
		name: 'dup'
		resource: '/api'
		required_trust: .low
		action: .deny
	}) or { return }
	engine.add_policy(v_zerotrust.Policy{
		name: 'dup'
		resource: '/other'
		required_trust: .high
		action: .deny
	}) or {
		assert err.msg().contains('duplicate')
		return
	}
	assert false, 'expected error for duplicate policy'
}

// test_evaluate_access_allow verifies that a high-trust identity
// is granted access.
fn test_evaluate_access_allow() {
	mut engine := v_zerotrust.new_engine('test-zt')
	engine.add_policy(v_zerotrust.Policy{
		name: 'data-access'
		resource: '/api/data'
		required_trust: .medium
		action: .deny
	}) or { return }
	identity := v_zerotrust.Identity{
		subject: 'alice@example.com'
		roles: ['user', 'admin']
		groups: ['engineering']
		mfa_verified: true
		device_posture: v_zerotrust.DevicePosture{
			compliant: true
			os_version: 'Fedora 43'
			encrypted: true
			antivirus: true
			last_checkin: time.now()
		}
	}
	decision := engine.evaluate_access(identity, '/api/data')
	assert decision == .allow
	audit := engine.get_audit_log()
	assert audit.len == 1
	assert audit[0].subject == 'alice@example.com'
	assert audit[0].decision == .allow
}

// test_evaluate_access_deny_low_trust verifies that a low-trust
// identity is denied access to a high-trust resource.
fn test_evaluate_access_deny_low_trust() {
	mut engine := v_zerotrust.new_engine('test-zt')
	engine.add_policy(v_zerotrust.Policy{
		name: 'secure-data'
		resource: '/api/secure'
		required_trust: .high
		action: .deny
	}) or { return }
	identity := v_zerotrust.Identity{
		subject: 'bob@example.com'
		roles: ['viewer']
		mfa_verified: false
		device_posture: v_zerotrust.DevicePosture{
			compliant: false
			encrypted: false
			last_checkin: time.now()
		}
	}
	decision := engine.evaluate_access(identity, '/api/secure')
	assert decision == .deny
}

// test_evaluate_access_challenge_mfa verifies that MFA-required
// resources prompt a challenge when MFA is not verified.
fn test_evaluate_access_challenge_mfa() {
	mut engine := v_zerotrust.new_engine('test-zt')
	engine.add_policy(v_zerotrust.Policy{
		name: 'mfa-required'
		resource: '/api/admin'
		required_trust: .low
		require_mfa: true
		action: .deny
	}) or { return }
	identity := v_zerotrust.Identity{
		subject: 'charlie@example.com'
		roles: ['admin']
		groups: ['ops']
		mfa_verified: false
		device_posture: v_zerotrust.DevicePosture{
			compliant: true
			encrypted: true
			antivirus: true
			last_checkin: time.now()
		}
	}
	decision := engine.evaluate_access(identity, '/api/admin')
	assert decision == .challenge
}

// test_evaluate_access_no_matching_policy verifies that requests
// with no matching policy are denied.
fn test_evaluate_access_no_matching_policy() {
	mut engine := v_zerotrust.new_engine('test-zt')
	identity := v_zerotrust.Identity{
		subject: 'eve@example.com'
		roles: ['user']
		mfa_verified: true
		device_posture: v_zerotrust.DevicePosture{
			compliant: true
			encrypted: true
			last_checkin: time.now()
		}
	}
	decision := engine.evaluate_access(identity, '/api/unknown')
	assert decision == .deny
}

// test_evaluate_access_condition_role verifies role-based conditions.
fn test_evaluate_access_condition_role() {
	mut engine := v_zerotrust.new_engine('test-zt')
	engine.add_policy(v_zerotrust.Policy{
		name: 'admin-only'
		resource: '/api/admin'
		required_trust: .low
		conditions: ['role=admin']
		action: .deny
	}) or { return }
	// User without admin role should be denied.
	identity := v_zerotrust.Identity{
		subject: 'user@example.com'
		roles: ['viewer']
		mfa_verified: true
		device_posture: v_zerotrust.DevicePosture{
			compliant: true
			encrypted: true
			antivirus: true
			last_checkin: time.now()
		}
	}
	decision := engine.evaluate_access(identity, '/api/admin')
	assert decision == .deny
}

// test_verify_identity_valid verifies that a well-formed identity
// passes verification.
fn test_verify_identity_valid() {
	identity := v_zerotrust.Identity{
		subject: 'alice@example.com'
		roles: ['user']
	}
	v_zerotrust.verify_identity(identity) or {
		assert false, 'verify failed: ${err}'
		return
	}
}

// test_verify_identity_empty_subject_returns_error verifies that
// empty subjects are rejected.
fn test_verify_identity_empty_subject_returns_error() {
	identity := v_zerotrust.Identity{
		roles: ['user']
	}
	v_zerotrust.verify_identity(identity) or {
		assert err.msg().contains('subject must not be empty')
		return
	}
	assert false, 'expected error for empty subject'
}

// test_verify_identity_no_roles_returns_error verifies that
// identities without roles are rejected.
fn test_verify_identity_no_roles_returns_error() {
	identity := v_zerotrust.Identity{
		subject: 'alice@example.com'
	}
	v_zerotrust.verify_identity(identity) or {
		assert err.msg().contains('at least one role')
		return
	}
	assert false, 'expected error for no roles'
}

// test_assess_device_compliant verifies that a compliant device
// passes assessment.
fn test_assess_device_compliant() {
	posture := v_zerotrust.DevicePosture{
		compliant: true
		os_version: 'Fedora 43'
		encrypted: true
		antivirus: true
		last_checkin: time.now()
	}
	assert v_zerotrust.assess_device(posture) == true
}

// test_assess_device_not_compliant verifies that a non-compliant
// device fails assessment.
fn test_assess_device_not_compliant() {
	posture := v_zerotrust.DevicePosture{
		compliant: false
		encrypted: true
		last_checkin: time.now()
	}
	assert v_zerotrust.assess_device(posture) == false
}

// test_assess_device_not_encrypted verifies that an unencrypted
// device fails assessment.
fn test_assess_device_not_encrypted() {
	posture := v_zerotrust.DevicePosture{
		compliant: true
		encrypted: false
		last_checkin: time.now()
	}
	assert v_zerotrust.assess_device(posture) == false
}

// test_calculate_trust_score verifies trust score calculation with
// all positive signals.
fn test_calculate_trust_score() {
	identity := v_zerotrust.Identity{
		subject: 'alice@example.com'
		roles: ['admin']
		groups: ['engineering']
		mfa_verified: true
		device_posture: v_zerotrust.DevicePosture{
			compliant: true
			encrypted: true
			antivirus: true
			last_checkin: time.now()
		}
	}
	score := v_zerotrust.calculate_trust_score(identity)
	// MFA(30) + compliant(20) + encrypted(15) + antivirus(10) + roles(15) + groups(10) = 100
	assert score == 100
}

// test_calculate_trust_score_minimal verifies trust score with
// minimal attributes.
fn test_calculate_trust_score_minimal() {
	identity := v_zerotrust.Identity{
		subject: 'bob@example.com'
		mfa_verified: false
		device_posture: v_zerotrust.DevicePosture{
			compliant: false
			encrypted: false
		}
	}
	score := v_zerotrust.calculate_trust_score(identity)
	assert score == 0
}
