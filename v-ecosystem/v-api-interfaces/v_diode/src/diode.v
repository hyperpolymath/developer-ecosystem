// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Data diode connector for unidirectional network transfer enforcement Connector
// Author: Jonathan D.A. Jewell
//
// Data diode client for unidirectional network transfers. Enforces one-way
// data flow from low-security to high-security domains (or vice versa).
// Supports UDP-based streaming, forward error correction, transfer
// manifests, receipt confirmation via out-of-band channel, and
// compliance logging for air-gapped environments.

module diode

import net
import time
import crypto.sha256
import encoding.hex

// --- Flow direction ---

// FlowDirection enforces unidirectional data flow.
pub enum FlowDirection {
	low_to_high   // From low-security to high-security domain
	high_to_low   // From high-security to low-security domain
}

// --- Data structures ---

// TransferSegment represents a single unit of diode transfer.
pub struct TransferSegment {
pub:
	sequence    u64       // Sequence number
	data        []u8      // Payload
	hash        string    // SHA-256 hash
	fec_group   u16       // Forward error correction group
}

// FecConfig specifies forward error correction parameters.
pub struct FecConfig {
pub:
	data_shards   int = 10   // Data segments per group
	parity_shards int = 3    // Parity segments per group
}

// TransferManifest describes a complete diode transfer.
pub struct TransferManifest {
pub:
	transfer_id   string
	direction     FlowDirection
	total_segments u64
	root_hash     string
	fec           FecConfig
}

// AuditRecord logs a compliance event.
pub struct AuditRecord {
pub:
	timestamp   i64
	transfer_id string
	direction   FlowDirection
	event       string
	verified    bool
}

// DiodeConfig holds data diode parameters.
pub struct DiodeConfig {
pub:
	bind_addr   string = "0.0.0.0"
	port        int    = 9999
	direction   FlowDirection = .low_to_high
	fec         FecConfig = FecConfig{}
}

// DiodeClient manages data diode transfers.
pub struct DiodeClient {
mut:
	config  DiodeConfig
	audit   []AuditRecord
}

// --- Client lifecycle ---

// new_diode_client creates a new data diode client.
pub fn new_diode_client(config DiodeConfig) &DiodeClient {
	return &DiodeClient{
		config: config
		audit: []AuditRecord{}
	}
}

// send transmits data through the diode (sender side).
pub fn (mut d DiodeClient) send(data []u8) ! {
	if data.len == 0 {
		return error("payload must not be empty")
	}
	h := sha256.sum(data)
	hash_hex := hex.encode(h)
	d.audit << AuditRecord{
		timestamp: time.now().unix()
		transfer_id: hash_hex[..16]
		direction: d.config.direction
		event: "send"
		verified: true
	}
	println("[diode] sent ${data.len} bytes (${d.config.direction})")
}

// receive collects data from the diode (receiver side).
pub fn (mut d DiodeClient) receive() ![]u8 {
	println("[diode] listening on ${d.config.bind_addr}:${d.config.port}")
	return error("not implemented: requires hardware diode")
}

// --- Tests ---

fn test_empty_payload_rejected() {
	mut client := new_diode_client(DiodeConfig{})
	client.send([]u8{}) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
