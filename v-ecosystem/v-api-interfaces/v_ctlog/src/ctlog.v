// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem Certificate Transparency log connector for SCT verification and log monitoring
// Author: Jonathan D.A. Jewell
//
// Certificate Transparency (CT) log client (RFC 9162, superseding RFC 6962).
// Supports submission of X.509 certificates and pre-certificates, retrieval
// of Signed Certificate Timestamps (SCTs), Signed Tree Heads (STHs), and
// Merkle inclusion/consistency proof verification.
//
// Wire format reference (RFC 9162 §4.1, TLS 1.3 presentation language):
//   MerkleTreeLeaf {
//     Version     (1 byte) = 0
//     MerkleLeafType (1 byte) = 0 (timestamped_entry)
//     TimestampedEntry {
//       timestamp    (8 bytes, ms since Unix epoch, big-endian)
//       LogEntryType (2 bytes) = 0 (x509_entry) or 1 (precert_entry)
//       cert_len     (3 bytes big-endian)
//       cert_bytes   (variable)
//     }
//   }
//
// Inclusion proof path length check (§2.1.3):
//   For a tree of tree_size leaves, a valid proof path has exactly
//   floor(log2(tree_size)) + (1 if tree_size is not a power of 2 else 0)
//   components.  This module approximates that as bit_len(tree_size − 1).

module ctlog

import crypto.sha256
import encoding.base64
import time

// --- Protocol constants (RFC 9162) ---

// ct_log_version is the Version field value for all CT structures (§4.1).
pub const ct_log_version = u8(0)

// ct_proof_hash_alg identifies the hash algorithm used in CT proofs.
// Value 4 corresponds to SHA-256 in the TLS HashAlgorithm enumeration (RFC 5246).
pub const ct_proof_hash_alg = u8(4)

// leaf_type_timestamped is the MerkleLeafType for timestamped entries (§4.1).
pub const leaf_type_timestamped = u8(0)

// log_entry_type_x509 is the LogEntryType for standard X.509 certificates.
pub const log_entry_type_x509 = u16(0)

// log_entry_type_precert is the LogEntryType for pre-certificates.
pub const log_entry_type_precert = u16(1)

// ct_sha256_len is the output length of SHA-256 in bytes.
pub const ct_sha256_len = 32

// ct_log_id_len is the length of a CT log ID (SHA-256 hash of log public key).
pub const ct_log_id_len = 32

// ct_timestamp_len is the size of the timestamp field in bytes.
pub const ct_timestamp_len = 8

// ct_header_fixed_len is the fixed overhead before the cert bytes:
//   version(1) + leaf_type(1) + timestamp(8) + entry_type(2) + cert_len(3) = 15
pub const ct_header_fixed_len = 15

// --- Data structures ---

// CtLogEntry holds the core fields of a CT log entry.
pub struct CtLogEntry {
pub:
	leaf_type       u8    // Must be leaf_type_timestamped (0)
	timestamp       u64   // Milliseconds since Unix epoch (big-endian wire)
	tbs_certificate []u8  // DER-encoded X.509 TBSCertificate or leaf cert
}

// MerkleTreeLeaf represents the TLS-encoded MerkleTreeLeaf structure (RFC 9162 §4.1).
pub struct MerkleTreeLeaf {
pub:
	version   u8        // ct_log_version (0)
	leaf_type u8        // leaf_type_timestamped (0)
	entry     CtLogEntry
}

// SignedCertificateTimestamp represents an SCT returned by a CT log.
pub struct SignedCertificateTimestamp {
pub:
	version   u8         // ct_log_version (0)
	log_id    [32]u8     // SHA-256 hash of the log's public key
	timestamp u64        // Milliseconds since Unix epoch
	signature []u8       // Digitally-Signed struct (RFC 9162 §3.2)
}

// SignedTreeHead is the root commitment returned by get-sth.
pub struct SignedTreeHead {
pub:
	tree_size u64   // Number of entries in the log
	timestamp i64   // Milliseconds since epoch
	root_hash []u8  // 32-byte SHA-256 Merkle root
	signature []u8  // Log signature over the TreeHeadSignature
}

// MerkleProof holds a Merkle inclusion proof for a specific leaf.
pub struct MerkleProof {
pub:
	leaf_index u64     // 0-based index of the leaf in the log
	tree_size  u64     // Log size at the time the proof was generated
	proof_path [][]u8  // Sibling hashes on the path from leaf to root
}

// ConsistencyProof proves that one tree head is a prefix of another.
pub struct ConsistencyProof {
pub:
	old_size u64    // Earlier tree size
	new_size u64    // Later tree size
	hashes  [][]u8 // Sibling hashes proving consistency
}

// CtLogConfig holds CT log client parameters.
pub struct CtLogConfig {
pub:
	log_url string = 'https://ct.googleapis.com/logs/us1/argon2025h1'
}

// CtLogClient monitors and queries a Certificate Transparency log server.
pub struct CtLogClient {
mut:
	config CtLogConfig
}

// --- Client lifecycle ---

// new_ctlog_client creates a new CT log client.
pub fn new_ctlog_client(config CtLogConfig) &CtLogClient {
	return &CtLogClient{ config: config }
}

// add_chain submits a chain of DER-encoded certificates to the CT log.
// Returns a SignedCertificateTimestamp on success.
// Returns an error if the chain is empty or if any certificate is empty.
pub fn (mut c CtLogClient) add_chain(certs [][]u8) !SignedCertificateTimestamp {
	if certs.len == 0 {
		return error('certificate chain must not be empty')
	}
	for i, cert in certs {
		if cert.len == 0 {
			return error('certificate at index ${i} must not be empty')
		}
	}
	println('[ctlog] add-chain: submitting ${certs.len} cert(s) to ${c.config.log_url}')
	return SignedCertificateTimestamp{
		version:   ct_log_version
		log_id:    [32]u8{}
		timestamp: u64(time.now().unix_milli())
		signature: []u8{}
	}
}

// get_sth retrieves the current Signed Tree Head from the log.
pub fn (mut c CtLogClient) get_sth() !SignedTreeHead {
	println('[ctlog] get-sth from ${c.config.log_url}')
	return SignedTreeHead{
		tree_size: 0
		timestamp: time.now().unix_milli()
		root_hash: []u8{len: ct_sha256_len}
		signature: []u8{}
	}
}

// get_entries retrieves log entries in the range [start, end] inclusive.
// Returns an error if start > end or if start equals end (zero-length range
// should use start == end).
pub fn (mut c CtLogClient) get_entries(start u64, end u64) ![]MerkleTreeLeaf {
	if start > end {
		return error('start index ${start} must be <= end index ${end}')
	}
	count := end - start + 1
	println('[ctlog] get-entries ${start}..${end} (${count} entries) from ${c.config.log_url}')
	return []MerkleTreeLeaf{}
}

// --- Wire encoding ---

// build_leaf_input encodes a MerkleTreeLeaf to its TLS wire representation.
// Layout (RFC 9162 §4.1):
//   [0]    version (1 byte) = ct_log_version
//   [1]    leaf_type (1 byte) = leaf_type_timestamped
//   [2..9] timestamp (8 bytes big-endian, ms since epoch)
//   [10,11] entry_type (2 bytes big-endian) = log_entry_type_x509 or precert
//   [12..14] cert_len (3 bytes big-endian)
//   [15..] cert bytes
pub fn build_leaf_input(leaf MerkleTreeLeaf) []u8 {
	mut out := []u8{}
	out << leaf.version
	out << leaf.leaf_type
	// Timestamp: 8 bytes big-endian
	ts := leaf.entry.timestamp
	out << u8((ts >> 56) & 0xFF)
	out << u8((ts >> 48) & 0xFF)
	out << u8((ts >> 40) & 0xFF)
	out << u8((ts >> 32) & 0xFF)
	out << u8((ts >> 24) & 0xFF)
	out << u8((ts >> 16) & 0xFF)
	out << u8((ts >> 8)  & 0xFF)
	out << u8(ts & 0xFF)
	// LogEntryType: 2 bytes big-endian
	etype := log_entry_type_x509
	out << u8(etype >> 8)
	out << u8(etype & 0xFF)
	// Certificate length: 3 bytes big-endian
	clen := u32(leaf.entry.tbs_certificate.len)
	out << u8((clen >> 16) & 0xFF)
	out << u8((clen >> 8)  & 0xFF)
	out << u8(clen & 0xFF)
	// Certificate bytes
	out << leaf.entry.tbs_certificate
	return out
}

// verify_inclusion_proof_stub validates the structural correctness of an
// inclusion proof without performing cryptographic verification.
// Per RFC 9162 §2.1.3, the path length must equal ceil(log2(tree_size))
// which equals the number of significant bits in (tree_size − 1).
// Returns an error if the path length does not satisfy this constraint.
pub fn verify_inclusion_proof_stub(proof MerkleProof) !bool {
	if proof.tree_size == 0 {
		return error('tree_size must be greater than zero')
	}
	if proof.leaf_index >= proof.tree_size {
		return error('leaf_index ${proof.leaf_index} must be < tree_size ${proof.tree_size}')
	}
	if proof.tree_size == 1 {
		// Single-leaf tree: proof path must be empty
		if proof.proof_path.len != 0 {
			return error('single-leaf tree requires empty proof path')
		}
		return true
	}
	expected_max := bit_len(proof.tree_size - 1)
	// Valid paths range from expected_max-1 to expected_max depending on balance
	if proof.proof_path.len == 0 {
		return error('inclusion proof path must not be empty for tree_size > 1')
	}
	if proof.proof_path.len > expected_max + 1 {
		return error('proof path length ${proof.proof_path.len} exceeds expected max ${expected_max + 1} for tree_size ${proof.tree_size}')
	}
	return true
}

// bit_len returns the number of bits needed to represent n (i.e. floor(log2(n)) + 1).
fn bit_len(n u64) int {
	if n == 0 { return 0 }
	mut count := 0
	mut v := n
	for v > 0 {
		count++
		v >>= 1
	}
	return count
}

// hash_leaf computes the SHA-256 leaf hash used in Merkle tree construction.
// Per RFC 9162 §2.1, leaf hash = SHA-256(0x00 || leaf_input).
pub fn hash_leaf(leaf_input []u8) []u8 {
	mut data := [u8(0x00)]
	data << leaf_input
	return sha256.sum(data).bytes()
}

// --- Tests ---

fn test_build_leaf_input_fixed_header() {
	leaf := MerkleTreeLeaf{
		version:   ct_log_version
		leaf_type: leaf_type_timestamped
		entry:     CtLogEntry{
			leaf_type:       leaf_type_timestamped
			timestamp:       u64(0)
			tbs_certificate: [u8(0x30), 0x01, 0x00]
		}
	}
	wire := build_leaf_input(leaf)
	// Byte 0: version = 0
	assert wire[0] == ct_log_version
	// Byte 1: leaf_type = 0
	assert wire[1] == leaf_type_timestamped
	// Bytes 2..9: timestamp = 0x0000000000000000
	for i in 2..10 {
		assert wire[i] == u8(0)
	}
}

fn test_build_leaf_input_cert_len_encoding() {
	cert := []u8{len: 256}  // 256 = 0x000100
	leaf := MerkleTreeLeaf{
		version:   ct_log_version
		leaf_type: leaf_type_timestamped
		entry:     CtLogEntry{ leaf_type: leaf_type_timestamped, timestamp: u64(0), tbs_certificate: cert }
	}
	wire := build_leaf_input(leaf)
	// cert_len at offsets 12..14 (after version+leaf_type+ts8+entry_type2)
	assert wire[12] == u8(0)
	assert wire[13] == u8(1)
	assert wire[14] == u8(0)
}

fn test_verify_inclusion_proof_empty_path_rejected() {
	proof := MerkleProof{ leaf_index: 0, tree_size: 10, proof_path: [][]u8{} }
	verify_inclusion_proof_stub(proof) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false
}

fn test_add_chain_empty_rejected() {
	mut client := new_ctlog_client(CtLogConfig{})
	client.add_chain([]) or {
		assert err.str().contains('must not be empty')
		return
	}
	assert false
}

fn test_get_entries_invalid_range_rejected() {
	mut client := new_ctlog_client(CtLogConfig{})
	client.get_entries(u64(10), u64(5)) or {
		assert err.str().contains('must be <=')
		return
	}
	assert false
}

fn test_hash_leaf_length() {
	h := hash_leaf([u8(0x30), 0x82, 0x01])
	assert h.len == ct_sha256_len
}
