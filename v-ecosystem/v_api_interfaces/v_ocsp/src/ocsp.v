// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_ocsp — Online Certificate Status Protocol types and responder.
// Maps to proven-servers/protocols/proven-ocsp.
//
// Implements RFC 6960 OCSP with request creation, response processing,
// and response signing. The responder maintains a certificate status
// database and produces signed responses. Network I/O is stubbed with
// TODO markers; all type definitions and logic are real.
module v_ocsp

import time
import crypto.sha256
import encoding.hex

// CertStatus represents the status of a certificate as returned by
// the OCSP responder, per RFC 6960 Section 2.2.
pub enum CertStatus {
	good
	revoked
	unknown
}

// RevocationReason enumerates the standard reasons for certificate
// revocation, per RFC 5280 Section 5.3.1.
pub enum RevocationReason {
	unspecified
	key_compromise
	ca_compromise
	affiliation_changed
	superseded
	cessation_of_operation
}

// OcspRequest represents an OCSP request identifying a certificate
// whose status is being queried.
pub struct OcspRequest {
pub:
	// issuer_name_hash is the SHA-256 hash of the issuer's DN.
	issuer_name_hash string
	// issuer_key_hash is the SHA-256 hash of the issuer's public key.
	issuer_key_hash string
	// serial_number is the serial number of the certificate to check.
	serial_number string
}

// OcspResponse represents the OCSP responder's answer for a single
// certificate.
pub struct OcspResponse {
pub:
	// cert_status is the certificate's current status.
	cert_status CertStatus
	// this_update is the time at which this status was known to be
	// correct.
	this_update time.Time
	// next_update is the time by which the responder will have
	// updated status information.
	next_update time.Time
	// revocation_reason is set when cert_status is .revoked.
	revocation_reason RevocationReason
	// revocation_time is when the certificate was revoked (if
	// applicable).
	revocation_time time.Time
	// signature is the responder's signature over this response.
	signature []u8
}

// CertRecord stores the status of a certificate in the responder's
// database.
pub struct CertRecord {
pub:
	// serial_number is the certificate's serial number.
	serial_number string
	// issuer_name_hash identifies the issuing CA.
	issuer_name_hash string
	// issuer_key_hash identifies the issuing CA's key.
	issuer_key_hash string
pub mut:
	// status is the current certificate status.
	status CertStatus
	// revocation_reason is set when status is .revoked.
	revocation_reason RevocationReason
	// revocation_time is when the certificate was revoked.
	revocation_time time.Time
}

// OcspServer is the OCSP responder server. It maintains a database
// of certificate statuses and produces signed OCSP responses.
pub struct OcspServer {
pub:
	// responder_id identifies this OCSP responder.
	responder_id string
	// port is the HTTP port the responder listens on (default 8080).
	port int = 8080
	// signing_key is the responder's signing key (opaque bytes).
	// In production, this would be loaded from an HSM or key file.
	signing_key []u8
	// validity_period is the duration in seconds for which a response
	// is valid (default 1 hour).
	validity_period int = 3600
pub mut:
	// records stores certificate status records keyed by serial number.
	records map[string]CertRecord
}

// new_server creates a new OCSP responder server.
pub fn new_server(responder_id string, signing_key []u8) &OcspServer {
	return &OcspServer{
		responder_id: responder_id
		signing_key: signing_key
		records: map[string]CertRecord{}
	}
}

// add_record registers a certificate status record with the responder.
pub fn (mut s OcspServer) add_record(record CertRecord) ! {
	if record.serial_number.len == 0 {
		return error('serial number must not be empty')
	}
	s.records[record.serial_number] = record
}

// revoke_record marks a certificate as revoked with the given reason.
// Returns an error if the certificate is not in the database.
pub fn (mut s OcspServer) revoke_record(serial string, reason RevocationReason) ! {
	if serial !in s.records {
		return error('certificate not found: ${serial}')
	}
	mut record := s.records[serial] or { return error('certificate not found: ${serial}') }
	record.status = .revoked
	record.revocation_reason = reason
	record.revocation_time = time.now()
	s.records[serial] = record
}

// check_status processes an OCSP request and returns a signed response.
// This is the main entry point for OCSP status checking.
pub fn (s OcspServer) check_status(req OcspRequest) OcspResponse {
	record := s.records[req.serial_number] or {
		// Certificate not in our database — return unknown.
		return s.build_response(.unknown, .unspecified, time.Time{})
	}
	// Verify issuer hashes match if provided.
	if req.issuer_name_hash.len > 0 && record.issuer_name_hash.len > 0 {
		if req.issuer_name_hash != record.issuer_name_hash {
			return s.build_response(.unknown, .unspecified, time.Time{})
		}
	}
	if req.issuer_key_hash.len > 0 && record.issuer_key_hash.len > 0 {
		if req.issuer_key_hash != record.issuer_key_hash {
			return s.build_response(.unknown, .unspecified, time.Time{})
		}
	}
	return s.build_response(record.status, record.revocation_reason, record.revocation_time)
}

// create_request builds an OCSP request for the given certificate
// serial number and issuer information.
pub fn create_request(issuer_name string, issuer_key []u8, serial_number string) OcspRequest {
	name_hash := sha256.sum(issuer_name.bytes())
	key_hash := sha256.sum(issuer_key)
	return OcspRequest{
		issuer_name_hash: hex.encode(name_hash)
		issuer_key_hash: hex.encode(key_hash)
		serial_number: serial_number
	}
}

// process_response validates an OCSP response by checking the
// signature and validity period. Returns an error if invalid.
pub fn process_response(response OcspResponse, responder_key []u8) ! {
	// Check that the response hasn't expired.
	now := time.now()
	if response.next_update.unix() > 0 && now.unix() > response.next_update.unix() {
		return error('OCSP response has expired')
	}
	// Verify signature.
	// TODO: Perform real cryptographic signature verification.
	// Placeholder: recompute expected signature and compare.
	expected := compute_response_signature(response, responder_key)
	if response.signature.len != expected.len {
		return error('OCSP response signature verification failed')
	}
	for i in 0 .. response.signature.len {
		if response.signature[i] != expected[i] {
			return error('OCSP response signature verification failed')
		}
	}
}

// sign_response adds a cryptographic signature to an OCSP response
// using the responder's signing key.
pub fn sign_response(response OcspResponse, signing_key []u8) OcspResponse {
	sig := compute_response_signature(response, signing_key)
	return OcspResponse{
		cert_status: response.cert_status
		this_update: response.this_update
		next_update: response.next_update
		revocation_reason: response.revocation_reason
		revocation_time: response.revocation_time
		signature: sig
	}
}

// build_response creates an OCSP response with the current timestamp,
// validity period, and a signature.
fn (s OcspServer) build_response(status CertStatus, reason RevocationReason, revocation_time time.Time) OcspResponse {
	now := time.now()
	response := OcspResponse{
		cert_status: status
		this_update: now
		next_update: time.unix(now.unix() + i64(s.validity_period))
		revocation_reason: reason
		revocation_time: revocation_time
		signature: []u8{}
	}
	// Sign the response.
	return sign_response(response, s.signing_key)
}

// compute_response_signature generates a signature over an OCSP
// response using the given key.
fn compute_response_signature(response OcspResponse, key []u8) []u8 {
	// TODO: Use a real signing algorithm (RSA/ECDSA).
	// Placeholder: SHA-256 HMAC-like construction.
	mut input := []u8{}
	input << key
	input << '${response.cert_status}'.bytes()
	input << '${response.this_update.unix()}'.bytes()
	input << '${response.next_update.unix()}'.bytes()
	hash := sha256.sum(input)
	return hash.to_array()
}
