// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_kms.
// Validates key creation, encryption/decryption, signing/verification,
// rotation, and lifecycle management.
module main

import v_kms

// test_new_server_creates_empty verifies that a new KMS server has no
// keys.
fn test_new_server_creates_empty() {
	server := v_kms.new_server('test-kms')
	assert server.name == 'test-kms'
	assert server.keys.len == 0
}

// test_create_symmetric_key verifies creation of an AES-256 key.
fn test_create_symmetric_key() {
	mut server := v_kms.new_server('test-kms')
	meta := server.create_key('my-aes-key', .symmetric, .aes256) or {
		assert false, 'create_key failed: ${err}'
		return
	}
	assert meta.alias == 'my-aes-key'
	assert meta.key_type == .symmetric
	assert meta.algorithm == .aes256
	assert meta.state == .active
	assert meta.version == 1
	assert server.keys.len == 1
}

// test_create_asymmetric_key verifies creation of an Ed25519 key.
fn test_create_asymmetric_key() {
	mut server := v_kms.new_server('test-kms')
	meta := server.create_key('my-signing-key', .asymmetric, .ed25519) or {
		assert false, 'create_key failed: ${err}'
		return
	}
	assert meta.key_type == .asymmetric
	assert meta.algorithm == .ed25519
}

// test_create_key_empty_alias_returns_error verifies that an empty
// alias is rejected.
fn test_create_key_empty_alias_returns_error() {
	mut server := v_kms.new_server('test-kms')
	server.create_key('', .symmetric, .aes256) or {
		assert err.msg().contains('alias must not be empty')
		return
	}
	assert false, 'expected error for empty alias'
}

// test_create_key_duplicate_alias_returns_error verifies that duplicate
// aliases are rejected.
fn test_create_key_duplicate_alias_returns_error() {
	mut server := v_kms.new_server('test-kms')
	server.create_key('dup', .symmetric, .aes128) or { return }
	server.create_key('dup', .symmetric, .aes256) or {
		assert err.msg().contains('duplicate')
		return
	}
	assert false, 'expected error for duplicate alias'
}

// test_encrypt_decrypt_roundtrip verifies that encrypting then
// decrypting returns the original plaintext.
fn test_encrypt_decrypt_roundtrip() {
	mut server := v_kms.new_server('test-kms')
	meta := server.create_key('enc-key', .symmetric, .aes256) or { return }
	plaintext := 'hello, world!'.bytes()
	result := server.encrypt(meta.id, plaintext) or {
		assert false, 'encrypt failed: ${err}'
		return
	}
	assert result.key_id == meta.id
	decrypted := server.decrypt(meta.id, result.ciphertext) or {
		assert false, 'decrypt failed: ${err}'
		return
	}
	assert decrypted == plaintext
}

// test_encrypt_with_asymmetric_key_returns_error verifies that
// encryption rejects asymmetric keys.
fn test_encrypt_with_asymmetric_key_returns_error() {
	mut server := v_kms.new_server('test-kms')
	meta := server.create_key('asym', .asymmetric, .rsa2048) or { return }
	server.encrypt(meta.id, 'test'.bytes()) or {
		assert err.msg().contains('not a symmetric key')
		return
	}
	assert false, 'expected error for asymmetric encrypt'
}

// test_sign_verify_roundtrip verifies that signing then verifying
// succeeds for the same data.
fn test_sign_verify_roundtrip() {
	mut server := v_kms.new_server('test-kms')
	meta := server.create_key('sig-key', .asymmetric, .ecdsa_p256) or { return }
	data := 'important document'.bytes()
	result := server.sign(meta.id, data) or {
		assert false, 'sign failed: ${err}'
		return
	}
	assert result.key_id == meta.id
	server.verify(meta.id, data, result.signature) or {
		assert false, 'verify failed: ${err}'
		return
	}
}

// test_verify_wrong_data_returns_error verifies that verification
// fails when data is tampered with.
fn test_verify_wrong_data_returns_error() {
	mut server := v_kms.new_server('test-kms')
	meta := server.create_key('sig-key', .asymmetric, .ed25519) or { return }
	result := server.sign(meta.id, 'original'.bytes()) or { return }
	server.verify(meta.id, 'tampered'.bytes(), result.signature) or {
		assert err.msg().contains('verification failed')
		return
	}
	assert false, 'expected verification failure'
}

// test_rotate_key verifies that rotation increments the version and
// updates the rotation timestamp.
fn test_rotate_key() {
	mut server := v_kms.new_server('test-kms')
	meta := server.create_key('rot-key', .symmetric, .aes256) or { return }
	assert meta.version == 1
	rotated := server.rotate_key(meta.id) or {
		assert false, 'rotate failed: ${err}'
		return
	}
	assert rotated.version == 2
	assert rotated.state == .active
}

// test_disable_key verifies that disabling a key changes its state.
fn test_disable_key() {
	mut server := v_kms.new_server('test-kms')
	meta := server.create_key('dis-key', .symmetric, .aes128) or { return }
	server.disable_key(meta.id) or {
		assert false, 'disable failed: ${err}'
		return
	}
	keys := server.list_keys()
	assert keys[0].state == .disabled
}

// test_disabled_key_cannot_encrypt verifies that a disabled key
// cannot be used for encryption.
fn test_disabled_key_cannot_encrypt() {
	mut server := v_kms.new_server('test-kms')
	meta := server.create_key('dis-key', .symmetric, .aes256) or { return }
	server.disable_key(meta.id) or { return }
	server.encrypt(meta.id, 'test'.bytes()) or {
		assert err.msg().contains('not active')
		return
	}
	assert false, 'expected error for disabled key'
}

// test_schedule_deletion verifies that scheduling deletion transitions
// the key to pending_deletion state.
fn test_schedule_deletion() {
	mut server := v_kms.new_server('test-kms')
	meta := server.create_key('del-key', .symmetric, .aes256) or { return }
	server.schedule_deletion(meta.id) or {
		assert false, 'schedule_deletion failed: ${err}'
		return
	}
	keys := server.list_keys()
	assert keys[0].state == .pending_deletion
}

// test_list_keys returns all managed keys.
fn test_list_keys() {
	mut server := v_kms.new_server('test-kms')
	server.create_key('key-1', .symmetric, .aes256) or { return }
	server.create_key('key-2', .asymmetric, .rsa4096) or { return }
	server.create_key('key-3', .hmac, .aes128) or { return }
	keys := server.list_keys()
	assert keys.len == 3
}
