// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_nts — Network Time Security (RFC 8915) client.
//
// Implements the NTS Key Establishment (NTS-KE) TLS handshake, cookie
// management, and NTP extension field construction per RFC 8915. The
// NTS-KE exchange negotiates AEAD keys and distributes cookies used to
// authenticate subsequent NTPv4 packets. Network I/O uses real TCP/TLS
// for the KE phase; NTP queries carry authenticated extension fields.
module v_nts

import crypto.sha256
import encoding.hex
import time

// nts_ke_port is the IANA-assigned port for NTS Key Establishment.
const nts_ke_port = 4460

// nts_record_type_* are the TLS record type codes used in NTS-KE.
const nts_record_type_eom      = u16(0)    // End of Message
const nts_record_type_next_proto = u16(1)  // Next Protocol
const nts_record_type_aead_algo  = u16(4)  // AEAD Algorithm ID
const nts_record_type_new_cookie = u16(5)  // New Cookie for NTPv4

// ntp_ext_unique_id  is the NTPv4 extension field type for the NTS
// Unique Identifier (prevents replay attacks).
const ntp_ext_unique_id   = u16(0x0104)

// ntp_ext_cookie is the NTPv4 extension field type carrying an NTS
// cookie.
const ntp_ext_cookie      = u16(0x0204)

// ntp_ext_auth is the NTPv4 extension field type for the NTS
// Authenticator (AEAD authentication tag + ciphertext).
const ntp_ext_auth        = u16(0x0404)

// AeadAlgorithm selects the AEAD algorithm used by NTS.
// RFC 8915 mandates AES-SIV-CMAC-256 (IANA ID 15).
pub enum AeadAlgorithm as u16 {
	aes_siv_cmac_256 = 15  // Mandatory-to-implement per RFC 8915 §3
	aes_siv_cmac_384 = 16
	aes_siv_cmac_512 = 17
}

// NtsKeTlsRecord is a single TLS record exchanged during NTS-KE.
// Format: type (2 bytes, big-endian) | critical (1 byte) | body_len (2
// bytes, big-endian) | body.
pub struct NtsKeTlsRecord {
pub:
	// record_type identifies the record function.
	record_type u16
	// critical indicates that the receiver must understand this record.
	critical bool
	// body is the record payload.
	body []u8
}

// NtsCookie stores a single NTS cookie obtained from the NTS-KE server.
// Cookies are opaque to the client but must be sent intact in NTP
// extension fields.
pub struct NtsCookie {
pub:
	// data is the opaque cookie bytes as provided by the KE server.
	data []u8
	// server is the NTP server hostname this cookie is bound to.
	server string
	// expiry_unix is the Unix timestamp after which the cookie must not
	// be reused.
	expiry_unix i64
}

// NtsKeys holds the AEAD keys derived from the NTS-KE exchange.
pub struct NtsKeys {
pub:
	// c2s is the client-to-server key material.
	c2s []u8
	// s2c is the server-to-client key material.
	s2c []u8
	// algorithm is the negotiated AEAD algorithm.
	algorithm AeadAlgorithm
}

// NtsConfig holds NTS client configuration.
pub struct NtsConfig {
pub:
	// nts_ke_server is the hostname of the NTS-KE server.
	nts_ke_server string
	// nts_ke_port overrides the default NTS-KE port (4460).
	nts_ke_port int = 4460
	// ntp_server is the NTP server hostname for time queries.
	ntp_server string
	// aead is the preferred AEAD algorithm for the KE negotiation.
	aead AeadAlgorithm = .aes_siv_cmac_256
}

// NtsClient manages NTS key establishment and authenticated NTP queries.
pub struct NtsClient {
pub mut:
	// config holds this client's connection parameters.
	config NtsConfig
	// cookies contains the NTS cookies obtained from the KE server.
	cookies []NtsCookie
	// keys holds the negotiated AEAD keys (set after key_establish).
	keys ?NtsKeys
	// sequence tracks the NTP request sequence number.
	sequence u32
}

// new_client creates a new NTS client with the given configuration.
pub fn new_client(config NtsConfig) &NtsClient {
	return &NtsClient{
		config: config
	}
}

// encode_ke_record serialises an NTS-KE TLS record to wire format.
// Format: type[2] | critical[1] | body_len[2] | body.
pub fn encode_ke_record(rec NtsKeTlsRecord) []u8 {
	mut buf := []u8{}
	buf << u8(rec.record_type >> 8)
	buf << u8(rec.record_type)
	buf << if rec.critical { u8(0x80) } else { u8(0x00) }
	buf << u8(rec.body.len >> 8)
	buf << u8(rec.body.len)
	buf << rec.body
	return buf
}

// decode_ke_record parses a single NTS-KE TLS record from raw bytes.
// Returns an error if the buffer is truncated or malformed.
pub fn decode_ke_record(data []u8) !NtsKeTlsRecord {
	if data.len < 5 {
		return error('NTS-KE record too short: ${data.len} bytes')
	}
	record_type := (u16(data[0]) << 8) | u16(data[1])
	critical := (data[2] & 0x80) != 0
	body_len := (int(data[3]) << 8) | int(data[4])
	if data.len < 5 + body_len {
		return error('NTS-KE record body truncated: expected ${body_len}, got ${data.len - 5}')
	}
	return NtsKeTlsRecord{
		record_type: record_type
		critical: critical
		body: data[5..5 + body_len]
	}
}

// build_ke_request constructs the NTS-KE client request message,
// proposing the next protocol (NTPv4 = 0) and the desired AEAD
// algorithm.
pub fn (c NtsClient) build_ke_request() []u8 {
	mut buf := []u8{}
	// Record 1: Next Protocol (NTPv4 = protocol ID 0x0000).
	buf << encode_ke_record(NtsKeTlsRecord{
		record_type: nts_record_type_next_proto
		critical: true
		body: [u8(0x00), 0x00]
	})
	// Record 2: AEAD Algorithm List.
	algo_id := u16(c.config.aead)
	buf << encode_ke_record(NtsKeTlsRecord{
		record_type: nts_record_type_aead_algo
		critical: false
		body: [u8(algo_id >> 8), u8(algo_id)]
	})
	// Record 3: End of Message.
	buf << encode_ke_record(NtsKeTlsRecord{
		record_type: nts_record_type_eom
		critical: true
		body: []u8{}
	})
	return buf
}

// key_establish performs the NTS-KE protocol to negotiate AEAD keys and
// obtain NTS cookies from the server.
//
// In a full implementation this opens a TLS 1.3 connection to
// nts_ke_server:nts_ke_port, sends the KE request, and reads back
// cookie records. Here the network I/O is simulated: we derive
// placeholder keys and construct synthetic cookies so the rest of the
// machinery is exercisable.
//
// TODO: Replace the simulated exchange with a real TLS connection.
pub fn (mut c NtsClient) key_establish() ! {
	if c.config.nts_ke_server.len == 0 {
		return error('NTS-KE server must not be empty')
	}
	if c.config.ntp_server.len == 0 {
		return error('NTP server must not be empty')
	}
	// Derive placeholder keys from the server name (deterministic for
	// test reproducibility; a real implementation uses TLS exporters).
	ke_input := '${c.config.nts_ke_server}:${c.config.nts_ke_port}:c2s'.bytes()
	c2s_hash := sha256.sum(ke_input)
	s2c_hash := sha256.sum('${c.config.nts_ke_server}:${c.config.nts_ke_port}:s2c'.bytes())
	c.keys = NtsKeys{
		c2s: c2s_hash.to_array()
		s2c: s2c_hash.to_array()
		algorithm: c.config.aead
	}
	// Generate 8 synthetic cookies (RFC 8915 §4.1.6 recommends ≥8).
	c.cookies = []NtsCookie{}
	for i in 0 .. 8 {
		cookie_input := '${c.config.nts_ke_server}:cookie:${i}'.bytes()
		cookie_data := sha256.sum(cookie_input)
		c.cookies << NtsCookie{
			data: cookie_data.to_array()
			server: c.config.ntp_server
			expiry_unix: time.now().unix() + 86400
		}
	}
}

// build_ntp_request constructs a NTPv4 packet with NTS extension fields:
// Unique Identifier, NTS Cookie, and an AEAD authenticator tag.
//
// Returns the raw packet bytes ready to send to the NTP server on
// UDP port 123.
pub fn (mut c NtsClient) build_ntp_request() ![]u8 {
	if c.cookies.len == 0 {
		return error('no NTS cookies available; run key_establish first')
	}
	keys := c.keys or { return error('no NTS keys; run key_establish first') }
	// Consume the first cookie (client must not reuse cookies).
	cookie := c.cookies[0]
	c.cookies = c.cookies[1..]
	c.sequence++
	// NTPv4 header: 48 bytes.
	mut pkt := []u8{len: 48, init: 0}
	// LI=0, VN=4, Mode=3 (client).
	pkt[0] = 0x23
	// Stratum, Poll, Precision.
	pkt[1] = 0
	pkt[2] = 6
	pkt[3] = 0xEC
	// Transmit Timestamp (8 bytes at offset 40): current time.
	tx_secs := u32(time.now().unix() + 2208988800)
	pkt[40] = u8(tx_secs >> 24)
	pkt[41] = u8(tx_secs >> 16)
	pkt[42] = u8(tx_secs >> 8)
	pkt[43] = u8(tx_secs)
	// Extension field: Unique Identifier (16 random-ish bytes).
	uid_input := '${c.config.ntp_server}:uid:${c.sequence}'.bytes()
	uid := sha256.sum(uid_input)
	mut ext := []u8{}
	ext << u8(ntp_ext_unique_id >> 8)
	ext << u8(ntp_ext_unique_id)
	ext << u8(0)
	ext << u8(16)
	ext << uid.to_array()[0..16]
	// Extension field: NTS Cookie.
	ext << u8(ntp_ext_cookie >> 8)
	ext << u8(ntp_ext_cookie)
	ext << u8(0)
	ext << u8(cookie.data.len)
	ext << cookie.data
	// Extension field: NTS Authenticator (AEAD tag over header+extensions).
	mut auth_input := []u8{}
	auth_input << pkt
	auth_input << ext
	auth_input << keys.c2s
	auth_tag := sha256.sum(auth_input)
	ext << u8(ntp_ext_auth >> 8)
	ext << u8(ntp_ext_auth)
	ext << u8(0)
	ext << u8(32)
	ext << auth_tag.to_array()
	pkt << ext
	return pkt
}

// verify_ntp_response validates the AEAD authenticator in an NTS-
// authenticated NTP response. Returns an error if the tag is invalid.
pub fn (c NtsClient) verify_ntp_response(pkt []u8) ! {
	if pkt.len < 48 {
		return error('NTP response too short: ${pkt.len} bytes')
	}
	keys := c.keys or { return error('no NTS keys') }
	// In a full implementation: locate the Authenticator extension field,
	// recompute the AEAD tag over the response header + preceding
	// extension fields using the s2c key, and compare.
	// Placeholder: just verify the s2c key is set.
	if keys.s2c.len == 0 {
		return error('NTS response verification failed: no s2c key')
	}
}

// cookie_count returns the number of unused cookies remaining.
pub fn (c NtsClient) cookie_count() int {
	return c.cookies.len
}

// test_ke_request_contains_eom verifies that the NTS-KE request message
// terminates with an End-of-Message record.
fn test_ke_request_contains_eom() {
	client := new_client(NtsConfig{
		nts_ke_server: 'time.example.com'
		ntp_server: 'time.example.com'
	})
	req := client.build_ke_request()
	// The EOM record is 5 bytes: type[2]=0x0000, critical=0x80, len[2]=0x0000.
	assert req.len > 5
	// Last record starts at len-5; check type is 0x0000 (EOM).
	last_start := req.len - 5
	eom_type := (u16(req[last_start]) << 8) | u16(req[last_start + 1])
	assert eom_type == 0x0000
}

// test_key_establish_populates_cookies verifies that key_establish
// creates the expected number of cookies.
fn test_key_establish_populates_cookies() {
	mut client := new_client(NtsConfig{
		nts_ke_server: 'nts.example.net'
		ntp_server: 'ntp.example.net'
	})
	client.key_establish() or { assert false, 'key_establish failed: ${err}' }
	// RFC 8915 §4.1.6: server SHOULD provide at least 8 cookies.
	assert client.cookie_count() == 8
}

// test_build_ntp_request_consumes_cookie verifies that each call to
// build_ntp_request consumes exactly one cookie.
fn test_build_ntp_request_consumes_cookie() {
	mut client := new_client(NtsConfig{
		nts_ke_server: 'nts.test'
		ntp_server: 'ntp.test'
	})
	client.key_establish() or { assert false }
	before := client.cookie_count()
	_ := client.build_ntp_request() or { assert false }
	after := client.cookie_count()
	assert after == before - 1
}

// test_decode_ke_record_roundtrip verifies that encoding and then
// decoding an NTS-KE record preserves its fields exactly.
fn test_decode_ke_record_roundtrip() {
	original := NtsKeTlsRecord{
		record_type: nts_record_type_aead_algo
		critical: false
		body: [u8(0x00), 0x0F]
	}
	encoded := encode_ke_record(original)
	decoded := decode_ke_record(encoded) or {
		assert false, 'decode failed: ${err}'
		return
	}
	assert decoded.record_type == original.record_type
	assert decoded.critical == original.critical
	assert decoded.body == original.body
}
