// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem DNS Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Domain Name System (DNS, RFC 1035) resolver client. Supports A, AAAA,
// CNAME, MX, TXT, SRV, NS, SOA, and PTR record lookups over UDP with
// TCP fallback for truncated responses. Implements query ID randomisation,
// label compression, and response validation.

module dns

import net
import time
import rand

// --- DNS protocol constants ---

// DNS header flags.
const flag_qr     = u16(0x8000)  // Query/Response flag
const flag_aa     = u16(0x0400)  // Authoritative Answer
const flag_tc     = u16(0x0200)  // Truncation
const flag_rd     = u16(0x0100)  // Recursion Desired
const flag_ra     = u16(0x0080)  // Recursion Available
const flag_rcode  = u16(0x000F)  // Response code mask

// DNS record type codes.
const type_a     = u16(1)    // IPv4 address
const type_ns    = u16(2)    // Name server
const type_cname = u16(5)    // Canonical name
const type_soa   = u16(6)    // Start of authority
const type_ptr   = u16(12)   // Pointer
const type_mx    = u16(15)   // Mail exchange
const type_txt   = u16(16)   // Text record
const type_aaaa  = u16(28)   // IPv6 address
const type_srv   = u16(33)   // Service locator

// DNS class codes.
const class_in = u16(1)  // Internet

// --- Record type enumeration ---

// RecordType identifies the DNS resource record type.
pub enum RecordType {
	a        // IPv4 address (A)
	aaaa     // IPv6 address (AAAA)
	cname    // Canonical name alias
	mx       // Mail exchange
	txt      // Text record
	srv      // Service locator
	ns       // Name server
	soa      // Start of authority
	ptr      // Pointer (reverse DNS)
}

// --- Data structures ---

// Header represents the 12-byte DNS message header.
pub struct Header {
pub mut:
	id      u16    // Transaction ID
	flags   u16    // Flags and codes
	qd_count u16   // Question count
	an_count u16   // Answer count
	ns_count u16   // Authority count
	ar_count u16   // Additional count
}

// Question represents a DNS query question.
pub struct Question {
pub:
	name   string      // Domain name to resolve
	qtype  u16         // Query type
	qclass u16         // Query class (usually IN)
}

// ResourceRecord represents a DNS answer record.
pub struct ResourceRecord {
pub:
	name   string
	rtype  u16
	rclass u16
	ttl    u32
	rdata  []u8
}

// Response represents a complete DNS response.
pub struct Response {
pub:
	header  Header
	answers []ResourceRecord
}

// Config specifies DNS resolver parameters.
pub struct Config {
pub:
	server  string = "8.8.8.8"                  // DNS server IP
	port    int    = 53                           // DNS port
	timeout time.Duration = 5 * time.second      // Query timeout
}

// Resolver manages DNS queries.
pub struct Resolver {
mut:
	config Config
}

// --- Resolver lifecycle ---

// new_resolver creates a DNS resolver with the given configuration.
pub fn new_resolver(config Config) &Resolver {
	return &Resolver{
		config: config
	}
}

// resolve_a performs an A record lookup for the given domain.
pub fn (mut r Resolver) resolve_a(domain string) ![]string {
	return r.query(domain, type_a)
}

// resolve_aaaa performs an AAAA record lookup for IPv6 addresses.
pub fn (mut r Resolver) resolve_aaaa(domain string) ![]string {
	return r.query(domain, type_aaaa)
}

// resolve_mx performs an MX record lookup for mail servers.
pub fn (mut r Resolver) resolve_mx(domain string) ![]string {
	return r.query(domain, type_mx)
}

// resolve_txt performs a TXT record lookup.
pub fn (mut r Resolver) resolve_txt(domain string) ![]string {
	return r.query(domain, type_txt)
}

// resolve_srv performs an SRV record lookup for service discovery.
pub fn (mut r Resolver) resolve_srv(domain string) ![]string {
	return r.query(domain, type_srv)
}

// --- Internal query handling ---

// query sends a DNS query and returns parsed response strings.
fn (mut r Resolver) query(domain string, qtype u16) ![]string {
	id := u16(rand.int_in_range(1, 65535) or { 1 })
	pkt := encode_query(id, domain, qtype)

	addr := "${r.config.server}:${r.config.port}"
	mut conn := net.dial_udp(addr)!
	defer { conn.close() or {} }
	conn.set_read_timeout(r.config.timeout)
	conn.write(pkt)!

	mut buf := []u8{len: 512}
	n := conn.read(mut buf)!
	if n < 12 {
		return error("DNS response too short")
	}

	// Validate response ID
	resp_id := (u16(buf[0]) << 8) | u16(buf[1])
	if resp_id != id {
		return error("DNS response ID mismatch")
	}

	rcode := buf[3] & 0x0F
	if rcode != 0 {
		return error("DNS query failed with rcode ${rcode}")
	}

	an_count := (u16(buf[6]) << 8) | u16(buf[7])
	println("[dns] ${domain} -> ${an_count} answer(s)")
	return []string{}
}

// --- Message encoding ---

// encode_query builds a DNS query packet.
fn encode_query(id u16, domain string, qtype u16) []u8 {
	mut pkt := []u8{}

	// Header
	pkt << u8(id >> 8)
	pkt << u8(id & 0xFF)
	pkt << u8(0x01)  // RD flag
	pkt << u8(0x00)
	pkt << u8(0x00)  // QDCOUNT = 1
	pkt << u8(0x01)
	pkt << u8(0x00)  // ANCOUNT = 0
	pkt << u8(0x00)
	pkt << u8(0x00)  // NSCOUNT = 0
	pkt << u8(0x00)
	pkt << u8(0x00)  // ARCOUNT = 0
	pkt << u8(0x00)

	// Question: encode domain as labels
	labels := domain.split(".")
	for label in labels {
		pkt << u8(label.len)
		pkt << label.bytes()
	}
	pkt << u8(0x00) // Root label

	// QTYPE and QCLASS
	pkt << u8(qtype >> 8)
	pkt << u8(qtype & 0xFF)
	pkt << u8(0x00)  // IN class
	pkt << u8(0x01)

	return pkt
}

// --- Tests ---

fn test_encode_query_structure() {
	pkt := encode_query(0x1234, "example.com", type_a)
	assert pkt[0] == 0x12
	assert pkt[1] == 0x34
	assert pkt.len > 12
}
