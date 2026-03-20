// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_pqc.
// Validates KEM keygen/encapsulate/decapsulate, signature keygen/sign/verify,
// and hybrid key exchange.
module main

import v_pqc

// test_new_server_creates_empty verifies that a new PQC server has no
// keys.
fn test_new_server_creates_empty() {
	server := v_pqc.new_server('test-pqc')
	assert server.name == 'test-pqc'
	assert server.kem_keys.len == 0
	assert server.sig_keys.len == 0
}

// test_kem_keygen_kyber768 verifies KEM key generation for Kyber768.
fn test_kem_keygen_kyber768() {
	mut server := v_pqc.new_server('test-pqc')
	kp := server.kem_keygen('my-kem', .kyber768) or {
		assert false, 'kem_keygen failed: ${err}'
		return
	}
	assert kp.public_key.len == 1184
	assert kp.secret_key.len == 2400
	assert kp.algorithm == 'kyber768'
	assert server.kem_keys.len == 1
}

// test_kem_keygen_kyber512 verifies KEM key generation for Kyber512.
fn test_kem_keygen_kyber512() {
	mut server := v_pqc.new_server('test-pqc')
	kp := server.kem_keygen('kem-512', .kyber512) or {
		assert false, 'kem_keygen failed: ${err}'
		return
	}
	assert kp.public_key.len == 800
	assert kp.secret_key.len == 1632
}

// test_kem_keygen_empty_label_returns_error verifies empty label
// rejection.
fn test_kem_keygen_empty_label_returns_error() {
	mut server := v_pqc.new_server('test-pqc')
	server.kem_keygen('', .kyber768) or {
		assert err.msg().contains('must not be empty')
		return
	}
	assert false, 'expected error for empty label'
}

// test_kem_keygen_duplicate_returns_error verifies duplicate label
// rejection.
fn test_kem_keygen_duplicate_returns_error() {
	mut server := v_pqc.new_server('test-pqc')
	server.kem_keygen('dup', .kyber768) or { return }
	server.kem_keygen('dup', .kyber1024) or {
		assert err.msg().contains('already exists')
		return
	}
	assert false, 'expected error for duplicate label'
}

// test_kem_encapsulate verifies KEM encapsulation produces ciphertext
// and a shared secret.
fn test_kem_encapsulate() {
	mut server := v_pqc.new_server('test-pqc')
	server.kem_keygen('enc-kem', .kyber768) or { return }
	ct, shared_secret := server.kem_encapsulate('enc-kem') or {
		assert false, 'encapsulate failed: ${err}'
		return
	}
	assert ct.data.len > 0
	assert ct.algorithm == .kyber768
	assert shared_secret.len == 32
	assert ct.shared_secret_hash.len == 32
}

// test_kem_encapsulate_nonexistent_returns_error verifies that
// encapsulation fails for a missing key.
fn test_kem_encapsulate_nonexistent_returns_error() {
	server := v_pqc.new_server('test-pqc')
	server.kem_encapsulate('missing') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing KEM key'
}

// test_kem_decapsulate verifies KEM decapsulation produces a shared
// secret.
fn test_kem_decapsulate() {
	mut server := v_pqc.new_server('test-pqc')
	server.kem_keygen('dec-kem', .kyber1024) or { return }
	ct, _ := server.kem_encapsulate('dec-kem') or { return }
	decap_secret := server.kem_decapsulate('dec-kem', ct) or {
		assert false, 'decapsulate failed: ${err}'
		return
	}
	assert decap_secret.len == 32
}

// test_sig_keygen_dilithium3 verifies signature key generation for
// Dilithium3.
fn test_sig_keygen_dilithium3() {
	mut server := v_pqc.new_server('test-pqc')
	kp := server.sig_keygen('my-sig', .dilithium3) or {
		assert false, 'sig_keygen failed: ${err}'
		return
	}
	assert kp.public_key.len == 1952
	assert kp.secret_key.len == 4000
	assert kp.algorithm == 'dilithium3'
	assert server.sig_keys.len == 1
}

// test_sig_keygen_falcon512 verifies key generation for Falcon-512.
fn test_sig_keygen_falcon512() {
	mut server := v_pqc.new_server('test-pqc')
	kp := server.sig_keygen('falcon', .falcon512) or {
		assert false, 'sig_keygen failed: ${err}'
		return
	}
	assert kp.public_key.len == 897
	assert kp.secret_key.len == 1281
}

// test_sig_sign_verify_roundtrip verifies that signing then verifying
// succeeds.
fn test_sig_sign_verify_roundtrip() {
	mut server := v_pqc.new_server('test-pqc')
	server.sig_keygen('sign-key', .dilithium2) or { return }
	message := 'post-quantum secure message'.bytes()
	sig := server.sig_sign('sign-key', message) or {
		assert false, 'sign failed: ${err}'
		return
	}
	assert sig.data.len == 32
	assert sig.algorithm == .dilithium2
	server.sig_verify('sign-key', message, sig) or {
		assert false, 'verify failed: ${err}'
		return
	}
}

// test_sig_verify_wrong_message_returns_error verifies that tampered
// messages fail verification.
fn test_sig_verify_wrong_message_returns_error() {
	mut server := v_pqc.new_server('test-pqc')
	server.sig_keygen('tamper-key', .dilithium5) or { return }
	sig := server.sig_sign('tamper-key', 'original'.bytes()) or { return }
	server.sig_verify('tamper-key', 'tampered'.bytes(), sig) or {
		assert err.msg().contains('verification failed')
		return
	}
	assert false, 'expected verification failure'
}

// test_sig_sign_nonexistent_returns_error verifies that signing with
// a missing key fails.
fn test_sig_sign_nonexistent_returns_error() {
	server := v_pqc.new_server('test-pqc')
	server.sig_sign('missing', 'test'.bytes()) or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing sig key'
}

// test_hybrid_exchange verifies that hybrid key exchange produces a
// 32-byte combined shared secret.
fn test_hybrid_exchange() {
	mut server := v_pqc.new_server('test-pqc')
	server.kem_keygen('hybrid-kem', .kyber768) or { return }
	secret := server.hybrid_exchange('hybrid-kem') or {
		assert false, 'hybrid_exchange failed: ${err}'
		return
	}
	assert secret.len == 32
}

// test_hybrid_exchange_nonexistent_returns_error verifies that hybrid
// exchange fails for a missing KEM key.
fn test_hybrid_exchange_nonexistent_returns_error() {
	server := v_pqc.new_server('test-pqc')
	server.hybrid_exchange('missing') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for missing KEM key'
}
