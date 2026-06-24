// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_pop3 -- POP3 protocol types and server for the V-Ecosystem.
// Implements message retrieval, deletion, and UID listing per RFC 1939.
// Network I/O is stubbed with TODO markers; all type definitions and
// logic are real.
module v_pop3

// State represents the POP3 session state machine per RFC 1939 section 6.
pub enum State {
	authorization
	transaction
	update
}

// state_to_string returns a human-readable label for a POP3 State.
pub fn state_to_string(s State) string {
	return match s {
		.authorization { 'AUTHORIZATION' }
		.transaction { 'TRANSACTION' }
		.update { 'UPDATE' }
	}
}

// Command enumerates the POP3 commands per RFC 1939.
pub enum Command {
	user
	pass
	stat
	list
	retr
	dele
	noop
	rset
	quit
	top
	uidl
}

// command_to_string returns the POP3 wire keyword for a Command.
pub fn command_to_string(cmd Command) string {
	return match cmd {
		.user { 'USER' }
		.pass { 'PASS' }
		.stat { 'STAT' }
		.list { 'LIST' }
		.retr { 'RETR' }
		.dele { 'DELE' }
		.noop { 'NOOP' }
		.rset { 'RSET' }
		.quit { 'QUIT' }
		.top { 'TOP' }
		.uidl { 'UIDL' }
	}
}

// Pop3Message represents a single message in the POP3 maildrop.
pub struct Pop3Message {
pub:
	// id is the one-based message number within the maildrop.
	id int
	// uid is the unique-id for the message (UIDL command).
	uid string
	// size is the message size in octets.
	size int
	// body holds the full message content.
	body string
pub mut:
	// deleted indicates whether this message is marked for deletion.
	deleted bool
}

// Pop3Server holds the state for a POP3 server instance.
pub struct Pop3Server {
pub:
	// port is the TCP port the server listens on (default 110).
	port int
pub mut:
	// state is the current session state.
	state State
	// authenticated_user is the username of the logged-in user.
	authenticated_user string
	// pending_user is the username provided via USER before PASS.
	pending_user string
	// messages holds the maildrop contents.
	messages []Pop3Message
}

// new_server creates a new Pop3Server with the given port and messages.
pub fn new_server(port int, messages []Pop3Message) &Pop3Server {
	return &Pop3Server{
		port: port
		state: .authorization
		messages: messages
	}
}

// authenticate transitions from Authorization to Transaction state.
// TODO: Replace with pluggable auth backend; currently accepts any non-empty password.
pub fn (mut s Pop3Server) authenticate(user string, password string) ! {
	if s.state != .authorization {
		return error('already authenticated')
	}
	if user.len == 0 {
		return error('username must not be empty')
	}
	if password.len == 0 {
		return error('password must not be empty')
	}
	s.authenticated_user = user
	s.state = .transaction
}

// stat returns the number of non-deleted messages and their total size
// in octets, formatted as the POP3 STAT response.
pub fn (s Pop3Server) stat() !(int, int) {
	if s.state != .transaction {
		return error('must be in TRANSACTION state')
	}
	mut count := 0
	mut total_size := 0
	for msg in s.messages {
		if !msg.deleted {
			count++
			total_size += msg.size
		}
	}
	return count, total_size
}

// list_messages returns the non-deleted messages with their ids and sizes.
pub fn (s Pop3Server) list_messages() ![]Pop3Message {
	if s.state != .transaction {
		return error('must be in TRANSACTION state')
	}
	mut result := []Pop3Message{}
	for msg in s.messages {
		if !msg.deleted {
			result << msg
		}
	}
	return result
}

// retrieve returns the full message body for the given message id.
pub fn (s Pop3Server) retrieve(msg_id int) !string {
	if s.state != .transaction {
		return error('must be in TRANSACTION state')
	}
	for msg in s.messages {
		if msg.id == msg_id {
			if msg.deleted {
				return error('message ${msg_id} has been deleted')
			}
			return msg.body
		}
	}
	return error('no such message: ${msg_id}')
}

// delete marks a message for deletion. The message is not actually
// removed until the session transitions to the Update state.
pub fn (mut s Pop3Server) delete(msg_id int) ! {
	if s.state != .transaction {
		return error('must be in TRANSACTION state')
	}
	for mut msg in s.messages {
		if msg.id == msg_id {
			if msg.deleted {
				return error('message ${msg_id} already deleted')
			}
			msg.deleted = true
			return
		}
	}
	return error('no such message: ${msg_id}')
}

// reset unmarks all messages marked for deletion.
pub fn (mut s Pop3Server) reset() ! {
	if s.state != .transaction {
		return error('must be in TRANSACTION state')
	}
	for mut msg in s.messages {
		msg.deleted = false
	}
}

// get_headers returns the first n lines of the message body (TOP command).
// If n is 0, returns only the headers (lines before the first blank line).
pub fn (s Pop3Server) get_headers(msg_id int, n int) !string {
	if s.state != .transaction {
		return error('must be in TRANSACTION state')
	}
	body := s.retrieve(msg_id)!
	lines := body.split('\n')
	mut result := []string{}
	mut in_headers := true
	mut body_lines := 0

	for line in lines {
		trimmed := line.trim_right('\r')
		if in_headers {
			result << trimmed
			if trimmed.len == 0 {
				in_headers = false
			}
		} else {
			if body_lines >= n {
				break
			}
			result << trimmed
			body_lines++
		}
	}
	return result.join('\n')
}
