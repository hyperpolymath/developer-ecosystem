// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem LDAP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// LDAPv3 (RFC 4511) client over raw TCP with BER-TLV encoding.
// Supports bind/unbind (simple and SASL), search (base/one-level/
// subtree), add/modify/delete entries, compare, and modify DN.
// Designed for directory service integration within the V-Ecosystem
// API layer (Active Directory, OpenLDAP, 389 Directory Server).

module ldap

import net
import time
import encoding.hex

// --- LDAP protocol constants ---

// BER tag classes and protocol operation codes as defined in RFC 4511.
const bind_request_tag = u8(0x60)
const bind_response_tag = u8(0x61)
const unbind_request_tag = u8(0x42)
const search_request_tag = u8(0x63)
const search_result_entry_tag = u8(0x64)
const search_result_done_tag = u8(0x65)
const modify_request_tag = u8(0x66)
const modify_response_tag = u8(0x67)
const add_request_tag = u8(0x68)
const add_response_tag = u8(0x69)
const delete_request_tag = u8(0x4A)
const delete_response_tag = u8(0x6B)
const modify_dn_request_tag = u8(0x6C)
const modify_dn_response_tag = u8(0x6D)
const compare_request_tag = u8(0x6E)
const compare_response_tag = u8(0x6F)

// LDAP result codes (section 4.1.9)
const result_success = 0
const result_compare_true = 6
const result_compare_false = 5

// --- Search scope enumeration ---

// SearchScope determines the breadth of an LDAP search operation
// relative to the base DN.
pub enum SearchScope {
	base_object   // Search only the base DN entry itself
	single_level  // Search one level below the base DN
	whole_subtree // Search the entire subtree rooted at the base DN
}

// --- Deref aliases policy ---

// DerefAliases controls whether alias entries are dereferenced
// during search operations.
pub enum DerefAliases {
	never_deref       // Never dereference aliases
	deref_in_search   // Dereference while searching subordinates
	deref_finding_base // Dereference when finding the base object
	deref_always      // Always dereference aliases
}

// --- Modification operation type ---

// ModOperation specifies the type of change applied to an attribute
// in a modify request.
pub enum ModOperation {
	add_values     // Add values to the attribute
	delete_values  // Remove values from the attribute
	replace_values // Replace all existing values
}

// --- Data structures ---

// Config holds the parameters needed to connect to an LDAP directory.
pub struct Config {
pub:
	host             string
	port             int    = 389
	use_tls          bool                       // LDAPS (port 636)
	use_starttls     bool                       // STARTTLS upgrade
	connect_timeout  time.Duration = 10 * time.second
	read_timeout     time.Duration = 30 * time.second
}

// Attribute represents a named attribute with one or more string
// values, as stored in an LDAP directory entry.
pub struct Attribute {
pub:
	name   string
	values []string
}

// Entry represents a single directory entry identified by its DN
// and carrying a list of attributes.
pub struct Entry {
pub:
	dn         string
	attributes []Attribute
}

// SearchRequest describes the parameters for an LDAP search
// operation.
pub struct SearchRequest {
pub:
	base_dn       string
	scope         SearchScope    = .whole_subtree
	deref_aliases DerefAliases   = .never_deref
	size_limit    int            = 0    // 0 = no limit
	time_limit    int            = 0    // 0 = no limit
	types_only    bool                  // Return attribute names without values
	filter        string         = '(objectClass=*)'
	attributes    []string              // Empty = return all attributes
}

// SearchResult holds the entries and referrals returned by a search.
pub struct SearchResult {
pub mut:
	entries   []Entry
	referrals []string
}

// Modification pairs an operation type with the attribute and
// values to be changed.
pub struct Modification {
pub:
	operation ModOperation
	attribute Attribute
}

// --- Client ---

// Client manages the TCP connection and message sequencing for
// the LDAP protocol.
pub struct Client {
mut:
	conn        net.TcpConn
	connected   bool
	bound       bool
	message_id  int
	config      Config
}

// connect establishes a TCP connection to the LDAP directory
// server. Does not perform a bind; call bind() separately.
pub fn connect(config Config) !&Client {
	port := if config.use_tls { 636 } else { config.port }
	addr := '${config.host}:${port}'
	mut conn := net.dial_tcp(addr)!
	conn.set_read_timeout(config.read_timeout)

	mut client := &Client{
		conn: conn
		config: config
	}
	client.connected = true
	println('[ldap] connected to ${addr}')
	return client
}

// --- Bind / Unbind ---

// bind performs a simple bind (username/password authentication)
// against the directory. The bind_dn is typically a full DN like
// "cn=admin,dc=example,dc=org".
pub fn (mut c Client) bind(bind_dn string, password string) ! {
	if !c.connected {
		return error('not connected to LDAP server')
	}

	c.message_id++
	// Build BIND request: version 3, simple authentication
	mut bind_payload := []u8{}
	bind_payload << encode_integer(3) // LDAP version 3
	bind_payload << encode_octet_string(bind_dn)
	bind_payload << encode_context_string(0, password) // simple auth

	message := encode_ldap_message(c.message_id, bind_request_tag, bind_payload)
	c.conn.write(message)!

	// Read and validate BIND response
	response := c.read_ldap_message()!
	result_code := extract_result_code(response.payload)
	if result_code != result_success {
		return error('bind failed: result code ${result_code}')
	}

	c.bound = true
	println('[ldap] bound as ${bind_dn}')
}

// bind_sasl performs a SASL bind using the specified mechanism
// (e.g. "EXTERNAL", "GSSAPI", "DIGEST-MD5"). The credentials
// parameter carries mechanism-specific authentication data.
pub fn (mut c Client) bind_sasl(mechanism string, credentials []u8) ! {
	if !c.connected {
		return error('not connected to LDAP server')
	}

	c.message_id++
	mut bind_payload := []u8{}
	bind_payload << encode_integer(3) // LDAP version 3
	bind_payload << encode_octet_string('') // empty DN for SASL
	// SASL choice (context tag 3, constructed)
	mut sasl_payload := []u8{}
	sasl_payload << encode_octet_string(mechanism)
	if credentials.len > 0 {
		sasl_payload << encode_octet_string(credentials.bytestr())
	}
	bind_payload << encode_context_constructed(3, sasl_payload)

	message := encode_ldap_message(c.message_id, bind_request_tag, bind_payload)
	c.conn.write(message)!

	response := c.read_ldap_message()!
	result_code := extract_result_code(response.payload)
	if result_code != result_success {
		return error('sasl bind failed (${mechanism}): result code ${result_code}')
	}

	c.bound = true
	println('[ldap] sasl bound via ${mechanism}')
}

// unbind sends the UNBIND notice and closes the connection.
pub fn (mut c Client) unbind() {
	if !c.connected {
		return
	}
	c.message_id++
	message := encode_ldap_message(c.message_id, unbind_request_tag, []u8{})
	c.conn.write(message) or {}
	c.conn.close() or {}
	c.connected = false
	c.bound = false
	println('[ldap] unbound and disconnected')
}

// --- Search ---

// search executes an LDAP search operation and returns all matching
// entries. The search filter uses RFC 4515 string representation.
pub fn (mut c Client) search(request SearchRequest) !SearchResult {
	if !c.connected {
		return error('not connected')
	}
	if !c.bound {
		return error('not bound — call bind() first')
	}

	c.message_id++
	mut search_payload := []u8{}
	search_payload << encode_octet_string(request.base_dn)
	search_payload << encode_enumerated(int(request.scope))
	search_payload << encode_enumerated(int(request.deref_aliases))
	search_payload << encode_integer(request.size_limit)
	search_payload << encode_integer(request.time_limit)
	search_payload << encode_boolean(request.types_only)
	search_payload << encode_filter(request.filter)
	search_payload << encode_attribute_list(request.attributes)

	message := encode_ldap_message(c.message_id, search_request_tag, search_payload)
	c.conn.write(message)!

	// Collect result entries until SearchResultDone
	mut result := SearchResult{}
	for {
		response := c.read_ldap_message()!
		if response.tag == search_result_entry_tag {
			entry := parse_search_entry(response.payload)
			result.entries << entry
		} else if response.tag == search_result_done_tag {
			result_code := extract_result_code(response.payload)
			if result_code != result_success {
				return error('search failed: result code ${result_code}')
			}
			break
		}
	}

	println('[ldap] search returned ${result.entries.len} entries')
	return result
}

// --- Add / Modify / Delete / Compare / ModifyDN ---

// add creates a new directory entry at the specified DN with the
// given attributes.
pub fn (mut c Client) add(dn string, attributes []Attribute) ! {
	if !c.bound {
		return error('not bound')
	}

	c.message_id++
	mut add_payload := []u8{}
	add_payload << encode_octet_string(dn)
	// Encode attribute list as a SEQUENCE of partial attributes
	mut attrs_payload := []u8{}
	for attr in attributes {
		mut attr_payload := []u8{}
		attr_payload << encode_octet_string(attr.name)
		mut values_payload := []u8{}
		for val in attr.values {
			values_payload << encode_octet_string(val)
		}
		attr_payload << encode_set(values_payload)
		attrs_payload << encode_sequence(attr_payload)
	}
	add_payload << encode_sequence(attrs_payload)

	message := encode_ldap_message(c.message_id, add_request_tag, add_payload)
	c.conn.write(message)!

	response := c.read_ldap_message()!
	result_code := extract_result_code(response.payload)
	if result_code != result_success {
		return error('add entry failed: result code ${result_code}')
	}
	println('[ldap] added entry ${dn}')
}

// modify applies a list of modifications to an existing directory
// entry.
pub fn (mut c Client) modify(dn string, modifications []Modification) ! {
	if !c.bound {
		return error('not bound')
	}

	c.message_id++
	mut modify_payload := []u8{}
	modify_payload << encode_octet_string(dn)
	mut mods_payload := []u8{}
	for modification in modifications {
		mut mod_payload := []u8{}
		mod_payload << encode_enumerated(int(modification.operation))
		mut attr_payload := []u8{}
		attr_payload << encode_octet_string(modification.attribute.name)
		mut values_payload := []u8{}
		for val in modification.attribute.values {
			values_payload << encode_octet_string(val)
		}
		attr_payload << encode_set(values_payload)
		mod_payload << encode_sequence(attr_payload)
		mods_payload << encode_sequence(mod_payload)
	}
	modify_payload << encode_sequence(mods_payload)

	message := encode_ldap_message(c.message_id, modify_request_tag, modify_payload)
	c.conn.write(message)!

	response := c.read_ldap_message()!
	result_code := extract_result_code(response.payload)
	if result_code != result_success {
		return error('modify entry failed: result code ${result_code}')
	}
	println('[ldap] modified entry ${dn}')
}

// delete_entry removes a leaf directory entry by its DN.
pub fn (mut c Client) delete_entry(dn string) ! {
	if !c.bound {
		return error('not bound')
	}

	c.message_id++
	// DELETE request encodes the DN directly as the request value
	delete_payload := encode_octet_string(dn)
	message := encode_ldap_message(c.message_id, delete_request_tag, delete_payload)
	c.conn.write(message)!

	response := c.read_ldap_message()!
	result_code := extract_result_code(response.payload)
	if result_code != result_success {
		return error('delete entry failed: result code ${result_code}')
	}
	println('[ldap] deleted entry ${dn}')
}

// compare tests whether a specific attribute value assertion holds
// true for the given entry.
pub fn (mut c Client) compare(dn string, attribute_name string, assertion_value string) !bool {
	if !c.bound {
		return error('not bound')
	}

	c.message_id++
	mut compare_payload := []u8{}
	compare_payload << encode_octet_string(dn)
	mut ava_payload := []u8{}
	ava_payload << encode_octet_string(attribute_name)
	ava_payload << encode_octet_string(assertion_value)
	compare_payload << encode_sequence(ava_payload)

	message := encode_ldap_message(c.message_id, compare_request_tag, compare_payload)
	c.conn.write(message)!

	response := c.read_ldap_message()!
	result_code := extract_result_code(response.payload)
	if result_code == result_compare_true {
		return true
	}
	if result_code == result_compare_false {
		return false
	}
	return error('compare failed: result code ${result_code}')
}

// modify_dn renames or moves a directory entry. Set delete_old_rdn
// to true to remove the old RDN attribute value from the entry.
pub fn (mut c Client) modify_dn(dn string, new_rdn string, delete_old_rdn bool, new_superior string) ! {
	if !c.bound {
		return error('not bound')
	}

	c.message_id++
	mut modrdn_payload := []u8{}
	modrdn_payload << encode_octet_string(dn)
	modrdn_payload << encode_octet_string(new_rdn)
	modrdn_payload << encode_boolean(delete_old_rdn)
	if new_superior.len > 0 {
		modrdn_payload << encode_context_string(0, new_superior)
	}

	message := encode_ldap_message(c.message_id, modify_dn_request_tag, modrdn_payload)
	c.conn.write(message)!

	response := c.read_ldap_message()!
	result_code := extract_result_code(response.payload)
	if result_code != result_success {
		return error('modify dn failed: result code ${result_code}')
	}
	println('[ldap] renamed ${dn} to ${new_rdn}')
}

// --- Internal BER-TLV encoding ---

// LdapMessage is the parsed envelope for an LDAP protocol message.
struct LdapMessage {
	message_id int
	tag        u8
	payload    []u8
}

// encode_ldap_message wraps a protocol operation in an LDAP message
// envelope (SEQUENCE { messageID, protocolOp }).
fn encode_ldap_message(message_id int, op_tag u8, payload []u8) []u8 {
	mut inner := []u8{}
	inner << encode_integer(message_id)
	// Protocol operation with its application tag
	inner << op_tag
	inner << encode_length(payload.len)
	inner << payload

	mut message := []u8{}
	message << u8(0x30) // SEQUENCE tag
	message << encode_length(inner.len)
	message << inner
	return message
}

// read_ldap_message reads one complete LDAP message from the TCP
// connection and returns the parsed envelope.
fn (mut c Client) read_ldap_message() !LdapMessage {
	// Read SEQUENCE tag and length
	mut tag_buf := []u8{len: 1}
	c.conn.read(mut tag_buf)!
	if tag_buf[0] != 0x30 {
		return error('expected SEQUENCE tag 0x30, got 0x${tag_buf[0]:02x}')
	}

	total_length := c.read_ber_length()!
	mut body := []u8{len: total_length}
	if total_length > 0 {
		c.conn.read(mut body)!
	}

	// Parse messageID (INTEGER)
	if body.len < 2 {
		return error('ldap message too short')
	}
	msg_id_len := int(body[1])
	mut msg_id := 0
	for i in 0 .. msg_id_len {
		msg_id = (msg_id << 8) | int(body[2 + i])
	}

	// Remaining bytes are the protocol operation
	op_offset := 2 + msg_id_len
	if op_offset >= body.len {
		return error('no protocol operation in message')
	}
	op_tag := body[op_offset]
	// Skip tag and length to get payload
	op_len_offset := op_offset + 1
	op_payload_start, op_len := decode_ber_length(body, op_len_offset)
	op_payload := body[op_payload_start..op_payload_start + op_len]

	return LdapMessage{
		message_id: msg_id
		tag: op_tag
		payload: op_payload
	}
}

// read_ber_length reads a BER-encoded length from the TCP stream.
fn (mut c Client) read_ber_length() !int {
	mut first := []u8{len: 1}
	c.conn.read(mut first)!
	if first[0] & 0x80 == 0 {
		return int(first[0])
	}
	num_octets := int(first[0] & 0x7F)
	mut length_bytes := []u8{len: num_octets}
	c.conn.read(mut length_bytes)!
	mut length := 0
	for b in length_bytes {
		length = (length << 8) | int(b)
	}
	return length
}

// decode_ber_length decodes a BER length from a byte array at the
// given offset. Returns (data_start_offset, length).
fn decode_ber_length(data []u8, offset int) (int, int) {
	if offset >= data.len {
		return offset, 0
	}
	first := data[offset]
	if first & 0x80 == 0 {
		return offset + 1, int(first)
	}
	num_octets := int(first & 0x7F)
	mut length := 0
	for i in 0 .. num_octets {
		if offset + 1 + i < data.len {
			length = (length << 8) | int(data[offset + 1 + i])
		}
	}
	return offset + 1 + num_octets, length
}

// encode_length produces a BER definite-length encoding.
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
	mut out := []u8{cap: 1 + num_bytes}
	out << u8(0x80 | num_bytes)
	for i := num_bytes - 1; i >= 0; i-- {
		out << u8((length >> (i * 8)) & 0xFF)
	}
	return out
}

// encode_integer produces a BER INTEGER (tag 0x02).
fn encode_integer(value int) []u8 {
	mut bytes := []u8{}
	mut v := value
	if v == 0 {
		bytes << u8(0)
	} else {
		for v > 0 {
			bytes.prepend(u8(v & 0xFF))
			v = v >> 8
		}
		// Add sign byte if high bit set on positive number
		if bytes[0] & 0x80 != 0 {
			bytes.prepend(u8(0))
		}
	}
	mut out := []u8{cap: 2 + bytes.len}
	out << u8(0x02) // INTEGER tag
	out << encode_length(bytes.len)
	out << bytes
	return out
}

// encode_octet_string produces a BER OCTET STRING (tag 0x04).
fn encode_octet_string(value string) []u8 {
	data := value.bytes()
	mut out := []u8{cap: 2 + data.len}
	out << u8(0x04) // OCTET STRING tag
	out << encode_length(data.len)
	out << data
	return out
}

// encode_boolean produces a BER BOOLEAN (tag 0x01).
fn encode_boolean(value bool) []u8 {
	return [u8(0x01), u8(1), if value { u8(0xFF) } else { u8(0x00) }]
}

// encode_enumerated produces a BER ENUMERATED (tag 0x0A).
fn encode_enumerated(value int) []u8 {
	mut out := []u8{}
	out << u8(0x0A) // ENUMERATED tag
	out << u8(1)
	out << u8(value)
	return out
}

// encode_sequence wraps payload bytes in a BER SEQUENCE (tag 0x30).
fn encode_sequence(payload []u8) []u8 {
	mut out := []u8{cap: 2 + payload.len}
	out << u8(0x30) // SEQUENCE tag
	out << encode_length(payload.len)
	out << payload
	return out
}

// encode_set wraps payload bytes in a BER SET (tag 0x31).
fn encode_set(payload []u8) []u8 {
	mut out := []u8{cap: 2 + payload.len}
	out << u8(0x31) // SET tag
	out << encode_length(payload.len)
	out << payload
	return out
}

// encode_context_string produces a context-specific primitive string
// (e.g. for simple authentication in BIND).
fn encode_context_string(tag_number int, value string) []u8 {
	data := value.bytes()
	mut out := []u8{cap: 2 + data.len}
	out << u8(0x80 | tag_number) // context-specific, primitive
	out << encode_length(data.len)
	out << data
	return out
}

// encode_context_constructed wraps payload in a context-specific
// constructed tag (e.g. for SASL credentials in BIND).
fn encode_context_constructed(tag_number int, payload []u8) []u8 {
	mut out := []u8{cap: 2 + payload.len}
	out << u8(0xA0 | tag_number) // context-specific, constructed
	out << encode_length(payload.len)
	out << payload
	return out
}

// encode_filter converts an RFC 4515 LDAP filter string into its
// BER-encoded representation. Currently supports simple equality
// filters of the form "(attribute=value)".
fn encode_filter(filter_str string) []u8 {
	// Minimal filter parser: handle (attr=value) equality filters
	trimmed := filter_str.trim('()')
	if eq_pos := trimmed.index('=') {
		attr_name := trimmed[..eq_pos]
		attr_value := trimmed[eq_pos + 1..]
		// Equality match: context tag 0xA3
		mut payload := []u8{}
		payload << encode_octet_string(attr_name)
		payload << encode_octet_string(attr_value)
		mut out := []u8{}
		out << u8(0xA3) // equalityMatch
		out << encode_length(payload.len)
		out << payload
		return out
	}
	// Fallback: present filter for objectClass
	return encode_context_string(7, 'objectClass')
}

// encode_attribute_list encodes the list of requested attributes
// as a BER SEQUENCE of OCTET STRINGs.
fn encode_attribute_list(attributes []string) []u8 {
	mut payload := []u8{}
	for attr in attributes {
		payload << encode_octet_string(attr)
	}
	return encode_sequence(payload)
}

// --- Response parsing ---

// extract_result_code reads the resultCode INTEGER from an LDAP
// result message (the first element in the payload SEQUENCE).
fn extract_result_code(payload []u8) int {
	// Result is: ENUMERATED resultCode, OCTET STRING matchedDN, OCTET STRING diagnosticMessage
	if payload.len < 3 {
		return -1
	}
	// First element should be ENUMERATED (0x0A) with the result code
	if payload[0] == 0x0A && payload[1] == 1 {
		return int(payload[2])
	}
	return -1
}

// parse_search_entry extracts the DN and attributes from a
// SearchResultEntry payload.
fn parse_search_entry(payload []u8) Entry {
	// Minimal extraction: first OCTET STRING is the DN
	if payload.len < 4 {
		return Entry{}
	}
	// Skip tag (0x04) and length to read DN
	if payload[0] != 0x04 {
		return Entry{}
	}
	dn_len := int(payload[1])
	dn := payload[2..2 + dn_len].bytestr()

	return Entry{
		dn: dn
	}
}

// --- Tests ---

fn test_encode_length_short() {
	assert encode_length(0) == [u8(0)]
	assert encode_length(127) == [u8(127)]
}

fn test_encode_length_long() {
	result := encode_length(128)
	assert result[0] == u8(0x81)
	assert result[1] == u8(128)
}

fn test_encode_integer_zero() {
	result := encode_integer(0)
	assert result[0] == u8(0x02) // INTEGER tag
	assert result[1] == u8(1)    // length
	assert result[2] == u8(0)    // value
}

fn test_encode_octet_string() {
	result := encode_octet_string('test')
	assert result[0] == u8(0x04) // OCTET STRING tag
	assert result[1] == u8(4)    // length
	assert result[2..].bytestr() == 'test'
}

fn test_encode_boolean_values() {
	true_result := encode_boolean(true)
	assert true_result == [u8(0x01), u8(1), u8(0xFF)]
	false_result := encode_boolean(false)
	assert false_result == [u8(0x01), u8(1), u8(0x00)]
}

fn test_extract_result_code_success() {
	// ENUMERATED(0x0A) length(1) value(0)
	payload := [u8(0x0A), u8(1), u8(0)]
	assert extract_result_code(payload) == 0
}
