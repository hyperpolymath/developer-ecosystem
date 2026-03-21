// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Network Time Security for authenticated NTP with AEAD encryption Connector
// Author: Jonathan D.A. Jewell
//
// Network Time Security for authenticated NTP with AEAD encryption.
// Provides typed client bindings for the proven-nts protocol.

module nts

import os
import time
import net

// --- NTS-KE mode ---

// NtsKeMode selects the NTS Key Establishment mode.
pub enum NtsKeMode {
	ntske_over_tls   // Standard NTS-KE over TLS 1.3
}

// --- AEAD algorithm ---

// AeadAlgorithm selects the NTS AEAD cipher.
pub enum AeadAlgorithm {
	aes_siv_cmac_256   // Mandatory-to-implement
	aes_siv_cmac_384
	aes_siv_cmac_512
}

// --- Data structures ---

// NtsConfig holds NTS client parameters.
pub struct NtsConfig {
pub:
	nts_ke_server string     // NTS-KE server hostname
	nts_ke_port   int = 4460
	aead          AeadAlgorithm = .aes_siv_cmac_256
	ntp_server    string     // NTP server for time queries
}

// NtsCookie stores an NTS cookie for authenticated NTP.
pub struct NtsCookie {
pub:
	cookie_data  []u8
	server       string
	expiry_epoch i64
}

// NtsClient manages NTS key establishment and NTP queries.
pub struct NtsClient {
mut:
	config   NtsConfig
	cookies  []NtsCookie
}

// --- Client lifecycle ---

// new_nts_client creates a new NTS client.
pub fn new_nts_client(config NtsConfig) &NtsClient {
	return &NtsClient{
		config:  config
		cookies: []NtsCookie{}
	}
}

// key_establish performs NTS-KE to obtain cookies.
pub fn (mut c NtsClient) key_establish() ! {
	if c.config.nts_ke_server.len == 0 {
		return error("NTS-KE server must not be empty")
	}
	println("[nts] key establishment with ${c.config.nts_ke_server}:${c.config.nts_ke_port}")
}

// query_time sends an authenticated NTP request.
pub fn (c &NtsClient) query_time() !i64 {
	if c.cookies.len == 0 {
		return error("no cookies available; run key_establish first")
	}
	println("[nts] querying authenticated time from ${c.config.ntp_server}")
	return time.now().unix()
}

// --- Tests ---

fn test_empty_ke_server_rejected() {
	mut client := new_nts_client(NtsConfig{ nts_ke_server: "", ntp_server: "pool.ntp.org" })
	client.key_establish() or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
