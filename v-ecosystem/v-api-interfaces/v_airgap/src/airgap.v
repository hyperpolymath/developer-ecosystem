// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_airgap -- Air-gap file transfer via removable media (USB/QR code).
// Supports manifest creation, SHA-256 hash verification, staged chunked copy,
// and Merkle-root integrity proofs for high-security offline environments.
// Maps to proven-servers/protocols/proven-airgap.
module airgap

import os
import crypto.sha256
import encoding.hex
import time

// -- Constants ----------------------------------------------------------------

// max_qr_chunk is the maximum chunk size suitable for QR code encoding (bytes).
pub const max_qr_chunk = 2048

// max_usb_chunk is the maximum chunk size for USB block transfer (bytes).
pub const max_usb_chunk = 1_048_576

// manifest_filename is the conventional manifest filename written to media.
pub const manifest_filename = 'AIRGAP_MANIFEST.json'

// hash_algo names the hash algorithm used for all integrity checks.
pub const hash_algo = 'sha256'

// -- Enumerations -------------------------------------------------------------

// TransferDirection indicates whether data is leaving or entering the enclave.
pub enum TransferDirection {
	// export_out means data is moving from the secure environment to external media.
	export_out
	// import_in means data is being loaded from media into the secure environment.
	import_in
}

// TransferStatus tracks the progress of a transfer session.
pub enum TransferStatus {
	// initialised means the session is configured but no chunks have been exchanged.
	initialised
	// in_progress means chunks are actively being sent or received.
	in_progress
	// complete means all chunks have been received and verified.
	complete
	// failed means a hash mismatch or I/O error occurred; error_msg is set.
	failed
}

// -- Structures ---------------------------------------------------------------

// Chunk represents a single data fragment within an air-gap transfer.
// Each chunk carries its own SHA-256 hash for independent verification before
// assembly, allowing the receiver to detect corruption at the per-chunk level.
pub struct Chunk {
pub:
	// index is the zero-based position of this chunk in the transfer.
	index int
	// data is the raw payload bytes for this chunk.
	data []u8
	// hash is the lowercase hex-encoded SHA-256 hash of data.
	hash string
}

// ChunkManifest describes the complete set of chunks that make up a transfer.
// The manifest is written to the removable medium alongside the chunk files so
// that the receiver can verify completeness and root integrity independently.
pub struct ChunkManifest {
pub:
	// transfer_id is the unique identifier for this transfer session.
	transfer_id string
	// total_chunks is the expected number of chunks in this transfer.
	total_chunks int
	// hash_algo identifies the hash function used (always "sha256").
	hash_algo string
	// root_hash is the SHA-256 of the concatenation of all chunk hashes.
	root_hash string
	// direction indicates whether this is an export or import.
	direction TransferDirection
	// created_at is the Unix timestamp when the manifest was created.
	created_at i64
}

// TransferSession tracks the state of an ongoing air-gap transfer.
// Use prepare_export to set up an outgoing transfer and
// set_import_manifest + receive_chunk to consume an incoming one.
pub struct TransferSession {
pub mut:
	// manifest describes the expected transfer parameters.
	manifest ChunkManifest
	// received is a boolean bitmap: received[i] is true when chunk i arrived.
	received []bool
	// status is the current transfer state.
	status TransferStatus
	// error_msg records the first error encountered (set when status == .failed).
	error_msg string
}

// Config holds parameters for the air-gap transfer client.
pub struct Config {
pub:
	// chunk_size is the size of each chunk in bytes (default: max_qr_chunk).
	chunk_size int = max_qr_chunk
	// verify_hash enables per-chunk integrity verification on receive.
	verify_hash bool = true
	// device_path is the path to the removable media mount point.
	device_path string = '/media/removable'
	// staging_dir is the local staging directory for chunk files.
	staging_dir string = '/tmp/airgap-staging'
}

// -- Functions ----------------------------------------------------------------

// new_session creates a new air-gap transfer session with uninitialised state.
pub fn new_session(config Config) &TransferSession {
	return &TransferSession{
		manifest: ChunkManifest{
			transfer_id:  'ag-unset'
			total_chunks: 0
			hash_algo:    hash_algo
			root_hash:    ''
			direction:    .export_out
			created_at:   time.now().unix()
		}
		received: []bool{}
		status:   .initialised
	}
}

// prepare_export splits data into fixed-size chunks, computes per-chunk SHA-256
// hashes, builds a Merkle-style root from all chunk hashes, and initialises
// the session manifest. Returns the slice of Chunk values ready for transfer.
pub fn (mut s TransferSession) prepare_export(data []u8, chunk_size int, transfer_id string) ![]Chunk {
	if data.len == 0 {
		return error('export data must not be empty')
	}
	if chunk_size <= 0 {
		return error('chunk_size must be positive')
	}
	mut chunks := []Chunk{}
	mut offset := 0
	mut idx := 0
	mut chunk_hashes := []string{}

	for offset < data.len {
		end := if offset + chunk_size > data.len { data.len } else { offset + chunk_size }
		slice := data[offset..end]
		h := hex.encode(sha256.sum(slice))
		chunks << Chunk{
			index: idx
			data:  slice
			hash:  h
		}
		chunk_hashes << h
		offset = end
		idx++
	}

	// Compute root hash as SHA-256 of all chunk hashes concatenated.
	root_hash := hex.encode(sha256.sum(chunk_hashes.join('').bytes()))

	s.manifest = ChunkManifest{
		transfer_id:  transfer_id
		total_chunks: chunks.len
		hash_algo:    hash_algo
		root_hash:    root_hash
		direction:    .export_out
		created_at:   time.now().unix()
	}
	s.received = []bool{len: chunks.len, init: false}
	s.status = .in_progress
	return chunks
}

// set_import_manifest configures the session to receive an incoming transfer.
// Must be called before receive_chunk when operating in import_in direction.
pub fn (mut s TransferSession) set_import_manifest(manifest ChunkManifest) {
	s.manifest = manifest
	s.received = []bool{len: manifest.total_chunks, init: false}
	s.status = .initialised
}

// receive_chunk validates the hash of an incoming chunk and marks it received.
// Returns an error on index out of range or SHA-256 hash mismatch.
pub fn (mut s TransferSession) receive_chunk(chunk Chunk) ! {
	if s.manifest.total_chunks == 0 {
		return error('manifest not initialised -- call set_import_manifest first')
	}
	if chunk.index < 0 || chunk.index >= s.manifest.total_chunks {
		return error('chunk index ${chunk.index} out of range (total=${s.manifest.total_chunks})')
	}
	computed := hex.encode(sha256.sum(chunk.data))
	if computed != chunk.hash {
		s.status = .failed
		s.error_msg = 'chunk ${chunk.index} hash mismatch: expected ${chunk.hash}, got ${computed}'
		return error(s.error_msg)
	}
	s.received[chunk.index] = true
	s.status = .in_progress
}

// is_complete returns true when all expected chunks have been received and verified.
pub fn (s &TransferSession) is_complete() bool {
	if s.received.len == 0 || s.manifest.total_chunks == 0 {
		return false
	}
	for r in s.received {
		if !r {
			return false
		}
	}
	return true
}

// received_count returns the number of successfully received chunks so far.
pub fn (s &TransferSession) received_count() int {
	mut n := 0
	for r in s.received {
		if r {
			n++
		}
	}
	return n
}

// write_manifest serialises the manifest as a minimal JSON string.
// Suitable for writing to a file on removable media.
pub fn (s &TransferSession) write_manifest() string {
	m := s.manifest
	return '{"transfer_id":"${m.transfer_id}","total_chunks":${m.total_chunks},"hash_algo":"${m.hash_algo}","root_hash":"${m.root_hash}","created_at":${m.created_at}}'
}

// verify_root_hash recomputes the Merkle root from all provided chunks and
// compares it against expected_root. Returns an error on any mismatch.
pub fn verify_root_hash(chunks []Chunk, expected_root string) !bool {
	if chunks.len == 0 {
		return error('chunks slice is empty')
	}
	mut hashes := []string{}
	for c in chunks {
		computed := hex.encode(sha256.sum(c.data))
		if computed != c.hash {
			return error('chunk ${c.index} stored hash is invalid')
		}
		hashes << c.hash
	}
	root := hex.encode(sha256.sum(hashes.join('').bytes()))
	if root != expected_root {
		return error('root hash mismatch: expected ${expected_root}, got ${root}')
	}
	return true
}

// write_chunks_to_dir writes each chunk as chunk_NNNN.bin plus the manifest
// JSON to the given directory. Creates the directory if absent.
pub fn write_chunks_to_dir(chunks []Chunk, manifest ChunkManifest, dir string) ! {
	if dir.len == 0 {
		return error('output directory must not be empty')
	}
	os.mkdir_all(dir) or { return error('cannot create output dir ${dir}: ${err}') }
	for c in chunks {
		filename := os.join_path(dir, 'chunk_${c.index:04d}.bin')
		os.write_file_array(filename, c.data) or {
			return error('failed writing chunk ${c.index}: ${err}')
		}
	}
	manifest_json := '{"transfer_id":"${manifest.transfer_id}","total_chunks":${manifest.total_chunks},"hash_algo":"${manifest.hash_algo}","root_hash":"${manifest.root_hash}"}'
	os.write_file(os.join_path(dir, manifest_filename), manifest_json) or {
		return error('failed writing manifest: ${err}')
	}
}

// -- Tests --------------------------------------------------------------------

fn test_chunk_splitting_produces_correct_count() {
	mut sess := new_session(Config{})
	data := []u8{len: 100, init: u8(0x41)}
	chunks := sess.prepare_export(data, 30, 'tx-test') or {
		assert false, 'prepare_export failed: ${err}'
		return
	}
	// 100 bytes / 30 = 3 full + 1 partial = 4 chunks.
	assert chunks.len == 4
	assert sess.manifest.total_chunks == 4
	assert sess.manifest.transfer_id == 'tx-test'
	assert sess.manifest.hash_algo == 'sha256'
}

fn test_receive_chunk_detects_hash_corruption() {
	mut export_sess := new_session(Config{})
	data := []u8{len: 50, init: u8(0xAB)}
	chunks := export_sess.prepare_export(data, 25, 'tx-corrupt') or {
		assert false, 'prepare_export failed: ${err}'
		return
	}
	// Tamper with the stored hash on chunk 0.
	bad := Chunk{
		index: chunks[0].index
		data:  chunks[0].data
		hash:  'badc0de0' + chunks[0].hash[8..]
	}
	mut import_sess := new_session(Config{})
	import_sess.set_import_manifest(export_sess.manifest)
	import_sess.receive_chunk(bad) or {
		assert err.str().contains('hash mismatch')
		return
	}
	assert false, 'should have rejected corrupted chunk'
}

fn test_verify_root_hash_round_trip() {
	mut sess := new_session(Config{})
	data := []u8{len: 60, init: u8(0xFF)}
	chunks := sess.prepare_export(data, 20, 'tx-root') or {
		assert false, 'prepare_export failed: ${err}'
		return
	}
	ok := verify_root_hash(chunks, sess.manifest.root_hash) or {
		assert false, 'verify_root_hash error: ${err}'
		return
	}
	assert ok
}
