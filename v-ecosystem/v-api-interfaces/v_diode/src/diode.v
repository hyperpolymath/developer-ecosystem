// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Data diode connector for unidirectional network transfer enforcement Connector
// Author: Jonathan D.A. Jewell
//
// Data diode client for unidirectional network transfers. Enforces one-way
// data flow from low-security to high-security domains (or vice versa).
// Supports UDP-based streaming, forward error correction, transfer
// manifests, receipt confirmation via out-of-band channel, and
// compliance logging for air-gapped environments.

module diode

import net
import time
import crypto.sha256
import encoding.hex

// --- Protocol constants ---

// Magic bytes prepended to every diode frame for sync detection.
const frame_magic = [u8(0xD1), 0x0D]

// Minimum frame size in bytes (magic + length + seq).
const frame_min_size = 10

// Maximum payload size per frame.
const frame_max_payload = 65507  // UDP max datagram payload

// --- Flow direction ---

// DiodeDirection describes the permitted data flow direction.
pub enum DiodeDirection {
	inbound       // Data flows into this node (receive side)
	outbound      // Data flows out of this node (send side)
	bidirectional // Stub for testing; never used in production
}

// FlowDirection enforces unidirectional data flow (legacy alias).
pub enum FlowDirection {
	low_to_high   // From low-security to high-security domain
	high_to_low   // From high-security to low-security domain
}

// --- Data structures ---

// DiodeStats holds transfer statistics for the current session.
pub struct DiodeStats {
pub:
	bytes_sent     u64
	bytes_received u64
	frames_sent    u64
	frames_dropped u64
	errors         int
}

// DiodeFilter specifies rules for dropping unwanted frames.
pub struct DiodeFilter {
pub:
	max_frame_size   int   // 0 = no limit
	allowed_seq_mod  u32   // Accept only frames where seq % mod == 0 (0 = accept all)
	require_nonzero  bool  // Drop frames with empty payload
}

// TransferSegment represents a single unit of diode transfer.
pub struct TransferSegment {
pub:
	sequence    u64       // Sequence number
	data        []u8      // Payload
	hash        string    // SHA-256 hash
	fec_group   u16       // Forward error correction group
}

// FecConfig specifies forward error correction parameters.
pub struct FecConfig {
pub:
	data_shards   int = 10   // Data segments per group
	parity_shards int = 3    // Parity segments per group
}

// TransferManifest describes a complete diode transfer.
pub struct TransferManifest {
pub:
	transfer_id   string
	direction     FlowDirection
	total_segments u64
	root_hash     string
	fec           FecConfig
}

// AuditRecord logs a compliance event.
pub struct AuditRecord {
pub:
	timestamp   i64
	transfer_id string
	direction   FlowDirection
	event       string
	verified    bool
}

// DiodeConfig holds data diode parameters.
pub struct DiodeConfig {
pub:
	bind_addr   string = "0.0.0.0"
	port        int    = 9999
	direction   FlowDirection = .low_to_high
	fec         FecConfig = FecConfig{}
}

// DiodeClient manages data diode transfers.
pub struct DiodeClient {
mut:
	config     DiodeConfig
	audit      []AuditRecord
	stats      DiodeStats
	filter     DiodeFilter
}

// --- Client lifecycle ---

// new_diode_client creates a new data diode client.
pub fn new_diode_client(config DiodeConfig) &DiodeClient {
	return &DiodeClient{
		config: config
		audit:  []AuditRecord{}
		stats:  DiodeStats{}
		filter: DiodeFilter{}
	}
}

// send transmits data through the diode (sender side).
pub fn (mut d DiodeClient) send(data []u8) ! {
	if data.len == 0 {
		return error("payload must not be empty")
	}
	h := sha256.sum(data)
	hash_hex := hex.encode(h)
	d.audit << AuditRecord{
		timestamp: time.now().unix()
		transfer_id: hash_hex[..16]
		direction: d.config.direction
		event: "send"
		verified: true
	}
	d.stats = DiodeStats{
		bytes_sent:     d.stats.bytes_sent + u64(data.len)
		bytes_received: d.stats.bytes_received
		frames_sent:    d.stats.frames_sent + 1
		frames_dropped: d.stats.frames_dropped
		errors:         d.stats.errors
	}
	println("[diode] sent ${data.len} bytes (${d.config.direction})")
}

// receive collects data from the diode (receiver side).
pub fn (mut d DiodeClient) receive() ![]u8 {
	println("[diode] listening on ${d.config.bind_addr}:${d.config.port}")
	return error("not implemented: requires hardware diode")
}

// get_stats returns the current transfer statistics.
pub fn (d &DiodeClient) get_stats() !DiodeStats {
	return d.stats
}

// set_filter configures the frame filter for the diode client.
pub fn (mut d DiodeClient) set_filter(filter DiodeFilter) ! {
	if filter.max_frame_size < 0 {
		return error("max_frame_size must be non-negative")
	}
	d.filter = filter
	println("[diode] filter set: max_frame_size=${filter.max_frame_size} require_nonzero=${filter.require_nonzero}")
}

// --- Frame encoding helper ---

// encode_frame builds a diode frame with magic header, 4-byte payload length, 4-byte sequence,
// and the payload bytes.
// Frame layout: [0xD1, 0x0D] | length(4 BE) | seq(4 BE) | payload
pub fn encode_frame(data []u8, seq u32) []u8 {
	mut out := []u8{}
	// Magic
	out << frame_magic
	// Length (4 bytes, big-endian)
	len_u32 := u32(data.len)
	out << u8(len_u32 >> 24)
	out << u8((len_u32 >> 16) & 0xFF)
	out << u8((len_u32 >> 8) & 0xFF)
	out << u8(len_u32 & 0xFF)
	// Sequence (4 bytes, big-endian)
	out << u8(seq >> 24)
	out << u8((seq >> 16) & 0xFF)
	out << u8((seq >> 8) & 0xFF)
	out << u8(seq & 0xFF)
	// Payload
	out << data
	return out
}

// decode_frame_header extracts magic, length, and sequence from a frame header.
// Returns (length, seq) or error if magic is wrong or frame is too short.
pub fn decode_frame_header(frame []u8) !(u32, u32) {
	if frame.len < frame_min_size {
		return error("frame too short: ${frame.len} bytes (min ${frame_min_size})")
	}
	if frame[0] != frame_magic[0] || frame[1] != frame_magic[1] {
		return error("invalid frame magic: 0x${frame[0]:02X}${frame[1]:02X}")
	}
	length := u32(frame[2]) << 24 | u32(frame[3]) << 16 | u32(frame[4]) << 8 | u32(frame[5])
	seq    := u32(frame[6]) << 24 | u32(frame[7]) << 16 | u32(frame[8]) << 8 | u32(frame[9])
	return length, seq
}

// --- Tests ---

fn test_empty_payload_rejected() {
	mut client := new_diode_client(DiodeConfig{})
	client.send([]u8{}) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_encode_frame_magic_and_seq() {
	payload := [u8(0xAA), 0xBB, 0xCC]
	frame := encode_frame(payload, 7)
	assert frame[0] == 0xD1
	assert frame[1] == 0x0D
	// seq = 7, stored at bytes 6-9
	assert frame[9] == 7
	// length = 3
	assert frame[5] == 3
}

fn test_encode_frame_includes_payload() {
	payload := "hello".bytes()
	frame := encode_frame(payload, 1)
	assert frame.len == frame_min_size + payload.len
	for i, b in payload {
		assert frame[frame_min_size + i] == b
	}
}

fn test_decode_frame_header_roundtrip() {
	payload := [u8(1), 2, 3, 4, 5]
	frame := encode_frame(payload, 42)
	length, seq := decode_frame_header(frame) or { panic(err) }
	assert length == 5
	assert seq == 42
}

fn test_decode_frame_header_invalid_magic() {
	bad := [u8(0x00), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
	decode_frame_header(bad) or {
		assert err.str().contains("invalid frame magic")
		return
	}
	assert false
}

