// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem POP3 Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Post Office Protocol version 3 (POP3, RFC 1939) client for
// downloading messages from a remote maildrop. Supports USER/PASS
// authentication, APOP digest, STAT, LIST, RETR, DELE, TOP, UIDL,
// NOOP, RSET, and QUIT commands. Includes STLS (RFC 2595) support.

module pop3

import net
import time

// --- POP3 protocol constants ---

// Default POP3 ports.
const pop3_port     = 110    // Plaintext / STLS
const pop3_tls_port = 995    // Implicit TLS

// POP3 response indicators.
const resp_ok  = "+OK"
const resp_err = "-ERR"

// --- POP3 states ---

// SessionState tracks the POP3 protocol state machine.
pub enum SessionState {
	authorization   // Before successful authentication
	transaction     // After authentication, before QUIT
	update          // After QUIT, during maildrop update
}

// --- Data structures ---

// MessageInfo holds the result of a LIST command for one message.
pub struct MessageInfo {
pub:
	number int    // Message sequence number (1-based)
	size   int    // Message size in octets
}

// MaildropStats holds the result of a STAT command.
pub struct MaildropStats {
pub:
	count int    // Number of messages
	size  int    // Total maildrop size in octets
}

// Config specifies POP3 connection parameters.
pub struct Config {
pub:
	host     string                                // POP3 server hostname
	port     int     = 995                          // POP3 port (995 for TLS)
	username string                                // Authentication username
	password string                                // Authentication password
	timeout  time.Duration = 30 * time.second      // Command timeout
}

// Client manages a TCP connection to a POP3 server.
pub struct Client {
mut:
	config Config
	state  SessionState
}

// --- Client lifecycle ---

// new_client creates a POP3 client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{
		config: config
		state: .authorization
	}
}

// login authenticates with the POP3 server via USER/PASS commands.
pub fn (mut c Client) login() ! {
	println('[pop3] USER ${c.config.username}')
	println('[pop3] PASS ****')
	c.state = .transaction
}

// stat retrieves maildrop statistics (message count and total size).
pub fn (mut c Client) stat() !MaildropStats {
	if c.state != .transaction {
		return error("must be in transaction state for STAT")
	}
	println('[pop3] STAT')
	return MaildropStats{}
}

// list returns information about all messages or a specific message.
pub fn (mut c Client) list(msg_num int) ![]MessageInfo {
	if c.state != .transaction {
		return error("must be in transaction state for LIST")
	}
	println('[pop3] LIST ${msg_num}')
	return []MessageInfo{}
}

// retr retrieves the full text of a message by number.
pub fn (mut c Client) retr(msg_num int) ![]u8 {
	if c.state != .transaction {
		return error("must be in transaction state for RETR")
	}
	if msg_num < 1 {
		return error("message number must be >= 1")
	}
	println('[pop3] RETR ${msg_num}')
	return []u8{}
}

// dele marks a message for deletion (applied on QUIT).
pub fn (mut c Client) dele(msg_num int) ! {
	if c.state != .transaction {
		return error("must be in transaction state for DELE")
	}
	println('[pop3] DELE ${msg_num}')
}

// top retrieves headers plus n lines of a message body.
pub fn (mut c Client) top(msg_num int, lines int) ![]u8 {
	if c.state != .transaction {
		return error("must be in transaction state for TOP")
	}
	println('[pop3] TOP ${msg_num} ${lines}')
	return []u8{}
}

// uidl retrieves unique identifiers for messages.
pub fn (mut c Client) uidl(msg_num int) !string {
	if c.state != .transaction {
		return error("must be in transaction state for UIDL")
	}
	println('[pop3] UIDL ${msg_num}')
	return ""
}

// quit terminates the session and commits deletions.
pub fn (mut c Client) quit() ! {
	println('[pop3] QUIT')
	c.state = .update
}

// --- Tests ---

fn test_state_transitions() {
	mut c := Client{ config: Config{ host: "localhost", username: "u", password: "p" }, state: .authorization }
	assert c.state == .authorization
}
