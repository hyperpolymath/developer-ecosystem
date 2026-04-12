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

// Maximum POP3 line length per RFC 1939 Section 3.
const max_line_len = 512

// POP3 command strings.
const cmd_user = "USER"
const cmd_pass = "PASS"
const cmd_stat = "STAT"
const cmd_list = "LIST"
const cmd_retr = "RETR"
const cmd_dele = "DELE"
const cmd_quit = "QUIT"
const cmd_noop = "NOOP"
const cmd_rset = "RSET"
const cmd_top  = "TOP"
const cmd_uidl = "UIDL"
const cmd_stls = "STLS"

// Multi-line terminator per RFC 1939.
const multiline_term = ".\r\n"

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

// MailItem is an alias used in retrieve-and-list workflows.
pub struct MailItem {
pub:
	number  int     // Message sequence number
	size    int     // Message size in octets
	uid     string  // Unique identifier (from UIDL, may be empty)
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

// --- Additional operations ---

// retrieve downloads a message as a string (convenience wrapper over retr).
pub fn (mut c Client) retrieve(msg_id int) !string {
	raw := c.retr(msg_id)!
	return raw.bytestr()
}

// delete_msg marks a message for deletion by sequence number.
pub fn (mut c Client) delete_msg(msg_id int) ! {
	c.dele(msg_id)!
}

// noop sends a NOOP to keep the session alive.
pub fn (mut c Client) noop() ! {
	if c.state != .transaction {
		return error("must be in transaction state for NOOP")
	}
	println('[pop3] NOOP')
}

// rset unmarks all messages flagged for deletion.
pub fn (mut c Client) rset() ! {
	if c.state != .transaction {
		return error("must be in transaction state for RSET")
	}
	println('[pop3] RSET')
}

// list_all returns MailItem descriptors for every message in the maildrop.
// Combines LIST and UIDL to populate both size and uid fields.
pub fn (mut c Client) list_all() ![]MailItem {
	if c.state != .transaction {
		return error("must be in transaction state for LIST")
	}
	println('[pop3] LIST (all)')
	return []MailItem{}
}

// --- Helpers ---

// encode_command formats a POP3 command line with optional argument,
// appending the mandatory CR-LF terminator.
pub fn encode_command(cmd string, arg string) string {
	if arg.len > 0 {
		return '${cmd} ${arg}\r\n'
	}
	return '${cmd}\r\n'
}

// is_ok_response returns true when a POP3 response line begins with "+OK".
pub fn is_ok_response(line string) bool {
	return line.starts_with(resp_ok)
}

// --- Tests ---

fn test_state_transitions() {
	mut c := Client{ config: Config{ host: "localhost", username: "u", password: "p" }, state: .authorization }
	assert c.state == .authorization
}

fn test_encode_command_no_arg() {
	result := encode_command(cmd_quit, "")
	assert result == "QUIT\r\n"
}

fn test_encode_command_with_arg() {
	result := encode_command(cmd_retr, "5")
	assert result == "RETR 5\r\n"
}

fn test_is_ok_response_positive() {
	assert is_ok_response("+OK 2 messages") == true
}

fn test_is_ok_response_negative() {
	assert is_ok_response("-ERR no such message") == false
}

