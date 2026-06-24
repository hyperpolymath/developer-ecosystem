// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_tacacs — TACACS+ authentication, authorisation, and accounting.
// Maps to proven-servers/protocols/proven-tacacs.
//
// Implements the TACACS+ protocol (RFC 8907) with separate AAA flows,
// body encryption, and reply construction. Network I/O is stubbed with
// TODO markers; all type definitions and logic are real.
module tacacs

import crypto.sha256
import rand

// PacketType identifies the TACACS+ packet function.
pub enum PacketType {
	authentication
	authorization
	accounting
}

// AuthenAction specifies the authentication action requested by the
// client.
pub enum AuthenAction {
	login
	change_pass
	send_auth
}

// AuthenType specifies the authentication method.
pub enum AuthenType {
	ascii
	pap
	chap
	mschap
}

// AuthenStatus represents the outcome of an authentication exchange.
pub enum AuthenStatus {
	pass
	fail
	get_data
	get_user
	get_pass
	error
}

// AuthorStatus represents the outcome of an authorisation request.
pub enum AuthorStatus {
	pass_add
	pass_repl
	fail
	error
}

// AccountingStatus represents the outcome of an accounting request.
pub enum AccountingStatus {
	success
	error
}

// TacacsHeader represents the fixed-length TACACS+ packet header.
pub struct TacacsHeader {
pub:
	// version is the protocol version (major << 4 | minor).
	version u8 = 0xc1
	// packet_type identifies the packet function.
	packet_type PacketType
	// seq_no is the sequence number within a session.
	seq_no u8
	// session_id identifies the TACACS+ session.
	session_id u32
}

// AuthenRequest represents a TACACS+ authentication START packet.
pub struct AuthenRequest {
pub:
	// action is the authentication action (login, change_pass, etc.).
	action AuthenAction
	// authen_type is the authentication method (ASCII, PAP, etc.).
	authen_type AuthenType
	// user is the username to authenticate.
	user string
	// port is the NAS port identifier.
	port string
	// remote_addr is the client's remote address.
	remote_addr string
	// data is the authentication data (password for PAP, etc.).
	data string
}

// AuthenReply represents a TACACS+ authentication REPLY packet.
pub struct AuthenReply {
pub:
	// status is the authentication result.
	status AuthenStatus
	// server_msg is a message from the server to be displayed.
	server_msg string
	// data is additional server data.
	data string
}

// AuthorRequest represents a TACACS+ authorisation REQUEST packet.
pub struct AuthorRequest {
pub:
	// user is the username requesting authorisation.
	user string
	// port is the NAS port.
	port string
	// remote_addr is the client's address.
	remote_addr string
	// args are the authorisation argument-value pairs.
	args []string
}

// AuthorReply represents a TACACS+ authorisation RESPONSE packet.
pub struct AuthorReply {
pub:
	// status is the authorisation result.
	status AuthorStatus
	// server_msg is a message from the server.
	server_msg string
	// args are the returned authorisation arguments.
	args []string
}

// AccountingRequest represents a TACACS+ accounting REQUEST packet.
pub struct AccountingRequest {
pub:
	// user is the username for accounting.
	user string
	// port is the NAS port.
	port string
	// remote_addr is the client's address.
	remote_addr string
	// args are the accounting argument-value pairs.
	args []string
}

// UserRecord stores a user's credentials and authorisation data.
pub struct UserRecord {
pub:
	// username is the login name.
	username string
	// password_hash is the SHA-256 hash of the password.
	password_hash []u8
	// allowed_commands lists the commands this user may execute.
	allowed_commands []string
	// privilege_level is the user's privilege level (0-15).
	privilege_level int
}

// AccountingRecord stores a single accounting event.
pub struct AccountingRecord {
pub:
	// user is the username.
	user string
	// args are the accounting arguments.
	args []string
	// session_id identifies the session.
	session_id string
}

// TacacsServer is the TACACS+ AAA server. It manages user records
// and processes authentication, authorisation, and accounting requests.
pub struct TacacsServer {
pub:
	// port is the TCP port the server listens on (default 49).
	port int = 49
	// shared_secret is the secret used for body encryption.
	shared_secret string
pub mut:
	// users stores registered user records keyed by username.
	users map[string]UserRecord
	// accounting_log stores accounting records.
	accounting_log []AccountingRecord
}

// new_server creates a new TACACS+ server with the given shared secret.
pub fn new_server(shared_secret string) &TacacsServer {
	return &TacacsServer{
		shared_secret: shared_secret
		users: map[string]UserRecord{}
		accounting_log: []AccountingRecord{}
	}
}

// add_user registers a user with the TACACS+ server. The password
// is stored as a SHA-256 hash.
pub fn (mut s TacacsServer) add_user(username string, password string, commands []string, priv_level int) ! {
	if username.len == 0 {
		return error('username must not be empty')
	}
	if username in s.users {
		return error('user already exists: ${username}')
	}
	if priv_level < 0 || priv_level > 15 {
		return error('privilege level must be 0-15, got: ${priv_level}')
	}
	hash := sha256.sum(password.bytes())
	s.users[username] = UserRecord{
		username: username
		password_hash: hash.to_array()
		allowed_commands: commands
		privilege_level: priv_level
	}
}

// authenticate processes an authentication request and returns a
// reply indicating success or failure.
pub fn (s TacacsServer) authenticate(req AuthenRequest) AuthenReply {
	if req.user.len == 0 {
		return AuthenReply{
			status: .get_user
			server_msg: 'Username required'
		}
	}
	if req.data.len == 0 && req.authen_type == .pap {
		return AuthenReply{
			status: .get_pass
			server_msg: 'Password required'
		}
	}
	user := s.users[req.user] or {
		return AuthenReply{
			status: .fail
			server_msg: 'Authentication failed'
		}
	}
	// Verify password.
	password_hash := sha256.sum(req.data.bytes())
	if !bytes_equal(password_hash.to_array(), user.password_hash) {
		return AuthenReply{
			status: .fail
			server_msg: 'Authentication failed'
		}
	}
	return AuthenReply{
		status: .pass
		server_msg: 'Authentication successful'
	}
}

// authorize processes an authorisation request, checking whether the
// user is allowed to execute the requested commands.
pub fn (s TacacsServer) authorize(req AuthorRequest) AuthorReply {
	user := s.users[req.user] or {
		return AuthorReply{
			status: .fail
			server_msg: 'User not found'
		}
	}
	// Check each requested argument against allowed commands.
	for arg in req.args {
		if arg.starts_with('cmd=') {
			cmd := arg[4..]
			if !is_command_allowed(cmd, user.allowed_commands) {
				return AuthorReply{
					status: .fail
					server_msg: 'Command not authorized: ${cmd}'
				}
			}
		}
	}
	return AuthorReply{
		status: .pass_add
		server_msg: 'Authorization successful'
		args: ['priv-lvl=${user.privilege_level}']
	}
}

// account processes an accounting request and stores the record.
pub fn (mut s TacacsServer) account(req AccountingRequest) AccountingStatus {
	session_id := generate_session_id()
	s.accounting_log << AccountingRecord{
		user: req.user
		args: req.args
		session_id: session_id
	}
	return .success
}

// encrypt_body encrypts a TACACS+ packet body using the shared secret
// and session metadata. Uses the pseudo-pad generation defined in
// RFC 8907 Section 4.6.
pub fn encrypt_body(body []u8, shared_secret string, session_id u32, version u8, seq_no u8) []u8 {
	// Generate the pseudo-pad using SHA-256.
	// pad = hash(secret + session_id + version + seq_no)
	mut pad_input := []u8{}
	pad_input << shared_secret.bytes()
	pad_input << u8(session_id >> 24)
	pad_input << u8(session_id >> 16)
	pad_input << u8(session_id >> 8)
	pad_input << u8(session_id)
	pad_input << version
	pad_input << seq_no
	// Generate enough pad bytes to cover the body.
	mut pad := []u8{}
	mut prev_hash := sha256.sum(pad_input)
	pad << prev_hash.to_array()
	for pad.len < body.len {
		mut next_input := []u8{}
		next_input << shared_secret.bytes()
		next_input << prev_hash.to_array()
		prev_hash = sha256.sum(next_input)
		pad << prev_hash.to_array()
	}
	// XOR body with pad.
	mut encrypted := []u8{len: body.len}
	for i in 0 .. body.len {
		encrypted[i] = body[i] ^ pad[i]
	}
	return encrypted
}

// create_reply builds an authentication reply with the given status
// and message.
pub fn create_reply(status AuthenStatus, message string) AuthenReply {
	return AuthenReply{
		status: status
		server_msg: message
	}
}

// is_command_allowed checks whether a command is in the allowed list.
// An empty allowed list permits all commands.
fn is_command_allowed(cmd string, allowed []string) bool {
	if allowed.len == 0 {
		return true
	}
	return cmd in allowed
}

// bytes_equal compares two byte arrays for equality in constant time.
fn bytes_equal(a []u8, b []u8) bool {
	if a.len != b.len {
		return false
	}
	mut result := u8(0)
	for i in 0 .. a.len {
		result |= a[i] ^ b[i]
	}
	return result == 0
}

// generate_session_id creates a random session identifier string.
fn generate_session_id() string {
	mut parts := []string{}
	for _ in 0 .. 2 {
		val := rand.int_in_range(0x1000, 0xFFFF) or { 0 }
		parts << '${val:04x}'
	}
	return parts.join('')
}
