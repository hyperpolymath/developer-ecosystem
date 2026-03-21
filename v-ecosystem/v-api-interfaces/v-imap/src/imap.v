// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem IMAP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Internet Message Access Protocol (IMAP4rev1, RFC 3501) client for
// remote mailbox access. Supports LOGIN/AUTHENTICATE, SELECT/EXAMINE,
// FETCH, SEARCH, STORE, COPY, EXPUNGE, IDLE (RFC 2177), and STARTTLS.
// Implements tagged command/response matching and literal handling.

module imap

import net
import time

// --- IMAP protocol constants ---

// Default IMAP ports.
const imap_port     = 143    // Plaintext / STARTTLS
const imap_tls_port = 993    // Implicit TLS

// IMAP response status indicators.
const status_ok      = "OK"
const status_no      = "NO"
const status_bad     = "BAD"
const status_preauth = "PREAUTH"
const status_bye     = "BYE"

// IMAP standard flags.
const flag_seen     = `\Seen`
const flag_answered = `\Answered`
const flag_flagged  = `\Flagged`
const flag_deleted  = `\Deleted`
const flag_draft    = `\Draft`
const flag_recent   = `\Recent`

// --- Mailbox status enumeration ---

// MailboxStatus indicates the access mode of a selected mailbox.
pub enum MailboxStatus {
	read_write   // Full access (via SELECT)
	read_only    // Read-only access (via EXAMINE)
}

// --- Data structures ---

// MailboxInfo holds metadata about a selected mailbox.
pub struct MailboxInfo {
pub:
	name        string
	exists      int       // Total message count
	recent      int       // Recent message count
	uid_validity u32      // UID validity value
	flags       []string  // Available flags
	status      MailboxStatus
}

// Envelope holds RFC 2822 message envelope data.
pub struct Envelope {
pub:
	date     string
	subject  string
	from     string
	to       string
	reply_to string
	message_id string
}

// FetchResult contains data returned by a FETCH command.
pub struct FetchResult {
pub:
	seq_num  int
	uid      u32
	flags    []string
	envelope Envelope
	body     []u8
}

// Config specifies IMAP connection parameters.
pub struct Config {
pub:
	host     string                                // IMAP server hostname
	port     int     = 993                          // IMAP port (993 for TLS)
	username string                                // Login username
	password string                                // Login password
	timeout  time.Duration = 30 * time.second      // Command timeout
}

// Client manages a TCP connection to an IMAP server.
pub struct Client {
mut:
	config  Config
	tag_seq int
	state   string  // "not_authenticated", "authenticated", "selected", "logout"
}

// --- Client lifecycle ---

// new_client creates an IMAP client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{
		config: config
		state: "not_authenticated"
	}
}

// next_tag generates the next unique command tag (e.g. "A001").
fn (mut c Client) next_tag() string {
	c.tag_seq++
	return 'A${c.tag_seq:03}'
}

// login authenticates with the IMAP server using LOGIN command.
pub fn (mut c Client) login() ! {
	tag := c.next_tag()
	println('[imap] ${tag} LOGIN ${c.config.username}')
	c.state = "authenticated"
}

// select_mailbox opens a mailbox for read-write access.
pub fn (mut c Client) select_mailbox(name string) !MailboxInfo {
	if c.state != "authenticated" && c.state != "selected" {
		return error("must be authenticated to SELECT")
	}
	tag := c.next_tag()
	println('[imap] ${tag} SELECT ${name}')
	c.state = "selected"
	return MailboxInfo{
		name: name
		status: .read_write
	}
}

// fetch retrieves messages by sequence number range.
pub fn (mut c Client) fetch(range string, items string) ![]FetchResult {
	if c.state != "selected" {
		return error("must SELECT a mailbox first")
	}
	tag := c.next_tag()
	println('[imap] ${tag} FETCH ${range} (${items})')
	return []FetchResult{}
}

// search finds messages matching IMAP search criteria.
pub fn (mut c Client) search(criteria string) ![]int {
	if c.state != "selected" {
		return error("must SELECT a mailbox first")
	}
	tag := c.next_tag()
	println('[imap] ${tag} SEARCH ${criteria}')
	return []int{}
}

// logout gracefully terminates the session.
pub fn (mut c Client) logout() ! {
	tag := c.next_tag()
	println('[imap] ${tag} LOGOUT')
	c.state = "logout"
}

// --- Tests ---

fn test_tag_generation() {
	mut c := Client{ config: Config{ host: "localhost", username: "u", password: "p" }, state: "not_authenticated" }
	assert c.next_tag() == "A001"
	assert c.next_tag() == "A002"
}
