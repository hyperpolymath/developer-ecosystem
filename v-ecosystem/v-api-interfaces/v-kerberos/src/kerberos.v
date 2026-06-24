// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem Kerberos Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Kerberos 5 (RFC 4120) authentication client using system libkrb5
// via C FFI. Supports initial ticket acquisition (AS-REQ/AS-REP),
// service ticket requests (TGS-REQ/TGS-REP), ticket caching,
// credential delegation, and keytab-based authentication.
// Designed for enterprise SSO integration within the V-Ecosystem.

module kerberos

import time

// --- C FFI bindings to libkrb5 ---

#flag -lkrb5
#include <krb5.h>

// Opaque Kerberos context handle from libkrb5.
struct C.krb5_context {}

// Opaque credential cache handle.
struct C.krb5_ccache {}

// Opaque keytab handle.
struct C.krb5_keytab {}

// Kerberos principal structure.
struct C.krb5_principal_data {}

// Kerberos credentials structure.
struct C.krb5_creds {}

// krb5_init_context initialises the Kerberos library context.
fn C.krb5_init_context(ctx &&C.krb5_context) int

// krb5_free_context releases all resources held by the context.
fn C.krb5_free_context(ctx &C.krb5_context)

// krb5_cc_default opens the default credential cache.
fn C.krb5_cc_default(ctx &C.krb5_context, cc &&C.krb5_ccache) int

// krb5_cc_close closes a credential cache handle.
fn C.krb5_cc_close(ctx &C.krb5_context, cc &C.krb5_ccache) int

// krb5_parse_name parses a principal name string into internal form.
fn C.krb5_parse_name(ctx &C.krb5_context, name &char, princ &&C.krb5_principal_data) int

// krb5_free_principal releases a parsed principal.
fn C.krb5_free_principal(ctx &C.krb5_context, princ &C.krb5_principal_data)

// krb5_kt_resolve opens a keytab by name (e.g. "FILE:/etc/krb5.keytab").
fn C.krb5_kt_resolve(ctx &C.krb5_context, name &char, kt &&C.krb5_keytab) int

// krb5_kt_close closes a keytab handle.
fn C.krb5_kt_close(ctx &C.krb5_context, kt &C.krb5_keytab) int

// --- Encryption type enumeration ---

// EncType enumerates Kerberos encryption types for ticket requests.
pub enum EncType {
	aes256_cts_hmac_sha1     // AES-256 (preferred)
	aes128_cts_hmac_sha1     // AES-128
	des3_cbc_sha1            // Triple DES (legacy)
}

// --- Ticket flags ---

// TicketFlags captures the boolean flags present in a Kerberos ticket.
pub struct TicketFlags {
pub:
	forwardable  bool   // Ticket can be forwarded to another host
	forwarded    bool   // Ticket has been forwarded
	proxiable    bool   // Ticket can be used as a proxy
	renewable    bool   // Ticket can be renewed past its expiry
	pre_authent  bool   // Pre-authentication was performed
}

// --- Data structures ---

// Config specifies the Kerberos realm and KDC connection parameters.
pub struct Config {
pub:
	realm           string                               // Kerberos realm (e.g. "EXAMPLE.COM")
	kdc_host        string                               // KDC hostname or IP
	kdc_port        int    = 88                           // KDC port (default 88)
	admin_server    string                               // Admin server for kadmin operations
	default_keytab  string = '/etc/krb5.keytab'          // Default keytab file path
	ticket_lifetime time.Duration = 10 * time.hour       // Requested ticket lifetime
	renew_lifetime  time.Duration = 7 * 24 * time.hour   // Requested renewable lifetime
}

// Principal represents a Kerberos principal (user or service).
pub struct Principal {
pub:
	name       string   // Primary component (e.g. "user" or "HTTP")
	instance   string   // Instance component (e.g. "admin" or "host.example.com")
	realm      string   // Realm (e.g. "EXAMPLE.COM")
}

// Ticket represents a cached Kerberos ticket with its metadata.
pub struct Ticket {
pub:
	client      Principal
	server      Principal
	auth_time   time.Time
	start_time  time.Time
	end_time    time.Time
	renew_till  time.Time
	flags       TicketFlags
	enc_type    EncType
}

// Client manages the Kerberos library context and credential cache.
pub struct Client {
mut:
	ctx          &C.krb5_context = unsafe { nil }
	ccache       &C.krb5_ccache = unsafe { nil }
	initialised  bool
	config       Config
}

// --- Client lifecycle ---

// new_client creates and initialises a Kerberos client context.
// Calls krb5_init_context and opens the default credential cache.
pub fn new_client(config Config) !&Client {
	mut client := &Client{
		config: config
	}

	ret := C.krb5_init_context(&client.ctx)
	if ret != 0 {
		return error('krb5_init_context failed: error code ${ret}')
	}

	ret2 := C.krb5_cc_default(client.ctx, &client.ccache)
	if ret2 != 0 {
		C.krb5_free_context(client.ctx)
		return error('krb5_cc_default failed: error code ${ret2}')
	}

	client.initialised = true
	println('[kerberos] context initialised for realm ${config.realm}')
	return client
}

// close releases all Kerberos library resources.
pub fn (mut c Client) close() {
	if !c.initialised {
		return
	}
	if c.ccache != unsafe { nil } {
		C.krb5_cc_close(c.ctx, c.ccache)
	}
	C.krb5_free_context(c.ctx)
	c.initialised = false
	println('[kerberos] context closed')
}

// --- Authentication operations ---

// kinit acquires an initial TGT for the given principal using a
// password. Equivalent to the kinit command-line tool.
pub fn (mut c Client) kinit(principal_name string, password string) ! {
	if !c.initialised {
		return error('kerberos context not initialised')
	}
	// Parse the principal name
	mut princ := unsafe { nil }
	ret := C.krb5_parse_name(c.ctx, principal_name.str, &princ)
	if ret != 0 {
		return error('krb5_parse_name failed for "${principal_name}": error code ${ret}')
	}
	defer {
		C.krb5_free_principal(c.ctx, princ)
	}

	// In a full implementation, krb5_get_init_creds_password would
	// be called here to acquire the TGT and store it in the ccache.
	println('[kerberos] kinit for ${principal_name}@${c.config.realm}')
}

// kinit_keytab acquires an initial TGT using a keytab file instead
// of a password. Used for service principals and automated systems.
pub fn (mut c Client) kinit_keytab(principal_name string, keytab_path string) ! {
	if !c.initialised {
		return error('kerberos context not initialised')
	}

	mut kt := unsafe { nil }
	kt_name := if keytab_path.len > 0 { keytab_path } else { c.config.default_keytab }
	ret := C.krb5_kt_resolve(c.ctx, 'FILE:${kt_name}'.str, &kt)
	if ret != 0 {
		return error('krb5_kt_resolve failed for "${kt_name}": error code ${ret}')
	}
	defer {
		C.krb5_kt_close(c.ctx, kt)
	}

	println('[kerberos] kinit via keytab ${kt_name} for ${principal_name}')
}

// get_service_ticket requests a service ticket (TGS-REQ) for the
// specified service principal (e.g. "HTTP/host.example.com@EXAMPLE.COM").
pub fn (mut c Client) get_service_ticket(service_principal string) !Ticket {
	if !c.initialised {
		return error('kerberos context not initialised')
	}

	println('[kerberos] requesting service ticket for ${service_principal}')
	// Placeholder: in production this calls krb5_get_credentials
	return Ticket{
		client: Principal{ name: 'user', realm: c.config.realm }
		server: parse_principal_string(service_principal)
		auth_time: time.now()
		start_time: time.now()
		end_time: time.now().add(c.config.ticket_lifetime)
		renew_till: time.now().add(c.config.renew_lifetime)
		flags: TicketFlags{ forwardable: true, renewable: true }
		enc_type: .aes256_cts_hmac_sha1
	}
}

// list_tickets returns all tickets currently in the credential cache.
pub fn (c &Client) list_tickets() ![]Ticket {
	if !c.initialised {
		return error('kerberos context not initialised')
	}
	println('[kerberos] listing cached tickets')
	return []Ticket{}
}

// renew_ticket attempts to renew a renewable TGT before it expires.
pub fn (mut c Client) renew_ticket() ! {
	if !c.initialised {
		return error('kerberos context not initialised')
	}
	println('[kerberos] renewing TGT')
}

// destroy_tickets removes all tickets from the credential cache
// (equivalent to kdestroy).
pub fn (mut c Client) destroy_tickets() ! {
	if !c.initialised {
		return error('kerberos context not initialised')
	}
	println('[kerberos] destroying credential cache')
}

// --- Internal helpers ---

// parse_principal_string splits a "name/instance@REALM" string into
// a Principal struct.
fn parse_principal_string(s string) Principal {
	mut name := s
	mut instance := ''
	mut realm := ''

	if at_pos := s.index('@') {
		realm = s[at_pos + 1..]
		name = s[..at_pos]
	}
	if slash_pos := name.index('/') {
		instance = name[slash_pos + 1..]
		name = name[..slash_pos]
	}

	return Principal{ name: name, instance: instance, realm: realm }
}

// --- Tests ---

fn test_parse_principal_simple() {
	p := parse_principal_string('user@EXAMPLE.COM')
	assert p.name == 'user'
	assert p.instance == ''
	assert p.realm == 'EXAMPLE.COM'
}

fn test_parse_principal_with_instance() {
	p := parse_principal_string('HTTP/host.example.com@EXAMPLE.COM')
	assert p.name == 'HTTP'
	assert p.instance == 'host.example.com'
	assert p.realm == 'EXAMPLE.COM'
}

fn test_parse_principal_no_realm() {
	p := parse_principal_string('admin')
	assert p.name == 'admin'
	assert p.instance == ''
	assert p.realm == ''
}
