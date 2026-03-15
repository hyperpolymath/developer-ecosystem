// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Cap'n Proto-style Zero-Copy Message Builder
// Author: Jonathan D.A. Jewell
//
// Implements Cap'n Proto-inspired flat serialisation: messages are
// written directly into a contiguous byte buffer with pointer-based
// field access, so deserialisation is a bounds check rather than a
// copy. Includes a simple RPC request/response pattern over the same
// wire format.
//
// This is NOT a full Cap'n Proto implementation — it is a V-native
// approximation of the zero-copy principle using fixed-size segments
// and inline struct layouts.

module capnproto

// --- Constants ---

// Segment alignment: all fields are 8-byte aligned to match Cap'n
// Proto's word size.
const word_size = 8

// Default segment capacity in bytes.
const default_segment_cap = 4096

// --- Segment (contiguous byte buffer) ---

// Segment is a flat byte buffer that structs and lists are written
// into. Pointers are offsets within this buffer.
pub struct Segment {
mut:
	data []u8
	pos  int // Write cursor
}

// new_segment allocates a segment with the given capacity.
pub fn new_segment(capacity int) &Segment {
	cap := if capacity < default_segment_cap { default_segment_cap } else { capacity }
	return &Segment{
		data: []u8{len: cap}
	}
}

// alloc reserves `size` bytes (rounded up to word alignment) and
// returns the offset where they start.
pub fn (mut s Segment) alloc(size int) !int {
	aligned := align(size)
	if s.pos + aligned > s.data.len {
		return error('segment overflow: need ${aligned} bytes at offset ${s.pos}, capacity ${s.data.len}')
	}
	offset := s.pos
	s.pos += aligned
	return offset
}

// used returns the number of bytes written so far.
pub fn (s &Segment) used() int {
	return s.pos
}

// bytes returns the used portion of the segment as a slice.
pub fn (s &Segment) bytes() []u8 {
	return s.data[..s.pos]
}

// --- Field writers ---

// write_u8 stores a single byte at the given offset.
pub fn (mut s Segment) write_u8(offset int, val u8) {
	s.data[offset] = val
}

// write_u16 stores a 16-bit little-endian integer.
pub fn (mut s Segment) write_u16(offset int, val u16) {
	s.data[offset] = u8(val & 0xFF)
	s.data[offset + 1] = u8(val >> 8)
}

// write_u32 stores a 32-bit little-endian integer.
pub fn (mut s Segment) write_u32(offset int, val u32) {
	s.data[offset] = u8(val & 0xFF)
	s.data[offset + 1] = u8((val >> 8) & 0xFF)
	s.data[offset + 2] = u8((val >> 16) & 0xFF)
	s.data[offset + 3] = u8(val >> 24)
}

// write_u64 stores a 64-bit little-endian integer.
pub fn (mut s Segment) write_u64(offset int, val u64) {
	for i in 0 .. 8 {
		s.data[offset + i] = u8((val >> (u64(i) * 8)) & 0xFF)
	}
}

// write_bytes copies a byte slice at the given offset.
pub fn (mut s Segment) write_bytes(offset int, src []u8) {
	for i, b in src {
		s.data[offset + i] = b
	}
}

// --- Field readers (zero-copy — read directly from the buffer) ---

// read_u8 reads a single byte from the given offset.
pub fn (s &Segment) read_u8(offset int) u8 {
	return s.data[offset]
}

// read_u16 reads a 16-bit little-endian integer.
pub fn (s &Segment) read_u16(offset int) u16 {
	return u16(s.data[offset]) | (u16(s.data[offset + 1]) << 8)
}

// read_u32 reads a 32-bit little-endian integer.
pub fn (s &Segment) read_u32(offset int) u32 {
	mut val := u32(0)
	for i in 0 .. 4 {
		val |= u32(s.data[offset + i]) << (u32(i) * 8)
	}
	return val
}

// read_u64 reads a 64-bit little-endian integer.
pub fn (s &Segment) read_u64(offset int) u64 {
	mut val := u64(0)
	for i in 0 .. 8 {
		val |= u64(s.data[offset + i]) << (u64(i) * 8)
	}
	return val
}

// read_bytes reads a byte slice of the given length from the offset.
pub fn (s &Segment) read_bytes(offset int, length int) []u8 {
	return s.data[offset..offset + length]
}

// --- Message builder ---

// MessageBuilder wraps a segment and provides high-level struct and
// text writing.
pub struct MessageBuilder {
mut:
	seg &Segment
}

// new_message creates a message builder with a default-sized segment.
pub fn new_message() &MessageBuilder {
	return &MessageBuilder{
		seg: new_segment(default_segment_cap)
	}
}

// new_message_with_capacity creates a message builder with a specific
// segment capacity.
pub fn new_message_with_capacity(cap int) &MessageBuilder {
	return &MessageBuilder{
		seg: new_segment(cap)
	}
}

// alloc_struct reserves space for a struct with the given data and
// pointer section sizes (in bytes). Returns the offset.
pub fn (mut m MessageBuilder) alloc_struct(data_size int, pointer_count int) !int {
	total := data_size + pointer_count * word_size
	return m.seg.alloc(total)
}

// write_text writes a length-prefixed text blob into the segment.
// Returns the offset where the length prefix starts.
pub fn (mut m MessageBuilder) write_text(text string) !int {
	bytes := text.bytes()
	total := 4 + bytes.len + 1 // 4-byte length + content + null terminator
	offset := m.seg.alloc(total)!
	m.seg.write_u32(offset, u32(bytes.len))
	m.seg.write_bytes(offset + 4, bytes)
	m.seg.write_u8(offset + 4 + bytes.len, 0) // null terminator
	return offset
}

// read_text reads a length-prefixed text blob from the given offset.
pub fn (m &MessageBuilder) read_text(offset int) string {
	length := m.seg.read_u32(offset)
	return m.seg.read_bytes(offset + 4, int(length)).bytestr()
}

// finish returns the serialised message bytes.
pub fn (m &MessageBuilder) finish() []u8 {
	return m.seg.bytes()
}

// segment returns the underlying segment for direct field access.
pub fn (m &MessageBuilder) segment() &Segment {
	return m.seg
}

// --- RPC message format ---

// RPC messages use a simple header: [method_id: u32][payload_len: u32]
// followed by the payload struct.

// RpcHeader is the wire header for an RPC call or response.
pub struct RpcHeader {
pub:
	method_id   u32
	payload_len u32
}

// write_rpc_header writes an RPC header at the current position and
// returns the offset where the payload should be written.
pub fn (mut m MessageBuilder) write_rpc_header(method_id u32, payload_len u32) !int {
	offset := m.seg.alloc(word_size)!
	m.seg.write_u32(offset, method_id)
	m.seg.write_u32(offset + 4, payload_len)
	return offset + int(word_size)
}

// read_rpc_header reads an RPC header from the given offset.
pub fn (m &MessageBuilder) read_rpc_header(offset int) RpcHeader {
	return RpcHeader{
		method_id: m.seg.read_u32(offset)
		payload_len: m.seg.read_u32(offset + 4)
	}
}

// --- Utilities ---

// align rounds size up to the nearest word boundary.
fn align(size int) int {
	return (size + word_size - 1) & ~(word_size - 1)
}

// --- Tests ---

fn test_alloc_and_read_write() {
	mut msg := new_message()
	offset := msg.alloc_struct(16, 0) or {
		assert false, 'alloc failed: ${err}'
		return
	}
	msg.segment().write_u32(offset, 0xDEADBEEF)
	msg.segment().write_u64(offset + 8, 0x0102030405060708)

	assert msg.segment().read_u32(offset) == 0xDEADBEEF
	assert msg.segment().read_u64(offset + 8) == 0x0102030405060708
}

fn test_text_roundtrip() {
	mut msg := new_message()
	offset := msg.write_text('hello capnproto') or {
		assert false, 'write_text failed: ${err}'
		return
	}
	assert msg.read_text(offset) == 'hello capnproto'
}

fn test_rpc_header() {
	mut msg := new_message()
	msg.write_rpc_header(42, 128) or {
		assert false, 'write_rpc_header failed: ${err}'
		return
	}
	hdr := msg.read_rpc_header(0)
	assert hdr.method_id == 42
	assert hdr.payload_len == 128
}

fn test_alignment() {
	assert align(1) == 8
	assert align(8) == 8
	assert align(9) == 16
	assert align(16) == 16
}

fn test_segment_overflow() {
	mut seg := new_segment(16)
	seg.alloc(8) or {
		assert false, 'first alloc should succeed'
		return
	}
	seg.alloc(8) or {
		assert false, 'second alloc should succeed'
		return
	}
	seg.alloc(8) or {
		assert err.str().contains('overflow')
		return
	}
	assert false, 'third alloc should have failed'
}
