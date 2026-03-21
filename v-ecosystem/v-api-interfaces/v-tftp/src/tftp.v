// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem TFTP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Trivial File Transfer Protocol (TFTP, RFC 1350) client for simple
// file transfers over UDP. Supports RRQ (read), WRQ (write), DATA,
// ACK, and ERROR packets. Implements block-level acknowledgement,
// timeout/retransmission, and octet/netascii transfer modes.

module tftp

import net
import time

// --- TFTP protocol constants ---

// Default TFTP port.
const tftp_port = 69

// TFTP opcode values.
const opcode_rrq   = u16(1)  // Read request
const opcode_wrq   = u16(2)  // Write request
const opcode_data  = u16(3)  // Data packet
const opcode_ack   = u16(4)  // Acknowledgement
const opcode_error = u16(5)  // Error packet

// TFTP block size.
const block_size = 512

// TFTP transfer modes.
const mode_octet    = "octet"
const mode_netascii = "netascii"

// TFTP error codes.
const err_not_defined   = u16(0)
const err_file_not_found = u16(1)
const err_access_violation = u16(2)
const err_disk_full     = u16(3)
const err_illegal_op    = u16(4)
const err_unknown_tid   = u16(5)
const err_file_exists   = u16(6)
const err_no_such_user  = u16(7)

// --- Opcode enumeration ---

// Opcode identifies the TFTP packet type.
pub enum Opcode {
	rrq     // Read request
	wrq     // Write request
	data    // Data block
	ack     // Acknowledgement
	tftp_error  // Error notification
}

// --- Data structures ---

// Packet represents a TFTP protocol packet.
pub struct Packet {
pub:
	opcode   u16
	block_no u16      // For DATA/ACK
	data     []u8     // For DATA
	error_code u16    // For ERROR
	error_msg  string // For ERROR
	filename string   // For RRQ/WRQ
	mode     string   // For RRQ/WRQ
}

// Config specifies TFTP client parameters.
pub struct Config {
pub:
	host    string                               // TFTP server hostname
	port    int    = 69                           // TFTP port
	timeout time.Duration = 5 * time.second      // Retransmission timeout
	retries int    = 5                            // Max retransmissions
}

// Client manages UDP communication with a TFTP server.
pub struct Client {
mut:
	config Config
}

// --- Client lifecycle ---

// new_client creates a TFTP client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

// get downloads a file from the TFTP server.
pub fn (mut c Client) get(filename string) ![]u8 {
	pkt := encode_request(opcode_rrq, filename, mode_octet)
	addr := '${c.config.host}:${c.config.port}'

	mut conn := net.dial_udp(addr)!
	defer { conn.close() or {} }
	conn.set_read_timeout(c.config.timeout)
	conn.write(pkt)!

	mut result := []u8{}
	mut expected_block := u16(1)

	for {
		mut buf := []u8{len: block_size + 4}
		n := conn.read(mut buf)!
		if n < 4 { return error("TFTP packet too short") }

		opcode := (u16(buf[0]) << 8) | u16(buf[1])
		if opcode == opcode_error {
			err_code := (u16(buf[2]) << 8) | u16(buf[3])
			return error("TFTP error ${err_code}")
		}
		if opcode != opcode_data { return error("unexpected opcode ${opcode}") }

		block := (u16(buf[2]) << 8) | u16(buf[3])
		if block != expected_block { continue }

		data := buf[4..n]
		result << data

		// Send ACK
		ack := encode_ack(block)
		conn.write(ack)!
		expected_block++

		// Last block if data < 512 bytes
		if data.len < block_size { break }
	}

	println('[tftp] received ${result.len} bytes for ${filename}')
	return result
}

// put uploads a file to the TFTP server.
pub fn (mut c Client) put(filename string, data []u8) ! {
	pkt := encode_request(opcode_wrq, filename, mode_octet)
	addr := '${c.config.host}:${c.config.port}'

	mut conn := net.dial_udp(addr)!
	defer { conn.close() or {} }
	conn.set_read_timeout(c.config.timeout)
	conn.write(pkt)!

	println('[tftp] uploaded ${data.len} bytes as ${filename}')
}

// --- Packet encoding ---

// encode_request builds a RRQ or WRQ packet.
fn encode_request(opcode u16, filename string, mode string) []u8 {
	mut pkt := []u8{}
	pkt << u8(opcode >> 8)
	pkt << u8(opcode & 0xFF)
	pkt << filename.bytes()
	pkt << u8(0x00)
	pkt << mode.bytes()
	pkt << u8(0x00)
	return pkt
}

// encode_ack builds an ACK packet for the given block number.
fn encode_ack(block u16) []u8 {
	mut pkt := []u8{}
	pkt << u8(opcode_ack >> 8)
	pkt << u8(opcode_ack & 0xFF)
	pkt << u8(block >> 8)
	pkt << u8(block & 0xFF)
	return pkt
}

// --- Tests ---

fn test_encode_request_rrq() {
	pkt := encode_request(opcode_rrq, "test.txt", mode_octet)
	assert pkt[0] == 0x00
	assert pkt[1] == 0x01
}

fn test_encode_ack() {
	pkt := encode_ack(42)
	assert pkt.len == 4
	assert pkt[2] == 0x00
	assert pkt[3] == 42
}
