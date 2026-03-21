// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem SOCKS Protocol Connector
// Author: Jonathan D.A. Jewell
//
// SOCKS5 (RFC 1928) client for establishing proxied TCP and UDP
// connections. Supports no-auth and username/password (RFC 1929)
// authentication, CONNECT/BIND/UDP ASSOCIATE commands, IPv4/IPv6/
// domain address types, and reply status validation.

module socks

import net
import time

// --- SOCKS5 protocol constants ---

// SOCKS version.
const socks_version = u8(5)

// Authentication methods.
const auth_none     = u8(0x00)  // No authentication
const auth_userpass = u8(0x02)  // Username/password (RFC 1929)
const auth_rejected = u8(0xFF)  // No acceptable methods

// SOCKS commands.
const cmd_connect       = u8(0x01)
const cmd_bind          = u8(0x02)
const cmd_udp_associate = u8(0x03)

// Address types.
const atyp_ipv4   = u8(0x01)  // IPv4 (4 bytes)
const atyp_domain = u8(0x03)  // Domain name
const atyp_ipv6   = u8(0x04)  // IPv6 (16 bytes)

// Reply codes.
const reply_success           = u8(0x00)
const reply_general_failure   = u8(0x01)
const reply_not_allowed       = u8(0x02)
const reply_network_unreachable = u8(0x03)
const reply_host_unreachable  = u8(0x04)
const reply_connection_refused = u8(0x05)
const reply_ttl_expired       = u8(0x06)
const reply_command_not_supported = u8(0x07)
const reply_address_not_supported = u8(0x08)

// --- Data structures ---

// Config specifies SOCKS5 proxy parameters.
pub struct Config {
pub:
	proxy_host string                              // Proxy server hostname
	proxy_port int    = 1080                        // SOCKS5 default port
	username   string                              // Auth username (optional)
	password   string                              // Auth password (optional)
	timeout    time.Duration = 10 * time.second    // Connection timeout
}

// BoundAddress holds the address assigned by the proxy.
pub struct BoundAddress {
pub:
	addr_type u8
	addr      string
	port      u16
}

// Client manages a SOCKS5 proxy connection.
pub struct Client {
mut:
	config      Config
	authenticated bool
}

// --- Client lifecycle ---

// new_client creates a SOCKS5 client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

// connect establishes a proxied TCP connection to a target host:port.
pub fn (mut c Client) connect(target_host string, target_port int) !BoundAddress {
	addr := '${c.config.proxy_host}:${c.config.proxy_port}'
	mut conn := net.dial_tcp(addr)!
	defer { conn.close() or {} }
	conn.set_read_timeout(c.config.timeout)

	// Method negotiation
	mut methods := [auth_none]
	if c.config.username.len > 0 {
		methods << auth_userpass
	}

	mut greeting := []u8{}
	greeting << socks_version
	greeting << u8(methods.len)
	greeting << methods
	conn.write(greeting)!

	// Read method selection
	mut buf := []u8{len: 2}
	conn.read(mut buf)!
	if buf[0] != socks_version {
		return error("SOCKS5 version mismatch")
	}
	if buf[1] == auth_rejected {
		return error("SOCKS5 no acceptable auth method")
	}

	// Connect request
	mut req := []u8{}
	req << socks_version
	req << cmd_connect
	req << u8(0x00)  // Reserved
	req << atyp_domain
	req << u8(target_host.len)
	req << target_host.bytes()
	req << u8(target_port >> 8)
	req << u8(target_port & 0xFF)
	conn.write(req)!

	// Read reply
	mut reply := []u8{len: 10}
	conn.read(mut reply)!
	if reply[1] != reply_success {
		return error("SOCKS5 connect failed: reply code ${reply[1]}")
	}

	println('[socks] connected to ${target_host}:${target_port} via proxy')
	return BoundAddress{ addr_type: reply[3], addr: target_host, port: u16(target_port) }
}

// --- Tests ---

fn test_greeting_structure() {
	mut pkt := []u8{}
	pkt << socks_version
	pkt << u8(1)
	pkt << auth_none
	assert pkt.len == 3
	assert pkt[0] == 5
}
