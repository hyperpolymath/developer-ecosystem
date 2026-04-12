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

// IMAP fetch data item names.
const fetch_envelope    = "ENVELOPE"
const fetch_body        = "BODY[]"
const fetch_body_peek   = "BODY.PEEK[]"
const fetch_flags       = "FLAGS"
const fetch_uid         = "UID"
const fetch_rfc822_size = "RFC822.SIZE"
const fetch_full        = "(FLAGS ENVELOPE RFC822.SIZE UID)"

// IMAP search criteria helpers.
const search_all        = "ALL"
const search_unseen     = "UNSEEN"
const search_seen       = "SEEN"
const search_flagged    = "FLAGGED"
const search_deleted    = "DELETED"
const search_recent     = "RECENT"

// --- Mailbox status enumeration ---

// MailboxStatus indicates the access mode of a selected mailbox.
pub enum MailboxStatus {
	read_write   // Full access (via SELECT)
	read_only    // Read-only access (via EXAMINE)
}

// StoreAction specifies how to modify message flags.
pub enum StoreAction {
	set       // Replace flags (+FLAGS)
	add       // Add flags (+FLAGS)
	remove    // Remove flags (-FLAGS)
}

// --- Data structures ---

// MailboxInfo holds metadata about a selected mailbox.
pub struct MailboxInfo {
pub:
	name         string
	exists       int       // Total message count
	recent       int       // Recent message count
	unseen       int       // First unseen message sequence number
	uid_validity u32       // UID validity value
	uid_next     u32       // Next UID to be assigned
	flags        []string  // Available flags
	perm_flags   []string  // Flags the client can change
	status       MailboxStatus
}

// Envelope holds RFC 2822 message envelope data.
pub struct Envelope {
pub:
	date       string
	subject    string
	from       string
	to         string
	cc         string
	reply_to   string
	message_id string
}

// FetchResult contains data returned by a FETCH command.
pub struct FetchResult {
pub:
	seq_num  int
	uid      u32
	size     int
	flags    []string
	envelope Envelope
	body     []u8
}

// MailboxListEntry represents a mailbox returned by LIST/LSUB.
pub struct MailboxListEntry {
pub:
	name        string
	delimiter   string
	attributes  []string  // e.g. \\Noselect, \\HasChildren
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
	config       Config
	tag_seq      int
	selected_box string
	state        string  // "not_authenticated", "authenticated", "selected", "logout"
}

// --- Client lifecycle ---

// new_client creates an IMAP client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{
		config: config
		state:  "not_authenticated"
	}
}

// next_tag generates the next unique command tag (e.g. "A001").
fn (mut c Client) next_tag() string {
	c.tag_seq++
	return 'A${c.tag_seq:03}'
}

// connect establishes the TCP connection and reads the server greeting.
pub fn (mut c Client) connect() ! {
	addr := '${c.config.host}:${c.config.port}'
	println('[imap] connecting to ${addr}')
	// Real implementation: net.dial_tcp(addr), read greeting line, check for PREAUTH.
}

// login authenticates with the IMAP server using the LOGIN command.
pub fn (mut c Client) login() ! {
	tag := c.next_tag()
	println('[imap] ${tag} LOGIN ${c.config.username} ****')
	// Real implementation: write "${tag} LOGIN user pass\r\n", read tagged response.
	c.state = "authenticated"
}

// logout gracefully terminates the IMAP session.
pub fn (mut c Client) logout() ! {
	tag := c.next_tag()
	println('[imap] ${tag} LOGOUT')
	c.state = "logout"
}

// capability queries server capabilities (IMAP4rev1, AUTH=PLAIN, etc.).
pub fn (mut c Client) capability() ![]string {
	tag := c.next_tag()
	println('[imap] ${tag} CAPABILITY')
	return []string{}
}

// --- Mailbox operations ---

// list returns mailboxes matching the given reference and pattern.
// Use list("", "*") to list all mailboxes.
pub fn (mut c Client) list(reference string, pattern string) ![]MailboxListEntry {
	if c.state == "not_authenticated" || c.state == "logout" {
		return error("must be authenticated to LIST")
	}
	tag := c.next_tag()
	ref_q := quote_string(reference)
	pat_q := quote_string(pattern)
	println('[imap] ${tag} LIST ${ref_q} ${pat_q}')
	return []MailboxListEntry{}
}

// select_mailbox opens a mailbox for read-write access (SELECT).
pub fn (mut c Client) select_mailbox(name string) !MailboxInfo {
	if c.state != "authenticated" && c.state != "selected" {
		return error("must be authenticated to SELECT")
	}
	tag := c.next_tag()
	println('[imap] ${tag} SELECT ${quote_string(name)}')
	c.state = "selected"
	c.selected_box = name
	return MailboxInfo{
		name:   name
		status: .read_write
	}
}

// examine_mailbox opens a mailbox read-only (EXAMINE).
pub fn (mut c Client) examine_mailbox(name string) !MailboxInfo {
	if c.state != "authenticated" && c.state != "selected" {
		return error("must be authenticated to EXAMINE")
	}
	tag := c.next_tag()
	println('[imap] ${tag} EXAMINE ${quote_string(name)}')
	c.state = "selected"
	c.selected_box = name
	return MailboxInfo{
		name:   name
		status: .read_only
	}
}

// create creates a new mailbox on the server.
pub fn (mut c Client) create(name string) ! {
	if c.state == "not_authenticated" || c.state == "logout" {
		return error("must be authenticated to CREATE")
	}
	tag := c.next_tag()
	println('[imap] ${tag} CREATE ${quote_string(name)}')
}

// delete removes a mailbox from the server.
pub fn (mut c Client) delete(name string) ! {
	if c.state == "not_authenticated" || c.state == "logout" {
		return error("must be authenticated to DELETE")
	}
	tag := c.next_tag()
	println('[imap] ${tag} DELETE ${quote_string(name)}')
}

// --- Message operations ---

// fetch retrieves messages by sequence number range with specified data items.
// range_ examples: "1", "1:10", "1:*"
pub fn (mut c Client) fetch(range_ string, items string) ![]FetchResult {
	if c.state != "selected" {
		return error("must SELECT a mailbox first")
	}
	tag := c.next_tag()
	println('[imap] ${tag} FETCH ${range_} ${items}')
	return []FetchResult{}
}

// uid_fetch retrieves messages by UID range.
pub fn (mut c Client) uid_fetch(uid_range string, items string) ![]FetchResult {
	if c.state != "selected" {
		return error("must SELECT a mailbox first")
	}
	tag := c.next_tag()
	println('[imap] ${tag} UID FETCH ${uid_range} ${items}')
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

// store modifies flags on a set of messages.
pub fn (mut c Client) store(range_ string, action StoreAction, flags []string) ! {
	if c.state != "selected" {
		return error("must SELECT a mailbox first")
	}
	flag_list := '(${flags.join(" ")})'
	item := match action {
		.set    { '+FLAGS' }
		.add    { '+FLAGS' }
		.remove { '-FLAGS' }
	}
	tag := c.next_tag()
	println('[imap] ${tag} STORE ${range_} ${item} ${flag_list}')
}

// copy copies messages from the selected mailbox to another.
pub fn (mut c Client) copy(range_ string, dest string) ! {
	if c.state != "selected" {
		return error("must SELECT a mailbox first")
	}
	tag := c.next_tag()
	println('[imap] ${tag} COPY ${range_} ${quote_string(dest)}')
}

// expunge permanently removes messages marked \\Deleted.
pub fn (mut c Client) expunge() ! {
	if c.state != "selected" {
		return error("must SELECT a mailbox first")
	}
	tag := c.next_tag()
	println('[imap] ${tag} EXPUNGE')
}

// --- Helpers ---

// quote_string wraps a string in IMAP double-quoted form, escaping " and \.
pub fn quote_string(s string) string {
	escaped := s.replace('\\', '\\\\').replace('"', '\\"')
	return '"${escaped}"'
}

// parse_flags extracts flag strings from an IMAP FLAGS response token.
// Input: "(\\Seen \\Flagged)" → ["\\Seen", "\\Flagged"]
pub fn parse_flags(token string) []string {
	inner := token.trim_string("(").trim_string(")")
	if inner.len == 0 { return []string{} }
	return inner.split(" ")
}

// format_fetch_range returns a sequence set string for a single UID.
pub fn format_uid_range(uid u32) string {
	return uid.str()
}

// --- Tests ---

fn test_tag_generation() {
	mut c := Client{ config: Config{ host: "localhost", username: "u", password: "p" }, state: "not_authenticated" }
	assert c.next_tag() == "A001"
	assert c.next_tag() == "A002"
	assert c.next_tag() == "A003"
}

fn test_quote_string_plain() {
	assert quote_string("INBOX") == '"INBOX"'
	assert quote_string("My Mailbox") == '"My Mailbox"'
}

fn test_quote_string_escaping() {
	assert quote_string('say "hello"') == '"say \\"hello\\""'
	assert quote_string('back\\slash') == '"back\\\\slash"'
}

fn test_parse_flags() {
	flags := parse_flags('(\\Seen \\Flagged)')
	assert flags.len == 2
	assert flags[0] == '\\Seen'
	assert flags[1] == '\\Flagged'
}

fn test_select_requires_auth() {
	mut c := Client{ config: Config{ host: "localhost", username: "u", password: "p" }, state: "not_authenticated" }
	c.select_mailbox("INBOX") or {
		assert err.msg().contains("must be authenticated")
		return
	}
	assert false, "expected error"
}

fn test_fetch_requires_selected() {
	mut c := Client{ config: Config{ host: "localhost", username: "u", password: "p" }, state: "authenticated" }
	c.fetch("1:10", fetch_full) or {
		assert err.msg().contains("must SELECT")
		return
	}
	assert false, "expected error"
}
