// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_xmpp -- XMPP protocol types and server for the V-Ecosystem.
// Implements stanza handling, presence management, and JID parsing
// per RFC 6120/6121. Network I/O is stubbed with TODO markers; all
// type definitions and logic are real.
module v_xmpp

// StanzaType represents the three core XMPP stanza kinds.
pub enum StanzaType {
	message
	presence
	iq
}

// stanza_type_to_string returns the XML element name for a StanzaType.
pub fn stanza_type_to_string(st StanzaType) string {
	return match st {
		.message { 'message' }
		.presence { 'presence' }
		.iq { 'iq' }
	}
}

// MessageType represents the XMPP message types per RFC 6121 section 5.2.2.
pub enum MessageType {
	chat
	groupchat
	normal
	headline
	error_
}

// message_type_to_string returns the type attribute value for a MessageType.
pub fn message_type_to_string(mt MessageType) string {
	return match mt {
		.chat { 'chat' }
		.groupchat { 'groupchat' }
		.normal { 'normal' }
		.headline { 'headline' }
		.error_ { 'error' }
	}
}

// PresenceType represents the XMPP presence types per RFC 6121 section 4.7.1.
pub enum PresenceType {
	available
	unavailable
	subscribe
	subscribed
	unsubscribe
	probe
}

// presence_type_to_string returns the type attribute value for a PresenceType.
pub fn presence_type_to_string(pt PresenceType) string {
	return match pt {
		.available { 'available' }
		.unavailable { 'unavailable' }
		.subscribe { 'subscribe' }
		.subscribed { 'subscribed' }
		.unsubscribe { 'unsubscribe' }
		.probe { 'probe' }
	}
}

// Jid represents a parsed XMPP JID (Jabber ID) with local, domain,
// and optional resource parts per RFC 7622.
pub struct Jid {
pub:
	// local is the localpart before the '@' (may be empty for bare domain JIDs).
	local string
	// domain is the domainpart.
	domain string
	// resource is the optional resourcepart after '/'.
	resource string
}

// parse_jid parses a JID string into its component parts.
// Format: [local@]domain[/resource]
pub fn parse_jid(jid_str string) !Jid {
	if jid_str.len == 0 {
		return error('empty JID')
	}
	mut local := ''
	mut remainder := jid_str

	// Extract localpart if present
	at_idx := jid_str.index_u8(`@`)
	if at_idx > 0 {
		local = jid_str[..at_idx]
		remainder = jid_str[at_idx + 1..]
	}

	// Extract resource if present
	mut domain := remainder
	mut resource := ''
	slash_idx := remainder.index_u8(`/`)
	if slash_idx >= 0 {
		domain = remainder[..slash_idx]
		resource = remainder[slash_idx + 1..]
	}

	if domain.len == 0 {
		return error('JID must have a domain part')
	}

	return Jid{
		local: local
		domain: domain
		resource: resource
	}
}

// jid_to_string formats a Jid back into its string representation.
pub fn jid_to_string(jid Jid) string {
	mut result := ''
	if jid.local.len > 0 {
		result += '${jid.local}@'
	}
	result += jid.domain
	if jid.resource.len > 0 {
		result += '/${jid.resource}'
	}
	return result
}

// jid_bare returns the bare JID (without resource) as a string.
pub fn jid_bare(jid Jid) string {
	if jid.local.len > 0 {
		return '${jid.local}@${jid.domain}'
	}
	return jid.domain
}

// Stanza represents a single XMPP stanza (message, presence, or IQ).
pub struct Stanza {
pub:
	// stanza_type identifies the kind of stanza.
	stanza_type StanzaType
	// from is the sender JID as a string.
	from string
	// to is the recipient JID as a string.
	to string
	// id is the stanza identifier for tracking.
	id string
	// body is the text content of the stanza.
	body string
}

// format_stanza serialises a Stanza into a simplified XML representation.
pub fn format_stanza(s Stanza) string {
	tag := stanza_type_to_string(s.stanza_type)
	mut result := '<${tag}'
	if s.from.len > 0 {
		result += ' from="${s.from}"'
	}
	if s.to.len > 0 {
		result += ' to="${s.to}"'
	}
	if s.id.len > 0 {
		result += ' id="${s.id}"'
	}
	if s.body.len > 0 {
		result += '><body>${s.body}</body></${tag}>'
	} else {
		result += '/>'
	}
	return result
}

// XmppServer holds the state for an XMPP server instance.
pub struct XmppServer {
pub:
	// port is the TCP port the server listens on (default 5222).
	port int
	// domain is the server's XMPP domain.
	domain string
pub mut:
	// users holds the registered users by bare JID.
	users map[string]PresenceType
	// rooms holds the multi-user chat rooms by name.
	rooms map[string][]string
	// stanzas stores sent stanzas (in-memory for testing).
	stanzas []Stanza
}

// new_server creates a new XmppServer for the given domain.
pub fn new_server(port int, domain string) &XmppServer {
	return &XmppServer{
		port: port
		domain: domain
	}
}

// authenticate registers a user with the server and sets their presence
// to available. Returns an error if the JID is invalid or the user is
// not on this server's domain.
// TODO: Replace with SASL auth backend; currently accepts any credentials.
pub fn (mut s XmppServer) authenticate(jid_str string, password string) ! {
	jid := parse_jid(jid_str)!
	if jid.domain != s.domain {
		return error('JID domain ${jid.domain} does not match server domain ${s.domain}')
	}
	if password.len == 0 {
		return error('password must not be empty')
	}
	bare := jid_bare(jid)
	s.users[bare] = .available
}

// send_stanza processes an outbound stanza, stores it, and returns it.
// TODO: Full network I/O -- route to remote servers via S2S.
pub fn (mut s XmppServer) send_stanza(stanza Stanza) !Stanza {
	if stanza.to.len == 0 {
		return error('stanza must have a recipient')
	}
	s.stanzas << stanza
	return stanza
}

// set_presence updates the presence state for a user.
pub fn (mut s XmppServer) set_presence(jid_str string, presence PresenceType) ! {
	jid := parse_jid(jid_str)!
	bare := jid_bare(jid)
	if bare !in s.users {
		return error('user not registered: ${bare}')
	}
	s.users[bare] = presence
}

// join_room adds a user to a multi-user chat room, creating the room
// if it does not exist.
pub fn (mut s XmppServer) join_room(jid_str string, room_name string) ! {
	jid := parse_jid(jid_str)!
	bare := jid_bare(jid)
	if bare !in s.users {
		return error('user not registered: ${bare}')
	}
	if room_name !in s.rooms {
		s.rooms[room_name] = []string{}
	}
	mut room := &s.rooms[room_name]
	if bare !in room {
		room << bare
	}
}

// leave_room removes a user from a multi-user chat room.
pub fn (mut s XmppServer) leave_room(jid_str string, room_name string) ! {
	jid := parse_jid(jid_str)!
	bare := jid_bare(jid)
	if room_name !in s.rooms {
		return error('no such room: ${room_name}')
	}
	mut room := &s.rooms[room_name]
	idx := room.index(bare)
	if idx < 0 {
		return error('user ${bare} not in room ${room_name}')
	}
	room.delete(idx)
	// Remove empty rooms
	if room.len == 0 {
		s.rooms.delete(room_name)
	}
}
