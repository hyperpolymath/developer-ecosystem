// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_ssh.
// Validates bastion server creation, session management, forward rules,
// host key generation, and fingerprint computation.
module main

import v_ssh

// test_new_bastion_creates_server verifies that new_bastion returns a
// properly configured server with no active sessions.
fn test_new_bastion_creates_server() {
	config := v_ssh.BastionConfig{
		port: 2222
		host_key_path: '/etc/ssh/host_key'
		allowed_users: ['admin', 'deploy']
		max_sessions: 50
		idle_timeout: 600
		audit_log: '/var/log/bastion.log'
	}
	server := v_ssh.new_bastion(config)
	assert server.config.port == 2222
	assert server.config.max_sessions == 50
	assert server.config.idle_timeout == 600
	assert server.config.allowed_users.len == 2
	assert server.sessions.len == 0
	assert server.forward_rules.len == 0
}

// test_default_config_values verifies the default bastion configuration.
fn test_default_config_values() {
	config := v_ssh.BastionConfig{}
	assert config.port == 22
	assert config.max_sessions == 100
	assert config.idle_timeout == 300
	assert config.allowed_users.len == 0
}

// test_add_forward_rule verifies that forward rules accumulate correctly.
fn test_add_forward_rule() {
	config := v_ssh.BastionConfig{port: 2222}
	mut server := v_ssh.new_bastion(config)
	rule1 := v_ssh.ForwardRule{
		source_host: '0.0.0.0'
		source_port: 8080
		dest_host: '10.0.0.1'
		dest_port: 80
		allowed_users: ['admin']
	}
	rule2 := v_ssh.ForwardRule{
		source_host: '0.0.0.0'
		source_port: 5432
		dest_host: '10.0.0.2'
		dest_port: 5432
	}
	server.add_forward_rule(rule1)
	server.add_forward_rule(rule2)
	assert server.forward_rules.len == 2
	assert server.forward_rules[0].dest_host == '10.0.0.1'
	assert server.forward_rules[1].dest_port == 5432
}

// test_active_sessions_filters_closed verifies that active_sessions
// excludes closed sessions.
fn test_active_sessions_filters_closed() {
	config := v_ssh.BastionConfig{port: 2222}
	mut server := v_ssh.new_bastion(config)
	server.sessions['s1'] = v_ssh.SshSession{
		id: 's1'
		user: 'alice'
		auth_method: .public_key
		state: .active
		remote_addr: '192.168.1.10:54321'
	}
	server.sessions['s2'] = v_ssh.SshSession{
		id: 's2'
		user: 'bob'
		auth_method: .password
		state: .closed
		remote_addr: '192.168.1.11:54322'
	}
	active := server.active_sessions()
	assert active.len == 1
	assert active[0].user == 'alice'
}

// test_disconnect_closes_session verifies that disconnect transitions
// a session to the closed state.
fn test_disconnect_closes_session() {
	config := v_ssh.BastionConfig{port: 2222}
	mut server := v_ssh.new_bastion(config)
	server.sessions['s1'] = v_ssh.SshSession{
		id: 's1'
		user: 'alice'
		auth_method: .public_key
		state: .active
		channels: [.session, .direct_tcpip]
		remote_addr: '192.168.1.10:54321'
	}
	server.disconnect('s1') or { assert false, 'unexpected error: ${err}' }
	session := server.sessions['s1'] or {
		assert false, 'session should still exist'
		return
	}
	assert session.state == .closed
	assert session.channels.len == 0
}

// test_disconnect_nonexistent_returns_error verifies that disconnecting
// a nonexistent session returns an error.
fn test_disconnect_nonexistent_returns_error() {
	config := v_ssh.BastionConfig{port: 2222}
	mut server := v_ssh.new_bastion(config)
	server.disconnect('nonexistent') or {
		assert err.msg().contains('session not found')
		return
	}
	assert false, 'expected error for nonexistent session'
}

// test_disconnect_already_closed_returns_error verifies that
// disconnecting an already-closed session returns an error.
fn test_disconnect_already_closed_returns_error() {
	config := v_ssh.BastionConfig{port: 2222}
	mut server := v_ssh.new_bastion(config)
	server.sessions['s1'] = v_ssh.SshSession{
		id: 's1'
		user: 'alice'
		auth_method: .password
		state: .closed
		remote_addr: '192.168.1.10:54321'
	}
	server.disconnect('s1') or {
		assert err.msg().contains('already closed')
		return
	}
	assert false, 'expected error for already-closed session'
}

// test_is_user_allowed_empty_list verifies that an empty allowed_users
// list permits all users.
fn test_is_user_allowed_empty_list() {
	config := v_ssh.BastionConfig{port: 2222}
	server := v_ssh.new_bastion(config)
	assert server.is_user_allowed('anyone') == true
}

// test_is_user_allowed_with_list verifies that only listed users
// are permitted when allowed_users is non-empty.
fn test_is_user_allowed_with_list() {
	config := v_ssh.BastionConfig{
		port: 2222
		allowed_users: ['admin', 'deploy']
	}
	server := v_ssh.new_bastion(config)
	assert server.is_user_allowed('admin') == true
	assert server.is_user_allowed('deploy') == true
	assert server.is_user_allowed('hacker') == false
}

// test_can_forward_with_restrictions verifies forward rule user
// filtering.
fn test_can_forward_with_restrictions() {
	config := v_ssh.BastionConfig{port: 2222}
	server := v_ssh.new_bastion(config)
	rule := v_ssh.ForwardRule{
		source_host: '0.0.0.0'
		source_port: 8080
		dest_host: '10.0.0.1'
		dest_port: 80
		allowed_users: ['admin']
	}
	assert server.can_forward('admin', rule) == true
	assert server.can_forward('deploy', rule) == false
}

// test_generate_host_key_returns_correct_size verifies that key
// generation produces bytes of the expected length per algorithm.
fn test_generate_host_key_returns_correct_size() {
	ed25519_key := v_ssh.generate_host_key(.ed25519) or {
		assert false, 'key generation failed: ${err}'
		return
	}
	assert ed25519_key.len == 32

	rsa_key := v_ssh.generate_host_key(.rsa4096) or {
		assert false, 'key generation failed: ${err}'
		return
	}
	assert rsa_key.len == 512
}

// test_fingerprint_is_deterministic verifies that the same key always
// produces the same fingerprint.
fn test_fingerprint_is_deterministic() {
	key := [u8(0x01), 0x02, 0x03, 0x04]
	fp1 := v_ssh.fingerprint(key)
	fp2 := v_ssh.fingerprint(key)
	assert fp1 == fp2
	assert fp1.starts_with('SHA256:')
}

// test_fingerprint_format verifies the colon-separated hex format.
fn test_fingerprint_format() {
	key := [u8(0xAA), 0xBB, 0xCC]
	fp := v_ssh.fingerprint(key)
	assert fp.starts_with('SHA256:')
	// Should contain colons separating hex pairs.
	assert fp.contains(':')
}
