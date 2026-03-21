// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Protocol conformance tests for v_ocsp.
// Validates OCSP server creation, record management, status checking,
// request creation, response processing, and signing.
module main

import v_ocsp

// test_new_server_creates_empty verifies that a new OCSP server has
// no records.
fn test_new_server_creates_empty() {
	server := v_ocsp.new_server('test-responder', [u8(0x01), 0x02, 0x03])
	assert server.responder_id == 'test-responder'
	assert server.port == 8080
	assert server.records.len == 0
	assert server.validity_period == 3600
}

// test_add_record verifies that certificate records can be added.
fn test_add_record() {
	mut server := v_ocsp.new_server('test', [u8(0x01)])
	server.add_record(v_ocsp.CertRecord{
		serial_number: '00000001'
		issuer_name_hash: 'abc123'
		issuer_key_hash: 'def456'
		status: .good
	}) or {
		assert false, 'add_record failed: ${err}'
		return
	}
	assert server.records.len == 1
	assert '00000001' in server.records
}

// test_add_record_empty_serial_returns_error verifies that empty
// serial numbers are rejected.
fn test_add_record_empty_serial_returns_error() {
	mut server := v_ocsp.new_server('test', [u8(0x01)])
	server.add_record(v_ocsp.CertRecord{
		status: .good
	}) or {
		assert err.msg().contains('serial number must not be empty')
		return
	}
	assert false, 'expected error for empty serial'
}

// test_check_status_good verifies that a good certificate returns
// the correct status.
fn test_check_status_good() {
	mut server := v_ocsp.new_server('test', [u8(0x01), 0x02])
	server.add_record(v_ocsp.CertRecord{
		serial_number: '00000001'
		status: .good
	}) or { return }
	req := v_ocsp.OcspRequest{
		serial_number: '00000001'
	}
	response := server.check_status(req)
	assert response.cert_status == .good
	assert response.signature.len > 0
}

// test_check_status_revoked verifies that a revoked certificate
// returns revoked status with the correct reason.
fn test_check_status_revoked() {
	mut server := v_ocsp.new_server('test', [u8(0x01)])
	server.add_record(v_ocsp.CertRecord{
		serial_number: '00000002'
		status: .good
	}) or { return }
	server.revoke_record('00000002', .key_compromise) or { return }
	response := server.check_status(v_ocsp.OcspRequest{
		serial_number: '00000002'
	})
	assert response.cert_status == .revoked
	assert response.revocation_reason == .key_compromise
}

// test_check_status_unknown verifies that an unknown certificate
// returns unknown status.
fn test_check_status_unknown() {
	server := v_ocsp.new_server('test', [u8(0x01)])
	response := server.check_status(v_ocsp.OcspRequest{
		serial_number: 'nonexistent'
	})
	assert response.cert_status == .unknown
}

// test_check_status_issuer_mismatch verifies that mismatched issuer
// hashes return unknown.
fn test_check_status_issuer_mismatch() {
	mut server := v_ocsp.new_server('test', [u8(0x01)])
	server.add_record(v_ocsp.CertRecord{
		serial_number: '00000003'
		issuer_name_hash: 'correct-hash'
		status: .good
	}) or { return }
	response := server.check_status(v_ocsp.OcspRequest{
		serial_number: '00000003'
		issuer_name_hash: 'wrong-hash'
	})
	assert response.cert_status == .unknown
}

// test_revoke_record verifies that certificates can be revoked.
fn test_revoke_record() {
	mut server := v_ocsp.new_server('test', [u8(0x01)])
	server.add_record(v_ocsp.CertRecord{
		serial_number: '00000004'
		status: .good
	}) or { return }
	server.revoke_record('00000004', .superseded) or {
		assert false, 'revoke failed: ${err}'
		return
	}
	record := server.records['00000004'] or { return }
	assert record.status == .revoked
	assert record.revocation_reason == .superseded
}

// test_revoke_nonexistent_returns_error verifies that revoking a
// nonexistent certificate fails.
fn test_revoke_nonexistent_returns_error() {
	mut server := v_ocsp.new_server('test', [u8(0x01)])
	server.revoke_record('missing', .unspecified) or {
		assert err.msg().contains('not found')
		return
	}
	assert false, 'expected error for nonexistent cert'
}

// test_create_request verifies OCSP request construction with proper
// hash computation.
fn test_create_request() {
	req := v_ocsp.create_request('CN=Test CA', [u8(0xAA), 0xBB], '00000001')
	assert req.serial_number == '00000001'
	assert req.issuer_name_hash.len > 0
	assert req.issuer_key_hash.len > 0
}

// test_create_request_deterministic verifies that the same inputs
// produce the same request hashes.
fn test_create_request_deterministic() {
	req1 := v_ocsp.create_request('CN=CA', [u8(0x01)], 'serial')
	req2 := v_ocsp.create_request('CN=CA', [u8(0x01)], 'serial')
	assert req1.issuer_name_hash == req2.issuer_name_hash
	assert req1.issuer_key_hash == req2.issuer_key_hash
}

// test_sign_response verifies that signing produces a non-empty
// signature.
fn test_sign_response() {
	response := v_ocsp.OcspResponse{
		cert_status: .good
	}
	signed := v_ocsp.sign_response(response, [u8(0x01), 0x02, 0x03])
	assert signed.signature.len > 0
	assert signed.cert_status == .good
}

// test_process_response_valid verifies that a properly signed
// response passes validation.
fn test_process_response_valid() {
	key := [u8(0x01), 0x02, 0x03]
	response := v_ocsp.OcspResponse{
		cert_status: .good
	}
	signed := v_ocsp.sign_response(response, key)
	v_ocsp.process_response(signed, key) or {
		assert false, 'process_response failed: ${err}'
		return
	}
}

// test_process_response_wrong_key_returns_error verifies that
// validation fails with the wrong key.
fn test_process_response_wrong_key_returns_error() {
	response := v_ocsp.OcspResponse{
		cert_status: .good
	}
	signed := v_ocsp.sign_response(response, [u8(0x01), 0x02])
	v_ocsp.process_response(signed, [u8(0x03), 0x04]) or {
		assert err.msg().contains('verification failed')
		return
	}
	assert false, 'expected verification failure'
}

// test_all_revocation_reasons verifies that all revocation reason
// values are distinct.
fn test_all_revocation_reasons() {
	reasons := [
		v_ocsp.RevocationReason.unspecified,
		v_ocsp.RevocationReason.key_compromise,
		v_ocsp.RevocationReason.ca_compromise,
		v_ocsp.RevocationReason.affiliation_changed,
		v_ocsp.RevocationReason.superseded,
		v_ocsp.RevocationReason.cessation_of_operation,
	]
	// Verify all are distinct by checking against each other.
	for i in 0 .. reasons.len {
		for j in i + 1 .. reasons.len {
			assert reasons[i] != reasons[j]
		}
	}
}
