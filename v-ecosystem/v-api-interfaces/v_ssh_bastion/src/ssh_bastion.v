// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem SSH bastion host with session recording, MFA, and access policies Connector
// Author: Jonathan D.A. Jewell
//
// SSH bastion host with session recording, MFA, and access policies.
// Provides typed client bindings for the proven-ssh-bastion protocol.

module ssh_bastion

import os
import time
import net

// --- Auth method ---

// AuthMethod selects the SSH authentication method.
pub enum AuthMethod {
	public_key
	certificate
	mfa          // Multi-factor
	fido2        // FIDO2/WebAuthn
}

// --- Session state ---

// SessionState tracks a bastion session lifecycle.
pub enum SessionState {
	connecting
	authenticated
	active
	recording
	closed
}

// --- Data structures ---

// BastionSession represents a proxied SSH session.
pub struct BastionSession {
pub:
	session_id   string
	username     string
	src_addr     string
	dst_host     string
	dst_port     int = 22
	auth_method  AuthMethod
	state        SessionState
	started_at   i64
}

// AccessPolicy defines who can access what via bastion.
pub struct AccessPolicy {
pub:
	name         string
	allowed_users []string
	allowed_hosts []string
	require_mfa  bool = true
	record       bool = true
}

// BastionConfig holds SSH bastion parameters.
pub struct BastionConfig {
pub:
	listen_addr  string = "0.0.0.0"
	listen_port  int = 2222
	host_key     string
	recording_path string = "/var/log/bastion"
}

// BastionManager manages SSH bastion sessions and policies.
pub struct BastionManager {
mut:
	config    BastionConfig
	sessions  []BastionSession
	policies  []AccessPolicy
}

// --- Manager lifecycle ---

// new_bastion_manager creates a new bastion manager.
pub fn new_bastion_manager(config BastionConfig) &BastionManager {
	return &BastionManager{
		config:   config
		sessions: []BastionSession{}
		policies: []AccessPolicy{}
	}
}

// add_policy registers an access policy.
pub fn (mut m BastionManager) add_policy(policy AccessPolicy) ! {
	if policy.name.len == 0 {
		return error("policy name must not be empty")
	}
	m.policies << policy
	println("[bastion] added policy: ${policy.name} (MFA=${policy.require_mfa})")
}

// open_session starts a proxied SSH session.
pub fn (mut m BastionManager) open_session(session BastionSession) ! {
	if session.session_id.len == 0 {
		return error("session_id must not be empty")
	}
	m.sessions << session
	println("[bastion] session ${session.session_id}: ${session.username} -> ${session.dst_host}:${session.dst_port}")
}

// --- Tests ---

fn test_empty_policy_name_rejected() {
	mut mgr := new_bastion_manager(BastionConfig{ host_key: "/etc/ssh/bastion_key" })
	mgr.add_policy(AccessPolicy{ name: "", allowed_users: [], allowed_hosts: [], require_mfa: true, record: true }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
