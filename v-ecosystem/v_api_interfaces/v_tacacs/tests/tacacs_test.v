// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_tacacs.
// Validates server creation, user management, authentication,
// authorisation, accounting, and body encryption.
module main

import v_tacacs

// test_new_server_creates_empty verifies that a new TACACS+ server
// has no users or accounting records.
fn test_new_server_creates_empty() {
	server := v_tacacs.new_server('secret')
	assert server.shared_secret == 'secret'
	assert server.port == 49
	assert server.users.len == 0
	assert server.accounting_log.len == 0
}

// test_add_user verifies that users can be registered with a
// privilege level.
fn test_add_user() {
	mut server := v_tacacs.new_server('secret')
	server.add_user('admin', 'password', ['show', 'configure'], 15) or {
		assert false, 'add_user failed: ${err}'
		return
	}
	assert 'admin' in server.users
	user := server.users['admin'] or { return }
	assert user.privilege_level == 15
	assert user.allowed_commands.len == 2
}

// test_add_user_empty_name_returns_error verifies empty username
// rejection.
fn test_add_user_empty_name_returns_error() {
	mut server := v_tacacs.new_server('secret')
	server.add_user('', 'pass', []string{}, 0) or {
		assert err.msg().contains('must not be empty')
		return
	}
	assert false, 'expected error for empty username'
}

// test_add_user_invalid_priv_level_returns_error verifies privilege
// level bounds checking.
fn test_add_user_invalid_priv_level_returns_error() {
	mut server := v_tacacs.new_server('secret')
	server.add_user('user', 'pass', []string{}, 16) or {
		assert err.msg().contains('privilege level')
		return
	}
	assert false, 'expected error for invalid priv level'
}

// test_add_user_duplicate_returns_error verifies duplicate rejection.
fn test_add_user_duplicate_returns_error() {
	mut server := v_tacacs.new_server('secret')
	server.add_user('admin', 'pass1', []string{}, 15) or { return }
	server.add_user('admin', 'pass2', []string{}, 1) or {
		assert err.msg().contains('already exists')
		return
	}
	assert false, 'expected error for duplicate user'
}

// test_authenticate_pap_success verifies successful PAP authentication.
fn test_authenticate_pap_success() {
	mut server := v_tacacs.new_server('secret')
	server.add_user('alice', 'correct', []string{}, 1) or { return }
	reply := server.authenticate(v_tacacs.AuthenRequest{
		action: .login
		authen_type: .pap
		user: 'alice'
		data: 'correct'
	})
	assert reply.status == .pass
	assert reply.server_msg.contains('successful')
}

// test_authenticate_wrong_password verifies failed authentication.
fn test_authenticate_wrong_password() {
	mut server := v_tacacs.new_server('secret')
	server.add_user('alice', 'correct', []string{}, 1) or { return }
	reply := server.authenticate(v_tacacs.AuthenRequest{
		action: .login
		authen_type: .pap
		user: 'alice'
		data: 'wrong'
	})
	assert reply.status == .fail
}

// test_authenticate_unknown_user verifies that unknown users fail.
fn test_authenticate_unknown_user() {
	server := v_tacacs.new_server('secret')
	reply := server.authenticate(v_tacacs.AuthenRequest{
		action: .login
		authen_type: .ascii
		user: 'nobody'
		data: 'pass'
	})
	assert reply.status == .fail
}

// test_authenticate_missing_user verifies the get_user prompt.
fn test_authenticate_missing_user() {
	server := v_tacacs.new_server('secret')
	reply := server.authenticate(v_tacacs.AuthenRequest{
		action: .login
		authen_type: .pap
		data: 'pass'
	})
	assert reply.status == .get_user
}

// test_authenticate_missing_password_pap verifies the get_pass prompt
// for PAP without data.
fn test_authenticate_missing_password_pap() {
	mut server := v_tacacs.new_server('secret')
	server.add_user('alice', 'pass', []string{}, 1) or { return }
	reply := server.authenticate(v_tacacs.AuthenRequest{
		action: .login
		authen_type: .pap
		user: 'alice'
	})
	assert reply.status == .get_pass
}

// test_authorize_allowed_command verifies that allowed commands pass.
fn test_authorize_allowed_command() {
	mut server := v_tacacs.new_server('secret')
	server.add_user('admin', 'pass', ['show', 'configure'], 15) or { return }
	reply := server.authorize(v_tacacs.AuthorRequest{
		user: 'admin'
		args: ['cmd=show']
	})
	assert reply.status == .pass_add
	assert reply.args.len > 0
}

// test_authorize_denied_command verifies that disallowed commands fail.
fn test_authorize_denied_command() {
	mut server := v_tacacs.new_server('secret')
	server.add_user('user', 'pass', ['show'], 1) or { return }
	reply := server.authorize(v_tacacs.AuthorRequest{
		user: 'user'
		args: ['cmd=configure']
	})
	assert reply.status == .fail
	assert reply.server_msg.contains('not authorized')
}

// test_authorize_unknown_user verifies that unknown users fail.
fn test_authorize_unknown_user() {
	server := v_tacacs.new_server('secret')
	reply := server.authorize(v_tacacs.AuthorRequest{
		user: 'nobody'
		args: ['cmd=show']
	})
	assert reply.status == .fail
}

// test_account verifies that accounting records are stored.
fn test_account() {
	mut server := v_tacacs.new_server('secret')
	status := server.account(v_tacacs.AccountingRequest{
		user: 'admin'
		args: ['task_id=1', 'cmd=show running-config']
	})
	assert status == .success
	assert server.accounting_log.len == 1
	assert server.accounting_log[0].user == 'admin'
}

// test_encrypt_body_roundtrip verifies that encrypting then decrypting
// the body returns the original data (XOR is its own inverse).
fn test_encrypt_body_roundtrip() {
	body := 'hello tacacs+'.bytes()
	encrypted := v_tacacs.encrypt_body(body, 'secret', 0x12345678, 0xc1, 1)
	decrypted := v_tacacs.encrypt_body(encrypted, 'secret', 0x12345678, 0xc1, 1)
	assert decrypted == body
}

// test_encrypt_body_different_sessions verifies that different session
// IDs produce different ciphertext.
fn test_encrypt_body_different_sessions() {
	body := 'test data'.bytes()
	enc1 := v_tacacs.encrypt_body(body, 'secret', 0x11111111, 0xc1, 1)
	enc2 := v_tacacs.encrypt_body(body, 'secret', 0x22222222, 0xc1, 1)
	assert enc1 != enc2
}

// test_create_reply verifies reply construction.
fn test_create_reply() {
	reply := v_tacacs.create_reply(.pass, 'Welcome')
	assert reply.status == .pass
	assert reply.server_msg == 'Welcome'
}
