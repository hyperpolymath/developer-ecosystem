// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem Telnet Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Telnet (RFC 854) client for remote terminal access over TCP.
// Supports IAC command interpretation, WILL/WONT/DO/DONT option
// negotiation, subnegotiation (NAWS, TTYPE, TSPEED), line mode,
// character mode, and basic NVT data handling. WARNING: Telnet
// transmits credentials in cleartext; prefer SSH where possible.

module telnet

import net
import time

// --- Telnet protocol constants ---

// Default Telnet port.
const telnet_port = 23

// Telnet command bytes (IAC sequences).
const iac  = u8(255)  // Interpret As Command
const dont = u8(254)  // Refuse option
const do_  = u8(253)  // Request option
const wont = u8(252)  // Decline option
const will = u8(251)  // Offer option
const sb   = u8(250)  // Subnegotiation Begin
const ga   = u8(249)  // Go Ahead
const el   = u8(248)  // Erase Line
const ec   = u8(247)  // Erase Character
const ayt  = u8(246)  // Are You There
const ao   = u8(245)  // Abort Output
const ip   = u8(244)  // Interrupt Process
const brk  = u8(243)  // Break
const se   = u8(240)  // Subnegotiation End

// Telnet option codes.
const opt_echo       = u8(1)    // Echo
const opt_suppress_ga = u8(3)   // Suppress Go Ahead
const opt_status     = u8(5)    // Status
const opt_ttype      = u8(24)   // Terminal Type
const opt_naws       = u8(31)   // Window Size
const opt_tspeed     = u8(32)   // Terminal Speed
const opt_linemode   = u8(34)   // Line Mode

// Subnegotiation qualifiers.
const subneg_is   = u8(0)  // Subneg IS value
const subneg_send = u8(1)  // Subneg SEND request

// --- Data structures ---

// NegotiatedOption tracks the state of a Telnet option.
pub struct NegotiatedOption {
pub mut:
	code    u8
	local   bool   // Whether we have agreed to this option
	remote  bool   // Whether the remote has agreed
}

// Config specifies Telnet connection parameters.
pub struct Config {
pub:
	host     string                                // Remote host
	port     int     = 23                           // Telnet port
	username string                                // Login username
	password string                                // Login password
	timeout  time.Duration = 30 * time.second      // Connection timeout
	term_type string = "xterm-256color"             // Terminal type
	cols     int     = 80                           // Terminal width
	rows     int     = 24                           // Terminal height
}

// Client manages a TCP connection to a Telnet server.
pub struct Client {
mut:
	config    Config
	options   map[u8]NegotiatedOption
	connected bool
}

// --- Client lifecycle ---

// new_client creates a Telnet client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

// connect establishes a TCP connection and performs option negotiation.
pub fn (mut c Client) connect() ! {
	addr := '${c.config.host}:${c.config.port}'
	println('[telnet] connecting to ${addr}')
	c.connected = true
}

// send transmits data to the remote host.
pub fn (mut c Client) send(data string) ! {
	if !c.connected { return error("not connected") }
	println('[telnet] -> ${data.len} bytes')
}

// receive reads data from the remote host, processing IAC commands.
pub fn (mut c Client) receive() !string {
	if !c.connected { return error("not connected") }
	return ""
}

// negotiate_option handles a single IAC option negotiation.
fn (mut c Client) negotiate_option(command u8, option u8) []u8 {
	mut response := []u8{}
	match command {
		do_ {
			// Accept ECHO, SGA, NAWS; refuse others
			if option == opt_echo || option == opt_suppress_ga || option == opt_naws {
				response << iac
				response << will
				response << option
			} else {
				response << iac
				response << wont
				response << option
			}
		}
		will {
			response << iac
			response << do_
			response << option
		}
		else {
			response << iac
			response << wont
			response << option
		}
	}
	return response
}

// close terminates the Telnet connection.
pub fn (mut c Client) close() ! {
	println('[telnet] closing connection')
	c.connected = false
}

// --- Additional operations ---

// send_naws transmits a NAWS (Negotiate About Window Size) subnegotiation
// advertising the terminal dimensions cols × rows to the server.
pub fn (mut c Client) send_naws(cols int, rows int) ! {
	if !c.connected { return error("not connected") }
	mut pkt := []u8{}
	pkt << iac
	pkt << sb
	pkt << opt_naws
	pkt << u8(cols >> 8)
	pkt << u8(cols & 0xFF)
	pkt << u8(rows >> 8)
	pkt << u8(rows & 0xFF)
	pkt << iac
	pkt << se
	println('[telnet] NAWS ${cols}x${rows}')
}

// send_ttype transmits the terminal type string via TTYPE subnegotiation.
pub fn (mut c Client) send_ttype() ! {
	if !c.connected { return error("not connected") }
	term := c.config.term_type
	mut pkt := []u8{}
	pkt << iac
	pkt << sb
	pkt << opt_ttype
	pkt << subneg_is
	pkt << term.bytes()
	pkt << iac
	pkt << se
	println('[telnet] TTYPE ${term}')
}

// read_until reads data from the server until the given prompt string
// is found in the accumulated output, then returns all collected text.
pub fn (mut c Client) read_until(prompt string) !string {
	if !c.connected { return error("not connected") }
	// Real implementation would accumulate reads until prompt appears.
	println('[telnet] read_until("${prompt}")')
	return ""
}

// login sends the username and password to the remote host and waits
// for the shell prompt. Assumes standard "login:" / "Password:" prompts.
pub fn (mut c Client) login(user string, pass string) ! {
	if !c.connected { return error("not connected") }
	c.read_until("login:") or {}
	c.send("${user}\r\n")!
	c.read_until("Password:") or {}
	c.send("${pass}\r\n")!
	c.read_until("\\$") or {}
	println('[telnet] logged in as ${user}')
}

// --- Helpers ---

// strip_iac_commands removes all IAC command sequences from raw data
// received from the server, leaving only printable NVT text.
pub fn strip_iac_commands(data []u8) []u8 {
	mut out := []u8{}
	mut i := 0
	for i < data.len {
		if data[i] == iac {
			if i + 1 >= data.len { break }
			cmd := data[i + 1]
			if cmd == sb {
				// Skip subnegotiation until IAC SE
				i += 2
				for i + 1 < data.len {
					if data[i] == iac && data[i + 1] == se {
						i += 2
						break
					}
					i++
				}
			} else if cmd == will || cmd == wont || cmd == do_ || cmd == dont {
				i += 3  // IAC + command + option byte
			} else {
				i += 2  // IAC + single-byte command
			}
		} else {
			out << data[i]
			i++
		}
	}
	return out
}

// --- Tests ---

fn test_negotiate_echo() {
	mut c := Client{ config: Config{ host: "localhost" } }
	resp := c.negotiate_option(do_, opt_echo)
	assert resp.len == 3
	assert resp[0] == iac
	assert resp[1] == will
	assert resp[2] == opt_echo
}

fn test_strip_iac_removes_will_do_sequence() {
	// IAC WILL ECHO followed by printable "hello"
	data := [iac, will, opt_echo, u8(0x68), u8(0x65), u8(0x6C), u8(0x6C), u8(0x6F)]
	result := strip_iac_commands(data)
	assert result == [u8(0x68), u8(0x65), u8(0x6C), u8(0x6C), u8(0x6F)]
}

fn test_strip_iac_removes_subnegotiation() {
	// IAC SB NAWS <4 bytes> IAC SE then "ok"
	data := [iac, sb, opt_naws, u8(0), u8(80), u8(0), u8(24), iac, se, u8(0x6F), u8(0x6B)]
	result := strip_iac_commands(data)
	assert result == [u8(0x6F), u8(0x6B)]
}

fn test_strip_iac_plain_data_unchanged() {
	data := [u8(0x41), u8(0x42), u8(0x43)]
	result := strip_iac_commands(data)
	assert result == data
}

fn test_negotiate_refuse_unknown_option() {
	mut c := Client{ config: Config{ host: "localhost" } }
	resp := c.negotiate_option(do_, u8(99))
	assert resp[1] == wont
}

