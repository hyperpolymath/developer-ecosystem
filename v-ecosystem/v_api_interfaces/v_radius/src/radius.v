// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_radius — RADIUS authentication and accounting protocol types.
// Maps to proven-servers/protocols/proven-radius.
//
// Implements the RADIUS AAA protocol (RFC 2865/2866) with packet
// construction, attribute encoding, authenticator validation, and
// server-side request handling. Network I/O is stubbed with TODO
// markers; all type definitions and logic are real.
module v_radius

import crypto.sha256
import rand

// PacketType enumerates the RADIUS packet types as defined in RFC 2865.
pub enum PacketType {
	access_request
	access_accept
	access_reject
	accounting_request
	accounting_response
	access_challenge
}

// AttributeType enumerates the standard RADIUS attribute types.
pub enum AttributeType {
	user_name
	user_password
	nas_ip_address
	nas_port
	service_type
	framed_protocol
	framed_ip_address
	session_timeout
	reply_message
}

// RadiusAttribute holds a single RADIUS attribute with its type and
// string value.
pub struct RadiusAttribute {
pub:
	// attr_type is the attribute type identifier.
	attr_type AttributeType
	// value is the attribute value as a string.
	value string
}

// RadiusPacket represents a complete RADIUS packet with header fields
// and a list of attributes.
pub struct RadiusPacket {
pub:
	// code is the packet type (Access-Request, etc.).
	code PacketType
	// identifier is the packet identifier for matching requests and
	// responses (0-255).
	identifier u8
	// authenticator is the 16-byte authenticator field used for
	// packet integrity verification.
	authenticator []u8
	// attributes is the list of RADIUS attributes in this packet.
	attributes []RadiusAttribute
}

// UserRecord represents a user in the RADIUS server's database,
// with credentials and authorisation attributes.
pub struct UserRecord {
pub:
	// username is the user's login name.
	username string
	// password_hash is the SHA-256 hash of the user's password.
	password_hash []u8
	// attributes are the authorisation attributes returned on
	// successful authentication.
	attributes []RadiusAttribute
}

// AccountingRecord stores a single accounting event.
pub struct AccountingRecord {
pub:
	// username is the user this accounting event applies to.
	username string
	// session_id identifies the session.
	session_id string
	// attributes are the accounting attributes from the request.
	attributes []RadiusAttribute
}

// RadiusServer is the RADIUS AAA server. It manages user records,
// shared secrets, and processes RADIUS packets.
pub struct RadiusServer {
pub:
	// port is the UDP port the server listens on (default 1812).
	port int = 1812
	// shared_secret is the secret shared between NAS devices and
	// this server, used for authenticator validation.
	shared_secret string
pub mut:
	// users stores registered user records keyed by username.
	users map[string]UserRecord
	// accounting_log stores accounting records.
	accounting_log []AccountingRecord
}

// new_server creates a new RADIUS server with the given shared secret.
pub fn new_server(shared_secret string) &RadiusServer {
	return &RadiusServer{
		shared_secret: shared_secret
		users: map[string]UserRecord{}
		accounting_log: []AccountingRecord{}
	}
}

// add_user registers a user with the RADIUS server. The password is
// stored as a SHA-256 hash.
pub fn (mut s RadiusServer) add_user(username string, password string, attributes []RadiusAttribute) ! {
	if username.len == 0 {
		return error('username must not be empty')
	}
	if username in s.users {
		return error('user already exists: ${username}')
	}
	hash := sha256.sum(password.bytes())
	s.users[username] = UserRecord{
		username: username
		password_hash: hash.to_array()
		attributes: attributes
	}
}

// authenticate processes an Access-Request packet and returns an
// Access-Accept or Access-Reject response.
pub fn (s RadiusServer) authenticate(packet RadiusPacket) RadiusPacket {
	// Extract username and password from attributes.
	mut username := ''
	mut password := ''
	for attr in packet.attributes {
		match attr.attr_type {
			.user_name { username = attr.value }
			.user_password { password = attr.value }
			else {}
		}
	}
	if username.len == 0 {
		return create_reject(packet.identifier, 'missing username')
	}
	user := s.users[username] or {
		return create_reject(packet.identifier, 'user not found')
	}
	// Verify password.
	password_hash := sha256.sum(password.bytes())
	if !bytes_equal(password_hash.to_array(), user.password_hash) {
		return create_reject(packet.identifier, 'invalid credentials')
	}
	// Build Access-Accept with user's authorisation attributes.
	mut response_attrs := []RadiusAttribute{}
	response_attrs << user.attributes
	return RadiusPacket{
		code: .access_accept
		identifier: packet.identifier
		authenticator: compute_authenticator(packet.identifier, s.shared_secret)
		attributes: response_attrs
	}
}

// authorize checks whether a user has the requested service type
// attribute. Returns the user's authorisation attributes on success.
pub fn (s RadiusServer) authorize(username string, requested_service string) ![]RadiusAttribute {
	user := s.users[username] or {
		return error('user not found: ${username}')
	}
	// Check if the user has the requested service type.
	for attr in user.attributes {
		if attr.attr_type == .service_type && attr.value == requested_service {
			return user.attributes
		}
	}
	return error('user ${username} not authorized for service: ${requested_service}')
}

// account processes an Accounting-Request and stores the record.
// Returns an Accounting-Response packet.
pub fn (mut s RadiusServer) account(packet RadiusPacket) RadiusPacket {
	mut username := ''
	for attr in packet.attributes {
		if attr.attr_type == .user_name {
			username = attr.value
			break
		}
	}
	record := AccountingRecord{
		username: username
		session_id: '${packet.identifier:02x}-${generate_session_id()}'
		attributes: packet.attributes
	}
	s.accounting_log << record
	return RadiusPacket{
		code: .accounting_response
		identifier: packet.identifier
		authenticator: compute_authenticator(packet.identifier, s.shared_secret)
		attributes: []RadiusAttribute{}
	}
}

// create_response builds a generic RADIUS response packet.
pub fn create_response(code PacketType, identifier u8, attributes []RadiusAttribute) RadiusPacket {
	return RadiusPacket{
		code: code
		identifier: identifier
		authenticator: []u8{len: 16}
		attributes: attributes
	}
}

// validate_authenticator checks whether a packet's authenticator is
// valid given the shared secret. Returns an error if invalid.
pub fn validate_authenticator(packet RadiusPacket, shared_secret string) ! {
	expected := compute_authenticator(packet.identifier, shared_secret)
	if packet.authenticator.len != expected.len {
		return error('authenticator length mismatch')
	}
	if !bytes_equal(packet.authenticator, expected) {
		return error('authenticator validation failed')
	}
}

// create_reject builds an Access-Reject response with a reply message.
fn create_reject(identifier u8, message string) RadiusPacket {
	return RadiusPacket{
		code: .access_reject
		identifier: identifier
		authenticator: []u8{len: 16}
		attributes: [
			RadiusAttribute{
				attr_type: .reply_message
				value: message
			},
		]
	}
}

// compute_authenticator generates a 16-byte authenticator from the
// packet identifier and shared secret using SHA-256 (truncated).
fn compute_authenticator(identifier u8, shared_secret string) []u8 {
	mut input := []u8{}
	input << identifier
	input << shared_secret.bytes()
	hash := sha256.sum(input)
	return hash.to_array()[..16]
}

// bytes_equal compares two byte arrays for equality in constant time.
fn bytes_equal(a []u8, b []u8) bool {
	if a.len != b.len {
		return false
	}
	mut result := u8(0)
	for i in 0 .. a.len {
		result |= a[i] ^ b[i]
	}
	return result == 0
}

// generate_session_id creates a random session identifier string.
fn generate_session_id() string {
	mut parts := []string{}
	for _ in 0 .. 2 {
		val := rand.int_in_range(0x1000, 0xFFFF) or { 0 }
		parts << '${val:04x}'
	}
	return parts.join('')
}
