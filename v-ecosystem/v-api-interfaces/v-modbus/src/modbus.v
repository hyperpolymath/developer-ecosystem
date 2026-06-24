// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem Modbus Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Modbus TCP client implementing the MBAP (Modbus Application Protocol)
// framing over TCP/IP. Supports all four data object types: coils (FC 01/05/15),
// discrete inputs (FC 02), holding registers (FC 03/06/16), and input
// registers (FC 04). Designed for PLC communication, SCADA integration,
// and IIoT edge gateway scenarios within the V-Ecosystem API layer.

module modbus

import net
import time

// --- Modbus function codes ---

// Standard Modbus function codes for data access operations.
const fc_read_coils = u8(0x01)
const fc_read_discrete_inputs = u8(0x02)
const fc_read_holding_registers = u8(0x03)
const fc_read_input_registers = u8(0x04)
const fc_write_single_coil = u8(0x05)
const fc_write_single_register = u8(0x06)
const fc_write_multiple_coils = u8(0x0F)
const fc_write_multiple_registers = u8(0x10)

// Modbus exception codes
const exc_illegal_function = u8(0x01)
const exc_illegal_data_address = u8(0x02)
const exc_illegal_data_value = u8(0x03)
const exc_slave_device_failure = u8(0x04)

// --- Configuration ---

// Config holds the parameters needed to connect to a Modbus TCP
// device (PLC, gateway, or simulator).
pub struct Config {
pub:
	host             string
	port             int            = 502
	unit_id          u8             = 1     // Modbus unit/slave ID
	connect_timeout  time.Duration  = 5 * time.second
	read_timeout     time.Duration  = 10 * time.second
}

// --- Data structures ---

// RegisterValue holds a 16-bit register address and its value.
pub struct RegisterValue {
pub:
	address u16
	value   u16
}

// CoilValue holds a coil/discrete input address and its boolean state.
pub struct CoilValue {
pub:
	address u16
	state   bool
}

// ModbusException represents a Modbus error response with the
// offending function code and exception code.
pub struct ModbusException {
pub:
	function_code  u8
	exception_code u8
}

// --- Client ---

// Client manages the Modbus TCP connection and provides typed
// access to all four Modbus data object types through the
// standard function codes.
pub struct Client {
mut:
	conn            net.TcpConn
	config          Config
	connected       bool
	transaction_id  u16
}

// connect establishes a TCP connection to the Modbus device.
pub fn connect(config Config) !&Client {
	addr := '${config.host}:${config.port}'
	mut conn := net.dial_tcp(addr)!
	conn.set_read_timeout(config.read_timeout)

	mut client := &Client{
		conn: conn
		config: config
		connected: true
	}

	println('[modbus] connected to ${addr} (unit ${config.unit_id})')
	return client
}

// disconnect closes the TCP connection.
pub fn (mut c Client) disconnect() {
	if !c.connected {
		return
	}
	c.conn.close() or {}
	c.connected = false
	println('[modbus] disconnected')
}

// --- Coil operations (FC 01, 05, 15) ---

// read_coils reads the state of one or more coils starting at the
// given address (function code 01).
pub fn (mut c Client) read_coils(start_address u16, quantity u16) ![]CoilValue {
	if !c.connected {
		return error('not connected')
	}
	if quantity == 0 || quantity > 2000 {
		return error('coil quantity must be 1..2000')
	}

	response := c.send_read_request(fc_read_coils, start_address, quantity)!
	return decode_coil_response(response, start_address, quantity)
}

// write_single_coil sets a single coil to on (0xFF00) or off
// (0x0000) at the given address (function code 05).
pub fn (mut c Client) write_single_coil(address u16, state bool) ! {
	if !c.connected {
		return error('not connected')
	}

	value := if state { u16(0xFF00) } else { u16(0x0000) }
	mut pdu := []u8{cap: 5}
	pdu << fc_write_single_coil
	pdu << encode_u16(address)
	pdu << encode_u16(value)

	c.send_request(pdu)!
	c.receive_response()!
}

// write_multiple_coils sets the state of multiple consecutive coils
// starting at the given address (function code 15).
pub fn (mut c Client) write_multiple_coils(start_address u16, states []bool) ! {
	if !c.connected {
		return error('not connected')
	}
	if states.len == 0 || states.len > 1968 {
		return error('coil count must be 1..1968')
	}

	quantity := u16(states.len)
	byte_count := u8((states.len + 7) / 8)
	coil_bytes := pack_coil_bits(states)

	mut pdu := []u8{cap: 6 + coil_bytes.len}
	pdu << fc_write_multiple_coils
	pdu << encode_u16(start_address)
	pdu << encode_u16(quantity)
	pdu << byte_count
	pdu << coil_bytes

	c.send_request(pdu)!
	c.receive_response()!
}

// --- Discrete input operations (FC 02) ---

// read_discrete_inputs reads the state of one or more discrete
// inputs starting at the given address (function code 02).
pub fn (mut c Client) read_discrete_inputs(start_address u16, quantity u16) ![]CoilValue {
	if !c.connected {
		return error('not connected')
	}
	if quantity == 0 || quantity > 2000 {
		return error('discrete input quantity must be 1..2000')
	}

	response := c.send_read_request(fc_read_discrete_inputs, start_address, quantity)!
	return decode_coil_response(response, start_address, quantity)
}

// --- Holding register operations (FC 03, 06, 16) ---

// read_holding_registers reads one or more 16-bit holding registers
// starting at the given address (function code 03).
pub fn (mut c Client) read_holding_registers(start_address u16, quantity u16) ![]RegisterValue {
	if !c.connected {
		return error('not connected')
	}
	if quantity == 0 || quantity > 125 {
		return error('register quantity must be 1..125')
	}

	response := c.send_read_request(fc_read_holding_registers, start_address, quantity)!
	return decode_register_response(response, start_address, quantity)
}

// write_single_register writes a 16-bit value to a single holding
// register (function code 06).
pub fn (mut c Client) write_single_register(address u16, value u16) ! {
	if !c.connected {
		return error('not connected')
	}

	mut pdu := []u8{cap: 5}
	pdu << fc_write_single_register
	pdu << encode_u16(address)
	pdu << encode_u16(value)

	c.send_request(pdu)!
	c.receive_response()!
}

// write_multiple_registers writes values to multiple consecutive
// holding registers starting at the given address (function code 16).
pub fn (mut c Client) write_multiple_registers(start_address u16, values []u16) ! {
	if !c.connected {
		return error('not connected')
	}
	if values.len == 0 || values.len > 123 {
		return error('register count must be 1..123')
	}

	quantity := u16(values.len)
	byte_count := u8(values.len * 2)

	mut pdu := []u8{cap: 6 + int(byte_count)}
	pdu << fc_write_multiple_registers
	pdu << encode_u16(start_address)
	pdu << encode_u16(quantity)
	pdu << byte_count
	for value in values {
		pdu << encode_u16(value)
	}

	c.send_request(pdu)!
	c.receive_response()!
}

// --- Input register operations (FC 04) ---

// read_input_registers reads one or more 16-bit input registers
// starting at the given address (function code 04).
pub fn (mut c Client) read_input_registers(start_address u16, quantity u16) ![]RegisterValue {
	if !c.connected {
		return error('not connected')
	}
	if quantity == 0 || quantity > 125 {
		return error('register quantity must be 1..125')
	}

	response := c.send_read_request(fc_read_input_registers, start_address, quantity)!
	return decode_register_response(response, start_address, quantity)
}

// --- Internal protocol helpers ---

// send_read_request builds and sends a standard Modbus read request
// (function code, start address, quantity) and returns the response
// data bytes (excluding MBAP header and function code).
fn (mut c Client) send_read_request(function_code u8, start_address u16, quantity u16) ![]u8 {
	mut pdu := []u8{cap: 5}
	pdu << function_code
	pdu << encode_u16(start_address)
	pdu << encode_u16(quantity)

	c.send_request(pdu)!
	return c.receive_response()
}

// send_request wraps a Modbus PDU in an MBAP header and sends it
// over the TCP connection. The MBAP header contains the transaction
// ID, protocol ID (0), length, and unit ID.
fn (mut c Client) send_request(pdu []u8) ! {
	c.transaction_id++

	// MBAP header: transaction_id(2) + protocol_id(2) + length(2) + unit_id(1)
	length := u16(pdu.len + 1) // PDU length + unit ID byte
	mut frame := []u8{cap: 7 + pdu.len}
	frame << encode_u16(c.transaction_id)
	frame << encode_u16(0) // protocol ID (always 0 for Modbus)
	frame << encode_u16(length)
	frame << c.config.unit_id
	frame << pdu

	c.conn.write(frame)!
}

// receive_response reads a complete Modbus TCP response, validates
// the MBAP header, checks for exception responses, and returns the
// data payload (bytes after the function code).
fn (mut c Client) receive_response() ![]u8 {
	// Read MBAP header (7 bytes)
	mut header := []u8{len: 7}
	c.conn.read(mut header)!

	// Parse response length from MBAP header
	resp_length := (int(header[4]) << 8) | int(header[5])
	pdu_length := resp_length - 1 // Subtract unit ID byte

	if pdu_length <= 0 {
		return error('empty modbus response')
	}

	// Read PDU
	mut pdu := []u8{len: pdu_length}
	c.conn.read(mut pdu)!

	// Check for exception response (function code has bit 7 set)
	if pdu[0] & 0x80 != 0 {
		exc_code := if pdu.len > 1 { pdu[1] } else { u8(0) }
		return error('modbus exception: function 0x${pdu[0]:02x}, code 0x${exc_code:02x} (${exception_name(exc_code)})')
	}

	// Return data after function code
	if pdu.len > 1 {
		return pdu[1..]
	}
	return []u8{}
}

// --- Encoding utilities ---

// encode_u16 encodes a 16-bit unsigned integer in big-endian byte
// order (Modbus standard byte ordering).
fn encode_u16(value u16) []u8 {
	return [u8(value >> 8), u8(value & 0xFF)]
}

// decode_u16 reads a 16-bit unsigned integer in big-endian from the
// given byte array at the specified offset.
fn decode_u16(data []u8, offset int) u16 {
	if offset + 2 > data.len {
		return 0
	}
	return (u16(data[offset]) << 8) | u16(data[offset + 1])
}

// pack_coil_bits converts a boolean slice into packed coil bytes
// where each bit represents one coil (LSB first within each byte).
fn pack_coil_bits(states []bool) []u8 {
	byte_count := (states.len + 7) / 8
	mut bytes := []u8{len: byte_count}
	for i, state in states {
		if state {
			byte_index := i / 8
			bit_index := i % 8
			bytes[byte_index] = bytes[byte_index] | (u8(1) << bit_index)
		}
	}
	return bytes
}

// unpack_coil_bits converts packed coil bytes back into a boolean
// slice for the specified quantity of coils.
fn unpack_coil_bits(data []u8, quantity u16) []bool {
	mut states := []bool{len: int(quantity)}
	for i in 0 .. int(quantity) {
		byte_index := i / 8
		bit_index := i % 8
		if byte_index < data.len {
			states[i] = (data[byte_index] >> bit_index) & 1 == 1
		}
	}
	return states
}

// --- Response decoders ---

// decode_coil_response extracts CoilValue entries from a read
// coils/discrete inputs response. The response format is:
// byte_count(1) + coil_status(N bytes).
fn decode_coil_response(data []u8, start_address u16, quantity u16) []CoilValue {
	if data.len < 2 {
		return []
	}
	// First byte is the byte count; remaining bytes are coil states
	coil_data := data[1..]
	states := unpack_coil_bits(coil_data, quantity)

	mut coils := []CoilValue{cap: int(quantity)}
	for i, state in states {
		coils << CoilValue{
			address: start_address + u16(i)
			state: state
		}
	}
	return coils
}

// decode_register_response extracts RegisterValue entries from a
// read registers response. The response format is:
// byte_count(1) + register_values(N*2 bytes, big-endian).
fn decode_register_response(data []u8, start_address u16, quantity u16) []RegisterValue {
	if data.len < 2 {
		return []
	}
	// First byte is the byte count; remaining bytes are register values
	reg_data := data[1..]
	mut registers := []RegisterValue{cap: int(quantity)}

	for i in 0 .. int(quantity) {
		offset := i * 2
		if offset + 2 <= reg_data.len {
			value := decode_u16(reg_data, offset)
			registers << RegisterValue{
				address: start_address + u16(i)
				value: value
			}
		}
	}
	return registers
}

// exception_name returns a human-readable name for a Modbus
// exception code.
fn exception_name(code u8) string {
	return match code {
		exc_illegal_function { 'Illegal Function' }
		exc_illegal_data_address { 'Illegal Data Address' }
		exc_illegal_data_value { 'Illegal Data Value' }
		exc_slave_device_failure { 'Slave Device Failure' }
		else { 'Unknown (0x${code:02x})' }
	}
}

// --- Tests ---

fn test_encode_u16() {
	result := encode_u16(0x1234)
	assert result == [u8(0x12), u8(0x34)]
}

fn test_decode_u16() {
	data := [u8(0x12), u8(0x34)]
	assert decode_u16(data, 0) == 0x1234
}

fn test_decode_u16_out_of_bounds() {
	data := [u8(0x12)]
	assert decode_u16(data, 0) == 0
}

fn test_pack_coil_bits() {
	states := [true, false, true, true, false, false, false, false, true]
	result := pack_coil_bits(states)
	assert result[0] == 0b00001101 // bits 0,2,3 set
	assert result[1] == 0b00000001 // bit 0 set (coil 8)
}

fn test_unpack_coil_bits() {
	data := [u8(0b00001101)]
	states := unpack_coil_bits(data, 4)
	assert states[0] == true
	assert states[1] == false
	assert states[2] == true
	assert states[3] == true
}

fn test_register_value_struct() {
	rv := RegisterValue{
		address: 100
		value: 42
	}
	assert rv.address == 100
	assert rv.value == 42
}

fn test_exception_name() {
	assert exception_name(0x01) == 'Illegal Function'
	assert exception_name(0x02) == 'Illegal Data Address'
}
