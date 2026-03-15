// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem MQTT Client (QoS 0)
// Author: Jonathan D.A. Jewell
//
// Minimal MQTT 3.1.1 client over raw TCP. Supports CONNECT, PUBLISH,
// SUBSCRIBE, UNSUBSCRIBE, PINGREQ, and DISCONNECT at QoS 0 (fire and
// forget). Designed for IIoT/SCADA edge telemetry where lightweight
// message passing matters more than delivery guarantees.

module mqtt

import net
import time

// --- MQTT packet types (4-bit codes, upper nibble of byte 1) ---
const connect_type = u8(0x10)
const connack_type = u8(0x20)
const publish_type = u8(0x30)
const subscribe_type = u8(0x82) // QoS 1 flag set for subscribe
const suback_type = u8(0x90)
const unsubscribe_type = u8(0xA2)
const pingreq_type = u8(0xC0)
const pingresp_type = u8(0xD0)
const disconnect_type = u8(0xE0)

// --- Message callback ---

// MessageFn is invoked when a PUBLISH arrives on a subscribed topic.
pub type MessageFn = fn (topic string, payload []u8)

// --- Client ---

// Client holds the TCP connection and subscription callbacks.
pub struct Client {
mut:
	conn       net.TcpConn
	connected  bool
	client_id  string
	callbacks  map[string]MessageFn
	packet_id  u16
}

// connect establishes a TCP connection and sends the MQTT CONNECT
// packet. Returns an error if the broker rejects the handshake.
pub fn connect(host string, port int, client_id string) !&Client {
	addr := '${host}:${port}'
	mut conn := net.dial_tcp(addr)!
	conn.set_read_timeout(5 * time.second)

	mut c := &Client{
		conn: conn
		client_id: client_id
	}
	c.send_connect()!
	c.read_connack()!
	c.connected = true
	println('[mqtt] connected to ${addr} as ${client_id}')
	return c
}

// publish sends a QoS 0 PUBLISH packet to the broker.
pub fn (mut c Client) publish(topic string, payload []u8) ! {
	if !c.connected {
		return error('not connected')
	}
	// Fixed header: PUBLISH (0x30), no QoS/retain flags
	topic_bytes := encode_utf8_string(topic)
	remaining := topic_bytes.len + payload.len
	mut pkt := []u8{}
	pkt << publish_type
	pkt << encode_remaining_length(remaining)
	pkt << topic_bytes
	pkt << payload
	c.conn.write(pkt)!
}

// subscribe registers interest in a topic filter at QoS 0.
pub fn (mut c Client) subscribe(topic string, callback MessageFn) ! {
	if !c.connected {
		return error('not connected')
	}
	c.packet_id++
	pid := c.packet_id
	topic_bytes := encode_utf8_string(topic)
	remaining := 2 + topic_bytes.len + 1 // packet id + topic + qos
	mut pkt := []u8{}
	pkt << subscribe_type
	pkt << encode_remaining_length(remaining)
	pkt << u8(pid >> 8)
	pkt << u8(pid & 0xFF)
	pkt << topic_bytes
	pkt << u8(0) // QoS 0
	c.conn.write(pkt)!
	c.callbacks[topic] = callback
	println('[mqtt] subscribed to "${topic}"')
}

// unsubscribe removes a topic subscription.
pub fn (mut c Client) unsubscribe(topic string) ! {
	if !c.connected {
		return error('not connected')
	}
	c.packet_id++
	pid := c.packet_id
	topic_bytes := encode_utf8_string(topic)
	remaining := 2 + topic_bytes.len
	mut pkt := []u8{}
	pkt << unsubscribe_type
	pkt << encode_remaining_length(remaining)
	pkt << u8(pid >> 8)
	pkt << u8(pid & 0xFF)
	pkt << topic_bytes
	c.conn.write(pkt)!
	c.callbacks.delete(topic)
}

// ping sends a PINGREQ and expects a PINGRESP to keep the session alive.
pub fn (mut c Client) ping() ! {
	c.conn.write([pingreq_type, u8(0)])!
}

// disconnect sends a clean DISCONNECT and closes the socket.
pub fn (mut c Client) disconnect() ! {
	if c.connected {
		c.conn.write([disconnect_type, u8(0)]) or {}
		c.conn.close() or {}
		c.connected = false
		println('[mqtt] disconnected')
	}
}

// poll_once reads one incoming packet and dispatches any PUBLISH to
// the matching subscription callback. Non-blocking if no data ready.
pub fn (mut c Client) poll_once() ! {
	mut header_buf := []u8{len: 1}
	c.conn.read(mut header_buf) or { return }
	pkt_type := header_buf[0] & 0xF0

	remaining := c.read_remaining_length()!
	mut payload := []u8{len: remaining}
	if remaining > 0 {
		c.conn.read(mut payload) or {
			return error('incomplete packet')
		}
	}

	match pkt_type {
		publish_type {
			c.handle_publish(payload)
		}
		pingresp_type {
			// Keep-alive acknowledged; nothing to do.
		}
		else {}
	}
}

// --- Internal protocol helpers ---

// send_connect builds and sends the CONNECT packet.
fn (mut c Client) send_connect() ! {
	// Variable header: protocol name "MQTT", level 4, flags 0x02 (clean session), keepalive 60s
	mut var_header := []u8{}
	var_header << encode_utf8_string('MQTT')
	var_header << u8(4)    // protocol level
	var_header << u8(0x02) // clean session
	var_header << u8(0)    // keepalive MSB
	var_header << u8(60)   // keepalive LSB (60 seconds)

	payload := encode_utf8_string(c.client_id)
	remaining := var_header.len + payload.len

	mut pkt := []u8{}
	pkt << connect_type
	pkt << encode_remaining_length(remaining)
	pkt << var_header
	pkt << payload
	c.conn.write(pkt)!
}

// read_connack reads and validates the CONNACK response.
fn (mut c Client) read_connack() ! {
	mut buf := []u8{len: 4}
	c.conn.read(mut buf)!
	if buf[0] != connack_type {
		return error('expected CONNACK, got 0x${buf[0]:02x}')
	}
	if buf[3] != 0 {
		return error('CONNACK return code ${buf[3]} (connection refused)')
	}
}

// handle_publish extracts topic and payload from a PUBLISH packet body,
// then calls the matching subscription callback.
fn (mut c Client) handle_publish(data []u8) {
	if data.len < 2 {
		return
	}
	topic_len := (int(data[0]) << 8) | int(data[1])
	if data.len < 2 + topic_len {
		return
	}
	topic := data[2..2 + topic_len].bytestr()
	payload := data[2 + topic_len..]
	if cb := c.callbacks[topic] {
		cb(topic, payload)
	}
}

// read_remaining_length decodes the MQTT variable-length encoding.
fn (mut c Client) read_remaining_length() !int {
	mut value := 0
	mut multiplier := 1
	for _ in 0 .. 4 {
		mut b := []u8{len: 1}
		c.conn.read(mut b)!
		value += int(b[0] & 0x7F) * multiplier
		if b[0] & 0x80 == 0 {
			return value
		}
		multiplier *= 128
	}
	return error('malformed remaining length')
}

// --- Encoding utilities ---

// encode_utf8_string produces the MQTT length-prefixed UTF-8 string.
fn encode_utf8_string(s string) []u8 {
	len := s.len
	mut out := []u8{cap: 2 + len}
	out << u8(len >> 8)
	out << u8(len & 0xFF)
	out << s.bytes()
	return out
}

// encode_remaining_length produces the MQTT variable-length integer.
fn encode_remaining_length(length int) []u8 {
	mut out := []u8{}
	mut x := length
	for {
		mut encoded_byte := u8(x % 128)
		x = x / 128
		if x > 0 {
			encoded_byte = encoded_byte | 0x80
		}
		out << encoded_byte
		if x == 0 {
			break
		}
	}
	return out
}

// --- Tests ---

fn test_encode_utf8_string() {
	result := encode_utf8_string('AB')
	assert result == [u8(0), u8(2), u8(65), u8(66)]
}

fn test_encode_remaining_length_small() {
	assert encode_remaining_length(0) == [u8(0)]
	assert encode_remaining_length(127) == [u8(127)]
}

fn test_encode_remaining_length_two_byte() {
	// 128 encodes as [0x00, 0x01] in MQTT variable-length
	result := encode_remaining_length(128)
	assert result == [u8(0x80), u8(0x01)]
}
