// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_chat -- Real-time chat server types for the V-Ecosystem.
// Implements room management, message history, presence tracking,
// and message editing/deletion. Network I/O is stubbed with TODO
// markers; all type definitions and logic are real.
module chat

import time
import rand

// MessageType enumerates the kinds of chat messages supported.
pub enum MessageType {
	text
	image
	file
	system
	typing
	read
}

// message_type_to_string returns a human-readable label for a MessageType.
pub fn message_type_to_string(mt MessageType) string {
	return match mt {
		.text { 'text' }
		.image { 'image' }
		.file { 'file' }
		.system { 'system' }
		.typing { 'typing' }
		.read { 'read' }
	}
}

// Room represents a chat room with its member list and metadata.
pub struct Room {
pub:
	// id is the unique identifier for the room.
	id string
	// name is the human-readable room name.
	name string
	// created_at is the room creation timestamp.
	created_at time.Time
	// is_private indicates whether the room requires an invitation.
	is_private bool
pub mut:
	// members lists the user IDs of room members.
	members []string
}

// ChatMessage represents a single message in a chat room.
pub struct ChatMessage {
pub:
	// id is the unique message identifier.
	id string
	// room_id identifies the room this message belongs to.
	room_id string
	// sender is the user ID of the message author.
	sender string
	// message_type identifies the kind of message.
	message_type MessageType
	// timestamp is when the message was sent.
	timestamp time.Time
pub mut:
	// content is the message body text or file URL.
	content string
	// edited indicates whether the message has been modified.
	edited bool
}

// Presence represents a user's online status.
pub struct Presence {
pub:
	// user_id identifies the user.
	user_id string
pub mut:
	// status is the current status text (e.g. "online", "away", "busy").
	status string
	// last_seen is the timestamp of the user's last activity.
	last_seen time.Time
}

// ChatServer holds the state for a real-time chat server.
pub struct ChatServer {
pub:
	// port is the port the server listens on.
	port int
pub mut:
	// rooms holds all chat rooms by ID.
	rooms map[string]Room
	// messages holds all messages grouped by room ID.
	messages map[string][]ChatMessage
	// presences holds user presence state by user ID.
	presences map[string]Presence
}

// new_server creates a new ChatServer on the given port.
pub fn new_server(port int) &ChatServer {
	return &ChatServer{
		port: port
	}
}

// generate_id creates a simple unique identifier using random hex bytes.
fn generate_id() string {
	bytes := rand.bytes(8) or { return 'fallback-id' }
	mut hex := ''
	for b in bytes {
		hex += '${b:02x}'
	}
	return hex
}

// create_room creates a new chat room and returns it.
pub fn (mut s ChatServer) create_room(name string, is_private bool, creator string) Room {
	id := generate_id()
	room := Room{
		id: id
		name: name
		created_at: time.now()
		is_private: is_private
		members: [creator]
	}
	s.rooms[id] = room
	s.messages[id] = []ChatMessage{}
	return room
}

// join_room adds a user to an existing room. Returns an error if the
// room does not exist.
pub fn (mut s ChatServer) join_room(room_id string, user_id string) ! {
	if room_id !in s.rooms {
		return error('room not found: ${room_id}')
	}
	mut room := &s.rooms[room_id]
	if user_id !in room.members {
		room.members << user_id
	}
}

// leave_room removes a user from a room. Returns an error if the room
// does not exist or the user is not a member.
pub fn (mut s ChatServer) leave_room(room_id string, user_id string) ! {
	if room_id !in s.rooms {
		return error('room not found: ${room_id}')
	}
	mut room := &s.rooms[room_id]
	idx := room.members.index(user_id)
	if idx < 0 {
		return error('user ${user_id} not in room ${room_id}')
	}
	room.members.delete(idx)
}

// send_message creates and stores a new message in the given room.
// Returns the created ChatMessage. Returns an error if the room does
// not exist or the sender is not a member.
pub fn (mut s ChatServer) send_message(room_id string, sender string, msg_type MessageType, content string) !ChatMessage {
	if room_id !in s.rooms {
		return error('room not found: ${room_id}')
	}
	room := s.rooms[room_id]
	if sender !in room.members {
		return error('sender ${sender} not a member of room ${room_id}')
	}
	msg := ChatMessage{
		id: generate_id()
		room_id: room_id
		sender: sender
		message_type: msg_type
		content: content
		timestamp: time.now()
	}
	if room_id !in s.messages {
		s.messages[room_id] = []ChatMessage{}
	}
	s.messages[room_id] << msg
	return msg
}

// edit_message modifies the content of an existing message. Only the
// original sender can edit their message.
pub fn (mut s ChatServer) edit_message(room_id string, msg_id string, sender string, new_content string) ! {
	if room_id !in s.messages {
		return error('room not found: ${room_id}')
	}
	mut room_msgs := &s.messages[room_id]
	for mut msg in room_msgs {
		if msg.id == msg_id {
			if msg.sender != sender {
				return error('only the original sender can edit this message')
			}
			msg.content = new_content
			msg.edited = true
			return
		}
	}
	return error('message not found: ${msg_id}')
}

// delete_message removes a message from a room. Only the original sender
// can delete their message.
pub fn (mut s ChatServer) delete_message(room_id string, msg_id string, sender string) ! {
	if room_id !in s.messages {
		return error('room not found: ${room_id}')
	}
	mut room_msgs := &s.messages[room_id]
	for i, msg in room_msgs {
		if msg.id == msg_id {
			if msg.sender != sender {
				return error('only the original sender can delete this message')
			}
			room_msgs.delete(i)
			return
		}
	}
	return error('message not found: ${msg_id}')
}

// get_history returns the message history for a room, optionally limited
// to the most recent n messages. Pass 0 for no limit.
pub fn (s ChatServer) get_history(room_id string, limit int) ![]ChatMessage {
	if room_id !in s.messages {
		return error('room not found: ${room_id}')
	}
	msgs := s.messages[room_id]
	if limit <= 0 || limit >= msgs.len {
		return msgs
	}
	return msgs[msgs.len - limit..]
}

// set_presence updates or creates the presence state for a user.
pub fn (mut s ChatServer) set_presence(user_id string, status string) {
	s.presences[user_id] = Presence{
		user_id: user_id
		status: status
		last_seen: time.now()
	}
}

// get_members returns the list of member user IDs for a room.
pub fn (s ChatServer) get_members(room_id string) ![]string {
	if room_id !in s.rooms {
		return error('room not found: ${room_id}')
	}
	return s.rooms[room_id].members
}
