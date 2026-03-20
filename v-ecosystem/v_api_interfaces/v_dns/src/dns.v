// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_dns -- DNS protocol client and server types for the V-Ecosystem.
// Maps to proven-servers/protocols/proven-dns.
// Implements DNS query construction, response parsing, zone-based serving,
// and wire-format encoding/decoding per RFC 1035.
module v_dns

import encoding.binary
import net

// RecordType enumerates the DNS resource record types supported by this
// connector. Values correspond to the IANA-assigned type codes.
pub enum RecordType as u16 {
	a     = 1
	aaaa  = 28
	cname = 5
	mx    = 15
	ns    = 2
	ptr   = 12
	soa   = 6
	srv   = 33
	txt   = 16
	caa   = 257
}

// record_type_from_u16 converts a raw 16-bit integer to a RecordType.
// Returns an error if the value does not map to a known type.
pub fn record_type_from_u16(val u16) !RecordType {
	return match val {
		1 { RecordType.a }
		2 { RecordType.ns }
		5 { RecordType.cname }
		6 { RecordType.soa }
		12 { RecordType.ptr }
		15 { RecordType.mx }
		16 { RecordType.txt }
		28 { RecordType.aaaa }
		33 { RecordType.srv }
		257 { RecordType.caa }
		else { error('unknown DNS record type: ${val}') }
	}
}

// record_type_to_string returns the human-readable label for a RecordType.
pub fn record_type_to_string(rt RecordType) string {
	return match rt {
		.a { 'A' }
		.aaaa { 'AAAA' }
		.cname { 'CNAME' }
		.mx { 'MX' }
		.ns { 'NS' }
		.ptr { 'PTR' }
		.soa { 'SOA' }
		.srv { 'SRV' }
		.txt { 'TXT' }
		.caa { 'CAA' }
	}
}

// ResponseCode enumerates DNS response codes (RCODE) per RFC 1035 section 4.1.1.
pub enum ResponseCode as u8 {
	no_error  = 0
	form_err  = 1
	serv_fail = 2
	nx_domain = 3
	not_imp   = 4
	refused   = 5
}

// response_code_to_string returns the human-readable label for a ResponseCode.
pub fn response_code_to_string(rc ResponseCode) string {
	return match rc {
		.no_error { 'NOERROR' }
		.form_err { 'FORMERR' }
		.serv_fail { 'SERVFAIL' }
		.nx_domain { 'NXDOMAIN' }
		.not_imp { 'NOTIMP' }
		.refused { 'REFUSED' }
	}
}

// DnsQuery represents a single DNS question entry. Comprises a domain name,
// the desired record type, and a query class (typically 1 for IN / Internet).
pub struct DnsQuery {
pub:
	// name is the fully-qualified domain name being queried.
	name string
	// record_type is the desired resource record type.
	record_type RecordType
	// class_ is the DNS class (1 = IN). Trailing underscore avoids V keyword clash.
	class_ u16 = 1
}

// DnsRecord represents a single DNS resource record in a response.
pub struct DnsRecord {
pub:
	// name is the domain name this record belongs to.
	name string
	// record_type identifies the kind of record (A, AAAA, CNAME, etc.).
	record_type RecordType
	// ttl is the time-to-live in seconds.
	ttl u32
	// data holds the record payload as a human-readable string
	// (e.g. "93.184.216.34" for an A record).
	data string
}

// DnsResponse holds a complete DNS reply including the transaction id,
// a response code, and the list of answer records.
pub struct DnsResponse {
pub:
	// id is the 16-bit transaction identifier echoed from the query.
	id u16
	// response_code indicates success or the type of failure.
	response_code ResponseCode
	// records contains the answer resource records.
	records []DnsRecord
}

// Zone represents a DNS zone with its name and the resource records it holds.
pub struct Zone {
pub:
	// name is the zone origin (e.g. "example.com").
	name string
	// records are the resource records belonging to this zone.
	records []DnsRecord
}

// DnsServer holds the state for a DNS server that can serve queries
// against a set of configured zones.
pub struct DnsServer {
pub:
	// port is the UDP port the server listens on (default 53).
	port int
pub mut:
	// zones contains the zone data the server can answer from.
	zones []Zone
	// handler is an optional custom query handler function.
	// When set, it overrides the default zone-lookup behaviour.
	handler ?fn (DnsQuery) DnsResponse
}

// new_server creates a new DnsServer listening on the given UDP port.
pub fn new_server(port int) &DnsServer {
	return &DnsServer{
		port: port
	}
}

// add_zone registers a zone with the server. Queries matching this zone's
// name will be answered from its records.
pub fn (mut s DnsServer) add_zone(zone Zone) {
	s.zones << zone
}

// lookup_record searches the server's zones for a record matching the
// given name and type. Returns the first matching record or an error.
pub fn (s DnsServer) lookup_record(name string, rtype RecordType) !DnsRecord {
	for zone in s.zones {
		// Check if the queried name falls within this zone
		if name.ends_with(zone.name) || name == zone.name {
			for record in zone.records {
				if record.name == name && record.record_type == rtype {
					return record
				}
			}
		}
	}
	return error('no record found for ${name} ${record_type_to_string(rtype)}')
}

// handle_query processes a DnsQuery against the server's zones and returns
// an appropriate DnsResponse. Uses the custom handler if one is set.
pub fn (s DnsServer) handle_query(q DnsQuery, id u16) DnsResponse {
	// Delegate to custom handler if provided
	if handler := s.handler {
		return handler(q)
	}

	// Default zone-based lookup
	record := s.lookup_record(q.name, q.record_type) or {
		return DnsResponse{
			id: id
			response_code: .nx_domain
			records: []
		}
	}
	return DnsResponse{
		id: id
		response_code: .no_error
		records: [record]
	}
}

// serve starts the DNS server, listening on the configured UDP port.
// Blocks until an error occurs or the server is shut down.
// TODO: Full network I/O -- currently logs a start message and returns.
pub fn (mut s DnsServer) serve() ! {
	println('v_dns server starting on UDP port ${s.port}...')
	// TODO: Bind UDP socket via net.open_udp and enter receive loop.
	//       For each datagram:
	//       1. parse_packet(data)
	//       2. handle_query(query, id)
	//       3. encode_response(response) and send reply
	// Placeholder: open the socket to validate the port is usable.
	mut conn := net.open_udp(s.port)!
	defer {
		conn.close() or {}
	}
	println('v_dns server listening on UDP port ${s.port}')
}

// encode_name converts a dotted domain name to DNS wire-format labels.
// Each label is preceded by its length byte, terminated by a zero-length label.
pub fn encode_name(name string) []u8 {
	mut result := []u8{}
	labels := name.split('.')
	for label in labels {
		if label.len == 0 {
			continue
		}
		result << u8(label.len)
		result << label.bytes()
	}
	result << u8(0) // terminating zero-length label
	return result
}

// decode_name reads a DNS wire-format name from the given byte slice starting
// at the provided offset. Returns the decoded dotted name and the number of
// bytes consumed.
pub fn decode_name(data []u8, start int) !(string, int) {
	mut labels := []string{}
	mut pos := start
	mut jumped := false
	mut jump_pos := 0

	for pos < data.len {
		length := int(data[pos])
		if length == 0 {
			if !jumped {
				jump_pos = pos + 1
			}
			break
		}
		// Compression pointer (top two bits set)
		if length & 0xC0 == 0xC0 {
			if pos + 1 >= data.len {
				return error('truncated compression pointer')
			}
			offset := (int(data[pos] & 0x3F) << 8) | int(data[pos + 1])
			if !jumped {
				jump_pos = pos + 2
			}
			pos = offset
			jumped = true
			continue
		}
		pos++
		if pos + length > data.len {
			return error('label extends beyond packet')
		}
		labels << data[pos..pos + length].bytestr()
		pos += length
	}

	consumed := if jumped { jump_pos - start } else { pos + 1 - start }
	return labels.join('.'), consumed
}

// parse_packet decodes a raw DNS query packet into a DnsQuery.
// Expects at least a 12-byte header and one question section entry.
pub fn parse_packet(data []u8) !DnsQuery {
	if data.len < 12 {
		return error('packet too short: need at least 12 bytes, got ${data.len}')
	}
	// Skip the 12-byte header; parse the first question
	name, name_len := decode_name(data, 12)!
	qtype_offset := 12 + name_len
	if qtype_offset + 4 > data.len {
		return error('packet truncated in question section')
	}
	raw_type := binary.big_endian_u16_at(data, qtype_offset)
	raw_class := binary.big_endian_u16_at(data, qtype_offset + 2)
	rtype := record_type_from_u16(raw_type)!
	return DnsQuery{
		name: name
		record_type: rtype
		class_: raw_class
	}
}

// encode_response serialises a DnsResponse into DNS wire-format bytes
// suitable for sending over UDP.
pub fn encode_response(resp DnsResponse) []u8 {
	mut buf := []u8{len: 0, cap: 512}
	// Transaction ID
	mut id_bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut id_bytes, resp.id)
	buf << id_bytes

	// Flags: QR=1 (response), opcode=0, AA=1, TC=0, RD=1, RA=1, rcode
	flags := u16(0x8400) | u16(resp.response_code)
	mut flag_bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut flag_bytes, flags)
	buf << flag_bytes

	// QDCOUNT = 0, ANCOUNT = number of records, NSCOUNT = 0, ARCOUNT = 0
	mut count_bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut count_bytes, 0)
	buf << count_bytes // QDCOUNT
	binary.big_endian_put_u16(mut count_bytes, u16(resp.records.len))
	buf << count_bytes // ANCOUNT
	binary.big_endian_put_u16(mut count_bytes, 0)
	buf << count_bytes // NSCOUNT
	buf << count_bytes // ARCOUNT (reuse zero)

	// Answer section
	for record in resp.records {
		// Name
		buf << encode_name(record.name)
		// Type
		mut type_bytes := []u8{len: 2}
		binary.big_endian_put_u16(mut type_bytes, u16(record.record_type))
		buf << type_bytes
		// Class IN
		mut class_bytes := []u8{len: 2}
		binary.big_endian_put_u16(mut class_bytes, 1)
		buf << class_bytes
		// TTL
		mut ttl_bytes := []u8{len: 4}
		binary.big_endian_put_u32(mut ttl_bytes, record.ttl)
		buf << ttl_bytes
		// RDATA -- encode data as raw bytes with length prefix
		rdata := record.data.bytes()
		mut rdata_len := []u8{len: 2}
		binary.big_endian_put_u16(mut rdata_len, u16(rdata.len))
		buf << rdata_len
		buf << rdata
	}
	return buf
}

// query sends a DNS query to the specified server address for the given
// name and record type. Returns the parsed response.
// TODO: Full network I/O -- currently constructs the query packet and
//       returns a simulated NxDomain response.
pub fn query(server string, name string, rtype RecordType) !DnsResponse {
	// Build the query packet
	mut packet := []u8{len: 0, cap: 512}
	// Transaction ID (fixed for now; production code should randomise)
	mut id_bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut id_bytes, 0x1234)
	packet << id_bytes
	// Flags: QR=0 (query), RD=1
	mut flag_bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut flag_bytes, 0x0100)
	packet << flag_bytes
	// QDCOUNT=1, ANCOUNT=0, NSCOUNT=0, ARCOUNT=0
	mut one := []u8{len: 2}
	binary.big_endian_put_u16(mut one, 1)
	packet << one
	mut zero := []u8{len: 2}
	binary.big_endian_put_u16(mut zero, 0)
	packet << zero
	packet << zero
	packet << zero
	// Question section
	packet << encode_name(name)
	mut type_bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut type_bytes, u16(rtype))
	packet << type_bytes
	mut class_bytes := []u8{len: 2}
	binary.big_endian_put_u16(mut class_bytes, 1)
	packet << class_bytes

	// TODO: Send packet via UDP to server:53 and parse the response.
	//       For now, return a placeholder NxDomain so the API is exercisable
	//       without network access.
	_ = server
	return DnsResponse{
		id: 0x1234
		response_code: .nx_domain
		records: []
	}
}
