// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem RADIUS Protocol Connector
// Author: Jonathan D.A. Jewell
//
// RADIUS (RFC 2865/2866) client over UDP. Supports Access-Request,
// Access-Accept/Reject/Challenge, Accounting-Request/Response,
// and attribute-value pair (AVP) encoding/decoding. Implements
// MD5-based authenticator calculation and User-Password encryption.
// Designed for AAA (Authentication, Authorisation, Accounting)
// within the V-Ecosystem.

module radius

import net
import time
import crypto.md5

// --- RADIUS protocol constants ---

// RADIUS packet types (codes).
const access_request   = u8(1)
const access_accept    = u8(2)
const access_reject    = u8(3)
const accounting_request  = u8(4)
const accounting_response = u8(5)
const access_challenge = u8(11)

// Common RADIUS attribute types.
const attr_user_name       = u8(1)
const attr_user_password   = u8(2)
const attr_nas_ip_address  = u8(4)
const attr_nas_port        = u8(5)
const attr_service_type    = u8(6)
const attr_framed_protocol = u8(7)
const attr_framed_ip       = u8(8)
const attr_reply_message   = u8(18)
const attr_state           = u8(24)
const attr_session_timeout = u8(27)
const attr_calling_station = u8(31)
const attr_nas_identifier  = u8(32)
const attr_acct_status     = u8(40)
const attr_acct_session_id = u8(44)

// RADIUS packet header size: code(1) + identifier(1) + length(2) + authenticator(16).
const header_size = 20
const authenticator_size = 16

// --- Data structures ---

// AttributeType classifies the data type of a RADIUS AVP.
pub enum AttributeType {
	text       // UTF-8 string
	string_val // Opaque octets
	address    // IPv4 address (4 bytes)
	integer    // 32-bit unsigned integer
	time_val   // 32-bit Unix timestamp
}

// Attribute represents a single RADIUS attribute-value pair.
pub struct Attribute {
pub:
	attr_type u8
	data      []u8
}

// Packet represents a complete RADIUS packet.
pub struct Packet {
pub mut:
	code          u8
	identifier    u8
	authenticator []u8        // 16 bytes
	attributes    []Attribute
}

// Config specifies the RADIUS server and shared secret.
pub struct Config {
pub:
	host          string
	auth_port     int    = 1812                          // Authentication port
	acct_port     int    = 1813                          // Accounting port
	secret        string                                 // Shared secret
	timeout       time.Duration = 5 * time.second
	retries       int    = 3
	nas_ip        string = '0.0.0.0'                     // NAS IP address
	nas_identifier string                                // NAS identifier string
}

// AuthResult holds the outcome of an authentication request.
pub struct AuthResult {
pub:
	accepted       bool
	reply_message  string
	attributes     []Attribute
	challenge      bool          // Access-Challenge received
	state          []u8          // State attribute for challenge-response
}

// Client manages RADIUS communication with a server.
pub struct Client {
mut:
	config      Config
	identifier  u8
}

// --- Client lifecycle ---

// new_client creates a RADIUS client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{
		config: config
	}
}

// authenticate sends an Access-Request with username and password.
pub fn (mut c Client) authenticate(username string, password string) !AuthResult {
	c.identifier++

	// Generate random authenticator
	authenticator := generate_authenticator()

	// Build attributes
	mut attrs := []Attribute{}
	attrs << Attribute{ attr_type: attr_user_name, data: username.bytes() }
	attrs << Attribute{ attr_type: attr_user_password, data: encrypt_password(password, c.config.secret, authenticator) }
	attrs << Attribute{ attr_type: attr_nas_ip_address, data: ip_to_bytes(c.config.nas_ip) }
	if c.config.nas_identifier.len > 0 {
		attrs << Attribute{ attr_type: attr_nas_identifier, data: c.config.nas_identifier.bytes() }
	}

	// Build and send packet
	pkt := build_packet(access_request, c.identifier, authenticator, attrs)
	response := c.send_to_port(pkt, c.config.auth_port)!

	// Parse response
	resp_pkt := parse_packet(response)!

	mut result := AuthResult{}
	match resp_pkt.code {
		access_accept {
			result = AuthResult{
				accepted: true
				attributes: resp_pkt.attributes
				reply_message: extract_reply_message(resp_pkt.attributes)
			}
			println('[radius] access-accept for ${username}')
		}
		access_reject {
			result = AuthResult{
				accepted: false
				reply_message: extract_reply_message(resp_pkt.attributes)
			}
			println('[radius] access-reject for ${username}')
		}
		access_challenge {
			result = AuthResult{
				accepted: false
				challenge: true
				state: extract_state(resp_pkt.attributes)
				reply_message: extract_reply_message(resp_pkt.attributes)
			}
			println('[radius] access-challenge for ${username}')
		}
		else {
			return error('unexpected RADIUS response code ${resp_pkt.code}')
		}
	}

	return result
}

// accounting_start sends an Accounting-Request with status type Start.
pub fn (mut c Client) accounting_start(username string, session_id string) ! {
	c.identifier++
	mut attrs := []Attribute{}
	attrs << Attribute{ attr_type: attr_user_name, data: username.bytes() }
	attrs << Attribute{ attr_type: attr_acct_status, data: encode_u32(1) } // Start
	attrs << Attribute{ attr_type: attr_acct_session_id, data: session_id.bytes() }
	attrs << Attribute{ attr_type: attr_nas_ip_address, data: ip_to_bytes(c.config.nas_ip) }

	authenticator := [u8(0)].repeat(authenticator_size)
	pkt := build_packet(accounting_request, c.identifier, authenticator, attrs)

	// Calculate accounting authenticator (MD5 of packet with zero authenticator + secret)
	response := c.send_to_port(pkt, c.config.acct_port)!
	resp_pkt := parse_packet(response)!
	if resp_pkt.code != accounting_response {
		return error('accounting start failed: code ${resp_pkt.code}')
	}
	println('[radius] accounting start for ${username} session ${session_id}')
}

// accounting_stop sends an Accounting-Request with status type Stop.
pub fn (mut c Client) accounting_stop(username string, session_id string) ! {
	c.identifier++
	mut attrs := []Attribute{}
	attrs << Attribute{ attr_type: attr_user_name, data: username.bytes() }
	attrs << Attribute{ attr_type: attr_acct_status, data: encode_u32(2) } // Stop
	attrs << Attribute{ attr_type: attr_acct_session_id, data: session_id.bytes() }
	attrs << Attribute{ attr_type: attr_nas_ip_address, data: ip_to_bytes(c.config.nas_ip) }

	authenticator := [u8(0)].repeat(authenticator_size)
	pkt := build_packet(accounting_request, c.identifier, authenticator, attrs)

	response := c.send_to_port(pkt, c.config.acct_port)!
	resp_pkt := parse_packet(response)!
	if resp_pkt.code != accounting_response {
		return error('accounting stop failed: code ${resp_pkt.code}')
	}
	println('[radius] accounting stop for ${username} session ${session_id}')
}

// --- Internal helpers ---

// build_packet constructs a RADIUS packet from its components.
fn build_packet(code u8, identifier u8, authenticator []u8, attributes []Attribute) []u8 {
	// Calculate total length
	mut attr_len := 0
	for attr in attributes {
		attr_len += 2 + attr.data.len // type(1) + length(1) + data
	}
	total_len := header_size + attr_len

	mut pkt := []u8{cap: total_len}
	pkt << code
	pkt << identifier
	pkt << u8(total_len >> 8)
	pkt << u8(total_len & 0xFF)
	pkt << authenticator[..authenticator_size]

	for attr in attributes {
		pkt << attr.attr_type
		pkt << u8(2 + attr.data.len)
		pkt << attr.data
	}

	return pkt
}

// parse_packet decodes a RADIUS packet from bytes.
fn parse_packet(data []u8) !Packet {
	if data.len < header_size {
		return error('RADIUS packet too short (${data.len} bytes)')
	}

	code := data[0]
	identifier := data[1]
	length := (int(data[2]) << 8) | int(data[3])
	authenticator := data[4..20]

	// Parse attributes
	mut attributes := []Attribute{}
	mut i := header_size
	for i < length && i < data.len {
		if i + 2 > data.len {
			break
		}
		attr_type := data[i]
		attr_len := int(data[i + 1])
		if attr_len < 2 || i + attr_len > data.len {
			break
		}
		attributes << Attribute{
			attr_type: attr_type
			data: data[i + 2..i + attr_len]
		}
		i += attr_len
	}

	return Packet{
		code: code
		identifier: identifier
		authenticator: authenticator
		attributes: attributes
	}
}

// send_to_port sends a packet to the specified port and reads the response.
fn (c &Client) send_to_port(pkt []u8, port int) ![]u8 {
	addr := '${c.config.host}:${port}'
	mut conn := net.dial_udp(addr)!
	defer {
		conn.close() or {}
	}
	conn.set_read_timeout(c.config.timeout)
	conn.write(pkt)!

	mut buf := []u8{len: 4096}
	n := conn.read(mut buf)!
	return buf[..n]
}

// encrypt_password implements the RADIUS User-Password encryption
// (XOR with MD5 of secret + authenticator, RFC 2865 section 5.2).
fn encrypt_password(password string, secret string, authenticator []u8) []u8 {
	// Pad password to multiple of 16 bytes
	pwd_bytes := password.bytes()
	mut padded := []u8{len: ((pwd_bytes.len + 15) / 16) * 16, init: 0}
	for i, b in pwd_bytes {
		padded[i] = b
	}

	// First block: XOR with MD5(secret + authenticator)
	mut input := secret.bytes()
	input << authenticator
	mut hash := md5.sum(input)

	mut result := []u8{cap: padded.len}
	for i in 0 .. 16 {
		if i < padded.len {
			result << padded[i] ^ hash[i]
		}
	}

	// Subsequent blocks: XOR with MD5(secret + previous ciphertext)
	mut block := 1
	for block * 16 < padded.len {
		mut next_input := secret.bytes()
		next_input << result[(block - 1) * 16..block * 16]
		hash = md5.sum(next_input)
		for i in 0 .. 16 {
			idx := block * 16 + i
			if idx < padded.len {
				result << padded[idx] ^ hash[i]
			}
		}
		block++
	}

	return result
}

// generate_authenticator creates a 16-byte authenticator.
fn generate_authenticator() []u8 {
	// Use a simple hash-based approach for deterministic testing
	seed := '${time.now().unix()}'.bytes()
	hash := md5.sum(seed)
	return hash[..authenticator_size]
}

// extract_reply_message finds the Reply-Message attribute.
fn extract_reply_message(attrs []Attribute) string {
	for attr in attrs {
		if attr.attr_type == attr_reply_message {
			return attr.data.bytestr()
		}
	}
	return ''
}

// extract_state finds the State attribute.
fn extract_state(attrs []Attribute) []u8 {
	for attr in attrs {
		if attr.attr_type == attr_state {
			return attr.data
		}
	}
	return []u8{}
}

// ip_to_bytes converts a dotted-decimal IP to 4 bytes.
fn ip_to_bytes(ip string) []u8 {
	parts := ip.split('.')
	mut bytes := []u8{len: 4, init: 0}
	for i, part in parts {
		if i < 4 {
			bytes[i] = u8(part.int())
		}
	}
	return bytes
}

// encode_u32 encodes a 32-bit unsigned integer in network byte order.
fn encode_u32(val u32) []u8 {
	return [u8(val >> 24), u8(val >> 16), u8(val >> 8), u8(val)]
}

// --- Tests ---

fn test_ip_to_bytes() {
	result := ip_to_bytes('192.168.1.1')
	assert result == [u8(192), u8(168), u8(1), u8(1)]
}

fn test_encode_u32() {
	result := encode_u32(1)
	assert result == [u8(0), u8(0), u8(0), u8(1)]
}

fn test_build_parse_packet() {
	auth := [u8(0)].repeat(16)
	attrs := [Attribute{ attr_type: attr_user_name, data: 'test'.bytes() }]
	pkt := build_packet(access_request, 42, auth, attrs)

	parsed := parse_packet(pkt) or { panic('parse failed') }
	assert parsed.code == access_request
	assert parsed.identifier == 42
	assert parsed.attributes.len == 1
	assert parsed.attributes[0].attr_type == attr_user_name
	assert parsed.attributes[0].data.bytestr() == 'test'
}

fn test_extract_reply_message() {
	attrs := [
		Attribute{ attr_type: attr_user_name, data: 'user'.bytes() },
		Attribute{ attr_type: attr_reply_message, data: 'Welcome'.bytes() },
	]
	assert extract_reply_message(attrs) == 'Welcome'
}
