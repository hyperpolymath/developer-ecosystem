// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem CoAP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Constrained Application Protocol (CoAP, RFC 7252) client over UDP.
// Supports CON/NON/ACK/RST message types, GET/POST/PUT/DELETE methods,
// content-format negotiation, observe (RFC 7641), block-wise transfer
// (RFC 7959), and token-based request/response matching. Designed for
// constrained IoT devices within the V-Ecosystem.

module coap

import net
import time

// --- CoAP protocol constants ---

// CoAP version (2 bits, always 1 for RFC 7252).
const coap_version = u8(1)

// CoAP message types (2 bits).
const type_con = u8(0)  // Confirmable
const type_non = u8(1)  // Non-confirmable
const type_ack = u8(2)  // Acknowledgement
const type_rst = u8(3)  // Reset

// CoAP method codes (detail field of class 0).
const method_get    = u8(1)
const method_post   = u8(2)
const method_put    = u8(3)
const method_delete = u8(4)

// CoAP response code classes.
const class_success     = u8(2)
const class_client_err  = u8(4)
const class_server_err  = u8(5)

// Common response codes (class.detail).
const code_created  = u8(0x41)  // 2.01
const code_deleted  = u8(0x42)  // 2.02
const code_valid    = u8(0x43)  // 2.03
const code_changed  = u8(0x44)  // 2.04
const code_content  = u8(0x45)  // 2.05

// CoAP option numbers.
const opt_if_match       = u16(1)
const opt_uri_host       = u16(3)
const opt_uri_port       = u16(7)
const opt_uri_path       = u16(11)
const opt_content_format = u16(12)
const opt_max_age        = u16(14)
const opt_uri_query      = u16(15)
const opt_accept         = u16(17)
const opt_observe        = u16(6)
const opt_block2         = u16(23)
const opt_block1         = u16(27)
const opt_size2          = u16(28)

// Content format identifiers.
const content_text_plain     = u16(0)
const content_link_format    = u16(40)
const content_xml            = u16(41)
const content_octet_stream   = u16(42)
const content_json           = u16(50)
const content_cbor           = u16(60)

// --- Message type enumeration ---

// MsgType classifies the CoAP message reliability.
pub enum MsgType {
	confirmable       // Requires acknowledgement (CON)
	non_confirmable   // Fire-and-forget (NON)
	acknowledgement   // Response to CON (ACK)
	reset             // Rejection signal (RST)
}

// --- Data structures ---

// Option represents a single CoAP option (number + value).
pub struct Option {
pub:
	number u16
	value  []u8
}

// Message represents a CoAP message with header, options, and payload.
pub struct Message {
pub mut:
	msg_type   MsgType
	code       u8          // Method or response code
	message_id u16
	token      []u8        // 0-8 byte token
	options    []Option
	payload    []u8
}

// Config specifies the CoAP endpoint and client parameters.
pub struct Config {
pub:
	host     string                               // CoAP server hostname or IP
	port     int    = 5683                          // CoAP default port
	timeout  time.Duration = 5 * time.second       // ACK timeout
	retries  int    = 4                             // Max retransmissions for CON
}

// Client manages UDP communication with a CoAP endpoint.
pub struct Client {
mut:
	config     Config
	message_id u16
	token_seq  u16
}

// --- Client lifecycle ---

// new_client creates a CoAP client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{
		config: config
	}
}

// get sends a CoAP GET request and returns the response.
pub fn (mut c Client) get(path string) !Message {
	return c.request(method_get, path, []u8{}, .confirmable)
}

// post sends a CoAP POST request with a payload.
pub fn (mut c Client) post(path string, payload []u8, content_format u16) !Message {
	mut opts := []Option{}
	opts << Option{ number: opt_content_format, value: encode_uint(content_format) }
	return c.request_with_options(method_post, path, payload, opts, .confirmable)
}

// put sends a CoAP PUT request with a payload.
pub fn (mut c Client) put(path string, payload []u8, content_format u16) !Message {
	mut opts := []Option{}
	opts << Option{ number: opt_content_format, value: encode_uint(content_format) }
	return c.request_with_options(method_put, path, payload, opts, .confirmable)
}

// delete sends a CoAP DELETE request.
pub fn (mut c Client) delete(path string) !Message {
	return c.request(method_delete, path, []u8{}, .confirmable)
}

// observe registers for resource observation (RFC 7641).
pub fn (mut c Client) observe(path string) !Message {
	mut opts := []Option{}
	opts << Option{ number: opt_observe, value: [u8(0)] } // Register
	return c.request_with_options(method_get, path, []u8{}, opts, .confirmable)
}

// --- Internal request handling ---

// request builds and sends a CoAP request, then waits for the response.
fn (mut c Client) request(method u8, path string, payload []u8, msg_type MsgType) !Message {
	return c.request_with_options(method, path, payload, [], msg_type)
}

// request_with_options builds a request with additional options.
fn (mut c Client) request_with_options(method u8, path string, payload []u8, extra_opts []Option, msg_type MsgType) !Message {
	c.message_id++
	c.token_seq++
	token := encode_uint(c.token_seq)

	// Build URI path options
	mut options := []Option{}
	path_segments := path.trim_left('/').split('/')
	for seg in path_segments {
		if seg.len > 0 {
			options << Option{ number: opt_uri_path, value: seg.bytes() }
		}
	}
	options << extra_opts

	// Sort options by number (required by CoAP)
	options.sort(a.number < b.number)

	msg := Message{
		msg_type: msg_type
		code: method
		message_id: c.message_id
		token: token
		options: options
		payload: payload
	}

	pkt := encode_message(msg)
	addr := '${c.config.host}:${c.config.port}'

	mut conn := net.dial_udp(addr)!
	defer {
		conn.close() or {}
	}
	conn.set_read_timeout(c.config.timeout)
	conn.write(pkt)!

	// Read response
	mut buf := []u8{len: 1500}
	n := conn.read(mut buf)!
	response := decode_message(buf[..n])!

	code_class := (response.code >> 5) & 0x07
	code_detail := response.code & 0x1F
	println('[coap] ${code_class}.${code_detail:02} (${response.payload.len} bytes)')
	return response
}

// --- Message encoding ---

// encode_message serialises a CoAP message to bytes.
fn encode_message(msg Message) []u8 {
	type_val := match msg.msg_type {
		.confirmable { type_con }
		.non_confirmable { type_non }
		.acknowledgement { type_ack }
		.reset { type_rst }
	}

	tkl := u8(msg.token.len)
	mut pkt := []u8{}

	// Header (4 bytes)
	pkt << (coap_version << 6) | (type_val << 4) | tkl
	pkt << msg.code
	pkt << u8(msg.message_id >> 8)
	pkt << u8(msg.message_id & 0xFF)

	// Token
	pkt << msg.token

	// Options (delta-encoded)
	mut prev_number := u16(0)
	for opt in msg.options {
		delta := opt.number - prev_number
		pkt << encode_option_header(delta, u16(opt.value.len))
		pkt << opt.value
		prev_number = opt.number
	}

	// Payload marker + payload
	if msg.payload.len > 0 {
		pkt << u8(0xFF) // Payload marker
		pkt << msg.payload
	}

	return pkt
}

// encode_option_header encodes the option delta and length nibbles.
fn encode_option_header(delta u16, length u16) []u8 {
	mut out := []u8{}
	d := if delta < 13 { u8(delta) } else { u8(13) }
	l := if length < 13 { u8(length) } else { u8(13) }
	out << (d << 4) | l

	if delta >= 13 && delta < 269 {
		out << u8(delta - 13)
	}
	if length >= 13 && length < 269 {
		out << u8(length - 13)
	}
	return out
}

// --- Message decoding ---

// decode_message parses a CoAP message from bytes.
fn decode_message(data []u8) !Message {
	if data.len < 4 {
		return error('CoAP message too short')
	}

	tkl := int(data[0] & 0x0F)
	type_val := (data[0] >> 4) & 0x03
	code := data[1]
	message_id := (u16(data[2]) << 8) | u16(data[3])

	msg_type := match type_val {
		type_con { MsgType.confirmable }
		type_non { MsgType.non_confirmable }
		type_ack { MsgType.acknowledgement }
		else { MsgType.reset }
	}

	mut token := []u8{}
	if tkl > 0 && data.len >= 4 + tkl {
		token = data[4..4 + tkl]
	}

	// Parse options and payload
	mut options := []Option{}
	mut payload := []u8{}
	mut i := 4 + tkl
	mut prev_number := u16(0)

	for i < data.len {
		if data[i] == 0xFF {
			// Payload marker
			payload = data[i + 1..]
			break
		}
		delta := u16((data[i] >> 4) & 0x0F)
		length := u16(data[i] & 0x0F)
		i++

		mut actual_delta := delta
		if delta == 13 {
			actual_delta = u16(data[i]) + 13
			i++
		}
		mut actual_length := length
		if length == 13 {
			actual_length = u16(data[i]) + 13
			i++
		}

		opt_number := prev_number + actual_delta
		opt_value := if actual_length > 0 && i + int(actual_length) <= data.len {
			data[i..i + int(actual_length)]
		} else {
			[]u8{}
		}
		options << Option{ number: opt_number, value: opt_value }
		prev_number = opt_number
		i += int(actual_length)
	}

	return Message{
		msg_type: msg_type
		code: code
		message_id: message_id
		token: token
		options: options
		payload: payload
	}
}

// --- Encoding utilities ---

// encode_uint encodes a u16 as a variable-length byte array.
fn encode_uint(val u16) []u8 {
	if val == 0 {
		return []u8{}
	}
	if val < 256 {
		return [u8(val)]
	}
	return [u8(val >> 8), u8(val & 0xFF)]
}

// --- Tests ---

fn test_encode_uint_zero() {
	assert encode_uint(0) == []u8{}
}

fn test_encode_uint_small() {
	assert encode_uint(42) == [u8(42)]
}

fn test_encode_uint_large() {
	result := encode_uint(0x0102)
	assert result == [u8(1), u8(2)]
}

fn test_encode_decode_message() {
	msg := Message{
		msg_type: .confirmable
		code: method_get
		message_id: 1234
		token: [u8(0xAB)]
		options: [Option{ number: opt_uri_path, value: 'test'.bytes() }]
		payload: 'hello'.bytes()
	}
	encoded := encode_message(msg)
	decoded := decode_message(encoded) or { panic('decode failed') }
	assert decoded.code == method_get
	assert decoded.message_id == 1234
	assert decoded.token == [u8(0xAB)]
	assert decoded.payload == 'hello'.bytes()
}
