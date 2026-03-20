// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// auth_test -- Protocol conformance tests for v_auth.
// Covers auth method enumeration, password hashing and verification,
// token issuance, validation, revocation, and authentication flows.
module v_auth

// test_auth_method_to_string verifies string labels for all auth methods.
fn test_auth_method_to_string() {
	assert auth_method_to_string(.password) == 'password'
	assert auth_method_to_string(.token) == 'token'
	assert auth_method_to_string(.certificate) == 'certificate'
	assert auth_method_to_string(.oauth2) == 'oauth2'
	assert auth_method_to_string(.saml) == 'saml'
	assert auth_method_to_string(.webauthn) == 'webauthn'
	assert auth_method_to_string(.kerberos) == 'kerberos'
}

// test_auth_result_to_string verifies string labels for all auth results.
fn test_auth_result_to_string() {
	assert auth_result_to_string(.granted) == 'GRANTED'
	assert auth_result_to_string(.denied) == 'DENIED'
	assert auth_result_to_string(.mfa_required) == 'MFA_REQUIRED'
	assert auth_result_to_string(.expired) == 'EXPIRED'
	assert auth_result_to_string(.locked) == 'LOCKED'
	assert auth_result_to_string(.rate_limited) == 'RATE_LIMITED'
}

// test_hash_password verifies that password hashing produces a non-empty
// hex string that is consistent across calls.
fn test_hash_password() {
	hash1 := hash_password('my_secret_password')
	hash2 := hash_password('my_secret_password')
	// Same input produces same hash
	assert hash1 == hash2
	// Hash is non-empty hex
	assert hash1.len > 0
	// Different input produces different hash
	hash3 := hash_password('different_password')
	assert hash1 != hash3
}

// test_verify_password verifies that correct passwords match and
// incorrect passwords do not.
fn test_verify_password() {
	password := 'test_password_123'
	hash := hash_password(password)
	// Correct password verifies
	assert verify_password(password, hash) == true
	// Wrong password fails
	assert verify_password('wrong_password', hash) == false
	// Empty password fails against non-empty hash
	assert verify_password('', hash) == false
}

// test_password_authentication verifies the full password auth flow:
// register credentials, authenticate, receive token.
fn test_password_authentication() {
	mut server := new_server(8080)
	server.add_provider(.password, {})
	// Register a user
	server.credential_store['alice'] = hash_password('alice_pass')

	// Successful authentication
	req := AuthRequest{
		method: .password
		username: 'alice'
		credentials: 'alice_pass'
		client_info: ClientInfo{
			ip_address: '127.0.0.1'
		}
	}
	resp := server.authenticate(req)!
	assert resp.result == .granted
	assert resp.token.len > 0
	assert resp.claims.sub == 'alice'
	assert resp.claims.iss == 'v_auth'
	assert resp.claims.scopes.len > 0
}

// test_password_authentication_denied verifies that wrong credentials
// produce a denied result.
fn test_password_authentication_denied() {
	mut server := new_server(8080)
	server.add_provider(.password, {})
	server.credential_store['bob'] = hash_password('bob_pass')

	req := AuthRequest{
		method: .password
		username: 'bob'
		credentials: 'wrong_pass'
	}
	resp := server.authenticate(req)!
	assert resp.result == .denied
	assert resp.token == ''
}

// test_password_unknown_user verifies that an unknown username produces
// a denied result.
fn test_password_unknown_user() {
	mut server := new_server(8080)
	server.add_provider(.password, {})

	req := AuthRequest{
		method: .password
		username: 'unknown_user'
		credentials: 'any_pass'
	}
	resp := server.authenticate(req)!
	assert resp.result == .denied
}

// test_no_provider verifies that authentication fails when no provider
// is registered for the requested method.
fn test_no_provider() {
	mut server := new_server(8080)
	// No providers registered

	req := AuthRequest{
		method: .password
		username: 'alice'
		credentials: 'pass'
	}
	resp := server.authenticate(req)!
	assert resp.result == .denied
}

// test_token_validation verifies that issued tokens can be validated
// and return the correct claims.
fn test_token_validation() {
	mut server := new_server(8080)
	server.add_provider(.password, {})
	server.credential_store['carol'] = hash_password('carol_pass')

	// Authenticate to get a token
	req := AuthRequest{
		method: .password
		username: 'carol'
		credentials: 'carol_pass'
	}
	resp := server.authenticate(req)!
	assert resp.result == .granted

	// Validate the token
	claims := server.validate_token(resp.token)!
	assert claims.sub == 'carol'
	assert claims.iss == 'v_auth'
}

// test_token_revocation verifies that revoked tokens cannot be validated.
fn test_token_revocation() {
	mut server := new_server(8080)
	server.add_provider(.password, {})
	server.credential_store['dave'] = hash_password('dave_pass')

	// Authenticate
	req := AuthRequest{
		method: .password
		username: 'dave'
		credentials: 'dave_pass'
	}
	resp := server.authenticate(req)!
	token := resp.token

	// Revoke the token
	server.revoke_token(token)!

	// Validation should fail
	server.validate_token(token) or {
		assert err.msg().contains('revoked')
		return
	}
	assert false, 'expected error for revoked token'
}

// test_validate_unknown_token verifies that unknown tokens are rejected.
fn test_validate_unknown_token() {
	server := new_server(8080)
	server.validate_token('not_a_real_token') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for unknown token'
}

// test_revoke_unknown_token verifies that revoking a non-existent token
// produces an error.
fn test_revoke_unknown_token() {
	mut server := new_server(8080)
	server.revoke_token('fake_token') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for unknown token'
}

// test_token_claims_structure verifies that token claims contain all
// required fields with sensible values.
fn test_token_claims_structure() {
	mut server := new_server(8080)
	server.add_provider(.password, {})
	server.token_ttl = 7200
	server.credential_store['eve'] = hash_password('eve_pass')

	req := AuthRequest{
		method: .password
		username: 'eve'
		credentials: 'eve_pass'
	}
	resp := server.authenticate(req)!
	claims := resp.claims

	assert claims.sub == 'eve'
	assert claims.iss == 'v_auth'
	assert claims.aud == 'v_auth_clients'
	assert claims.iat > 0
	assert claims.exp > claims.iat
	assert claims.exp - claims.iat == 7200
}

// test_mfa_required verifies that when MFA is configured, authentication
// without an MFA code returns mfa_required.
fn test_mfa_required() {
	mut server := new_server(8080)
	server.add_provider(.password, {
		'require_mfa': 'true'
	})
	server.credential_store['frank'] = hash_password('frank_pass')

	req := AuthRequest{
		method: .password
		username: 'frank'
		credentials: 'frank_pass'
		// No mfa_code provided
	}
	resp := server.authenticate(req)!
	assert resp.result == .mfa_required
}
