// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_irc -- IRC protocol types and server for the V-Ecosystem.
// Implements channel management, user registration, message routing,
// and IRC message parsing per RFC 2812. Network I/O is stubbed with
// TODO markers; all type definitions and logic are real.
module v_irc

// Command enumerates the IRC commands supported by this connector.
pub enum Command {
	nick
	user
	join
	part
	privmsg
	notice
	quit
	ping
	pong
	mode
	topic
	kick
	ban
	who
	whois
	list
}

// command_to_string returns the IRC wire keyword for a Command.
pub fn command_to_string(cmd Command) string {
	return match cmd {
		.nick { 'NICK' }
		.user { 'USER' }
		.join { 'JOIN' }
		.part { 'PART' }
		.privmsg { 'PRIVMSG' }
		.notice { 'NOTICE' }
		.quit { 'QUIT' }
		.ping { 'PING' }
		.pong { 'PONG' }
		.mode { 'MODE' }
		.topic { 'TOPIC' }
		.kick { 'KICK' }
		.ban { 'BAN' }
		.who { 'WHO' }
		.whois { 'WHOIS' }
		.list { 'LIST' }
	}
}

// Channel represents an IRC channel with its topic, modes, and user list.
pub struct Channel {
pub:
	// name is the channel name (must start with '#' or '&').
	name string
pub mut:
	// topic is the current channel topic.
	topic string
	// modes holds the channel mode string (e.g. "+nt").
	modes string
	// users lists the nicknames of users in the channel.
	users []string
}

// User represents a connected IRC user.
pub struct User {
pub:
	// nick is the user's nickname.
	nick string
	// username is the user's ident/username.
	username string
	// hostname is the user's hostname or IP address.
	hostname string
	// realname is the user's real name (GECOS field).
	realname string
pub mut:
	// channels lists the channel names this user has joined.
	channels []string
}

// IrcMessage represents a parsed IRC protocol message with optional prefix,
// command keyword, and parameter list per RFC 2812 section 2.3.1.
pub struct IrcMessage {
pub:
	// prefix is the optional source prefix (e.g. "nick!user@host").
	prefix string
	// command is the IRC command keyword or numeric reply.
	command string
	// params holds the command parameters (the last may be a trailing param).
	params []string
}

// IrcServer holds the state for an IRC server instance.
pub struct IrcServer {
pub:
	// port is the TCP port the server listens on (default 6667).
	port int
	// server_name is the name used in server-originated messages.
	server_name string
pub mut:
	// users holds the registered users by nickname.
	users map[string]User
	// channels holds the channels by name.
	channels map[string]Channel
}

// new_server creates a new IrcServer on the given port.
pub fn new_server(port int, server_name string) &IrcServer {
	return &IrcServer{
		port: port
		server_name: server_name
	}
}

// register_user registers a new user on the server. Returns an error if
// the nickname is already in use.
pub fn (mut s IrcServer) register_user(nick string, username string, hostname string, realname string) ! {
	if nick.len == 0 {
		return error('nickname must not be empty')
	}
	if nick in s.users {
		return error('nickname already in use: ${nick}')
	}
	s.users[nick] = User{
		nick: nick
		username: username
		hostname: hostname
		realname: realname
	}
}

// join_channel adds a user to a channel, creating the channel if it does
// not exist. Returns an error if the user is not registered.
pub fn (mut s IrcServer) join_channel(nick string, channel_name string) ! {
	if nick !in s.users {
		return error('user not registered: ${nick}')
	}
	if !channel_name.starts_with('#') && !channel_name.starts_with('&') {
		return error('invalid channel name: ${channel_name} (must start with # or &)')
	}
	// Create channel if it does not exist
	if channel_name !in s.channels {
		s.channels[channel_name] = Channel{
			name: channel_name
			modes: '+nt'
		}
	}
	mut ch := &s.channels[channel_name]
	if nick !in ch.users {
		ch.users << nick
	}
	mut u := &s.users[nick]
	if channel_name !in u.channels {
		u.channels << channel_name
	}
}

// part_channel removes a user from a channel. Returns an error if the
// user is not in the channel.
pub fn (mut s IrcServer) part_channel(nick string, channel_name string) ! {
	if nick !in s.users {
		return error('user not registered: ${nick}')
	}
	if channel_name !in s.channels {
		return error('no such channel: ${channel_name}')
	}
	mut ch := &s.channels[channel_name]
	idx := ch.users.index(nick)
	if idx < 0 {
		return error('user ${nick} not in channel ${channel_name}')
	}
	ch.users.delete(idx)
	// Remove channel from user's list
	mut u := &s.users[nick]
	ch_idx := u.channels.index(channel_name)
	if ch_idx >= 0 {
		u.channels.delete(ch_idx)
	}
	// Remove empty channels
	if ch.users.len == 0 {
		s.channels.delete(channel_name)
	}
}

// send_message constructs a PRIVMSG IrcMessage from sender to target.
// Target may be a channel name or a nickname.
pub fn (s IrcServer) send_message(from string, target string, text string) !IrcMessage {
	if from !in s.users {
		return error('sender not registered: ${from}')
	}
	// Validate target exists
	if target.starts_with('#') || target.starts_with('&') {
		if target !in s.channels {
			return error('no such channel: ${target}')
		}
	} else {
		if target !in s.users {
			return error('no such nick: ${target}')
		}
	}
	sender := s.users[from]
	return IrcMessage{
		prefix: '${sender.nick}!${sender.username}@${sender.hostname}'
		command: 'PRIVMSG'
		params: [target, text]
	}
}

// set_topic sets the topic for a channel. Returns an error if the
// channel does not exist.
pub fn (mut s IrcServer) set_topic(channel_name string, new_topic string) ! {
	if channel_name !in s.channels {
		return error('no such channel: ${channel_name}')
	}
	mut ch := &s.channels[channel_name]
	ch.topic = new_topic
}

// kick_user removes a user from a channel (operator action).
pub fn (mut s IrcServer) kick_user(channel_name string, nick string, reason string) !IrcMessage {
	if channel_name !in s.channels {
		return error('no such channel: ${channel_name}')
	}
	mut ch := &s.channels[channel_name]
	idx := ch.users.index(nick)
	if idx < 0 {
		return error('user ${nick} not in channel ${channel_name}')
	}
	ch.users.delete(idx)
	// Remove channel from user's list
	if nick in s.users {
		mut u := &s.users[nick]
		ch_idx := u.channels.index(channel_name)
		if ch_idx >= 0 {
			u.channels.delete(ch_idx)
		}
	}
	return IrcMessage{
		prefix: s.server_name
		command: 'KICK'
		params: [channel_name, nick, reason]
	}
}

// parse_message parses a raw IRC protocol line into an IrcMessage.
// Format: [":" prefix SPACE] command { SPACE param } [SPACE ":" trailing]
pub fn parse_message(raw string) !IrcMessage {
	line := raw.trim_right('\r\n')
	if line.len == 0 {
		return error('empty message')
	}
	mut pos := 0
	mut prefix := ''

	// Parse optional prefix
	if line[0] == `:` {
		space_idx := line.index_u8(` `)
		if space_idx < 0 {
			return error('malformed message: prefix without command')
		}
		prefix = line[1..space_idx]
		pos = space_idx + 1
	}

	// Parse command and parameters
	remainder := line[pos..]
	mut parts := []string{}
	mut current := remainder

	for current.len > 0 {
		// Trailing parameter
		if current[0] == `:` {
			parts << current[1..]
			break
		}
		space_idx := current.index_u8(` `)
		if space_idx < 0 {
			parts << current
			break
		}
		parts << current[..space_idx]
		current = current[space_idx + 1..]
	}

	if parts.len == 0 {
		return error('malformed message: no command')
	}

	return IrcMessage{
		prefix: prefix
		command: parts[0]
		params: parts[1..]
	}
}

// format_message serialises an IrcMessage into IRC wire format.
pub fn format_message(msg IrcMessage) string {
	mut result := ''
	if msg.prefix.len > 0 {
		result += ':${msg.prefix} '
	}
	result += msg.command
	if msg.params.len > 0 {
		for i, param in msg.params {
			if i == msg.params.len - 1 && (param.contains(' ') || param.len == 0) {
				result += ' :${param}'
			} else {
				result += ' ${param}'
			}
		}
	}
	return '${result}\r\n'
}
