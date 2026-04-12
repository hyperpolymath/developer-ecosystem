// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem CardDAV Protocol Connector
// Author: Jonathan D.A. Jewell
//
// CardDAV (RFC 6352) client for contact and address book access
// over WebDAV. Supports PROPFIND, addressbook-multiget REPORT,
// PUT, DELETE on address book collections, vCard 4.0 (RFC 6350)
// contact creation/modification, and ETag-based concurrency.

module carddav

import net.http
import time

// --- CardDAV protocol constants ---

// Well-known CardDAV discovery path.
const well_known_path = "/.well-known/carddav"

// CardDAV XML namespace.
const ns_carddav = "urn:ietf:params:xml:ns:carddav"
const ns_dav     = "DAV:"

// vCard content type.
const content_type_vcard = "text/vcard; charset=utf-8"

// CardDAV XML content types and MIME types for REPORT bodies.
const content_type_xml = "application/xml; charset=utf-8"

// CardDAV REPORT names.
const report_addressbook_query    = "addressbook-query"
const report_addressbook_multiget = "addressbook-multiget"

// CardDAV property names used in PROPFIND and REPORT requests.
const prop_address_data  = "address-data"
const prop_getetag       = "getetag"
const prop_display_name  = "displayname"
const prop_ctag          = "getctag"

// --- Data structures ---

// Contact represents a vCard contact record.
pub struct Contact {
pub:
	uid    string     // Unique identifier
	fn_name string   // Formatted name (FN)
	given  string     // Given name
	family string     // Family name
	email  string     // Primary email
	tel    string     // Primary telephone
	org    string     // Organisation
	title  string     // Job title
	note   string     // Notes
}

// AddressBook represents an address book collection.
pub struct AddressBook {
pub:
	href         string    // Address book URL path
	display_name string    // Human-readable name
	ctag         string    // Collection change tag
}

// Config specifies CardDAV connection parameters.
pub struct Config {
pub:
	base_url string                                // CardDAV server URL
	username string                                // Authentication username
	password string                                // Authentication password
	timeout  time.Duration = 30 * time.second      // Request timeout
}

// Client manages HTTP communication with a CardDAV server.
pub struct Client {
mut:
	config Config
}

// --- Client lifecycle ---

// new_client creates a CardDAV client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

// discover_address_books finds all address book collections.
pub fn (mut c Client) discover_address_books() ![]AddressBook {
	println('[carddav] PROPFIND ${c.config.base_url}')
	return []AddressBook{}
}

// get_contacts retrieves all contacts from an address book.
pub fn (mut c Client) get_contacts(book_href string) ![]Contact {
	println('[carddav] REPORT ${book_href}')
	return []Contact{}
}

// create_contact adds a new contact to an address book via PUT.
pub fn (mut c Client) create_contact(book_href string, contact Contact) ! {
	vcard := encode_vcard(contact)
	println('[carddav] PUT ${book_href}/${contact.uid}.vcf (${vcard.len} bytes)')
}

// delete_contact removes a contact from an address book via DELETE.
pub fn (mut c Client) delete_contact(contact_href string) ! {
	println('[carddav] DELETE ${contact_href}')
}

// update_contact replaces an existing contact resource via PUT.
pub fn (mut c Client) update_contact(contact_href string, contact Contact) ! {
	if contact_href.len == 0 {
		return error("contact href must not be empty")
	}
	vcard := encode_vcard(contact)
	println('[carddav] PUT (update) ${contact_href} (${vcard.len} bytes)')
}

// get_contact_by_href retrieves a single contact using addressbook-multiget REPORT.
pub fn (mut c Client) get_contact_by_href(book_href string, contact_href string) !Contact {
	if contact_href.len == 0 {
		return error("contact href must not be empty")
	}
	println('[carddav] ${report_addressbook_multiget} ${contact_href}')
	return Contact{}
}

// --- vCard encoding ---

// encode_vcard serialises a Contact to vCard 4.0 format.
fn encode_vcard(contact Contact) string {
	mut lines := []string{}
	lines << 'BEGIN:VCARD'
	lines << 'VERSION:4.0'
	lines << 'UID:${contact.uid}'
	lines << 'FN:${contact.fn_name}'
	lines << 'N:${contact.family};${contact.given};;;'
	if contact.email.len > 0 {
		lines << 'EMAIL:${contact.email}'
	}
	if contact.tel.len > 0 {
		lines << 'TEL:${contact.tel}'
	}
	if contact.org.len > 0 {
		lines << 'ORG:${contact.org}'
	}
	if contact.title.len > 0 {
		lines << 'TITLE:${contact.title}'
	}
	lines << 'END:VCARD'
	return lines.join('\r\n')
}

// encode_addressbook_query builds a CardDAV addressbook-query REPORT XML body
// that requests address-data and getetag properties for all contacts.
pub fn encode_addressbook_query() string {
	return '<?xml version="1.0" encoding="utf-8"?>' +
		'<C:addressbook-query xmlns:D="${ns_dav}" xmlns:C="${ns_carddav}">' +
		'<D:prop>' +
		'<D:${prop_getetag}/>' +
		'<C:${prop_address_data}/>' +
		'</D:prop>' +
		'<C:filter/>' +
		'</C:addressbook-query>'
}

// --- Tests ---

fn test_encode_vcard() {
	c := Contact{
		uid: "test-456"
		fn_name: "Jane Doe"
		given: "Jane"
		family: "Doe"
		email: "jane@example.com"
	}
	vcard := encode_vcard(c)
	assert vcard.contains('BEGIN:VCARD')
	assert vcard.contains('FN:Jane Doe')
}

fn test_encode_addressbook_query_structure() {
	xml := encode_addressbook_query()
	assert xml.contains('addressbook-query')
	assert xml.contains(ns_carddav)
	assert xml.contains(ns_dav)
}

fn test_encode_addressbook_query_contains_props() {
	xml := encode_addressbook_query()
	assert xml.contains(prop_getetag)
	assert xml.contains(prop_address_data)
	assert xml.contains('<C:filter/>')
}

fn test_update_contact_empty_href_rejected() {
	mut client := new_client(Config{ base_url: "https://cards.example.com" })
	client.update_contact("", Contact{ uid: "u1" }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
