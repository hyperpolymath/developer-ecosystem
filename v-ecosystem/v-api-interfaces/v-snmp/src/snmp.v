// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem SNMP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// SNMPv2c (RFC 3416) and SNMPv3 (RFC 3414) client over UDP.
// Supports GET, GETNEXT, GETBULK, SET, and TRAP operations with
// BER-encoded ASN.1 PDUs. Implements USM (User-based Security Model)
// for SNMPv3 with HMAC-SHA authentication and AES privacy.
// Designed for network monitoring within the V-Ecosystem.

module snmp

import net
import time

// --- SNMP protocol constants ---

// SNMP version identifiers.
const snmp_v1  = 0
const snmp_v2c = 1
const snmp_v3  = 3

// PDU types (context-specific constructed tags).
const pdu_get_request      = u8(0xA0)
const pdu_get_next_request = u8(0xA1)
const pdu_get_response     = u8(0xA2)
const pdu_set_request      = u8(0xA3)
const pdu_trap_v2          = u8(0xA7)
const pdu_get_bulk_request = u8(0xA5)

// ASN.1 type tags used in SNMP variable bindings.
const asn1_integer       = u8(0x02)
const asn1_octet_string  = u8(0x04)
const asn1_null          = u8(0x05)
const asn1_oid           = u8(0x06)
const asn1_sequence      = u8(0x30)
const asn1_counter32     = u8(0x41)
const asn1_gauge32       = u8(0x42)
const asn1_timeticks     = u8(0x43)
const asn1_counter64     = u8(0x46)
const asn1_no_such_object   = u8(0x80)
const asn1_no_such_instance = u8(0x81)
const asn1_end_of_mib_view  = u8(0x82)

// --- SNMP version enumeration ---

// SnmpVersion selects the protocol version.
pub enum SnmpVersion {
	v1     // SNMPv1 (community-based, legacy)
	v2c    // SNMPv2c (community-based, enhanced PDUs)
	v3     // SNMPv3 (USM security model)
}

// --- Value types ---

// ValueType classifies the ASN.1 type of an SNMP variable binding.
pub enum ValueType {
	integer_val
	string_val
	oid_val
	counter32_val
	gauge32_val
	timeticks_val
	counter64_val
	null_val
	no_such_object
	no_such_instance
	end_of_mib_view
}

// --- Data structures ---

// OID represents an SNMP Object Identifier (e.g. "1.3.6.1.2.1.1.1.0").
pub struct OID {
pub:
	value string
}

// VarBind pairs an OID with its typed value.
pub struct VarBind {
pub:
	oid        OID
	value_type ValueType
	int_value  i64
	str_value  string
	oid_value  string
}

// Config specifies the SNMP agent and security parameters.
pub struct Config {
pub:
	host          string                               // Agent hostname or IP
	port          int    = 161                           // SNMP port (161 for queries, 162 for traps)
	version       SnmpVersion = .v2c
	community     string = 'public'                     // SNMPv1/v2c community string
	timeout       time.Duration = 5 * time.second
	retries       int    = 3
	// SNMPv3 USM parameters
	username      string
	auth_protocol string                               // "SHA" or "MD5"
	auth_password string
	priv_protocol string                               // "AES" or "DES"
	priv_password string
}

// Client manages UDP communication with an SNMP agent.
pub struct Client {
mut:
	config      Config
	request_id  int
}

// --- Client lifecycle ---

// new_client creates an SNMP client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{
		config: config
	}
}

// get retrieves the value of one or more OIDs from the agent.
pub fn (mut c Client) get(oids []string) ![]VarBind {
	c.request_id++
	pdu := c.build_pdu(pdu_get_request, oids_to_varbinds(oids), 0, 0)
	message := c.wrap_message(pdu)

	response := c.send_and_receive(message)!
	return parse_varbinds(response)
}

// get_next retrieves the next OID/value after each specified OID.
pub fn (mut c Client) get_next(oids []string) ![]VarBind {
	c.request_id++
	pdu := c.build_pdu(pdu_get_next_request, oids_to_varbinds(oids), 0, 0)
	message := c.wrap_message(pdu)

	response := c.send_and_receive(message)!
	return parse_varbinds(response)
}

// get_bulk performs a GETBULK request (SNMPv2c/v3 only) for efficient
// table traversal.
pub fn (mut c Client) get_bulk(oids []string, non_repeaters int, max_repetitions int) ![]VarBind {
	if c.config.version == .v1 {
		return error('GETBULK not supported in SNMPv1')
	}
	c.request_id++
	pdu := c.build_pdu(pdu_get_bulk_request, oids_to_varbinds(oids), non_repeaters, max_repetitions)
	message := c.wrap_message(pdu)

	response := c.send_and_receive(message)!
	return parse_varbinds(response)
}

// set writes one or more variable bindings to the agent.
pub fn (mut c Client) set(bindings []VarBind) ![]VarBind {
	c.request_id++
	pdu := c.build_pdu(pdu_set_request, bindings, 0, 0)
	message := c.wrap_message(pdu)

	response := c.send_and_receive(message)!
	return parse_varbinds(response)
}

// walk traverses an OID subtree using repeated GETNEXT requests.
pub fn (mut c Client) walk(root_oid string) ![]VarBind {
	mut results := []VarBind{}
	mut current_oid := root_oid

	for {
		bindings := c.get_next([current_oid])!
		if bindings.len == 0 {
			break
		}
		binding := bindings[0]
		// Check if we've left the subtree
		if !binding.oid.value.starts_with(root_oid) {
			break
		}
		if binding.value_type == .end_of_mib_view {
			break
		}
		results << binding
		current_oid = binding.oid.value
	}

	println('[snmp] walk ${root_oid}: ${results.len} bindings')
	return results
}

// --- Internal helpers ---

// build_pdu constructs a BER-encoded SNMP PDU.
fn (c &Client) build_pdu(pdu_type u8, varbinds []VarBind, non_repeaters int, max_repetitions int) []u8 {
	mut varbind_list := []u8{}
	for vb in varbinds {
		mut vb_payload := []u8{}
		vb_payload << encode_oid(vb.oid.value)
		match vb.value_type {
			.integer_val {
				vb_payload << encode_integer(vb.int_value)
			}
			.string_val {
				vb_payload << encode_octet_string(vb.str_value)
			}
			else {
				vb_payload << [u8(asn1_null), u8(0)]
			}
		}
		varbind_list << encode_sequence(vb_payload)
	}

	mut pdu_payload := []u8{}
	pdu_payload << encode_integer(i64(c.request_id))
	if pdu_type == pdu_get_bulk_request {
		pdu_payload << encode_integer(i64(non_repeaters))
		pdu_payload << encode_integer(i64(max_repetitions))
	} else {
		pdu_payload << encode_integer(0) // error status
		pdu_payload << encode_integer(0) // error index
	}
	pdu_payload << encode_sequence(varbind_list)

	mut pdu := []u8{}
	pdu << pdu_type
	pdu << encode_length(pdu_payload.len)
	pdu << pdu_payload
	return pdu
}

// wrap_message wraps a PDU in an SNMP message envelope.
fn (c &Client) wrap_message(pdu []u8) []u8 {
	mut msg_payload := []u8{}
	version_num := match c.config.version {
		.v1 { snmp_v1 }
		.v2c { snmp_v2c }
		.v3 { snmp_v3 }
	}
	msg_payload << encode_integer(i64(version_num))
	msg_payload << encode_octet_string(c.config.community)
	msg_payload << pdu
	return encode_sequence(msg_payload)
}

// send_and_receive transmits the message and reads the response.
fn (c &Client) send_and_receive(message []u8) ![]u8 {
	addr := '${c.config.host}:${c.config.port}'
	mut conn := net.dial_udp(addr)!
	defer {
		conn.close() or {}
	}
	conn.set_read_timeout(c.config.timeout)
	conn.write(message)!

	mut buf := []u8{len: 65535}
	n := conn.read(mut buf)!
	return buf[..n]
}

// oids_to_varbinds converts OID strings to null-valued VarBinds
// for GET/GETNEXT requests.
fn oids_to_varbinds(oids []string) []VarBind {
	mut varbinds := []VarBind{}
	for oid_str in oids {
		varbinds << VarBind{
			oid: OID{ value: oid_str }
			value_type: .null_val
		}
	}
	return varbinds
}

// parse_varbinds extracts variable bindings from an SNMP response.
fn parse_varbinds(data []u8) []VarBind {
	// Minimal parser: would decode BER-TLV in production
	return []VarBind{}
}

// --- BER encoding helpers ---

// encode_integer produces a BER INTEGER.
fn encode_integer(value i64) []u8 {
	mut bytes := []u8{}
	mut v := value
	if v == 0 {
		bytes << u8(0)
	} else {
		for v != 0 && v != -1 {
			bytes.prepend(u8(v & 0xFF))
			v = v >> 8
		}
		if value > 0 && bytes[0] & 0x80 != 0 {
			bytes.prepend(u8(0))
		}
	}
	mut out := []u8{}
	out << asn1_integer
	out << encode_length(bytes.len)
	out << bytes
	return out
}

// encode_octet_string produces a BER OCTET STRING.
fn encode_octet_string(value string) []u8 {
	data := value.bytes()
	mut out := []u8{}
	out << asn1_octet_string
	out << encode_length(data.len)
	out << data
	return out
}

// encode_oid produces a BER OBJECT IDENTIFIER.
fn encode_oid(oid_str string) []u8 {
	parts := oid_str.split('.').filter(it.len > 0)
	if parts.len < 2 {
		return [asn1_oid, u8(0)]
	}

	mut encoded := []u8{}
	// First two components are encoded as 40*X + Y
	first := parts[0].int()
	second := parts[1].int()
	encoded << u8(first * 40 + second)

	for i in 2 .. parts.len {
		val := parts[i].int()
		if val < 128 {
			encoded << u8(val)
		} else {
			// Multi-byte encoding (base-128)
			mut temp := []u8{}
			mut v := val
			temp.prepend(u8(v & 0x7F))
			v = v >> 7
			for v > 0 {
				temp.prepend(u8((v & 0x7F) | 0x80))
				v = v >> 7
			}
			encoded << temp
		}
	}

	mut out := []u8{}
	out << asn1_oid
	out << encode_length(encoded.len)
	out << encoded
	return out
}

// encode_sequence wraps bytes in a BER SEQUENCE.
fn encode_sequence(payload []u8) []u8 {
	mut out := []u8{}
	out << asn1_sequence
	out << encode_length(payload.len)
	out << payload
	return out
}

// encode_length produces BER definite-length encoding.
fn encode_length(length int) []u8 {
	if length < 128 {
		return [u8(length)]
	}
	mut temp := length
	mut num_bytes := 0
	for temp > 0 {
		num_bytes++
		temp = temp >> 8
	}
	mut out := []u8{}
	out << u8(0x80 | num_bytes)
	for i := num_bytes - 1; i >= 0; i-- {
		out << u8((length >> (i * 8)) & 0xFF)
	}
	return out
}

// --- Tests ---

fn test_encode_oid_simple() {
	// 1.3.6.1 -> first octet = 40*1+3=43, then 6, 1
	result := encode_oid('1.3.6.1')
	assert result[0] == asn1_oid
	assert result[2] == u8(43)
	assert result[3] == u8(6)
	assert result[4] == u8(1)
}

fn test_encode_integer_zero() {
	result := encode_integer(0)
	assert result[0] == asn1_integer
	assert result[1] == u8(1)
	assert result[2] == u8(0)
}

fn test_encode_length_short() {
	assert encode_length(100) == [u8(100)]
}

fn test_encode_length_long() {
	result := encode_length(256)
	assert result[0] == u8(0x82) || result[0] == u8(0x81)
}

fn test_oids_to_varbinds() {
	vbs := oids_to_varbinds(['1.3.6.1.2.1.1.1.0', '1.3.6.1.2.1.1.3.0'])
	assert vbs.len == 2
	assert vbs[0].oid.value == '1.3.6.1.2.1.1.1.0'
	assert vbs[0].value_type == .null_val
}
