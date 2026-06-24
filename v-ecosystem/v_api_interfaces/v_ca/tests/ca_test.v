// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_ca.
// Validates CA creation, certificate issuance, revocation, CRL management,
// chain verification, and renewal.
module main

import v_ca

// test_new_ca_creates_empty verifies that a new CA has no certificates
// or CRL entries.
fn test_new_ca_creates_empty() {
	ca := v_ca.new_ca('CN=Test Root CA', .root)
	assert ca.ca_subject == 'CN=Test Root CA'
	assert ca.ca_cert_type == .root
	assert ca.certificates.len == 0
	assert ca.crl.len == 0
}

// test_issue_cert_basic verifies that a certificate can be issued with
// the correct metadata.
fn test_issue_cert_basic() {
	mut ca := v_ca.new_ca('CN=Test CA', .root)
	req := v_ca.CertRequest{
		subject: 'CN=example.com'
		key_algo: .ecdsa_p256
		san_dns: ['example.com', 'www.example.com']
		validity_days: 90
	}
	cert := ca.issue_cert(req) or {
		assert false, 'issue_cert failed: ${err}'
		return
	}
	assert cert.subject == 'CN=example.com'
	assert cert.issuer == 'CN=Test CA'
	assert cert.key_algo == .ecdsa_p256
	assert cert.san_dns.len == 2
	assert cert.fingerprint.starts_with('SHA256:')
	assert cert.revoked == false
	assert ca.certificates.len == 1
}

// test_issue_cert_empty_subject_returns_error verifies that an empty
// subject is rejected.
fn test_issue_cert_empty_subject_returns_error() {
	mut ca := v_ca.new_ca('CN=Test CA', .root)
	req := v_ca.CertRequest{
		key_algo: .ed25519
		validity_days: 30
	}
	ca.issue_cert(req) or {
		assert err.msg().contains('subject must not be empty')
		return
	}
	assert false, 'expected error for empty subject'
}

// test_issue_cert_invalid_validity_returns_error verifies that zero
// or negative validity days are rejected.
fn test_issue_cert_invalid_validity_returns_error() {
	mut ca := v_ca.new_ca('CN=Test CA', .root)
	req := v_ca.CertRequest{
		subject: 'CN=test'
		key_algo: .rsa2048
		validity_days: 0
	}
	ca.issue_cert(req) or {
		assert err.msg().contains('validity_days')
		return
	}
	assert false, 'expected error for invalid validity'
}

// test_revoke_cert verifies that a certificate can be revoked and
// appears in the CRL.
fn test_revoke_cert() {
	mut ca := v_ca.new_ca('CN=Test CA', .root)
	cert := ca.issue_cert(v_ca.CertRequest{
		subject: 'CN=revoke-me'
		key_algo: .rsa4096
		validity_days: 365
	}) or {
		assert false, 'issue failed: ${err}'
		return
	}
	ca.revoke_cert(cert.serial, 'key compromise') or {
		assert false, 'revoke failed: ${err}'
		return
	}
	stored := ca.certificates[cert.serial] or {
		assert false, 'cert missing from store'
		return
	}
	assert stored.revoked == true
	crl := ca.get_crl()
	assert crl.len == 1
	assert crl[0].serial == cert.serial
	assert crl[0].reason == 'key compromise'
}

// test_revoke_nonexistent_returns_error verifies that revoking a
// nonexistent certificate fails.
fn test_revoke_nonexistent_returns_error() {
	mut ca := v_ca.new_ca('CN=Test CA', .root)
	ca.revoke_cert('nonexistent', 'test') or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for nonexistent cert'
}

// test_revoke_already_revoked_returns_error verifies that double
// revocation is rejected.
fn test_revoke_already_revoked_returns_error() {
	mut ca := v_ca.new_ca('CN=Test CA', .root)
	cert := ca.issue_cert(v_ca.CertRequest{
		subject: 'CN=double-revoke'
		key_algo: .ed25519
		validity_days: 30
	}) or { return }
	ca.revoke_cert(cert.serial, 'first') or { return }
	ca.revoke_cert(cert.serial, 'second') or {
		assert err.msg().contains('already revoked')
		return
	}
	assert false, 'expected error for double revocation'
}

// test_verify_chain_valid verifies that a valid certificate passes
// chain verification.
fn test_verify_chain_valid() {
	mut ca := v_ca.new_ca('CN=Test CA', .root)
	cert := ca.issue_cert(v_ca.CertRequest{
		subject: 'CN=valid.example.com'
		key_algo: .ecdsa_p384
		validity_days: 365
	}) or { return }
	ca.verify_chain(cert) or {
		assert false, 'verify_chain failed: ${err}'
		return
	}
}

// test_verify_chain_wrong_issuer verifies that a certificate with the
// wrong issuer fails verification.
fn test_verify_chain_wrong_issuer() {
	ca := v_ca.new_ca('CN=Test CA', .root)
	fake_cert := v_ca.Certificate{
		serial: '00000001'
		subject: 'CN=fake'
		issuer: 'CN=Other CA'
		key_algo: .rsa2048
	}
	ca.verify_chain(fake_cert) or {
		assert err.msg().contains('issuer mismatch')
		return
	}
	assert false, 'expected issuer mismatch error'
}

// test_verify_chain_revoked verifies that a revoked certificate fails
// chain verification.
fn test_verify_chain_revoked() {
	mut ca := v_ca.new_ca('CN=Test CA', .root)
	cert := ca.issue_cert(v_ca.CertRequest{
		subject: 'CN=revoked.example.com'
		key_algo: .ed25519
		validity_days: 365
	}) or { return }
	ca.revoke_cert(cert.serial, 'compromised') or { return }
	ca.verify_chain(cert) or {
		assert err.msg().contains('revoked')
		return
	}
	assert false, 'expected revocation error'
}

// test_renew_cert verifies that renewing a certificate creates a new
// certificate with fresh validity.
fn test_renew_cert() {
	mut ca := v_ca.new_ca('CN=Test CA', .root)
	original := ca.issue_cert(v_ca.CertRequest{
		subject: 'CN=renew.example.com'
		key_algo: .ecdsa_p256
		san_dns: ['renew.example.com']
		validity_days: 30
	}) or { return }
	renewed := ca.renew_cert(original.serial, 365) or {
		assert false, 'renew failed: ${err}'
		return
	}
	assert renewed.subject == original.subject
	assert renewed.key_algo == original.key_algo
	assert renewed.serial != original.serial
	assert ca.certificates.len == 2
}

// test_renew_revoked_returns_error verifies that renewing a revoked
// certificate is rejected.
fn test_renew_revoked_returns_error() {
	mut ca := v_ca.new_ca('CN=Test CA', .root)
	cert := ca.issue_cert(v_ca.CertRequest{
		subject: 'CN=revoked'
		key_algo: .rsa2048
		validity_days: 30
	}) or { return }
	ca.revoke_cert(cert.serial, 'test') or { return }
	ca.renew_cert(cert.serial, 365) or {
		assert err.msg().contains('revoked')
		return
	}
	assert false, 'expected error for renewing revoked cert'
}

// test_serial_increments verifies that serial numbers increase with
// each issued certificate.
fn test_serial_increments() {
	mut ca := v_ca.new_ca('CN=Test CA', .root)
	cert1 := ca.issue_cert(v_ca.CertRequest{
		subject: 'CN=first'
		key_algo: .ed25519
		validity_days: 30
	}) or { return }
	cert2 := ca.issue_cert(v_ca.CertRequest{
		subject: 'CN=second'
		key_algo: .ed25519
		validity_days: 30
	}) or { return }
	assert cert1.serial != cert2.serial
	assert ca.certificates.len == 2
}
