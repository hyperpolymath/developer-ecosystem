// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// xmpp_test -- Protocol conformance tests for v_xmpp.
// Covers JID parsing, stanza formatting, authentication, presence
// management, and multi-user chat room operations.
module v_xmpp

// test_stanza_type_to_string verifies XML element names for stanza types.
fn test_stanza_type_to_string() {
	assert stanza_type_to_string(.message) == 'message'
	assert stanza_type_to_string(.presence) == 'presence'
	assert stanza_type_to_string(.iq) == 'iq'
}

// test_message_type_to_string verifies type attribute values.
fn test_message_type_to_string() {
	assert message_type_to_string(.chat) == 'chat'
	assert message_type_to_string(.groupchat) == 'groupchat'
	assert message_type_to_string(.normal) == 'normal'
	assert message_type_to_string(.headline) == 'headline'
	assert message_type_to_string(.error_) == 'error'
}

// test_presence_type_to_string verifies presence type attribute values.
fn test_presence_type_to_string() {
	assert presence_type_to_string(.available) == 'available'
	assert presence_type_to_string(.unavailable) == 'unavailable'
	assert presence_type_to_string(.subscribe) == 'subscribe'
	assert presence_type_to_string(.subscribed) == 'subscribed'
	assert presence_type_to_string(.unsubscribe) == 'unsubscribe'
	assert presence_type_to_string(.probe) == 'probe'
}

// test_parse_jid_full verifies parsing a full JID with all three parts.
fn test_parse_jid_full() {
	jid := parse_jid('alice@example.com/desktop')!
	assert jid.local == 'alice'
	assert jid.domain == 'example.com'
	assert jid.resource == 'desktop'
}

// test_parse_jid_bare verifies parsing a bare JID (no resource).
fn test_parse_jid_bare() {
	jid := parse_jid('alice@example.com')!
	assert jid.local == 'alice'
	assert jid.domain == 'example.com'
	assert jid.resource == ''
}

// test_parse_jid_domain_only verifies parsing a domain-only JID.
fn test_parse_jid_domain_only() {
	jid := parse_jid('example.com')!
	assert jid.local == ''
	assert jid.domain == 'example.com'
	assert jid.resource == ''
}

// test_parse_jid_empty verifies rejection of empty JID strings.
fn test_parse_jid_empty() {
	parse_jid('') or {
		assert err.msg().contains('empty')
		return
	}
	assert false, 'expected error for empty JID'
}

// test_jid_to_string verifies JID serialisation for all forms.
fn test_jid_to_string() {
	full := Jid{ local: 'alice', domain: 'example.com', resource: 'mobile' }
	assert jid_to_string(full) == 'alice@example.com/mobile'

	bare := Jid{ local: 'alice', domain: 'example.com' }
	assert jid_to_string(bare) == 'alice@example.com'

	domain := Jid{ domain: 'example.com' }
	assert jid_to_string(domain) == 'example.com'
}

// test_jid_bare verifies bare JID extraction.
fn test_jid_bare() {
	jid := Jid{ local: 'alice', domain: 'example.com', resource: 'laptop' }
	assert jid_bare(jid) == 'alice@example.com'
}

// test_format_stanza_with_body verifies stanza XML with body content.
fn test_format_stanza_with_body() {
	stanza := Stanza{
		stanza_type: .message
		from: 'alice@example.com'
		to: 'bob@example.com'
		id: 'msg-1'
		body: 'Hello!'
	}
	xml := format_stanza(stanza)
	assert xml.contains('<message')
	assert xml.contains('from="alice@example.com"')
	assert xml.contains('to="bob@example.com"')
	assert xml.contains('<body>Hello!</body>')
	assert xml.contains('</message>')
}

// test_format_stanza_empty_body verifies self-closing stanza XML.
fn test_format_stanza_empty_body() {
	stanza := Stanza{
		stanza_type: .presence
		from: 'alice@example.com'
	}
	xml := format_stanza(stanza)
	assert xml.contains('<presence')
	assert xml.ends_with('/>')
}

// test_authenticate verifies user registration with the server.
fn test_authenticate() {
	mut server := new_server(5222, 'example.com')
	server.authenticate('alice@example.com', 'secret')!
	assert 'alice@example.com' in server.users
	assert server.users['alice@example.com'] == .available
}

// test_authenticate_wrong_domain verifies domain mismatch rejection.
fn test_authenticate_wrong_domain() {
	mut server := new_server(5222, 'example.com')
	server.authenticate('alice@other.com', 'secret') or {
		assert err.msg().contains('does not match')
		return
	}
	assert false, 'expected error for domain mismatch'
}

// test_send_stanza verifies stanza storage.
fn test_send_stanza() {
	mut server := new_server(5222, 'example.com')
	server.authenticate('alice@example.com', 'secret')!
	stanza := Stanza{
		stanza_type: .message
		from: 'alice@example.com'
		to: 'bob@example.com'
		body: 'Hi Bob'
	}
	result := server.send_stanza(stanza)!
	assert result.body == 'Hi Bob'
	assert server.stanzas.len == 1
}

// test_set_presence verifies presence updates.
fn test_set_presence() {
	mut server := new_server(5222, 'example.com')
	server.authenticate('alice@example.com', 'secret')!
	server.set_presence('alice@example.com', .unavailable)!
	assert server.users['alice@example.com'] == .unavailable
}

// test_join_room verifies multi-user chat room joining.
fn test_join_room() {
	mut server := new_server(5222, 'example.com')
	server.authenticate('alice@example.com', 'secret')!
	server.join_room('alice@example.com', 'general')!
	assert 'general' in server.rooms
	assert 'alice@example.com' in server.rooms['general']
}

// test_leave_room verifies room departure and cleanup.
fn test_leave_room() {
	mut server := new_server(5222, 'example.com')
	server.authenticate('alice@example.com', 'secret')!
	server.join_room('alice@example.com', 'general')!
	server.leave_room('alice@example.com', 'general')!
	// Room should be removed since it's empty
	assert 'general' !in server.rooms
}

// test_leave_room_not_member verifies error for non-member departure.
fn test_leave_room_not_member() {
	mut server := new_server(5222, 'example.com')
	server.authenticate('alice@example.com', 'secret')!
	server.authenticate('bob@example.com', 'secret')!
	server.join_room('alice@example.com', 'general')!
	server.leave_room('bob@example.com', 'general') or {
		assert err.msg().contains('not in room')
		return
	}
	assert false, 'expected error for non-member'
}
