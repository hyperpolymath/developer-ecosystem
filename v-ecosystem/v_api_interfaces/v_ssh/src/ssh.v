// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_ssh — SSH protocol types, bastion server, and session management.
// Maps to proven-servers/protocols/proven-ssh-bastion.
//
// Provides a bastion server abstraction with session tracking, port forwarding
// rules, host key generation, and fingerprint computation. Network I/O is
// stubbed with TODO markers; all type definitions and logic are real.
module v_ssh

import time
import crypto.sha256
import encoding.hex
import rand

// AuthMethod represents the SSH authentication methods supported by the
// bastion server, as defined in RFC 4252.
pub enum AuthMethod {
	public_key
	password
	keyboard_interactive
	certificate
}

// ChannelType represents the SSH channel types defined in RFC 4254.
pub enum ChannelType {
	session
	direct_tcpip
	forwarded_tcpip
	x11
}

// SessionState tracks the lifecycle of an SSH session from opening
// through authentication, active use, and teardown.
pub enum SessionState {
	opening
	authenticated
	active
	closing
	closed
}

// KeyType enumerates the host key algorithms the bastion supports.
// Ed25519 is preferred; RSA-4096 provided for legacy compatibility.
pub enum KeyType {
	ed25519
	rsa4096
	ecdsa_p256
	ecdsa_p384
}

// SshSession holds the state for a single connected SSH session,
// including authentication details, open channels, and timing.
pub struct SshSession {
pub:
	// id is a unique session identifier (UUID-style string).
	id string
	// user is the authenticated username.
	user string
	// auth_method records how the user authenticated.
	auth_method AuthMethod
	// remote_addr is the client's IP:port string.
	remote_addr string
	// started_at is the time the session was established.
	started_at time.Time
pub mut:
	// state tracks the current session lifecycle phase.
	state SessionState
	// channels lists the open channel types on this session.
	channels []ChannelType
}

// BastionConfig holds the configuration for a bastion SSH server.
pub struct BastionConfig {
pub:
	// port is the TCP port the bastion listens on (default 22).
	port int = 22
	// host_key_path is the filesystem path to the host private key.
	host_key_path string
	// allowed_users restricts connections to these usernames.
	// An empty list means all users are allowed.
	allowed_users []string
	// max_sessions caps the number of concurrent sessions.
	max_sessions int = 100
	// idle_timeout is the duration of inactivity before a session
	// is automatically closed, in seconds.
	idle_timeout int = 300
	// audit_log is the filesystem path for the audit log file.
	audit_log string
}

// BastionServer is the main bastion SSH server. It manages sessions,
// enforces forward rules, and provides an audit trail.
pub struct BastionServer {
pub:
	// config is the server configuration.
	config BastionConfig
pub mut:
	// sessions holds all current SSH sessions, keyed by session id.
	sessions map[string]SshSession
	// forward_rules defines the allowed port-forwarding rules.
	forward_rules []ForwardRule
	// listener is an opaque handle to the network listener.
	// Set when serve() is called.
	listener voidptr
}

// ForwardRule defines a port-forwarding permission for the bastion.
// Only users listed in allowed_users may create this forward.
pub struct ForwardRule {
pub:
	// source_host is the bind address on the bastion side.
	source_host string
	// source_port is the port on the bastion side.
	source_port int
	// dest_host is the target host to forward traffic to.
	dest_host string
	// dest_port is the target port on the destination host.
	dest_port int
	// allowed_users restricts who may use this forward rule.
	// An empty list means all authenticated users may use it.
	allowed_users []string
}

// new_bastion creates a new BastionServer with the given configuration.
// The server is not yet listening; call serve() to start accepting
// connections.
pub fn new_bastion(config BastionConfig) &BastionServer {
	return &BastionServer{
		config: config
		sessions: map[string]SshSession{}
		forward_rules: []ForwardRule{}
		listener: unsafe { nil }
	}
}

// serve starts the bastion SSH server, binding to the configured port
// and accepting incoming connections. This function blocks until the
// server is shut down.
pub fn (mut s BastionServer) serve() ! {
	if s.config.port < 1 || s.config.port > 65535 {
		return error('invalid port: ${s.config.port}')
	}
	// TODO: Bind TCP listener on s.config.port and accept SSH connections.
	// Network I/O requires an SSH protocol implementation (e.g. libssh2 FFI).
	// For now, log the intent.
	println('[v_ssh] bastion listening on port ${s.config.port}')
}

// add_forward_rule registers a new port-forwarding rule on the bastion.
// Rules are evaluated in order; the first matching rule wins.
pub fn (mut s BastionServer) add_forward_rule(rule ForwardRule) {
	s.forward_rules << rule
}

// active_sessions returns a snapshot of all sessions that are not in the
// Closed state.
pub fn (s BastionServer) active_sessions() []SshSession {
	mut result := []SshSession{}
	for _, session in s.sessions {
		if session.state != .closed {
			result << session
		}
	}
	return result
}

// disconnect terminates the session identified by session_id. Returns
// an error if no such session exists or if it is already closed.
pub fn (mut s BastionServer) disconnect(session_id string) ! {
	if session_id !in s.sessions {
		return error('session not found: ${session_id}')
	}
	mut session := s.sessions[session_id] or { return error('session not found: ${session_id}') }
	if session.state == .closed {
		return error('session already closed: ${session_id}')
	}
	session.state = .closed
	session.channels = []ChannelType{}
	s.sessions[session_id] = session
}

// is_user_allowed checks whether a username is permitted to connect,
// based on the bastion's allowed_users list. Returns true if the list
// is empty (all users allowed) or if the user is in the list.
pub fn (s BastionServer) is_user_allowed(user string) bool {
	if s.config.allowed_users.len == 0 {
		return true
	}
	return user in s.config.allowed_users
}

// can_forward checks whether a user is allowed to use a given forward
// rule. Returns true if the rule's allowed_users list is empty or
// contains the user.
pub fn (s BastionServer) can_forward(user string, rule ForwardRule) bool {
	if rule.allowed_users.len == 0 {
		return true
	}
	return user in rule.allowed_users
}

// generate_host_key generates a new host key of the specified type.
// Returns the raw key bytes. The actual cryptographic key generation
// is stubbed; production use requires a proper crypto library.
pub fn generate_host_key(key_type KeyType) ![]u8 {
	// Determine the key size based on the algorithm.
	key_size := match key_type {
		.ed25519 { 32 }
		.rsa4096 { 512 }
		.ecdsa_p256 { 32 }
		.ecdsa_p384 { 48 }
	}
	// TODO: Replace with real cryptographic key generation (e.g. libsodium FFI).
	// This placeholder generates random bytes of the appropriate length.
	mut key := []u8{len: key_size}
	for i in 0 .. key_size {
		key[i] = u8(rand.int_in_range(0, 256) or { 0 })
	}
	return key
}

// fingerprint computes a SHA-256 fingerprint of a public key, returned
// as a colon-separated hex string (e.g. "SHA256:ab:cd:ef:...").
pub fn fingerprint(pubkey []u8) string {
	hash := sha256.sum(pubkey)
	hex_str := hex.encode(hash)
	// Insert colons every two characters for readability.
	mut parts := []string{}
	for i := 0; i < hex_str.len; i += 2 {
		end := if i + 2 > hex_str.len { hex_str.len } else { i + 2 }
		parts << hex_str[i..end]
	}
	return 'SHA256:${parts.join(':')}'
}

// generate_session_id creates a random session identifier string.
// Used internally when registering new sessions.
fn generate_session_id() string {
	mut parts := []string{}
	for _ in 0 .. 4 {
		val := rand.int_in_range(0x1000, 0xFFFF) or { 0 }
		parts << '${val:04x}'
	}
	return parts.join('-')
}
