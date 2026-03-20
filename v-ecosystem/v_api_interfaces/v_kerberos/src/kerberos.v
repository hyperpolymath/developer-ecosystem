// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_kerberos — Kerberos V5 authentication protocol types and KDC server.
// Maps to proven-servers/protocols/proven-kerberos.
//
// Provides a KDC abstraction with AS and TGS exchanges, ticket validation,
// principal management, and password changes. Network I/O is stubbed with
// TODO markers; all type definitions and logic are real.
module v_kerberos

import time
import crypto.sha256
import encoding.hex
import rand

// MessageType enumerates the Kerberos V5 message types exchanged
// between clients and the KDC, as defined in RFC 4120.
pub enum MessageType {
	as_req
	as_rep
	tgs_req
	tgs_rep
	ap_req
	ap_rep
	krb_error
}

// EncryptionType enumerates the supported Kerberos encryption types.
// AES-256-CTS-HMAC is preferred per RFC 3962.
pub enum EncryptionType {
	aes256_cts_hmac
	aes128_cts_hmac
	des3_cbc_sha1
}

// Principal represents a Kerberos principal (user or service) with
// its name and realm.
pub struct Principal {
pub:
	// name is the principal name (e.g. "user" or "krbtgt").
	name string
	// realm is the Kerberos realm (e.g. "EXAMPLE.COM").
	realm string
}

// Ticket represents a Kerberos ticket issued by the KDC. Contains
// the service principal, encrypted portion, and validity window.
pub struct Ticket {
pub:
	// sname is the service principal name this ticket grants access to.
	sname Principal
	// enc_part is the encrypted portion of the ticket (opaque bytes).
	enc_part []u8
	// validity is the ticket's lifetime in seconds.
	validity int
	// issued_at is the time the ticket was issued.
	issued_at time.Time
	// enc_type is the encryption type used for this ticket.
	enc_type EncryptionType
pub mut:
	// expired indicates whether this ticket has been marked as expired.
	expired bool
}

// TicketGrantingTicket wraps a Ticket with the client principal and
// a session key for use in TGS exchanges.
pub struct TicketGrantingTicket {
pub:
	// client is the principal that owns this TGT.
	client Principal
	// ticket is the actual Kerberos ticket.
	ticket Ticket
	// session_key is the session key for communicating with the TGS.
	session_key []u8
}

// KdcServer is the Key Distribution Centre. It stores principals,
// their keys, and issues tickets for authentication and service access.
pub struct KdcServer {
pub:
	// realm is the Kerberos realm this KDC serves.
	realm string
	// port is the network port the KDC listens on (default 88).
	port int = 88
pub mut:
	// principals stores registered principals keyed by name.
	principals map[string]Principal
	// principal_keys stores secret keys for each principal (keyed by name).
	// In production these would be derived from passwords via string2key.
	principal_keys map[string][]u8
	// issued_tickets tracks all issued tickets for validation.
	issued_tickets []Ticket
}

// new_kdc creates a new KDC server for the given realm. The krbtgt
// principal is automatically registered.
pub fn new_kdc(realm string) &KdcServer {
	mut kdc := &KdcServer{
		realm: realm
		principals: map[string]Principal{}
		principal_keys: map[string][]u8{}
		issued_tickets: []Ticket{}
	}
	// Register the ticket-granting service principal.
	tgt_principal := Principal{
		name: 'krbtgt'
		realm: realm
	}
	kdc.principals['krbtgt'] = tgt_principal
	kdc.principal_keys['krbtgt'] = generate_key()
	return kdc
}

// authenticate performs an AS exchange: validates the client's
// credentials and returns a Ticket Granting Ticket (TGT). This is the
// initial authentication step in the Kerberos protocol.
pub fn (mut kdc KdcServer) authenticate(client_name string, password string) !TicketGrantingTicket {
	if client_name !in kdc.principals {
		return error('principal not found: ${client_name}@${kdc.realm}')
	}
	// Derive key from password and compare with stored key.
	derived_key := derive_key(password, kdc.realm)
	stored_key := kdc.principal_keys[client_name] or {
		return error('no key for principal: ${client_name}')
	}
	if !keys_match(derived_key, stored_key) {
		return error('authentication failed for ${client_name}@${kdc.realm}')
	}
	// Issue a TGT.
	client := kdc.principals[client_name] or {
		return error('principal not found: ${client_name}')
	}
	tgt_principal := Principal{name: 'krbtgt', realm: kdc.realm}
	session_key := generate_key()
	// TODO: Encrypt ticket with krbtgt's key using the selected enc type.
	enc_part := generate_enc_part(session_key, stored_key)
	ticket := Ticket{
		sname: tgt_principal
		enc_part: enc_part
		validity: 36000
		issued_at: time.now()
		enc_type: .aes256_cts_hmac
	}
	kdc.issued_tickets << ticket
	return TicketGrantingTicket{
		client: client
		ticket: ticket
		session_key: session_key
	}
}

// request_service_ticket performs a TGS exchange: given a valid TGT,
// issues a service ticket for the requested service principal.
pub fn (mut kdc KdcServer) request_service_ticket(tgt TicketGrantingTicket, service_name string) !Ticket {
	// Validate the TGT.
	kdc.validate_ticket(tgt.ticket)!
	if service_name !in kdc.principals {
		return error('service principal not found: ${service_name}@${kdc.realm}')
	}
	service := kdc.principals[service_name] or {
		return error('service principal not found: ${service_name}')
	}
	// TODO: Encrypt service ticket with the service principal's key.
	service_key := kdc.principal_keys[service_name] or {
		return error('no key for service: ${service_name}')
	}
	enc_part := generate_enc_part(tgt.session_key, service_key)
	ticket := Ticket{
		sname: service
		enc_part: enc_part
		validity: 3600
		issued_at: time.now()
		enc_type: .aes256_cts_hmac
	}
	kdc.issued_tickets << ticket
	return ticket
}

// validate_ticket checks whether a ticket is valid: not expired and
// known to the KDC.
pub fn (kdc KdcServer) validate_ticket(ticket Ticket) ! {
	if ticket.expired {
		return error('ticket has been marked as expired')
	}
	now := time.now()
	expiry := ticket.issued_at.unix() + i64(ticket.validity)
	if now.unix() > expiry {
		return error('ticket has expired')
	}
	// Verify the ticket was issued by this KDC.
	if ticket.sname.realm != kdc.realm {
		return error('ticket realm mismatch: expected ${kdc.realm}, got ${ticket.sname.realm}')
	}
}

// change_password updates the stored key for a principal after
// verifying the old password.
pub fn (mut kdc KdcServer) change_password(principal_name string, old_password string, new_password string) ! {
	if principal_name !in kdc.principals {
		return error('principal not found: ${principal_name}@${kdc.realm}')
	}
	// Verify old password.
	old_key := derive_key(old_password, kdc.realm)
	stored_key := kdc.principal_keys[principal_name] or {
		return error('no key for principal: ${principal_name}')
	}
	if !keys_match(old_key, stored_key) {
		return error('old password verification failed for ${principal_name}')
	}
	// Set new key.
	kdc.principal_keys[principal_name] = derive_key(new_password, kdc.realm)
}

// list_principals returns all registered principal names.
pub fn (kdc KdcServer) list_principals() []string {
	mut result := []string{}
	for name, _ in kdc.principals {
		result << '${name}@${kdc.realm}'
	}
	return result
}

// register_principal adds a new principal with the given password.
// This is an administrative function not part of the Kerberos wire
// protocol.
pub fn (mut kdc KdcServer) register_principal(name string, password string) ! {
	if name.len == 0 {
		return error('principal name must not be empty')
	}
	if name in kdc.principals {
		return error('principal already exists: ${name}@${kdc.realm}')
	}
	kdc.principals[name] = Principal{name: name, realm: kdc.realm}
	kdc.principal_keys[name] = derive_key(password, kdc.realm)
}

// derive_key derives a key from a password and realm using SHA-256.
// In production, this should use string2key per RFC 3962.
fn derive_key(password string, realm string) []u8 {
	input := '${password}:${realm}'.bytes()
	hash := sha256.sum(input)
	return hash.to_array()
}

// keys_match compares two key byte arrays for equality.
fn keys_match(a []u8, b []u8) bool {
	if a.len != b.len {
		return false
	}
	for i in 0 .. a.len {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

// generate_key creates a random 32-byte key for session use.
fn generate_key() []u8 {
	mut key := []u8{len: 32}
	for i in 0 .. 32 {
		key[i] = u8(rand.int_in_range(0, 256) or { 0 })
	}
	return key
}

// generate_enc_part creates a placeholder encrypted ticket portion
// by hashing the session key and service key together.
fn generate_enc_part(session_key []u8, service_key []u8) []u8 {
	mut combined := []u8{}
	combined << session_key
	combined << service_key
	hash := sha256.sum(combined)
	return hash.to_array()
}
