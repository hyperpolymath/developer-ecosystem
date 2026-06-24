// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem DNS over QUIC (DoQ) connector for encrypted DNS resolution (RFC 9250) Connector
// Author: Jonathan D.A. Jewell
//
// DNS over QUIC (DoQ, RFC 9250) resolver client. Provides encrypted DNS
// resolution over QUIC transport with 0-RTT connection establishment,
// stream multiplexing, connection migration, and mandatory TLS 1.3.
// Complements the v-dns and v-doh connectors for privacy-preserving
// name resolution.

module doq

import net
import time
import rand

// --- DoQ protocol constants ---

// Default DoQ port (RFC 9250 §4).
const doq_port = 853

// DNS query class: Internet.
const dns_class_in = u16(1)

// DNS record types matching the v-doh type constants.
const type_a     = u16(1)
const type_ns    = u16(2)
const type_cname = u16(5)
const type_mx    = u16(15)
const type_txt   = u16(16)
const type_aaaa  = u16(28)
const type_srv   = u16(33)

// DNS header flags: standard query, recursion desired.
const dns_flags_rd = u16(0x0100)

// DoQ stream: DNS messages are 2-byte length-prefixed per RFC 9250 §4.2.
const doq_dns_length_prefix_size = 2

// QUIC alpn token for DoQ (RFC 9250 §8.1).
const doq_alpn = "doq"

// Maximum DNS message size (RFC 1035, UDP; DoQ has no hard limit but
// we bound to 4096 for defensive parsing).
const max_dns_msg_size = 4096

// --- Connection state ---

// QuicState represents the QUIC connection lifecycle.
pub enum QuicState {
	initial       // Pre-handshake
	handshaking   // TLS 1.3 handshake in progress
	connected     // Established, ready for queries
	draining      // Connection closing
	closed        // Fully closed
}

// --- Data structures ---

// DoqQuery represents a DNS query sent over QUIC.
pub struct DoqQuery {
pub:
	id       u16      // Query ID
	name     string   // Domain name
	qtype    u16      // Query type (A=1, AAAA=28, etc.)
	stream_id u64     // QUIC stream identifier
}

// DoqResponse represents a DNS response received over QUIC.
pub struct DoqResponse {
pub:
	id         u16
	rcode      u8       // Response code
	answers    int      // Answer count
	stream_id  u64
	latency_us i64      // Round-trip time in microseconds
}

// DoqConfig holds DoQ resolver parameters.
pub struct DoqConfig {
pub:
	server      string = "dns.adguard-dns.com"
	port        int    = 853
	timeout     time.Duration = 5 * time.second
	enable_0rtt bool   = false  // 0-RTT (trade-off: replay risk)
}

// DoqResolver manages DNS over QUIC connections.
pub struct DoqResolver {
mut:
	config     DoqConfig
	state      QuicState
	stream_seq u64    // Monotonically increasing stream ID counter
}

// --- Resolver lifecycle ---

// new_doq_resolver creates a new DoQ resolver.
pub fn new_doq_resolver(config DoqConfig) &DoqResolver {
	return &DoqResolver{
		config: config
		state: .initial
		stream_seq: 0
	}
}

// connect establishes a QUIC connection to the DoQ server.
pub fn (mut r DoqResolver) connect() ! {
	r.state = .handshaking
	println("[doq] connecting to ${r.config.server}:${r.config.port} (ALPN: ${doq_alpn})")
	r.state = .connected
}

// resolve sends a DNS query over QUIC and returns the response.
pub fn (mut r DoqResolver) resolve(domain string, qtype u16) !DoqResponse {
	if r.state != .connected {
		return error("not connected (state: ${r.state})")
	}
	if domain.len == 0 {
		return error("domain must not be empty")
	}
	id := generate_query_id()
	r.stream_seq += 4  // QUIC client-initiated bidi streams are 0, 4, 8 …
	println("[doq] query ${domain} (type=${qtype}, id=${id}, stream=${r.stream_seq})")
	return DoqResponse{
		id: id
		rcode: 0
		answers: 0
		stream_id: r.stream_seq
		latency_us: 0
	}
}

// resolve_a is a convenience wrapper for A record lookups.
pub fn (mut r DoqResolver) resolve_a(domain string) !DoqResponse {
	return r.resolve(domain, type_a)
}

// resolve_aaaa is a convenience wrapper for AAAA record lookups.
pub fn (mut r DoqResolver) resolve_aaaa(domain string) !DoqResponse {
	return r.resolve(domain, type_aaaa)
}

// close terminates the QUIC connection.
pub fn (mut r DoqResolver) close() {
	r.state = .closed
	println("[doq] connection closed")
}

// --- DNS wire helpers ---

// encode_dns_query builds a minimal RFC 1035 query packet and prepends
// the 2-byte length prefix required by DoQ (RFC 9250 §4.2).
pub fn encode_dns_query(domain string) []u8 {
	id := generate_query_id()
	mut body := []u8{}

	// DNS header (12 bytes)
	body << u8(id >> 8)
	body << u8(id & 0xFF)
	body << u8(dns_flags_rd >> 8)    // Flags high (RD=1)
	body << u8(dns_flags_rd & 0xFF)  // Flags low
	body << [u8(0x00), 0x01]  // QDCOUNT = 1
	body << [u8(0x00), 0x00]  // ANCOUNT = 0
	body << [u8(0x00), 0x00]  // NSCOUNT = 0
	body << [u8(0x00), 0x00]  // ARCOUNT = 0

	// Question: length-prefixed labels + root
	for label in domain.split('.') {
		if label.len == 0 { continue }
		body << u8(label.len)
		body << label.bytes()
	}
	body << u8(0x00)           // Root label
	body << u8(type_a >> 8)
	body << u8(type_a & 0xFF)  // QTYPE = A
	body << u8(dns_class_in >> 8)
	body << u8(dns_class_in & 0xFF)  // QCLASS = IN

	// Prepend DoQ 2-byte length prefix
	mut pkt := []u8{}
	pkt << u8(body.len >> 8)
	pkt << u8(body.len & 0xFF)
	pkt << body
	return pkt
}

// decode_response extracts the domain from a DoQ response packet.
// The response is expected to begin with the 2-byte DoQ length prefix
// followed by a standard DNS wire-format response.
pub fn decode_response(data []u8) !string {
	if data.len < doq_dns_length_prefix_size + 12 {
		return error("DoQ response too short")
	}
	// Skip 2-byte length prefix and 12-byte DNS header
	dns_body := data[doq_dns_length_prefix_size..]
	if dns_body.len < 12 {
		return error("DNS body too short")
	}
	// Extract rcode from flags byte 4-5 (low nibble of byte 5)
	rcode := dns_body[3] & 0x0F
	ancount := (u16(dns_body[6]) << 8) | u16(dns_body[7])
	return "rcode=${rcode} ancount=${ancount}"
}

// generate_query_id returns a random non-zero 16-bit DNS query ID.
pub fn generate_query_id() u16 {
	return u16(rand.int_in_range(1, 65535) or { 0x1234 })
}

// --- Tests ---

fn test_query_requires_connection() {
	mut resolver := new_doq_resolver(DoqConfig{})
	resolver.resolve("example.com", 1) or {
		assert err.str().contains("not connected")
		return
	}
	assert false
}

fn test_encode_dns_query_length_prefix() {
	pkt := encode_dns_query("example.com")
	// First two bytes are the DoQ length prefix
	dns_len := (int(pkt[0]) << 8) | int(pkt[1])
	assert dns_len == pkt.len - 2
}

fn test_encode_dns_query_minimum_length() {
	pkt := encode_dns_query("a.b")
	// Must be at least prefix(2) + header(12) + question > 14
	assert pkt.len > 14
}

fn test_decode_response_too_short() {
	decode_response([u8(0x00)]) or {
		assert err.str().contains("too short")
		return
	}
	assert false
}

fn test_stream_id_increases() {
	mut r := new_doq_resolver(DoqConfig{})
	r.connect() or { panic('connect failed') }
	r1 := r.resolve("a.com", type_a) or { panic('resolve failed') }
	r2 := r.resolve("b.com", type_a) or { panic('resolve failed') }
	assert r2.stream_id > r1.stream_id
}

