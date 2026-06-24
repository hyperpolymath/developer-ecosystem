// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// chat_test -- Protocol conformance tests for v_chat.
// Covers room management, message sending, editing, deletion,
// history retrieval, presence, and member listing.
module v_chat

// test_message_type_to_string verifies labels for all message types.
fn test_message_type_to_string() {
	assert message_type_to_string(.text) == 'text'
	assert message_type_to_string(.image) == 'image'
	assert message_type_to_string(.file) == 'file'
	assert message_type_to_string(.system) == 'system'
	assert message_type_to_string(.typing) == 'typing'
	assert message_type_to_string(.read) == 'read'
}

// test_create_room verifies room creation with creator as member.
fn test_create_room() {
	mut server := new_server(8080)
	room := server.create_room('General', false, 'alice')
	assert room.name == 'General'
	assert room.is_private == false
	assert room.members.len == 1
	assert room.members[0] == 'alice'
	assert room.id in server.rooms
}

// test_join_room verifies adding a user to a room.
fn test_join_room() {
	mut server := new_server(8080)
	room := server.create_room('General', false, 'alice')
	server.join_room(room.id, 'bob')!
	members := server.get_members(room.id)!
	assert members.len == 2
	assert 'bob' in members
}

// test_join_room_not_found verifies error for missing room.
fn test_join_room_not_found() {
	mut server := new_server(8080)
	server.join_room('nonexistent', 'alice') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing room'
}

// test_leave_room verifies user removal from a room.
fn test_leave_room() {
	mut server := new_server(8080)
	room := server.create_room('General', false, 'alice')
	server.join_room(room.id, 'bob')!
	server.leave_room(room.id, 'bob')!
	members := server.get_members(room.id)!
	assert 'bob' !in members
}

// test_send_message verifies message creation and storage.
fn test_send_message() {
	mut server := new_server(8080)
	room := server.create_room('General', false, 'alice')
	msg := server.send_message(room.id, 'alice', .text, 'Hello!')!
	assert msg.sender == 'alice'
	assert msg.content == 'Hello!'
	assert msg.message_type == .text
	assert msg.edited == false
}

// test_send_message_not_member verifies error for non-member sender.
fn test_send_message_not_member() {
	mut server := new_server(8080)
	room := server.create_room('General', false, 'alice')
	server.send_message(room.id, 'stranger', .text, 'Hi') or {
		assert err.msg().contains('not a member')
		return
	}
	assert false, 'expected error for non-member sender'
}

// test_edit_message verifies message content editing.
fn test_edit_message() {
	mut server := new_server(8080)
	room := server.create_room('General', false, 'alice')
	msg := server.send_message(room.id, 'alice', .text, 'Helo')!
	server.edit_message(room.id, msg.id, 'alice', 'Hello')!
	history := server.get_history(room.id, 0)!
	assert history[0].content == 'Hello'
	assert history[0].edited == true
}

// test_edit_message_wrong_sender verifies only original sender can edit.
fn test_edit_message_wrong_sender() {
	mut server := new_server(8080)
	room := server.create_room('General', false, 'alice')
	server.join_room(room.id, 'bob')!
	msg := server.send_message(room.id, 'alice', .text, 'Hello')!
	server.edit_message(room.id, msg.id, 'bob', 'Changed') or {
		assert err.msg().contains('original sender')
		return
	}
	assert false, 'expected error for wrong sender'
}

// test_delete_message verifies message removal.
fn test_delete_message() {
	mut server := new_server(8080)
	room := server.create_room('General', false, 'alice')
	msg := server.send_message(room.id, 'alice', .text, 'Delete me')!
	server.delete_message(room.id, msg.id, 'alice')!
	history := server.get_history(room.id, 0)!
	assert history.len == 0
}

// test_get_history_with_limit verifies limited history retrieval.
fn test_get_history_with_limit() {
	mut server := new_server(8080)
	room := server.create_room('General', false, 'alice')
	for i in 0 .. 5 {
		_ := server.send_message(room.id, 'alice', .text, 'Message ${i}')!
	}
	history := server.get_history(room.id, 2)!
	assert history.len == 2
	// Should be the last 2 messages
	assert history[0].content == 'Message 3'
	assert history[1].content == 'Message 4'
}

// test_set_presence verifies presence state update.
fn test_set_presence() {
	mut server := new_server(8080)
	server.set_presence('alice', 'online')
	assert 'alice' in server.presences
	assert server.presences['alice'].status == 'online'

	server.set_presence('alice', 'away')
	assert server.presences['alice'].status == 'away'
}

// test_get_members verifies member listing.
fn test_get_members() {
	mut server := new_server(8080)
	room := server.create_room('Private', true, 'alice')
	server.join_room(room.id, 'bob')!
	server.join_room(room.id, 'charlie')!
	members := server.get_members(room.id)!
	assert members.len == 3
	assert 'alice' in members
	assert 'bob' in members
	assert 'charlie' in members
}
