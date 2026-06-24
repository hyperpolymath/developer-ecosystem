// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_imap -- IMAP protocol types and server for the V-Ecosystem.
// Implements mailbox management, message fetching, flag manipulation,
// and search per RFC 3501. Network I/O is stubbed with TODO markers;
// all type definitions and logic are real.
module v_imap

import time

// State represents the IMAP connection state machine per RFC 3501 section 3.
pub enum State {
	not_authenticated
	authenticated
	selected
	logout
}

// state_to_string returns a human-readable label for an IMAP State.
pub fn state_to_string(s State) string {
	return match s {
		.not_authenticated { 'Not Authenticated' }
		.authenticated { 'Authenticated' }
		.selected { 'Selected' }
		.logout { 'Logout' }
	}
}

// Command enumerates the IMAP commands supported by this connector.
pub enum Command {
	login
	select_
	examine
	create
	delete
	rename
	list
	fetch
	store
	search
	copy
	expunge
	idle
}

// command_to_string returns the IMAP wire keyword for a Command.
pub fn command_to_string(cmd Command) string {
	return match cmd {
		.login { 'LOGIN' }
		.select_ { 'SELECT' }
		.examine { 'EXAMINE' }
		.create { 'CREATE' }
		.delete { 'DELETE' }
		.rename { 'RENAME' }
		.list { 'LIST' }
		.fetch { 'FETCH' }
		.store { 'STORE' }
		.search { 'SEARCH' }
		.copy { 'COPY' }
		.expunge { 'EXPUNGE' }
		.idle { 'IDLE' }
	}
}

// Flag represents the system flags defined in RFC 3501 section 2.3.2.
pub enum Flag {
	seen
	answered
	flagged
	deleted
	draft
	recent
}

// flag_to_string returns the IMAP flag name (with backslash prefix).
pub fn flag_to_string(f Flag) string {
	return match f {
		.seen { '\\Seen' }
		.answered { '\\Answered' }
		.flagged { '\\Flagged' }
		.deleted { '\\Deleted' }
		.draft { '\\Draft' }
		.recent { '\\Recent' }
	}
}

// Mailbox represents an IMAP mailbox with its status counters.
pub struct Mailbox {
pub:
	// name is the mailbox name (e.g. "INBOX", "Sent").
	name string
pub mut:
	// messages is the total number of messages in the mailbox.
	messages int
	// recent is the number of messages with the \Recent flag.
	recent int
	// unseen is the sequence number of the first unseen message.
	unseen int
	// uid_validity is the UIDVALIDITY value for this mailbox.
	uid_validity u32
	// message_list holds the messages stored in this mailbox.
	message_list []Message
}

// Message represents a single email message within a mailbox.
pub struct Message {
pub:
	// uid is the unique identifier for this message within its mailbox.
	uid u32
	// size is the message size in octets (RFC 822 size).
	size int
	// date is the internal date of the message.
	date time.Time
	// subject is the Subject header value.
	subject string
	// from is the From header value.
	from string
	// to is the To header value.
	to string
pub mut:
	// flags holds the current set of flags on this message.
	flags []Flag
}

// ImapServer holds the state for an IMAP server instance.
pub struct ImapServer {
pub:
	// port is the TCP port the server listens on (default 143).
	port int
pub mut:
	// state is the current connection state.
	state State
	// mailboxes holds the server's mailbox store.
	mailboxes []Mailbox
	// selected_mailbox is the index of the currently selected mailbox,
	// or -1 if none is selected.
	selected_mailbox int = -1
	// authenticated_user is the username of the logged-in user.
	authenticated_user string
}

// new_server creates a new ImapServer with an empty mailbox store.
pub fn new_server(port int) &ImapServer {
	return &ImapServer{
		port: port
		state: .not_authenticated
	}
}

// authenticate verifies credentials against the server. Returns an error
// if authentication fails. On success, transitions to Authenticated state.
// TODO: Replace with pluggable auth backend; currently accepts any non-empty password.
pub fn (mut s ImapServer) authenticate(user string, password string) ! {
	if user.len == 0 {
		return error('username must not be empty')
	}
	if password.len == 0 {
		return error('password must not be empty')
	}
	s.authenticated_user = user
	s.state = .authenticated
}

// select_mailbox selects a mailbox by name, transitioning to Selected state.
// Returns the Mailbox on success or an error if it does not exist.
pub fn (mut s ImapServer) select_mailbox(name string) !&Mailbox {
	if s.state != .authenticated && s.state != .selected {
		return error('must be authenticated to select a mailbox')
	}
	for i, mb in s.mailboxes {
		if mb.name == name {
			s.selected_mailbox = i
			s.state = .selected
			return &s.mailboxes[i]
		}
	}
	return error('mailbox not found: ${name}')
}

// fetch_messages returns the messages in the currently selected mailbox.
// Returns an error if no mailbox is selected.
pub fn (s ImapServer) fetch_messages() ![]Message {
	if s.state != .selected || s.selected_mailbox < 0 {
		return error('no mailbox selected')
	}
	return s.mailboxes[s.selected_mailbox].message_list
}

// search searches the currently selected mailbox for messages matching
// the given criteria string. Returns matching message UIDs.
// Supports simple substring matching on subject and from fields.
pub fn (s ImapServer) search(criteria string) ![]u32 {
	if s.state != .selected || s.selected_mailbox < 0 {
		return error('no mailbox selected')
	}
	mut results := []u32{}
	needle := criteria.to_lower()
	for msg in s.mailboxes[s.selected_mailbox].message_list {
		if msg.subject.to_lower().contains(needle)
			|| msg.from.to_lower().contains(needle) {
			results << msg.uid
		}
	}
	return results
}

// store_flags sets the flags on a message identified by UID in the
// currently selected mailbox. Returns an error if the message is not found.
pub fn (mut s ImapServer) store_flags(uid u32, flags []Flag) ! {
	if s.state != .selected || s.selected_mailbox < 0 {
		return error('no mailbox selected')
	}
	mut mb := &s.mailboxes[s.selected_mailbox]
	for mut msg in mb.message_list {
		if msg.uid == uid {
			msg.flags = flags
			return
		}
	}
	return error('message not found: UID ${uid}')
}

// copy_message copies a message by UID from the currently selected mailbox
// to the destination mailbox. Returns an error if either is not found.
pub fn (mut s ImapServer) copy_message(uid u32, dest_name string) ! {
	if s.state != .selected || s.selected_mailbox < 0 {
		return error('no mailbox selected')
	}
	// Find the source message
	src_mb := s.mailboxes[s.selected_mailbox]
	mut found := ?Message(none)
	for msg in src_mb.message_list {
		if msg.uid == uid {
			found = msg
			break
		}
	}
	src_msg := found or { return error('message not found: UID ${uid}') }

	// Find the destination mailbox
	for i, mb in s.mailboxes {
		if mb.name == dest_name {
			mut dest := &s.mailboxes[i]
			// Assign a new UID in the destination mailbox
			new_uid := u32(dest.message_list.len + 1)
			dest.message_list << Message{
				...src_msg
				uid: new_uid
			}
			dest.messages = dest.message_list.len
			return
		}
	}
	return error('destination mailbox not found: ${dest_name}')
}
