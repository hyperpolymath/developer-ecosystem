// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// imap_test -- Protocol conformance tests for v_imap.
// Covers state transitions, authentication, mailbox selection, message
// fetching, search, flag storage, and message copying.
module v_imap

import time

// test_state_to_string verifies human-readable labels for all IMAP states.
fn test_state_to_string() {
	assert state_to_string(.not_authenticated) == 'Not Authenticated'
	assert state_to_string(.authenticated) == 'Authenticated'
	assert state_to_string(.selected) == 'Selected'
	assert state_to_string(.logout) == 'Logout'
}

// test_command_to_string verifies wire keywords for all IMAP commands.
fn test_command_to_string() {
	assert command_to_string(.login) == 'LOGIN'
	assert command_to_string(.select_) == 'SELECT'
	assert command_to_string(.examine) == 'EXAMINE'
	assert command_to_string(.create) == 'CREATE'
	assert command_to_string(.delete) == 'DELETE'
	assert command_to_string(.rename) == 'RENAME'
	assert command_to_string(.list) == 'LIST'
	assert command_to_string(.fetch) == 'FETCH'
	assert command_to_string(.store) == 'STORE'
	assert command_to_string(.search) == 'SEARCH'
	assert command_to_string(.copy) == 'COPY'
	assert command_to_string(.expunge) == 'EXPUNGE'
	assert command_to_string(.idle) == 'IDLE'
}

// test_flag_to_string verifies IMAP flag name formatting.
fn test_flag_to_string() {
	assert flag_to_string(.seen) == '\\Seen'
	assert flag_to_string(.answered) == '\\Answered'
	assert flag_to_string(.flagged) == '\\Flagged'
	assert flag_to_string(.deleted) == '\\Deleted'
	assert flag_to_string(.draft) == '\\Draft'
	assert flag_to_string(.recent) == '\\Recent'
}

// test_authenticate_success verifies successful authentication.
fn test_authenticate_success() {
	mut server := new_server(143)
	server.authenticate('alice', 'secret')!
	assert server.state == .authenticated
	assert server.authenticated_user == 'alice'
}

// test_authenticate_empty_user verifies rejection of empty username.
fn test_authenticate_empty_user() {
	mut server := new_server(143)
	server.authenticate('', 'secret') or {
		assert err.msg().contains('username')
		return
	}
	assert false, 'expected error for empty username'
}

// test_authenticate_empty_password verifies rejection of empty password.
fn test_authenticate_empty_password() {
	mut server := new_server(143)
	server.authenticate('alice', '') or {
		assert err.msg().contains('password')
		return
	}
	assert false, 'expected error for empty password'
}

// helper_server_with_mailbox creates a server with one mailbox and one message.
fn helper_server_with_mailbox() &ImapServer {
	mut server := new_server(143)
	server.authenticate('alice', 'secret') or { panic(err) }
	server.mailboxes << Mailbox{
		name: 'INBOX'
		messages: 1
		uid_validity: 1000
		message_list: [
			Message{
				uid: 1
				size: 512
				date: time.now()
				subject: 'Hello World'
				from: 'bob@example.com'
				to: 'alice@example.com'
				flags: [Flag.recent]
			},
		]
	}
	server.mailboxes << Mailbox{
		name: 'Archive'
		messages: 0
		uid_validity: 1001
	}
	return server
}

// test_select_mailbox verifies selecting an existing mailbox.
fn test_select_mailbox() {
	mut server := helper_server_with_mailbox()
	mb := server.select_mailbox('INBOX')!
	assert mb.name == 'INBOX'
	assert server.state == .selected
}

// test_select_mailbox_not_found verifies error for missing mailbox.
fn test_select_mailbox_not_found() {
	mut server := helper_server_with_mailbox()
	server.select_mailbox('NonExistent') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing mailbox'
}

// test_fetch_messages verifies retrieval from selected mailbox.
fn test_fetch_messages() {
	mut server := helper_server_with_mailbox()
	_ := server.select_mailbox('INBOX')!
	messages := server.fetch_messages()!
	assert messages.len == 1
	assert messages[0].subject == 'Hello World'
}

// test_fetch_messages_no_selection verifies error when no mailbox selected.
fn test_fetch_messages_no_selection() {
	mut server := helper_server_with_mailbox()
	server.fetch_messages() or {
		assert err.msg().contains('no mailbox')
		return
	}
	assert false, 'expected error for no selection'
}

// test_search verifies substring search on subject and from.
fn test_search() {
	mut server := helper_server_with_mailbox()
	_ := server.select_mailbox('INBOX')!
	results := server.search('hello')!
	assert results.len == 1
	assert results[0] == 1
}

// test_search_no_match verifies empty results for unmatched criteria.
fn test_search_no_match() {
	mut server := helper_server_with_mailbox()
	_ := server.select_mailbox('INBOX')!
	results := server.search('nonexistent')!
	assert results.len == 0
}

// test_store_flags verifies flag update on a message.
fn test_store_flags() {
	mut server := helper_server_with_mailbox()
	_ := server.select_mailbox('INBOX')!
	server.store_flags(1, [Flag.seen, Flag.flagged])!
	messages := server.fetch_messages()!
	assert messages[0].flags.len == 2
}

// test_copy_message verifies copying a message to another mailbox.
fn test_copy_message() {
	mut server := helper_server_with_mailbox()
	_ := server.select_mailbox('INBOX')!
	server.copy_message(1, 'Archive')!
	// Verify the message exists in Archive
	assert server.mailboxes[1].message_list.len == 1
	assert server.mailboxes[1].message_list[0].subject == 'Hello World'
}

// test_copy_message_not_found verifies error for missing source message.
fn test_copy_message_not_found() {
	mut server := helper_server_with_mailbox()
	_ := server.select_mailbox('INBOX')!
	server.copy_message(999, 'Archive') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing message'
}
