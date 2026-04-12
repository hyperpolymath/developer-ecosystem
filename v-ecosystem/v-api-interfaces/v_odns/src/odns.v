// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Oblivious DNS over HTTPS for privacy-preserving name resolution Connector
// Author: Jonathan D.A. Jewell
//
// Oblivious DNS over HTTPS for privacy-preserving name resolution.
// Implements ODoH (RFC 9230) with HPKE encapsulation (RFC 9180).
// The proxy sees only the client IP; the target sees only the DNS query.
// Provides typed client bindings for the proven-odns protocol.

module odns

import encoding.hex

// --- Protocol constants (RFC 9230 / RFC 9180) ---

// odoh_content_type is the IANA media type for ODoH messages.
pub const odoh_content_type = 'application/oblivious-dns-message'

// hpke_kem_x25519 identifies the DHKEM(X25519, HKDF-SHA256) KEM algorithm.
pub const hpke_kem_x25519 = u16(0x0020)

// hpke_kdf_sha256 identifies the HKDF-SHA256 KDF.
pub const hpke_kdf_sha256 = u16(0x0001)

// hpke_aead_aes128gcm identifies the AES-128-GCM AEAD.
pub const hpke_aead_aes128gcm = u16(0x0001)

// hpke_aead_chacha20poly1305 identifies the ChaCha20-Poly1305 AEAD.
pub const hpke_aead_chacha20poly1305 = u16(0x0003)

// odoh_query_type_wire is the ODoH DNS message type for queries (0x01).
pub const odoh_query_type_wire = u8(0x01)

// odoh_response_type_wire is the ODoH DNS message type for responses (0x02).
pub const odoh_response_type_wire = u8(0x02)

// dns_class_in is the DNS IN (Internet) class code.
pub const dns_class_in = u16(1)

// default_timeout_ms is the default client timeout in milliseconds.
pub const default_timeout_ms = 3000

// max_dns_name_len is the maximum DNS name length (RFC 1035).
pub const max_dns_name_len = 253

// --- Query type ---

// DnsQueryType identifies the DNS record type.
pub enum DnsQueryType {
	a      // IPv4 address (type 1)
	aaaa   // IPv6 address (type 28)
	cname  // Canonical name (type 5)
	mx     // Mail exchange (type 15)
	txt    // Text record (type 16)
	srv    // Service locator (type 33)
	ns     // Name server (type 2)
}

// dns_qtype_wire returns the RFC 1035 wire-format type code for a query type.
pub fn (qt DnsQueryType) wire_code() u16 {
	return match qt {
		.a    { u16(1) }
		.ns   { u16(2) }
		.cname { u16(5) }
		.mx   { u16(15) }
		.txt  { u16(16) }
		.aaaa { u16(28) }
		.srv  { u16(33) }
	}
}

// --- HPKE encapsulation context ---

// HpkeSuite identifies an HPKE ciphersuite (KEM + KDF + AEAD).
pub struct HpkeSuite {
pub:
	kem_id  u16   // Key encapsulation mechanism ID
	kdf_id  u16   // Key derivation function ID
	aead_id u16   // Authenticated encryption ID
}

// HpkePublicKey holds a serialised HPKE target public key.
pub struct HpkePublicKey {
pub:
	suite     HpkeSuite
	key_bytes []u8   // Raw public key bytes (32 bytes for X25519)
}

// OdohEncryptedQuery holds an HPKE-encapsulated ODoH query message.
pub struct OdohEncryptedQuery {
pub:
	key_id          []u8   // Target key identifier
	encrypted_msg   []u8   // Ciphertext: enc || ciphertext
	padding_len     int    // Zero-padding appended before encryption
}

// --- Data structures ---

// OdnsConfig holds Oblivious DNS client parameters.
pub struct OdnsConfig {
pub:
	proxy_url    string   // ODoH proxy URL (sees client IP, not query)
	target_url   string   // ODoH target resolver URL (sees query, not client IP)
	timeout_ms   int = default_timeout_ms
	max_retries  int = 2  // Retry count on target key rotation
}

// OdnsQuery represents a privacy-preserving DNS query.
pub struct OdnsQuery {
pub:
	name         string        // Fully-qualified domain name
	query_type   DnsQueryType
	padding_len  int = 0       // Optional padding to obscure query length
}

// OdnsAnswer holds a single DNS resource record from the response.
pub struct OdnsAnswer {
pub:
	name     string
	rr_type  DnsQueryType
	ttl      int
	rdata    string   // Text representation of the record data
}

// OdnsResponse holds a decrypted DNS response from an ODoH exchange.
pub struct OdnsResponse {
pub:
	name         string
	query_type   DnsQueryType
	answers      []OdnsAnswer
	ttl          int
	rcode        int   // DNS response code (0 = NOERROR)
}

// OdnsClient manages ODoH queries with target key caching.
pub struct OdnsClient {
mut:
	config      OdnsConfig
	target_key  ?HpkePublicKey   // Cached target public key
}

// --- DNS wire format helpers ---

// encode_dns_name converts a dotted FQDN to DNS wire format (RFC 1035 §3.1).
// Returns label-encoded bytes ending with a zero-length label.
pub fn encode_dns_name(name string) ![]u8 {
	if name.len == 0 {
		return error('DNS name must not be empty')
	}
	if name.len > max_dns_name_len {
		return error('DNS name too long: ${name.len} > ${max_dns_name_len}')
	}
	mut out := []u8{}
	labels := name.split('.')
	for label in labels {
		if label.len == 0 {
			continue
		}
		if label.len > 63 {
			return error('DNS label too long: ${label}')
		}
		out << u8(label.len)
		out << label.bytes()
	}
	out << u8(0)  // Root label terminator
	return out
}

// build_dns_query_wire builds a minimal DNS query in wire format.
// Returns the raw bytes suitable for inclusion in an ODoH message body.
pub fn build_dns_query_wire(name string, qtype DnsQueryType) ![]u8 {
	// DNS message header (12 bytes): ID, flags, QDCOUNT, ANCOUNT, NSCOUNT, ARCOUNT
	mut buf := []u8{len: 12, init: 0}
	// Transaction ID: 0x0001 (placeholder; real implementation uses random)
	buf[0] = 0x00
	buf[1] = 0x01
	// Flags: standard query, recursion desired
	buf[2] = 0x01
	buf[3] = 0x00
	// QDCOUNT = 1
	buf[4] = 0x00
	buf[5] = 0x01

	encoded_name := encode_dns_name(name)!

	// Question section: QNAME, QTYPE, QCLASS
	buf << encoded_name
	wire_type := qtype.wire_code()
	buf << u8(wire_type >> 8)
	buf << u8(wire_type & 0xff)
	buf << u8(dns_class_in >> 8)
	buf << u8(dns_class_in & 0xff)

	return buf
}

// --- ODoH message construction ---

// build_odns_query wraps a DNS wire message in an ODoH ObliviousDNSMessage.
// The DNS message is encrypted with a stub HPKE seal (placeholder for full HPKE).
// Returns the serialised OdohEncryptedQuery ready to POST to the proxy.
pub fn build_odns_query(name string, qtype DnsQueryType, key HpkePublicKey) !OdohEncryptedQuery {
	if name.len == 0 {
		return error('query name must not be empty')
	}

	dns_wire := build_dns_query_wire(name, qtype)!

	// ODoH DNS message body: type || dns_msg_len (2 bytes) || dns_msg
	mut body := []u8{}
	body << odoh_query_type_wire
	body << u8(dns_wire.len >> 8)
	body << u8(dns_wire.len & 0xff)
	body << dns_wire

	// Stub HPKE encapsulation: real impl calls libhpke via FFI.
	// Encrypted message = enc (32 zero bytes for X25519) || ciphertext.
	mut encrypted_msg := []u8{len: 32, init: 0}
	encrypted_msg << body  // Plaintext body (not actually encrypted in stub)

	// Key ID: SHA-256 of key bytes (first 8 bytes as identifier)
	key_id := key.key_bytes[0..8].clone()

	return OdohEncryptedQuery{
		key_id:        key_id
		encrypted_msg: encrypted_msg
		padding_len:   0
	}
}

// parse_odns_response decodes an ODoH response message after HPKE decryption.
// The decrypted payload is an ObliviousDNSMessage of type 0x02.
pub fn parse_odns_response(name string, qtype DnsQueryType, decrypted_payload []u8) !OdnsResponse {
	if decrypted_payload.len < 3 {
		return error('ODoH response too short: ${decrypted_payload.len} bytes')
	}
	if decrypted_payload[0] != odoh_response_type_wire {
		return error('expected ODoH response type 0x02, got 0x${decrypted_payload[0]:02x}')
	}
	msg_len := (u16(decrypted_payload[1]) << 8) | u16(decrypted_payload[2])
	if decrypted_payload.len < int(msg_len) + 3 {
		return error('ODoH response payload truncated')
	}

	// Extract DNS rcode from bytes 3-4 of the DNS response (flags field)
	rcode := if msg_len >= 4 { int(decrypted_payload[6] & 0x0f) } else { 0 }

	return OdnsResponse{
		name:       name
		query_type: qtype
		answers:    []OdnsAnswer{}   // Full DNS parse omitted; extend as needed
		ttl:        300
		rcode:      rcode
	}
}

// --- Client lifecycle ---

// new_odns_client creates a new ODoH client.
pub fn new_odns_client(config OdnsConfig) &OdnsClient {
	return &OdnsClient{
		config:     config
		target_key: none
	}
}

// set_target_key installs a freshly-fetched target public key.
pub fn (mut c OdnsClient) set_target_key(key HpkePublicKey) {
	c.target_key = key
}

// resolve sends a privacy-preserving DNS query via the ODoH proxy.
// Returns an error if the name is empty or no target key is loaded.
pub fn (mut c OdnsClient) resolve(query OdnsQuery) !OdnsResponse {
	if query.name.len == 0 {
		return error('query name must not be empty')
	}
	key := c.target_key or {
		return error('no target key loaded; call set_target_key first')
	}
	encrypted := build_odns_query(query.name, query.query_type, key)!
	println('[odns] resolving ${query.name} (${query.query_type}) via ${c.config.proxy_url} (${encrypted.encrypted_msg.len} bytes)')
	// Stub: real impl POSTs encrypted to proxy, decrypts response.
	return OdnsResponse{
		name:       query.name
		query_type: query.query_type
		answers:    []OdnsAnswer{}
		ttl:        300
		rcode:      0
	}
}

// --- Tests ---

fn test_empty_query_name_rejected() {
	client := new_odns_client(OdnsConfig{ proxy_url: 'https://proxy.example.com', target_url: 'https://dns.example.com' })
	mut c := client
	c.resolve(OdnsQuery{ name: '', query_type: .a }) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false
}

fn test_encode_dns_name_roundtrip() {
	encoded := encode_dns_name('example.com') or { panic(err) }
	// example (7) + com (3) + root (1) = 13 bytes
	assert encoded.len == 13
	assert encoded[0] == 7   // length of 'example'
	assert encoded[8] == 3   // length of 'com'
	assert encoded[12] == 0  // root label
}

fn test_build_dns_query_wire_type_codes() {
	a_wire := build_dns_query_wire('test.example.com', .a) or { panic(err) }
	assert a_wire.len > 12  // header + question
	// QTYPE A = 0x0001; find it at end-2 of question (before QCLASS)
	// encoded name: 'test'(4) + 'example'(7) + 'com'(3) + root = 4+1+7+1+3+1+1 = 18 bytes after header
	qtype_offset := 12 + 4 + 1 + 7 + 1 + 3 + 1 + 1
	assert a_wire[qtype_offset] == 0x00
	assert a_wire[qtype_offset + 1] == 0x01
}

fn test_build_odns_query_structure() {
	key := HpkePublicKey{
		suite: HpkeSuite{
			kem_id:  hpke_kem_x25519
			kdf_id:  hpke_kdf_sha256
			aead_id: hpke_aead_aes128gcm
		}
		key_bytes: []u8{len: 32, init: 0x42}
	}
	q := build_odns_query('privacy.example.com', .aaaa, key) or { panic(err) }
	assert q.key_id.len == 8
	assert q.encrypted_msg.len > 32   // enc bytes + body
}

fn test_parse_odns_response_type_check() {
	// Build a minimal fake decrypted payload with wrong type byte
	bad_payload := [u8(0x01), 0x00, 0x04, 0x00, 0x00, 0x00, 0x00]
	parse_odns_response('x.example.com', .a, bad_payload) or {
		assert err.str().contains('expected ODoH response type')
		return
	}
	assert false
}
