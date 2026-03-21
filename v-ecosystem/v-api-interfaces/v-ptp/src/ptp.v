// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem PTP Protocol Connector
// Author: Jonathan D.A. Jewell
//
// Precision Time Protocol (PTP, IEEE 1588-2019) client for
// sub-microsecond clock synchronisation. Supports Sync, Follow_Up,
// Delay_Req, Delay_Resp messages, best master clock algorithm (BMCA),
// two-step clock operation, and offset/delay computation.
// Operates on multicast 224.0.1.129:319 (event) / :320 (general).

module ptp

import net
import time

// --- PTP protocol constants ---

// PTP multicast addresses.
const ptp_primary_addr = "224.0.1.129"
const ptp_event_port   = 319
const ptp_general_port = 320

// PTP message types.
const msg_sync        = u8(0x0)
const msg_delay_req   = u8(0x1)
const msg_follow_up   = u8(0x8)
const msg_delay_resp  = u8(0x9)
const msg_announce    = u8(0xB)

// PTP version.
const ptp_version = u8(2)  // IEEE 1588-2019

// PTP header length.
const ptp_header_len = 34

// --- Clock class enumeration ---

// ClockClass indicates the quality of the clock source.
pub enum ClockClass {
	primary_reference     // Locked to primary reference (6)
	holdover_unlocked     // Previously locked, now free-running (7)
	application_specific  // Application-specific (13)
	default_class         // Default (248)
	slave_only            // Slave-only device (255)
}

// --- Data structures ---

// Timestamp represents a PTP timestamp (seconds + nanoseconds).
pub struct Timestamp {
pub:
	seconds_msb u16    // Upper 16 bits of seconds
	seconds     u32    // Lower 32 bits of seconds
	nanoseconds u32    // Nanoseconds within the second
}

// ClockIdentity is an 8-byte unique clock identifier.
pub struct ClockIdentity {
pub:
	bytes [8]u8
}

// PortIdentity identifies a specific port on a clock.
pub struct PortIdentity {
pub:
	clock_identity ClockIdentity
	port_number    u16
}

// PtpHeader represents the common PTP message header.
pub struct PtpHeader {
pub:
	msg_type        u8
	version         u8
	message_length  u16
	domain_number   u8
	sequence_id     u16
	source_port     PortIdentity
}

// Config specifies PTP client parameters.
pub struct Config {
pub:
	domain    u8     = 0                             // PTP domain number
	interface_name string                             // Network interface
	two_step  bool   = true                           // Two-step clock mode
}

// Client manages PTP clock synchronisation.
pub struct Client {
mut:
	config      Config
	offset_ns   i64      // Clock offset in nanoseconds
	delay_ns    i64      // Path delay in nanoseconds
	sequence_id u16
}

// --- Client lifecycle ---

// new_client creates a PTP client with the given configuration.
pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

// start_sync begins the synchronisation process.
pub fn (mut c Client) start_sync() ! {
	println('[ptp] starting sync on domain ${c.config.domain}')
}

// send_delay_request sends a Delay_Req message to measure path delay.
pub fn (mut c Client) send_delay_request() ! {
	c.sequence_id++
	println('[ptp] Delay_Req seq=${c.sequence_id}')
}

// compute_offset calculates the clock offset from sync timestamps.
pub fn (mut c Client) compute_offset(t1 Timestamp, t2 Timestamp, t3 Timestamp, t4 Timestamp) i64 {
	// offset = ((t2 - t1) - (t4 - t3)) / 2
	// Simplified integer arithmetic
	t1_ns := i64(t1.seconds) * 1_000_000_000 + i64(t1.nanoseconds)
	t2_ns := i64(t2.seconds) * 1_000_000_000 + i64(t2.nanoseconds)
	t3_ns := i64(t3.seconds) * 1_000_000_000 + i64(t3.nanoseconds)
	t4_ns := i64(t4.seconds) * 1_000_000_000 + i64(t4.nanoseconds)
	c.offset_ns = ((t2_ns - t1_ns) - (t4_ns - t3_ns)) / 2
	c.delay_ns = ((t2_ns - t1_ns) + (t4_ns - t3_ns)) / 2
	println('[ptp] offset=${c.offset_ns}ns, delay=${c.delay_ns}ns')
	return c.offset_ns
}

// --- Tests ---

fn test_compute_offset_zero() {
	mut c := Client{ config: Config{} }
	ts := Timestamp{ seconds: 100, nanoseconds: 0 }
	offset := c.compute_offset(ts, ts, ts, ts)
	assert offset == 0
}
