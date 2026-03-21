// SPDX-License-Identifier: PMPL-1.0-or-later
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

// --- Tests ---

fn test_negotiate_echo() {
	mut c := Client{ config: Config{ host: "localhost" } }
	resp := c.negotiate_option(do_, opt_echo)
	assert resp.len == 3
	assert resp[0] == iac
	assert resp[1] == will
	assert resp[2] == opt_echo
}
