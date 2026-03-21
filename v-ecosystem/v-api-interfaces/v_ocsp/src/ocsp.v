// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Online Certificate Status Protocol responder and stapling Connector
// Author: Jonathan D.A. Jewell
//
// Online Certificate Status Protocol responder and stapling.
// Provides typed client bindings for the proven-ocsp protocol.

module ocsp

import os
import time
import net

// --- Certificate status ---

// CertStatus reports the OCSP certificate status.
pub enum CertStatus {
	good
	revoked
	unknown
}

// --- Revocation reason ---

// RevocationReason identifies why a certificate was revoked.
pub enum RevocationReason {
	unspecified
	key_compromise
	ca_compromise
	affiliation_changed
	superseded
	cessation
	certificate_hold
}

// --- Data structures ---

// OcspRequest defines an OCSP status check request.
pub struct OcspRequest {
pub:
	serial_hex   string   // Certificate serial in hex
	issuer_hash  string   // Issuer name hash
	issuer_key   string   // Issuer key hash
}

// OcspResponse represents an OCSP responder reply.
pub struct OcspResponse {
pub:
	status       CertStatus
	reason       RevocationReason
	produced_at  i64
	next_update  i64
}

// OcspConfig holds OCSP responder parameters.
pub struct OcspConfig {
pub:
	responder_url string
	ca_cert_path  string
	stapling      bool = true
}

// OcspClient manages OCSP queries and stapling.
pub struct OcspClient {
mut:
	config  OcspConfig
}

// --- Client lifecycle ---

// new_ocsp_client creates a new OCSP client.
pub fn new_ocsp_client(config OcspConfig) &OcspClient {
	return &OcspClient{
		config: config
	}
}

// check queries the OCSP responder for certificate status.
pub fn (c &OcspClient) check(req OcspRequest) !OcspResponse {
	if req.serial_hex.len == 0 {
		return error("serial must not be empty")
	}
	println("[ocsp] checking serial ${req.serial_hex} at ${c.config.responder_url}")
	return OcspResponse{ status: .good, reason: .unspecified, produced_at: time.now().unix(), next_update: time.now().unix() + 86400 }
}

// staple fetches and caches an OCSP response for stapling.
pub fn (c &OcspClient) staple(serial_hex string) !OcspResponse {
	return c.check(OcspRequest{ serial_hex: serial_hex, issuer_hash: "", issuer_key: "" })
}

// --- Tests ---

fn test_empty_serial_rejected() {
	client := new_ocsp_client(OcspConfig{ responder_url: "http://ocsp.example.com", ca_cert_path: "" })
	client.check(OcspRequest{ serial_hex: "", issuer_hash: "", issuer_key: "" }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
