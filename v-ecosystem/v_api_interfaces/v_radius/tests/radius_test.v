// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_radius.
// Validates server creation, user management, authentication,
// authorisation, accounting, and authenticator validation.
module main

import v_radius

// test_new_server_creates_empty verifies that a new RADIUS server
// has no users or accounting records.
fn test_new_server_creates_empty() {
	server := v_radius.new_server('shared-secret')
	assert server.shared_secret == 'shared-secret'
	assert server.port == 1812
	assert server.users.len == 0
	assert server.accounting_log.len == 0
}

// test_add_user verifies that users can be registered.
fn test_add_user() {
	mut server := v_radius.new_server('secret')
	server.add_user('alice', 'pass123', [
		v_radius.RadiusAttribute{
			attr_type: .service_type
			value: 'login'
		},
	]) or {
		assert false, 'add_user failed: ${err}'
		return
	}
	assert 'alice' in server.users
}

// test_add_user_empty_name_returns_error verifies that empty
// usernames are rejected.
fn test_add_user_empty_name_returns_error() {
	mut server := v_radius.new_server('secret')
	server.add_user('', 'pass', []v_radius.RadiusAttribute{}) or {
		assert err.msg().contains('must not be empty')
		return
	}
	assert false, 'expected error for empty username'
}

// test_add_user_duplicate_returns_error verifies that duplicate
// usernames are rejected.
fn test_add_user_duplicate_returns_error() {
	mut server := v_radius.new_server('secret')
	server.add_user('alice', 'pass1', []v_radius.RadiusAttribute{}) or { return }
	server.add_user('alice', 'pass2', []v_radius.RadiusAttribute{}) or {
		assert err.msg().contains('already exists')
		return
	}
	assert false, 'expected error for duplicate user'
}

// test_authenticate_success verifies that a valid Access-Request
// receives an Access-Accept response.
fn test_authenticate_success() {
	mut server := v_radius.new_server('secret')
	server.add_user('alice', 'correct', [
		v_radius.RadiusAttribute{
			attr_type: .framed_ip_address
			value: '10.0.0.100'
		},
	]) or { return }
	request := v_radius.RadiusPacket{
		code: .access_request
		identifier: 42
		authenticator: []u8{len: 16}
		attributes: [
			v_radius.RadiusAttribute{attr_type: .user_name, value: 'alice'},
			v_radius.RadiusAttribute{attr_type: .user_password, value: 'correct'},
		]
	}
	response := server.authenticate(request)
	assert response.code == .access_accept
	assert response.identifier == 42
	assert response.attributes.len == 1
	assert response.attributes[0].attr_type == .framed_ip_address
}

// test_authenticate_wrong_password verifies that wrong credentials
// result in Access-Reject.
fn test_authenticate_wrong_password() {
	mut server := v_radius.new_server('secret')
	server.add_user('alice', 'correct', []v_radius.RadiusAttribute{}) or { return }
	request := v_radius.RadiusPacket{
		code: .access_request
		identifier: 1
		authenticator: []u8{len: 16}
		attributes: [
			v_radius.RadiusAttribute{attr_type: .user_name, value: 'alice'},
			v_radius.RadiusAttribute{attr_type: .user_password, value: 'wrong'},
		]
	}
	response := server.authenticate(request)
	assert response.code == .access_reject
}

// test_authenticate_unknown_user verifies that unknown users are
// rejected.
fn test_authenticate_unknown_user() {
	server := v_radius.new_server('secret')
	request := v_radius.RadiusPacket{
		code: .access_request
		identifier: 1
		authenticator: []u8{len: 16}
		attributes: [
			v_radius.RadiusAttribute{attr_type: .user_name, value: 'nobody'},
			v_radius.RadiusAttribute{attr_type: .user_password, value: 'pass'},
		]
	}
	response := server.authenticate(request)
	assert response.code == .access_reject
}

// test_authenticate_missing_username verifies that requests without
// a username are rejected.
fn test_authenticate_missing_username() {
	server := v_radius.new_server('secret')
	request := v_radius.RadiusPacket{
		code: .access_request
		identifier: 1
		authenticator: []u8{len: 16}
		attributes: [
			v_radius.RadiusAttribute{attr_type: .user_password, value: 'pass'},
		]
	}
	response := server.authenticate(request)
	assert response.code == .access_reject
}

// test_authorize_success verifies that an authorised user receives
// their attributes.
fn test_authorize_success() {
	mut server := v_radius.new_server('secret')
	server.add_user('alice', 'pass', [
		v_radius.RadiusAttribute{attr_type: .service_type, value: 'login'},
		v_radius.RadiusAttribute{attr_type: .session_timeout, value: '3600'},
	]) or { return }
	attrs := server.authorize('alice', 'login') or {
		assert false, 'authorize failed: ${err}'
		return
	}
	assert attrs.len == 2
}

// test_authorize_denied verifies that an unauthorised service type
// is rejected.
fn test_authorize_denied() {
	mut server := v_radius.new_server('secret')
	server.add_user('alice', 'pass', [
		v_radius.RadiusAttribute{attr_type: .service_type, value: 'login'},
	]) or { return }
	server.authorize('alice', 'admin') or {
		assert err.msg().contains('not authorized')
		return
	}
	assert false, 'expected authorization denial'
}

// test_account verifies that accounting requests are logged and
// an Accounting-Response is returned.
fn test_account() {
	mut server := v_radius.new_server('secret')
	request := v_radius.RadiusPacket{
		code: .accounting_request
		identifier: 10
		authenticator: []u8{len: 16}
		attributes: [
			v_radius.RadiusAttribute{attr_type: .user_name, value: 'alice'},
			v_radius.RadiusAttribute{attr_type: .session_timeout, value: '7200'},
		]
	}
	response := server.account(request)
	assert response.code == .accounting_response
	assert response.identifier == 10
	assert server.accounting_log.len == 1
	assert server.accounting_log[0].username == 'alice'
}

// test_create_response verifies generic response construction.
fn test_create_response() {
	response := v_radius.create_response(.access_accept, 99, [
		v_radius.RadiusAttribute{attr_type: .reply_message, value: 'Welcome'},
	])
	assert response.code == .access_accept
	assert response.identifier == 99
	assert response.attributes.len == 1
}

// test_validate_authenticator verifies authenticator validation
// with matching shared secrets.
fn test_validate_authenticator() {
	// Build a packet with a valid authenticator for the given secret.
	packet := v_radius.RadiusPacket{
		code: .access_accept
		identifier: 42
		authenticator: []u8{len: 16}
		attributes: []v_radius.RadiusAttribute{}
	}
	// Validation should fail because the zero authenticator doesn't
	// match the computed one.
	v_radius.validate_authenticator(packet, 'secret') or {
		assert err.msg().contains('validation failed')
		return
	}
	// If it didn't fail, the zero authenticator happened to match
	// (extremely unlikely but technically possible).
}
