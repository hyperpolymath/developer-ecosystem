// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_kms — Key Management Service protocol types and server abstraction.
// Maps to proven-servers/protocols/proven-kms.
//
// Provides key creation, encryption, decryption, signing, verification,
// rotation, and lifecycle management. Supports symmetric and asymmetric
// algorithms. Network I/O is stubbed with TODO markers; all type
// definitions and logic are real.
module v_kms

import time
import crypto.sha256
import encoding.hex
import rand

// KeyType classifies the cryptographic key category.
pub enum KeyType {
	symmetric
	asymmetric
	hmac
}

// KeyAlgorithm enumerates the supported key algorithms.
pub enum KeyAlgorithm {
	aes256
	aes128
	rsa2048
	rsa4096
	ecdsa_p256
	ed25519
}

// KeyState tracks the lifecycle state of a managed key.
pub enum KeyState {
	active
	disabled
	pending_deletion
	deleted
}

// KeyMetadata holds the metadata for a managed cryptographic key.
pub struct KeyMetadata {
pub:
	// id is the unique identifier for this key.
	id string
	// alias is a human-readable name for the key.
	alias string
	// key_type classifies the key (symmetric, asymmetric, hmac).
	key_type KeyType
	// algorithm is the cryptographic algorithm for this key.
	algorithm KeyAlgorithm
	// created_at is the time the key was created.
	created_at time.Time
pub mut:
	// state is the current lifecycle state of the key.
	state KeyState
	// rotated_at is the time the key was last rotated.
	rotated_at time.Time
	// version tracks key rotation versions.
	version int = 1
}

// EncryptResult holds the output of an encryption operation.
pub struct EncryptResult {
pub:
	// ciphertext is the encrypted data.
	ciphertext []u8
	// key_id identifies the key used for encryption.
	key_id string
	// algorithm is the algorithm used.
	algorithm KeyAlgorithm
}

// SignResult holds the output of a signing operation.
pub struct SignResult {
pub:
	// signature is the cryptographic signature.
	signature []u8
	// key_id identifies the key used for signing.
	key_id string
	// algorithm is the algorithm used.
	algorithm KeyAlgorithm
}

// KmsServer is the Key Management Service server. It manages keys
// and performs cryptographic operations.
pub struct KmsServer {
pub:
	// name identifies this KMS instance.
	name string
pub mut:
	// keys holds all managed keys, keyed by id.
	keys map[string]KeyMetadata
	// key_material holds the raw key bytes, keyed by key id.
	// In production, this would be stored in an HSM.
	key_material map[string][]u8
	// next_id tracks the next key id to assign.
	next_id int = 1
}

// new_server creates a new KMS server instance.
pub fn new_server(name string) &KmsServer {
	return &KmsServer{
		name: name
		keys: map[string]KeyMetadata{}
		key_material: map[string][]u8{}
	}
}

// create_key generates a new cryptographic key with the specified
// parameters. Returns the key metadata (never the raw key material).
pub fn (mut s KmsServer) create_key(alias string, key_type KeyType, algorithm KeyAlgorithm) !KeyMetadata {
	if alias.len == 0 {
		return error('key alias must not be empty')
	}
	// Check for duplicate aliases.
	for _, existing in s.keys {
		if existing.alias == alias {
			return error('duplicate key alias: ${alias}')
		}
	}
	key_id := 'key-${s.next_id:06x}'
	s.next_id += 1
	now := time.now()
	// Determine key material size based on algorithm.
	key_size := match algorithm {
		.aes256 { 32 }
		.aes128 { 16 }
		.rsa2048 { 256 }
		.rsa4096 { 512 }
		.ecdsa_p256 { 32 }
		.ed25519 { 32 }
	}
	// Generate placeholder key material.
	// TODO: Use a proper cryptographic RNG or HSM for real key generation.
	mut material := []u8{len: key_size}
	for i in 0 .. key_size {
		material[i] = u8(rand.int_in_range(0, 256) or { 0 })
	}
	s.key_material[key_id] = material
	metadata := KeyMetadata{
		id: key_id
		alias: alias
		key_type: key_type
		algorithm: algorithm
		state: .active
		created_at: now
		rotated_at: now
	}
	s.keys[key_id] = metadata
	return metadata
}

// encrypt encrypts plaintext using the specified key. Returns an error
// if the key does not exist, is not active, or is not suitable for
// encryption.
pub fn (s KmsServer) encrypt(key_id string, plaintext []u8) !EncryptResult {
	meta := s.get_active_key(key_id)!
	if meta.key_type != .symmetric {
		return error('key ${key_id} is not a symmetric key')
	}
	material := s.key_material[key_id] or { return error('key material not found') }
	// TODO: Perform real AES encryption with the key material.
	// Placeholder: XOR plaintext with repeating key material.
	mut ciphertext := []u8{len: plaintext.len}
	for i in 0 .. plaintext.len {
		ciphertext[i] = plaintext[i] ^ material[i % material.len]
	}
	return EncryptResult{
		ciphertext: ciphertext
		key_id: key_id
		algorithm: meta.algorithm
	}
}

// decrypt decrypts ciphertext using the specified key. Returns an error
// if the key does not exist, is not active, or is not suitable.
pub fn (s KmsServer) decrypt(key_id string, ciphertext []u8) ![]u8 {
	meta := s.get_active_key(key_id)!
	if meta.key_type != .symmetric {
		return error('key ${key_id} is not a symmetric key')
	}
	material := s.key_material[key_id] or { return error('key material not found') }
	// TODO: Perform real AES decryption.
	// Placeholder: XOR reverses the encryption above.
	mut plaintext := []u8{len: ciphertext.len}
	for i in 0 .. ciphertext.len {
		plaintext[i] = ciphertext[i] ^ material[i % material.len]
	}
	return plaintext
}

// sign creates a cryptographic signature over the given data using the
// specified asymmetric key.
pub fn (s KmsServer) sign(key_id string, data []u8) !SignResult {
	meta := s.get_active_key(key_id)!
	if meta.key_type != .asymmetric {
		return error('key ${key_id} is not an asymmetric key')
	}
	// TODO: Perform real asymmetric signing (RSA/ECDSA/Ed25519).
	// Placeholder: HMAC-like hash of data with key material.
	material := s.key_material[key_id] or { return error('key material not found') }
	mut combined := []u8{}
	combined << material
	combined << data
	hash := sha256.sum(combined)
	return SignResult{
		signature: hash.to_array()
		key_id: key_id
		algorithm: meta.algorithm
	}
}

// verify checks a signature against the given data using the specified
// asymmetric key. Returns an error if verification fails.
pub fn (s KmsServer) verify(key_id string, data []u8, signature []u8) ! {
	meta := s.get_active_key(key_id)!
	if meta.key_type != .asymmetric {
		return error('key ${key_id} is not an asymmetric key')
	}
	// TODO: Perform real asymmetric signature verification.
	// Placeholder: recompute the HMAC-like hash and compare.
	material := s.key_material[key_id] or { return error('key material not found') }
	mut combined := []u8{}
	combined << material
	combined << data
	hash := sha256.sum(combined)
	expected := hash.to_array()
	if signature.len != expected.len {
		return error('signature verification failed')
	}
	for i in 0 .. signature.len {
		if signature[i] != expected[i] {
			return error('signature verification failed')
		}
	}
}

// rotate_key generates new key material for the specified key, incrementing
// its version number. The old key material is discarded.
pub fn (mut s KmsServer) rotate_key(key_id string) !KeyMetadata {
	if key_id !in s.keys {
		return error('key not found: ${key_id}')
	}
	mut meta := s.keys[key_id] or { return error('key not found: ${key_id}') }
	if meta.state != .active {
		return error('can only rotate active keys')
	}
	// Generate new key material.
	old_material := s.key_material[key_id] or { return error('key material not found') }
	mut new_material := []u8{len: old_material.len}
	for i in 0 .. new_material.len {
		new_material[i] = u8(rand.int_in_range(0, 256) or { 0 })
	}
	s.key_material[key_id] = new_material
	meta.version += 1
	meta.rotated_at = time.now()
	s.keys[key_id] = meta
	return meta
}

// disable_key transitions a key to the disabled state. Disabled keys
// cannot be used for cryptographic operations.
pub fn (mut s KmsServer) disable_key(key_id string) ! {
	if key_id !in s.keys {
		return error('key not found: ${key_id}')
	}
	mut meta := s.keys[key_id] or { return error('key not found: ${key_id}') }
	if meta.state == .deleted {
		return error('cannot disable a deleted key')
	}
	meta.state = .disabled
	s.keys[key_id] = meta
}

// schedule_deletion marks a key for deletion. The key enters the
// pending_deletion state and can no longer be used.
pub fn (mut s KmsServer) schedule_deletion(key_id string) ! {
	if key_id !in s.keys {
		return error('key not found: ${key_id}')
	}
	mut meta := s.keys[key_id] or { return error('key not found: ${key_id}') }
	if meta.state == .deleted {
		return error('key already deleted')
	}
	meta.state = .pending_deletion
	s.keys[key_id] = meta
	// TODO: Schedule actual deletion after a grace period (e.g. 30 days).
}

// list_keys returns metadata for all keys managed by this server.
pub fn (s KmsServer) list_keys() []KeyMetadata {
	mut result := []KeyMetadata{}
	for _, meta in s.keys {
		result << meta
	}
	return result
}

// get_active_key retrieves a key's metadata, verifying it is in the
// active state. Returns an error if the key is not found or not active.
fn (s KmsServer) get_active_key(key_id string) !KeyMetadata {
	if key_id !in s.keys {
		return error('key not found: ${key_id}')
	}
	meta := s.keys[key_id] or { return error('key not found: ${key_id}') }
	if meta.state != .active {
		return error('key ${key_id} is not active (state: ${meta.state})')
	}
	return meta
}
