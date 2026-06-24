// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_socks -- SOCKS5 proxy protocol types, authentication method negotiation,
// and request handling for the V-Ecosystem.
// Maps to proven-servers/protocols/proven-socks.
// Implements the SOCKS5 handshake, connect/bind/UDP associate commands, and
// address type encoding per RFC 1928.
module v_socks

import encoding.binary

// socks_version is the SOCKS protocol version (always 5 for SOCKS5).
const socks_version = u8(5)

// AuthMethod enumerates the SOCKS5 authentication methods per RFC 1928 section 3.
pub enum AuthMethod as u8 {
	no_auth           = 0x00
	gssapi            = 0x01
	username_password = 0x02
}

// auth_method_to_string returns the human-readable label for an AuthMethod.
pub fn auth_method_to_string(am AuthMethod) string {
	return match am {
		.no_auth { 'NO AUTHENTICATION' }
		.gssapi { 'GSSAPI' }
		.username_password { 'USERNAME/PASSWORD' }
	}
}

// Command enumerates the SOCKS5 request commands per RFC 1928 section 4.
pub enum Command as u8 {
	connect       = 0x01
	bind          = 0x02
	udp_associate = 0x03
}

// command_to_string returns the human-readable label for a Command.
pub fn command_to_string(cmd Command) string {
	return match cmd {
		.connect { 'CONNECT' }
		.bind { 'BIND' }
		.udp_associate { 'UDP ASSOCIATE' }
	}
}

// AddressType enumerates the SOCKS5 address types per RFC 1928 section 4.
pub enum AddressType as u8 {
	ipv4   = 0x01
	domain = 0x03
	ipv6   = 0x04
}

// address_type_to_string returns the human-readable label for an AddressType.
pub fn address_type_to_string(at AddressType) string {
	return match at {
		.ipv4 { 'IPv4' }
		.domain { 'DOMAIN' }
		.ipv6 { 'IPv6' }
	}
}

// ReplyCode enumerates the SOCKS5 reply codes per RFC 1928 section 6.
pub enum ReplyCode as u8 {
	succeeded                = 0x00
	general_failure          = 0x01
	not_allowed              = 0x02
	network_unreachable      = 0x03
	host_unreachable         = 0x04
	connection_refused       = 0x05
	ttl_expired              = 0x06
	command_not_supported    = 0x07
	address_type_unsupported = 0x08
}

// reply_code_to_string returns the human-readable label for a ReplyCode.
pub fn reply_code_to_string(rc ReplyCode) string {
	return match rc {
		.succeeded { 'Succeeded' }
		.general_failure { 'General SOCKS server failure' }
		.not_allowed { 'Connection not allowed by ruleset' }
		.network_unreachable { 'Network unreachable' }
		.host_unreachable { 'Host unreachable' }
		.connection_refused { 'Connection refused' }
		.ttl_expired { 'TTL expired' }
		.command_not_supported { 'Command not supported' }
		.address_type_unsupported { 'Address type not supported' }
	}
}

// SocksRequest represents a SOCKS5 client request including the command,
// destination address type, address, and port.
pub struct SocksRequest {
pub:
	// version is the SOCKS protocol version (always 5).
	version u8 = 5
	// command is the requested action (connect, bind, or UDP associate).
	command Command
	// addr_type identifies the format of the destination address.
	addr_type AddressType
	// dest_addr is the destination address (IP or domain name).
	dest_addr string
	// dest_port is the destination port number.
	dest_port u16
}

// SocksResponse represents a SOCKS5 server reply including the reply code,
// bound address type, address, and port.
pub struct SocksResponse {
pub:
	// version is the SOCKS protocol version (always 5).
	version u8 = 5
	// reply is the status code of the response.
	reply ReplyCode
	// addr_type identifies the format of the bound address.
	addr_type AddressType
	// bind_addr is the server-bound address.
	bind_addr string
	// bind_port is the server-bound port.
	bind_port u16
}

// Credential stores username/password pairs for SOCKS5 authentication.
pub struct Credential {
pub:
	// username is the authentication username.
	username string
	// password is the authentication password.
	password string
}

// SocksServer manages SOCKS5 connection handling, authentication, and
// request processing.
pub struct SocksServer {
pub:
	// listen_port is the port the SOCKS server listens on.
	listen_port int = 1080
	// allowed_methods lists the authentication methods this server supports.
	allowed_methods []AuthMethod
pub mut:
	// credentials stores registered username/password pairs.
	credentials []Credential
	// total_connections tracks the number of handled connections.
	total_connections u64
}

// new_server creates a new SocksServer on the given port with specified
// authentication methods. If no methods are given, NoAuth is used.
pub fn new_server(port int, methods []AuthMethod) &SocksServer {
	m := if methods.len == 0 { [AuthMethod.no_auth] } else { methods }
	return &SocksServer{
		listen_port: port
		allowed_methods: m
	}
}

// add_credential registers a username/password pair for authentication.
pub fn (mut s SocksServer) add_credential(username string, password string) {
	s.credentials << Credential{
		username: username
		password: password
	}
}

// negotiate_auth selects the best matching authentication method from the
// client's offered methods. Returns the chosen method or an error if no
// acceptable method is found.
pub fn (s SocksServer) negotiate_auth(client_methods []AuthMethod) !AuthMethod {
	// Prefer server-configured methods in order
	for server_method in s.allowed_methods {
		for client_method in client_methods {
			if server_method == client_method {
				return server_method
			}
		}
	}
	return error('no acceptable authentication method')
}

// verify_credentials checks a username/password pair against the registered
// credentials. Returns true if the credentials are valid.
pub fn (s SocksServer) verify_credentials(username string, password string) bool {
	for cred in s.credentials {
		if cred.username == username && cred.password == password {
			return true
		}
	}
	return false
}

// process_request validates a SOCKS5 request and returns an appropriate
// response. Checks that the command and address type are supported.
// TODO: Network I/O -- actually establish the requested connection.
pub fn (mut s SocksServer) process_request(req SocksRequest) SocksResponse {
	s.total_connections++

	// Validate version
	if req.version != socks_version {
		return SocksResponse{
			reply: .general_failure
			addr_type: .ipv4
			bind_addr: '0.0.0.0'
			bind_port: 0
		}
	}

	// Validate command
	match req.command {
		.connect {
			// TODO: Establish TCP connection to dest_addr:dest_port
			return SocksResponse{
				reply: .succeeded
				addr_type: req.addr_type
				bind_addr: req.dest_addr
				bind_port: req.dest_port
			}
		}
		.bind {
			// TODO: Listen for incoming connection
			return SocksResponse{
				reply: .succeeded
				addr_type: .ipv4
				bind_addr: '0.0.0.0'
				bind_port: 0
			}
		}
		.udp_associate {
			// TODO: Set up UDP relay
			return SocksResponse{
				reply: .succeeded
				addr_type: .ipv4
				bind_addr: '0.0.0.0'
				bind_port: 0
			}
		}
	}
}

// connect_target attempts to resolve the destination address from a SOCKS
// request. For domain addresses, returns the domain; for IP addresses,
// returns the IP string. Real network connection is deferred to I/O layer.
// TODO: Network I/O -- perform actual DNS resolution and TCP connection.
pub fn connect_target(req SocksRequest) !string {
	match req.addr_type {
		.ipv4, .ipv6 {
			return req.dest_addr
		}
		.domain {
			if req.dest_addr.len == 0 {
				return error('empty domain name')
			}
			// TODO: Resolve domain to IP via DNS
			return req.dest_addr
		}
	}
}

// handle_udp processes a UDP associate request by validating the address
// and returning the relay address.
// TODO: Network I/O -- set up actual UDP relay socket.
pub fn (s SocksServer) handle_udp(client_addr string, client_port u16) !SocksResponse {
	if client_addr.len == 0 {
		return error('empty client address for UDP associate')
	}
	return SocksResponse{
		reply: .succeeded
		addr_type: .ipv4
		bind_addr: '0.0.0.0'
		bind_port: 0
	}
}

// encode_request serialises a SocksRequest into wire-format bytes.
pub fn encode_request(req SocksRequest) []u8 {
	mut buf := []u8{}
	buf << socks_version
	buf << u8(req.command)
	buf << u8(0) // reserved
	buf << u8(req.addr_type)

	match req.addr_type {
		.ipv4 {
			// Encode IPv4 as 4 octets
			parts := req.dest_addr.split('.')
			for part in parts {
				buf << u8(part.int())
			}
		}
		.domain {
			// Length-prefixed domain name
			buf << u8(req.dest_addr.len)
			buf << req.dest_addr.bytes()
		}
		.ipv6 {
			// Encode IPv6 as raw bytes (simplified: store as string bytes)
			// TODO: Proper IPv6 binary encoding
			buf << req.dest_addr.bytes()
		}
	}

	// Port in network byte order
	mut port_bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut port_bytes, req.dest_port)
	buf << port_bytes
	return buf
}

// encode_response serialises a SocksResponse into wire-format bytes.
pub fn encode_response(resp SocksResponse) []u8 {
	mut buf := []u8{}
	buf << socks_version
	buf << u8(resp.reply)
	buf << u8(0) // reserved
	buf << u8(resp.addr_type)

	match resp.addr_type {
		.ipv4 {
			parts := resp.bind_addr.split('.')
			for part in parts {
				buf << u8(part.int())
			}
		}
		.domain {
			buf << u8(resp.bind_addr.len)
			buf << resp.bind_addr.bytes()
		}
		.ipv6 {
			buf << resp.bind_addr.bytes()
		}
	}

	mut port_bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut port_bytes, resp.bind_port)
	buf << port_bytes
	return buf
}

// parse_auth_negotiation parses a SOCKS5 authentication method negotiation
// message from the client. Returns the list of offered methods.
pub fn parse_auth_negotiation(data []u8) ![]AuthMethod {
	if data.len < 2 {
		return error('auth negotiation too short')
	}
	if data[0] != socks_version {
		return error('unsupported SOCKS version: ${data[0]}')
	}
	nmethods := int(data[1])
	if data.len < 2 + nmethods {
		return error('auth negotiation truncated')
	}
	mut methods := []AuthMethod{}
	for i in 0 .. nmethods {
		methods << match data[2 + i] {
			0x00 { AuthMethod.no_auth }
			0x01 { AuthMethod.gssapi }
			0x02 { AuthMethod.username_password }
			else { continue }
		}
	}
	return methods
}
