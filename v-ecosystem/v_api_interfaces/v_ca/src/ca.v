// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_ca — Certificate Authority protocol types and server abstraction.
// Maps to proven-servers/protocols/proven-ca.
//
// Provides certificate issuance, revocation, CRL management, and chain
// verification. Supports RSA, ECDSA, and Ed25519 key algorithms. Network
// I/O is stubbed with TODO markers; all type definitions and logic are real.
module v_ca

import time
import crypto.sha256
import encoding.hex
import rand

// CertType classifies the purpose of a certificate within a PKI hierarchy.
pub enum CertType {
	root
	intermediate
	end_entity
	code_signing
}

// KeyAlgorithm enumerates the cryptographic algorithms supported for
// certificate key pairs.
pub enum KeyAlgorithm {
	rsa2048
	rsa4096
	ecdsa_p256
	ecdsa_p384
	ed25519
}

// CertRequest holds the parameters for requesting a new certificate
// from the CA.
pub struct CertRequest {
pub:
	// subject is the distinguished name (DN) for the certificate.
	subject string
	// key_algo specifies the key algorithm to use.
	key_algo KeyAlgorithm
	// san_dns lists the Subject Alternative Name DNS entries.
	san_dns []string
	// san_ip lists the Subject Alternative Name IP entries.
	san_ip []string
	// validity_days is the certificate lifetime in days.
	validity_days int = 365
}

// Certificate represents an issued X.509 certificate with its metadata.
pub struct Certificate {
pub:
	// serial is the unique serial number assigned by the CA.
	serial string
	// subject is the certificate's distinguished name.
	subject string
	// issuer is the distinguished name of the issuing CA.
	issuer string
	// not_before is the start of the certificate's validity period.
	not_before time.Time
	// not_after is the end of the certificate's validity period.
	not_after time.Time
	// key_algo is the algorithm used for the certificate's key pair.
	key_algo KeyAlgorithm
	// fingerprint is the SHA-256 fingerprint of the certificate.
	fingerprint string
	// cert_type classifies this certificate's role in the PKI.
	cert_type CertType
	// san_dns lists Subject Alternative Name DNS entries.
	san_dns []string
	// san_ip lists Subject Alternative Name IP entries.
	san_ip []string
pub mut:
	// revoked indicates whether the certificate has been revoked.
	revoked bool
}

// CrlEntry represents a single entry in a Certificate Revocation List.
pub struct CrlEntry {
pub:
	// serial is the serial number of the revoked certificate.
	serial string
	// revocation_date is the time the certificate was revoked.
	revocation_date time.Time
	// reason is a human-readable revocation reason.
	reason string
}

// CaServer is the Certificate Authority server. It manages issued
// certificates, revocation lists, and chain verification.
pub struct CaServer {
pub:
	// ca_subject is the distinguished name of this CA.
	ca_subject string
	// ca_cert_type is the type of this CA's own certificate.
	ca_cert_type CertType
pub mut:
	// certificates holds all issued certificates, keyed by serial.
	certificates map[string]Certificate
	// crl holds the current Certificate Revocation List.
	crl []CrlEntry
	// next_serial tracks the next serial number to assign.
	next_serial int = 1
}

// new_ca creates a new Certificate Authority server with the given
// subject name and type (root or intermediate).
pub fn new_ca(subject string, cert_type CertType) &CaServer {
	return &CaServer{
		ca_subject: subject
		ca_cert_type: cert_type
		certificates: map[string]Certificate{}
		crl: []CrlEntry{}
	}
}

// issue_cert creates and signs a new certificate based on the given
// request. Returns the issued certificate. The actual cryptographic
// signing is stubbed; the certificate metadata is fully populated.
pub fn (mut ca CaServer) issue_cert(req CertRequest) !Certificate {
	if req.subject.len == 0 {
		return error('certificate subject must not be empty')
	}
	if req.validity_days < 1 {
		return error('validity_days must be at least 1')
	}
	serial := '${ca.next_serial:08x}'
	ca.next_serial += 1
	now := time.now()
	// Compute a fingerprint from the subject and serial for uniqueness.
	hash_input := '${serial}:${req.subject}:${now}'.bytes()
	hash := sha256.sum(hash_input)
	fp := format_fingerprint(hex.encode(hash))
	cert := Certificate{
		serial: serial
		subject: req.subject
		issuer: ca.ca_subject
		not_before: now
		not_after: time.unix(now.unix() + i64(req.validity_days) * 86400)
		key_algo: req.key_algo
		fingerprint: fp
		cert_type: .end_entity
		san_dns: req.san_dns
		san_ip: req.san_ip
	}
	ca.certificates[serial] = cert
	// TODO: Perform actual cryptographic signing with the CA's private key.
	// This requires an X.509 library or FFI to OpenSSL/libcrypto.
	return cert
}

// revoke_cert marks a certificate as revoked and adds it to the CRL.
// Returns an error if the serial is not found or already revoked.
pub fn (mut ca CaServer) revoke_cert(serial string, reason string) ! {
	if serial !in ca.certificates {
		return error('certificate not found: ${serial}')
	}
	mut cert := ca.certificates[serial] or { return error('certificate not found: ${serial}') }
	if cert.revoked {
		return error('certificate already revoked: ${serial}')
	}
	cert.revoked = true
	ca.certificates[serial] = cert
	ca.crl << CrlEntry{
		serial: serial
		revocation_date: time.now()
		reason: reason
	}
}

// get_crl returns a copy of the current Certificate Revocation List.
pub fn (ca CaServer) get_crl() []CrlEntry {
	return ca.crl
}

// verify_chain checks whether a certificate was issued by this CA and
// is not revoked. Returns an error describing the verification failure,
// or nothing on success.
pub fn (ca CaServer) verify_chain(cert Certificate) ! {
	if cert.issuer != ca.ca_subject {
		return error('issuer mismatch: expected ${ca.ca_subject}, got ${cert.issuer}')
	}
	// Check revocation status.
	if cert.serial in ca.certificates {
		stored := ca.certificates[cert.serial] or {
			return error('certificate not found in CA store')
		}
		if stored.revoked {
			return error('certificate ${cert.serial} has been revoked')
		}
	} else {
		return error('certificate ${cert.serial} not issued by this CA')
	}
	// Check validity period.
	now := time.now()
	if now.unix() < cert.not_before.unix() {
		return error('certificate not yet valid')
	}
	if now.unix() > cert.not_after.unix() {
		return error('certificate has expired')
	}
	// TODO: Verify the cryptographic signature against the CA's public key.
}

// renew_cert issues a new certificate with the same subject and SANs
// as the original, but with a fresh validity period. The old certificate
// remains valid until explicitly revoked.
pub fn (mut ca CaServer) renew_cert(serial string, validity_days int) !Certificate {
	if serial !in ca.certificates {
		return error('certificate not found: ${serial}')
	}
	original := ca.certificates[serial] or { return error('certificate not found: ${serial}') }
	if original.revoked {
		return error('cannot renew revoked certificate: ${serial}')
	}
	req := CertRequest{
		subject: original.subject
		key_algo: original.key_algo
		san_dns: original.san_dns
		san_ip: original.san_ip
		validity_days: validity_days
	}
	return ca.issue_cert(req)
}

// format_fingerprint inserts colons every two characters into a hex
// string for human-readable display.
fn format_fingerprint(hex_str string) string {
	mut parts := []string{}
	for i := 0; i < hex_str.len; i += 2 {
		end := if i + 2 > hex_str.len { hex_str.len } else { i + 2 }
		parts << hex_str[i..end]
	}
	return 'SHA256:${parts.join(':')}'
}

// generate_serial creates a random serial number string suitable for
// certificate serial fields.
fn generate_serial() string {
	mut parts := []string{}
	for _ in 0 .. 4 {
		val := rand.int_in_range(0x1000, 0xFFFF) or { 0 }
		parts << '${val:04x}'
	}
	return parts.join('')
}
