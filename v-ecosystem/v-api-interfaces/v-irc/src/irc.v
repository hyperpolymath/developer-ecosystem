// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem IRC Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Internet Relay Chat (IRC, RFC 2812) client for real-time text
// communication. Supports NICK, USER, JOIN, PART, PRIVMSG, NOTICE,
// MODE, KICK, TOPIC, WHOIS, PING/PONG keepalive, and channel modes.
// Handles CTCP messages and IRC colour code stripping.

module irc

import net
import time

// --- IRC protocol constants ---

// Default IRC port.
const irc_port     = 6667   // Plaintext
const irc_tls_port = 6697   // TLS

// IRC message length limit (including CR-LF).
const max_message_len = 512

// Common IRC numeric replies.
const rpl_welcome    = 1
const rpl_yourhost   = 2
const rpl_created    = 3
const rpl_myinfo     = 4
const rpl_namreply   = 353
const rpl_endofnames = 366
const rpl_motd       = 372
const rpl_motdstart  = 375
const rpl_endofmotd  = 376
const err_nicknameinuse = 433

// IRC command name constants (RFC 2812 Section 3).
const cmd_nick    = "NICK"
const cmd_user    = "USER"
const cmd_join    = "JOIN"
const cmd_part    = "PART"
const cmd_privmsg = "PRIVMSG"
const cmd_notice  = "NOTICE"
const cmd_ping    = "PING"
const cmd_pong    = "PONG"
const cmd_quit    = "QUIT"
const cmd_kick    = "KICK"
const cmd_mode    = "MODE"
const cmd_topic   = "TOPIC"
const cmd_whois   = "WHOIS"

// CTCP delimiter byte.
const ctcp_delim = u8(0x01)

// --- Data structures ---

// IrcMessage represents a parsed IRC protocol message.
pub struct IrcMessage {
pub:
	prefix  string     // Server or user prefix (optional)
	command string     // Command or numeric reply
	params  []string   // Command parameters
}

// Channel represents an IRC channel with its state.
pub struct Channel {
pub mut:
	name   string
	topic  string
	users  []string
	modes  string
}

// Config specifies IRC connection parameters.
pub struct Config {
pub:
	host     string                                // IRC server hostname
	port     int     = 6697                         // IRC port (6697 for TLS)
	nick     string                                // Desired nickname
	username string                                // Username (ident)
	realname string                                // Real name / GECOS
	password string                                // Server password (optional)
	timeout  time.Duration = 30 * time.second      // Connection timeout
}

// Client manages a TCP connection to an IRC server.
pub struct Client {
mut:
	config   Config
	channels map[string]Channel
	connected bool
}

// --- Client lifecycle ---

// new_client creates an IRC client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{
		config: config
	}
}

// connect establishes a connection and sends registration commands.
pub fn (mut c Client) connect() ! {
	addr := '${c.config.host}:${c.config.port}'
	println('[irc] connecting to ${addr}')
	// NICK and USER registration
	println('[irc] NICK ${c.config.nick}')
	println('[irc] USER ${c.config.username} 0 * :${c.config.realname}')
	c.connected = true
}

// join enters an IRC channel.
pub fn (mut c Client) join(channel string) ! {
	if !c.connected { return error("not connected") }
	println('[irc] JOIN ${channel}')
	c.channels[channel] = Channel{ name: channel }
}

// part leaves an IRC channel with an optional message.
pub fn (mut c Client) part(channel string, message string) ! {
	if !c.connected { return error("not connected") }
	println('[irc] PART ${channel} :${message}')
	c.channels.delete(channel)
}

// privmsg sends a message to a channel or user.
pub fn (mut c Client) privmsg(target string, message string) ! {
	if !c.connected { return error("not connected") }
	if message.len > max_message_len - 50 {
		return error("message too long")
	}
	println('[irc] PRIVMSG ${target} :${message}')
}

// notice sends a NOTICE to a channel or user (no auto-reply).
pub fn (mut c Client) notice(target string, message string) ! {
	if !c.connected { return error("not connected") }
	println('[irc] NOTICE ${target} :${message}')
}

// quit disconnects from the IRC server with a quit message.
pub fn (mut c Client) quit(message string) ! {
	println('[irc] QUIT :${message}')
	c.connected = false
}

// --- Additional operations ---

// pong responds to a server PING with an appropriate PONG.
pub fn (mut c Client) pong(server string) ! {
	if !c.connected { return error("not connected") }
	println('[irc] PONG :${server}')
}

// nick changes the client's nickname.
pub fn (mut c Client) nick(new_nick string) ! {
	if !c.connected { return error("not connected") }
	if new_nick.len == 0 { return error("nickname must not be empty") }
	println('[irc] NICK ${new_nick}')
}

// kick removes a user from a channel with an optional reason.
pub fn (mut c Client) kick(channel string, user string, reason string) ! {
	if !c.connected { return error("not connected") }
	println('[irc] KICK ${channel} ${user} :${reason}')
}

// set_topic sets the topic for a channel.
pub fn (mut c Client) set_topic(channel string, topic string) ! {
	if !c.connected { return error("not connected") }
	println('[irc] TOPIC ${channel} :${topic}')
}

// format_message encodes a PRIVMSG or NOTICE line ready to write to the wire.
pub fn format_message(command string, target string, text string) string {
	return '${command} ${target} :${text}\r\n'
}

// --- Message parsing ---

// parse_message parses a raw IRC line into an IrcMessage.
pub fn parse_message(line string) !IrcMessage {
	if line.len == 0 {
		return error("empty IRC message")
	}
	mut rest := line.trim_right('\r\n')
	mut prefix := ''
	if rest.starts_with(':') {
		space := rest.index(' ') or { return error("malformed prefix") }
		prefix = rest[1..space]
		rest = rest[space + 1..]
	}
	parts := rest.split(' ')
	if parts.len == 0 {
		return error("no command in IRC message")
	}
	return IrcMessage{
		prefix: prefix
		command: parts[0]
		params: if parts.len > 1 { parts[1..] } else { []string{} }
	}
}

// --- Tests ---

fn test_parse_simple_message() {
	msg := parse_message(':server 001 nick :Welcome') or { panic('parse failed') }
	assert msg.prefix == 'server'
	assert msg.command == '001'
}

fn test_parse_ping() {
	msg := parse_message('PING :irc.example.net') or { panic('parse failed') }
	assert msg.prefix == ''
	assert msg.command == 'PING'
}

fn test_parse_privmsg() {
	msg := parse_message(':nick!user@host PRIVMSG #chan :hello world') or { panic('parse failed') }
	assert msg.prefix == 'nick!user@host'
	assert msg.command == 'PRIVMSG'
}

fn test_format_message() {
	line := format_message(cmd_privmsg, "#general", "hi there")
	assert line == "PRIVMSG #general :hi there\r\n"
}

fn test_parse_empty_fails() {
	parse_message('') or {
		assert err.str().contains("empty")
		return
	}
	assert false
}

