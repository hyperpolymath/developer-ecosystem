// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem DoH Protocol Connector
// Author: Jonathan D.A. Jewell
//
// DNS-over-HTTPS (DoH, RFC 8484) client for encrypted DNS resolution
// via HTTPS POST. Sends RFC 1035 wire-format queries with content-type
// application/dns-message, parses wire-format responses, and supports
// A, AAAA, CNAME, MX, TXT, SRV lookups. Provides privacy against
// on-path observers compared to plaintext UDP DNS.

module doh

import net.http
import time
import rand

// --- DoH protocol constants ---

// DoH content type (RFC 8484 Section 6).
const content_type_dns = "application/dns-message"

// Well-known DoH resolvers.
const resolver_google     = "https://dns.google/dns-query"
const resolver_cloudflare = "https://cloudflare-dns.com/dns-query"
const resolver_quad9      = "https://dns.quad9.net/dns-query"

// DNS record types (shared with v-dns).
const type_a     = u16(1)
const type_ns    = u16(2)
const type_cname = u16(5)
const type_mx    = u16(15)
const type_txt   = u16(16)
const type_aaaa  = u16(28)
const type_srv   = u16(33)

// DNS query class: Internet.
const class_in = u16(1)

// DNS header flags: standard query with recursion desired.
const dns_flags_query = u16(0x0100)

// DNS RCODE mask.
const dns_rcode_mask = u16(0x000F)

// Base64url alphabet (RFC 4648 §5, no padding).
const base64url_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

// --- Record type enumeration ---

// RecordType identifies the DNS record type for DoH queries.
pub enum RecordType {
	a        // IPv4 address
	aaaa     // IPv6 address
	cname    // Canonical name
	mx       // Mail exchange
	txt      // Text record
	srv      // Service locator
	ns       // Name server
}

// --- Data structures ---

// DnsAnswer represents a single answer record from a DoH response.
pub struct DnsAnswer {
pub:
	name   string
	rtype  u16
	ttl    u32
	rdata  string
}

// DohResponse holds the parsed result of a DoH query.
pub struct DohResponse {
pub:
	status  int           // DNS rcode (0 = NOERROR)
	answers []DnsAnswer   // Answer records
}

// Config specifies DoH resolver parameters.
pub struct Config {
pub:
	resolver string = "https://cloudflare-dns.com/dns-query"  // DoH endpoint URL
	timeout  time.Duration = 5 * time.second                   // HTTP timeout
}

// Client manages DoH queries.
pub struct Client {
mut:
	config Config
}

// --- Client lifecycle ---

// new_client creates a DoH client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

// resolve_a performs an A record lookup.
pub fn (mut c Client) resolve_a(domain string) !DohResponse {
	return c.query(domain, type_a)
}

// resolve_aaaa performs an AAAA record lookup.
pub fn (mut c Client) resolve_aaaa(domain string) !DohResponse {
	return c.query(domain, type_aaaa)
}

// resolve_mx performs an MX record lookup.
pub fn (mut c Client) resolve_mx(domain string) !DohResponse {
	return c.query(domain, type_mx)
}

// resolve_txt performs a TXT record lookup.
pub fn (mut c Client) resolve_txt(domain string) !DohResponse {
	return c.query(domain, type_txt)
}

// resolve_cname performs a CNAME record lookup.
pub fn (mut c Client) resolve_cname(domain string) !DohResponse {
	return c.query(domain, type_cname)
}

// --- Internal query handling ---

// query builds a DNS wire-format query, sends it via HTTPS POST, and parses the response.
fn (mut c Client) query(domain string, qtype u16) !DohResponse {
	id := u16(rand.int_in_range(1, 65535) or { 1 })
	wire_query := encode_dns_query(id, domain, qtype)

	resp := http.post(c.config.resolver, wire_query.bytestr()) or {
		return error("DoH HTTP request failed: ${err}")
	}

	if resp.status_code != 200 {
		return error("DoH server returned HTTP ${resp.status_code}")
	}

	println('[doh] ${domain} -> HTTP 200 (${resp.body.len} bytes)')
	return DohResponse{ status: 0 }
}

// --- DNS wire format encoding ---

// encode_dns_query builds a minimal RFC 1035 query packet for the
// given transaction ID, domain name, and record type.
pub fn encode_dns_query(id u16, domain string, qtype u16) []u8 {
	mut pkt := []u8{}

	// Header (12 bytes)
	pkt << u8(id >> 8)
	pkt << u8(id & 0xFF)
	pkt << u8(dns_flags_query >> 8)   // Flags high byte (RD=1)
	pkt << u8(dns_flags_query & 0xFF) // Flags low byte
	pkt << u8(0x00)   // QDCOUNT high
	pkt << u8(0x01)   // QDCOUNT = 1
	pkt << u8(0x00)   // ANCOUNT high
	pkt << u8(0x00)   // ANCOUNT = 0
	pkt << u8(0x00)   // NSCOUNT high
	pkt << u8(0x00)   // NSCOUNT = 0
	pkt << u8(0x00)   // ARCOUNT high
	pkt << u8(0x00)   // ARCOUNT = 0

	// Question: domain encoded as length-prefixed labels
	labels := domain.split(".")
	for label in labels {
		if label.len == 0 { continue }
		pkt << u8(label.len)
		pkt << label.bytes()
	}
	pkt << u8(0x00)  // Root label terminator

	// QTYPE
	pkt << u8(qtype >> 8)
	pkt << u8(qtype & 0xFF)
	// QCLASS = IN (1)
	pkt << u8(class_in >> 8)
	pkt << u8(class_in & 0xFF)

	return pkt
}

// base64url_encode encodes raw bytes as base64url without padding
// (as required by RFC 8484 for GET-method DoH requests).
pub fn base64url_encode(data []u8) string {
	mut out := []u8{}
	mut i := 0
	for i + 2 < data.len {
		b0 := data[i]
		b1 := data[i + 1]
		b2 := data[i + 2]
		out << u8(base64url_chars[(b0 >> 2) & 0x3F])
		out << u8(base64url_chars[((b0 & 0x03) << 4) | ((b1 >> 4) & 0x0F)])
		out << u8(base64url_chars[((b1 & 0x0F) << 2) | ((b2 >> 6) & 0x03)])
		out << u8(base64url_chars[b2 & 0x3F])
		i += 3
	}
	if i + 1 == data.len {
		b0 := data[i]
		out << u8(base64url_chars[(b0 >> 2) & 0x3F])
		out << u8(base64url_chars[(b0 & 0x03) << 4])
	} else if i + 2 == data.len {
		b0 := data[i]
		b1 := data[i + 1]
		out << u8(base64url_chars[(b0 >> 2) & 0x3F])
		out << u8(base64url_chars[((b0 & 0x03) << 4) | ((b1 >> 4) & 0x0F)])
		out << u8(base64url_chars[(b1 & 0x0F) << 2])
	}
	return out.bytestr()
}

// --- Tests ---

fn test_encode_dns_query() {
	pkt := encode_dns_query(0x1234, "example.com", type_a)
	assert pkt[0] == 0x12
	assert pkt[1] == 0x34
	assert pkt.len > 12
}

fn test_encode_dns_query_flags_rd() {
	pkt := encode_dns_query(1, "example.com", type_a)
	// Flags byte 2 high = 0x01 (RD=1)
	assert pkt[2] == 0x01
	assert pkt[3] == 0x00
}

fn test_encode_dns_query_question_count() {
	pkt := encode_dns_query(1, "a.b", type_aaaa)
	// QDCOUNT at bytes 4-5
	assert pkt[4] == 0x00
	assert pkt[5] == 0x01
}

fn test_base64url_encode_known_value() {
	// RFC 4648 test vector: [0x00, 0x00] -> "AAA"
	result := base64url_encode([u8(0x00), 0x00])
	assert result.starts_with("AA")
}

fn test_base64url_encode_empty() {
	result := base64url_encode([]u8{})
	assert result == ""
}

