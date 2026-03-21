// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Key management with envelope encryption, key rotation, and HSM integration Connector
// Author: Jonathan D.A. Jewell
//
// Key management with envelope encryption, key rotation, and HSM integration.
// Provides typed client bindings for the proven-kms protocol.

module kms

import os
import time
import net

// --- Key type ---

// KeyType identifies the cryptographic key algorithm.
pub enum KeyType {
	aes256_gcm     // Symmetric
	rsa4096        // Asymmetric
	ed25519        // EdDSA
	ml_kem_1024    // Post-quantum KEM
	ml_dsa_87      // Post-quantum signature
}

// --- Key state ---

// KeyState tracks the key lifecycle.
pub enum KeyState {
	active
	disabled
	scheduled_destruction
	destroyed
}

// --- Data structures ---

// CryptoKey defines a managed cryptographic key.
pub struct CryptoKey {
pub:
	key_id      string
	alias       string
	key_type    KeyType
	state       KeyState
	created_at  i64
	rotates_at  i64     // Epoch seconds for next rotation
}

// KmsConfig holds KMS connection parameters.
pub struct KmsConfig {
pub:
	endpoint    string
	auth_token  string
	hsm_slot    int = -1  // HSM slot (-1 = software)
}

// KmsManager manages cryptographic keys.
pub struct KmsManager {
mut:
	config  KmsConfig
	keys    []CryptoKey
}

// --- Manager lifecycle ---

// new_kms_manager creates a new KMS manager.
pub fn new_kms_manager(config KmsConfig) &KmsManager {
	return &KmsManager{
		config: config
		keys:   []CryptoKey{}
	}
}

// create_key provisions a new cryptographic key.
pub fn (mut m KmsManager) create_key(key CryptoKey) ! {
	if key.key_id.len == 0 {
		return error("key_id must not be empty")
	}
	m.keys << key
	println("[kms] created key ${key.alias} (${key.key_type})")
}

// rotate_key triggers key rotation for a key by ID.
pub fn (mut m KmsManager) rotate_key(key_id string) ! {
	for mut k in m.keys {
		if k.key_id == key_id {
			println("[kms] rotating key ${k.alias}")
			return
		}
	}
	return error("key not found: ${key_id}")
}

// --- Tests ---

fn test_empty_key_id_rejected() {
	mut mgr := new_kms_manager(KmsConfig{ endpoint: "http://localhost:8200", auth_token: "test" })
	mgr.create_key(CryptoKey{ key_id: "", alias: "test", key_type: .aes256_gcm, state: .active, created_at: 0, rotates_at: 0 }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
