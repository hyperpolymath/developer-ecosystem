// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// dns_test -- Protocol conformance tests for v_dns.
// Covers record type parsing, response code mapping, name encoding/decoding,
// query construction, and encode/decode roundtrips.
module v_dns

import encoding.binary

// test_record_type_from_u16_valid verifies that all known record type
// codes map correctly to their RecordType enum values.
fn test_record_type_from_u16_valid() {
	assert record_type_from_u16(1)! == RecordType.a
	assert record_type_from_u16(2)! == RecordType.ns
	assert record_type_from_u16(5)! == RecordType.cname
	assert record_type_from_u16(6)! == RecordType.soa
	assert record_type_from_u16(12)! == RecordType.ptr
	assert record_type_from_u16(15)! == RecordType.mx
	assert record_type_from_u16(16)! == RecordType.txt
	assert record_type_from_u16(28)! == RecordType.aaaa
	assert record_type_from_u16(33)! == RecordType.srv
	assert record_type_from_u16(257)! == RecordType.caa
}

// test_record_type_from_u16_invalid verifies that unknown type codes
// produce an error.
fn test_record_type_from_u16_invalid() {
	record_type_from_u16(9999) or {
		assert err.msg().contains('unknown DNS record type')
		return
	}
	assert false, 'expected error for unknown record type'
}

// test_record_type_to_string verifies human-readable labels for all
// record types.
fn test_record_type_to_string() {
	assert record_type_to_string(.a) == 'A'
	assert record_type_to_string(.aaaa) == 'AAAA'
	assert record_type_to_string(.cname) == 'CNAME'
	assert record_type_to_string(.mx) == 'MX'
	assert record_type_to_string(.ns) == 'NS'
	assert record_type_to_string(.ptr) == 'PTR'
	assert record_type_to_string(.soa) == 'SOA'
	assert record_type_to_string(.srv) == 'SRV'
	assert record_type_to_string(.txt) == 'TXT'
	assert record_type_to_string(.caa) == 'CAA'
}

// test_response_code_to_string verifies string labels for all DNS
// response codes.
fn test_response_code_to_string() {
	assert response_code_to_string(.no_error) == 'NOERROR'
	assert response_code_to_string(.form_err) == 'FORMERR'
	assert response_code_to_string(.serv_fail) == 'SERVFAIL'
	assert response_code_to_string(.nx_domain) == 'NXDOMAIN'
	assert response_code_to_string(.not_imp) == 'NOTIMP'
	assert response_code_to_string(.refused) == 'REFUSED'
}

// test_encode_name verifies DNS wire-format name encoding.
fn test_encode_name() {
	encoded := encode_name('example.com')
	// Expected: [7, 'e','x','a','m','p','l','e', 3, 'c','o','m', 0]
	assert encoded.len == 13
	assert encoded[0] == 7 // length of "example"
	assert encoded[1..8].bytestr() == 'example'
	assert encoded[8] == 3 // length of "com"
	assert encoded[9..12].bytestr() == 'com'
	assert encoded[12] == 0 // terminator
}

// test_decode_name verifies DNS wire-format name decoding.
fn test_decode_name() {
	data := encode_name('www.example.com')
	name, consumed := decode_name(data, 0)!
	assert name == 'www.example.com'
	assert consumed == data.len
}

// test_name_encode_decode_roundtrip verifies that encoding then decoding
// a domain name produces the original name.
fn test_name_encode_decode_roundtrip() {
	names := ['example.com', 'sub.domain.example.org', 'a.b.c.d.e', 'single']
	for original in names {
		encoded := encode_name(original)
		decoded, _ := decode_name(encoded, 0)!
		assert decoded == original, 'roundtrip failed for "${original}"'
	}
}

// test_parse_packet verifies parsing of a minimal DNS query packet.
fn test_parse_packet() {
	// Build a minimal DNS query packet for "test.com" A record
	mut packet := []u8{len: 12, init: 0} // 12-byte header
	// Set QDCOUNT = 1
	mut qdcount := []u8{len: 2}
	binary.big_endian_put_u16(mut qdcount, 1)
	packet[4] = qdcount[0]
	packet[5] = qdcount[1]
	// Append question: encoded name + type + class
	packet << encode_name('test.com')
	mut qtype := []u8{len: 2}
	binary.big_endian_put_u16(mut qtype, 1) // A record
	packet << qtype
	mut qclass := []u8{len: 2}
	binary.big_endian_put_u16(mut qclass, 1) // IN class
	packet << qclass

	query_result := parse_packet(packet)!
	assert query_result.name == 'test.com'
	assert query_result.record_type == .a
	assert query_result.class_ == 1
}

// test_parse_packet_too_short verifies that truncated packets are rejected.
fn test_parse_packet_too_short() {
	parse_packet([]u8{len: 5}) or {
		assert err.msg().contains('too short')
		return
	}
	assert false, 'expected error for short packet'
}

// test_encode_response verifies that a DnsResponse serialises into
// valid wire-format bytes with the correct header fields.
fn test_encode_response() {
	resp := DnsResponse{
		id: 0xABCD
		response_code: .no_error
		records: [
			DnsRecord{
				name: 'example.com'
				record_type: .a
				ttl: 300
				data: '93.184.216.34'
			},
		]
	}
	encoded := encode_response(resp)
	// Verify transaction ID
	assert encoded[0] == 0xAB
	assert encoded[1] == 0xCD
	// Verify QR bit is set (response)
	assert (encoded[2] & 0x80) != 0
	// Verify ANCOUNT = 1
	ancount := binary.big_endian_u16_at(encoded, 6)
	assert ancount == 1
}

// test_server_zone_lookup verifies that a server with zones can resolve
// records and returns NxDomain for unknown names.
fn test_server_zone_lookup() {
	mut server := new_server(5353)
	server.add_zone(Zone{
		name: 'example.com'
		records: [
			DnsRecord{
				name: 'www.example.com'
				record_type: .a
				ttl: 300
				data: '93.184.216.34'
			},
			DnsRecord{
				name: 'mail.example.com'
				record_type: .mx
				ttl: 600
				data: '10 smtp.example.com'
			},
		]
	})

	// Successful lookup
	record := server.lookup_record('www.example.com', .a)!
	assert record.data == '93.184.216.34'
	assert record.ttl == 300

	// NxDomain lookup
	server.lookup_record('nonexistent.example.com', .a) or {
		assert err.msg().contains('no record found')
		return
	}
	assert false, 'expected error for nonexistent record'
}

// test_server_handle_query verifies the server's query handler returns
// correct responses for existing and missing records.
fn test_server_handle_query() {
	mut server := new_server(5353)
	server.add_zone(Zone{
		name: 'example.com'
		records: [
			DnsRecord{
				name: 'example.com'
				record_type: .ns
				ttl: 3600
				data: 'ns1.example.com'
			},
		]
	})

	// Successful query
	q := DnsQuery{
		name: 'example.com'
		record_type: .ns
	}
	resp := server.handle_query(q, 42)
	assert resp.id == 42
	assert resp.response_code == .no_error
	assert resp.records.len == 1
	assert resp.records[0].data == 'ns1.example.com'

	// NxDomain query
	q2 := DnsQuery{
		name: 'missing.example.com'
		record_type: .a
	}
	resp2 := server.handle_query(q2, 43)
	assert resp2.response_code == .nx_domain
	assert resp2.records.len == 0
}

// test_query_function verifies that the query() function constructs
// a packet and returns a response (currently NxDomain placeholder).
fn test_query_function() {
	resp := query('127.0.0.1', 'example.com', .a)!
	assert resp.id == 0x1234
	assert resp.response_code == .nx_domain
}
