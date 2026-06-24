// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// pop3_test -- Protocol conformance tests for v_pop3.
// Covers state transitions, authentication, stat, list, retrieve,
// delete, reset, and header extraction.
module v_pop3

// helper_messages returns a sample message list for testing.
fn helper_messages() []Pop3Message {
	return [
		Pop3Message{
			id: 1
			uid: 'msg-001'
			size: 256
			body: 'Subject: Hello\r\nFrom: alice@example.com\r\n\r\nHello World\r\nLine 2\r\nLine 3'
		},
		Pop3Message{
			id: 2
			uid: 'msg-002'
			size: 128
			body: 'Subject: Test\r\nFrom: bob@example.com\r\n\r\nTest body'
		},
	]
}

// test_state_to_string verifies human-readable labels for POP3 states.
fn test_state_to_string() {
	assert state_to_string(.authorization) == 'AUTHORIZATION'
	assert state_to_string(.transaction) == 'TRANSACTION'
	assert state_to_string(.update) == 'UPDATE'
}

// test_command_to_string verifies wire keywords for all POP3 commands.
fn test_command_to_string() {
	assert command_to_string(.user) == 'USER'
	assert command_to_string(.pass) == 'PASS'
	assert command_to_string(.stat) == 'STAT'
	assert command_to_string(.list) == 'LIST'
	assert command_to_string(.retr) == 'RETR'
	assert command_to_string(.dele) == 'DELE'
	assert command_to_string(.noop) == 'NOOP'
	assert command_to_string(.rset) == 'RSET'
	assert command_to_string(.quit) == 'QUIT'
	assert command_to_string(.top) == 'TOP'
	assert command_to_string(.uidl) == 'UIDL'
}

// test_authenticate_success verifies successful authentication.
fn test_authenticate_success() {
	mut server := new_server(110, helper_messages())
	server.authenticate('alice', 'secret')!
	assert server.state == .transaction
	assert server.authenticated_user == 'alice'
}

// test_authenticate_empty verifies rejection of empty credentials.
fn test_authenticate_empty() {
	mut server := new_server(110, helper_messages())
	server.authenticate('', 'pass') or {
		assert err.msg().contains('username')
		return
	}
	assert false, 'expected error for empty username'
}

// test_stat verifies message count and total size.
fn test_stat() {
	mut server := new_server(110, helper_messages())
	server.authenticate('alice', 'secret')!
	count, total := server.stat()!
	assert count == 2
	assert total == 384 // 256 + 128
}

// test_stat_before_auth verifies stat requires transaction state.
fn test_stat_before_auth() {
	server := new_server(110, helper_messages())
	server.stat() or {
		assert err.msg().contains('TRANSACTION')
		return
	}
	assert false, 'expected error for wrong state'
}

// test_list_messages verifies listing non-deleted messages.
fn test_list_messages() {
	mut server := new_server(110, helper_messages())
	server.authenticate('alice', 'secret')!
	msgs := server.list_messages()!
	assert msgs.len == 2
	assert msgs[0].uid == 'msg-001'
}

// test_retrieve verifies message retrieval by ID.
fn test_retrieve() {
	mut server := new_server(110, helper_messages())
	server.authenticate('alice', 'secret')!
	body := server.retrieve(1)!
	assert body.contains('Hello World')
}

// test_retrieve_not_found verifies error for missing message.
fn test_retrieve_not_found() {
	mut server := new_server(110, helper_messages())
	server.authenticate('alice', 'secret')!
	server.retrieve(99) or {
		assert err.msg().contains('no such message')
		return
	}
	assert false, 'expected error for missing message'
}

// test_delete verifies message deletion marking.
fn test_delete() {
	mut server := new_server(110, helper_messages())
	server.authenticate('alice', 'secret')!
	server.delete(1)!
	count, _ := server.stat()!
	assert count == 1
}

// test_delete_already_deleted verifies error for double deletion.
fn test_delete_already_deleted() {
	mut server := new_server(110, helper_messages())
	server.authenticate('alice', 'secret')!
	server.delete(1)!
	server.delete(1) or {
		assert err.msg().contains('already deleted')
		return
	}
	assert false, 'expected error for double delete'
}

// test_retrieve_deleted verifies error for accessing deleted message.
fn test_retrieve_deleted() {
	mut server := new_server(110, helper_messages())
	server.authenticate('alice', 'secret')!
	server.delete(1)!
	server.retrieve(1) or {
		assert err.msg().contains('deleted')
		return
	}
	assert false, 'expected error for deleted message'
}

// test_reset verifies that reset unmarks all deleted messages.
fn test_reset() {
	mut server := new_server(110, helper_messages())
	server.authenticate('alice', 'secret')!
	server.delete(1)!
	server.delete(2)!
	server.reset()!
	count, _ := server.stat()!
	assert count == 2
}

// test_get_headers verifies header extraction with line limit.
fn test_get_headers() {
	mut server := new_server(110, helper_messages())
	server.authenticate('alice', 'secret')!
	headers := server.get_headers(1, 1)!
	assert headers.contains('Subject: Hello')
	assert headers.contains('Hello World')
	// Should only have 1 body line after headers
	lines := headers.split('\n')
	mut body_started := false
	mut body_count := 0
	for line in lines {
		if body_started {
			body_count++
		}
		if line.trim_right('\r').len == 0 && !body_started {
			body_started = true
		}
	}
	assert body_count == 1
}
