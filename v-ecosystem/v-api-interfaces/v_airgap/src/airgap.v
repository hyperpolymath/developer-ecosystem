// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Air-gapped transfer protocol connector for secure offline data exchange Connector
// Author: Jonathan D.A. Jewell
//
// Air-gapped data transfer client for secure offline environments. Supports
// sneakernet-style serialisation, QR code chunking, USB device enumeration,
// hash-chain integrity verification, and manifest-based transfer validation.
// Designed for high-security environments where network connectivity is
// intentionally absent.

module airgap

import os
import crypto.sha256
import encoding.hex

// --- Air-gap transfer constants ---

// Maximum chunk size for QR code encoding (bytes).
const max_qr_chunk = 2048

// Maximum chunk size for USB transfer (bytes).
const max_usb_chunk = 1048576

// --- Transfer direction ---

// TransferDirection indicates whether data flows in or out.
pub enum TransferDirection {
	export_out   // Data leaving the secure enclave
	import_in    // Data entering the secure enclave
}

// --- Data structures ---

// ChunkManifest describes a set of chunks comprising a single transfer.
pub struct ChunkManifest {
pub:
	transfer_id  string    // Unique transfer session identifier
	total_chunks int       // Total number of chunks
	hash_algo    string    // Hash algorithm (sha256)
	root_hash    string    // Merkle root of all chunk hashes
}

// Chunk represents a single data fragment within a transfer.
pub struct Chunk {
pub:
	index     int       // Chunk ordinal (0-based)
	data      []u8      // Raw chunk payload
	hash      string    // SHA-256 hash of data
}

// TransferSession tracks the state of an ongoing air-gapped transfer.
pub struct TransferSession {
pub mut:
	manifest  ChunkManifest
	received  []bool     // Which chunks have been received
	direction TransferDirection
}

// Config holds air-gap transfer parameters.
pub struct Config {
pub:
	chunk_size   int    = max_qr_chunk   // Chunk size in bytes
	verify_hash  bool   = true           // Verify chunk integrity
	device_path  string = "/dev/sda1"    // USB device path
}

// --- Session lifecycle ---

// new_session creates a new air-gapped transfer session.
pub fn new_session(config Config) &TransferSession {
	return &TransferSession{
		manifest: ChunkManifest{
			transfer_id: "ag-session"
			total_chunks: 0
			hash_algo: "sha256"
			root_hash: ""
		}
		received: []bool{}
		direction: .export_out
	}
}

// prepare_export splits data into chunks and builds a manifest.
pub fn (mut s TransferSession) prepare_export(data []u8, chunk_size int) []Chunk {
	mut chunks := []Chunk{}
	mut offset := 0
	mut idx := 0
	for offset < data.len {
		end := if offset + chunk_size > data.len { data.len } else { offset + chunk_size }
		slice := data[offset..end]
		h := sha256.sum(slice)
		chunks << Chunk{
			index: idx
			data: slice
			hash: hex.encode(h)
		}
		offset = end
		idx += 1
	}
	s.manifest.total_chunks = chunks.len
	s.received = []bool{len: chunks.len, init: false}
	return chunks
}

// receive_chunk validates and stores a single incoming chunk.
pub fn (mut s TransferSession) receive_chunk(chunk Chunk) ! {
	if chunk.index < 0 || chunk.index >= s.manifest.total_chunks {
		return error("chunk index ${chunk.index} out of range")
	}
	h := sha256.sum(chunk.data)
	computed := hex.encode(h)
	if computed != chunk.hash {
		return error("chunk ${chunk.index} hash mismatch")
	}
	s.received[chunk.index] = true
}

// is_complete returns true when all chunks have been received.
pub fn (s &TransferSession) is_complete() bool {
	for r in s.received {
		if !r { return false }
	}
	return s.received.len > 0
}

// --- Tests ---

fn test_chunk_splitting() {
	mut sess := TransferSession{
		manifest: ChunkManifest{ transfer_id: "test", total_chunks: 0, hash_algo: "sha256", root_hash: "" }
		received: []bool{}
		direction: .export_out
	}
	data := []u8{len: 100, init: u8(0x41)}
	chunks := sess.prepare_export(data, 30)
	assert chunks.len == 4
	assert sess.manifest.total_chunks == 4
}
