// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// irc_test -- Protocol conformance tests for v_irc.
// Covers user registration, channel management, message routing,
// IRC message parsing, and formatting.
module v_irc

// test_command_to_string verifies wire keywords for all IRC commands.
fn test_command_to_string() {
	assert command_to_string(.nick) == 'NICK'
	assert command_to_string(.user) == 'USER'
	assert command_to_string(.join) == 'JOIN'
	assert command_to_string(.part) == 'PART'
	assert command_to_string(.privmsg) == 'PRIVMSG'
	assert command_to_string(.notice) == 'NOTICE'
	assert command_to_string(.quit) == 'QUIT'
	assert command_to_string(.ping) == 'PING'
	assert command_to_string(.pong) == 'PONG'
	assert command_to_string(.mode) == 'MODE'
	assert command_to_string(.topic) == 'TOPIC'
	assert command_to_string(.kick) == 'KICK'
	assert command_to_string(.ban) == 'BAN'
	assert command_to_string(.who) == 'WHO'
	assert command_to_string(.whois) == 'WHOIS'
	assert command_to_string(.list) == 'LIST'
}

// test_register_user verifies user registration.
fn test_register_user() {
	mut server := new_server(6667, 'irc.example.com')
	server.register_user('alice', 'alice', 'example.com', 'Alice Smith')!
	assert 'alice' in server.users
	assert server.users['alice'].realname == 'Alice Smith'
}

// test_register_user_duplicate verifies duplicate nick rejection.
fn test_register_user_duplicate() {
	mut server := new_server(6667, 'irc.example.com')
	server.register_user('alice', 'alice', 'example.com', 'Alice')!
	server.register_user('alice', 'alice2', 'example.com', 'Alice 2') or {
		assert err.msg().contains('already in use')
		return
	}
	assert false, 'expected error for duplicate nick'
}

// test_join_channel verifies channel creation and joining.
fn test_join_channel() {
	mut server := new_server(6667, 'irc.example.com')
	server.register_user('alice', 'alice', 'example.com', 'Alice')!
	server.join_channel('alice', '#general')!
	assert '#general' in server.channels
	assert 'alice' in server.channels['#general'].users
	assert '#general' in server.users['alice'].channels
}

// test_join_channel_invalid_name verifies rejection of invalid channel names.
fn test_join_channel_invalid_name() {
	mut server := new_server(6667, 'irc.example.com')
	server.register_user('alice', 'alice', 'example.com', 'Alice')!
	server.join_channel('alice', 'nochanprefix') or {
		assert err.msg().contains('invalid channel name')
		return
	}
	assert false, 'expected error for invalid channel name'
}

// test_part_channel verifies leaving a channel.
fn test_part_channel() {
	mut server := new_server(6667, 'irc.example.com')
	server.register_user('alice', 'alice', 'example.com', 'Alice')!
	server.join_channel('alice', '#general')!
	server.part_channel('alice', '#general')!
	// Channel should be removed since it's empty
	assert '#general' !in server.channels
}

// test_send_message verifies PRIVMSG construction.
fn test_send_message() {
	mut server := new_server(6667, 'irc.example.com')
	server.register_user('alice', 'alice', 'example.com', 'Alice')!
	server.register_user('bob', 'bob', 'example.com', 'Bob')!
	server.join_channel('alice', '#general')!
	server.join_channel('bob', '#general')!
	msg := server.send_message('alice', '#general', 'Hello everyone!')!
	assert msg.command == 'PRIVMSG'
	assert msg.params[0] == '#general'
	assert msg.params[1] == 'Hello everyone!'
}

// test_set_topic verifies topic setting.
fn test_set_topic() {
	mut server := new_server(6667, 'irc.example.com')
	server.register_user('alice', 'alice', 'example.com', 'Alice')!
	server.join_channel('alice', '#general')!
	server.set_topic('#general', 'Welcome to #general!')!
	assert server.channels['#general'].topic == 'Welcome to #general!'
}

// test_kick_user verifies user removal from channel.
fn test_kick_user() {
	mut server := new_server(6667, 'irc.example.com')
	server.register_user('alice', 'alice', 'example.com', 'Alice')!
	server.register_user('bob', 'bob', 'example.com', 'Bob')!
	server.join_channel('alice', '#general')!
	server.join_channel('bob', '#general')!
	msg := server.kick_user('#general', 'bob', 'Misbehaving')!
	assert msg.command == 'KICK'
	assert 'bob' !in server.channels['#general'].users
}

// test_parse_message_simple verifies parsing a simple IRC message.
fn test_parse_message_simple() {
	msg := parse_message('PING :server.example.com')!
	assert msg.prefix == ''
	assert msg.command == 'PING'
	assert msg.params[0] == 'server.example.com'
}

// test_parse_message_with_prefix verifies parsing a prefixed IRC message.
fn test_parse_message_with_prefix() {
	msg := parse_message(':alice!alice@example.com PRIVMSG #general :Hello world')!
	assert msg.prefix == 'alice!alice@example.com'
	assert msg.command == 'PRIVMSG'
	assert msg.params[0] == '#general'
	assert msg.params[1] == 'Hello world'
}

// test_parse_message_empty verifies rejection of empty messages.
fn test_parse_message_empty() {
	parse_message('') or {
		assert err.msg().contains('empty')
		return
	}
	assert false, 'expected error for empty message'
}

// test_format_message verifies IRC message serialisation.
fn test_format_message() {
	msg := IrcMessage{
		prefix: 'server'
		command: 'NOTICE'
		params: ['#general', 'Server maintenance in 5 minutes']
	}
	formatted := format_message(msg)
	assert formatted.starts_with(':server NOTICE')
	assert formatted.contains(':Server maintenance')
	assert formatted.ends_with('\r\n')
}

// test_format_message_no_prefix verifies formatting without a prefix.
fn test_format_message_no_prefix() {
	msg := IrcMessage{
		command: 'PONG'
		params: ['server.example.com']
	}
	formatted := format_message(msg)
	assert formatted == 'PONG server.example.com\r\n'
}

// test_parse_format_roundtrip verifies that parsing then formatting
// produces a consistent result.
fn test_parse_format_roundtrip() {
	original := ':nick!user@host PRIVMSG #chan :Hello there'
	msg := parse_message(original)!
	formatted := format_message(msg).trim_right('\r\n')
	assert formatted == original
}
