// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Bidirectional Forwarding Detection for rapid link/path failure detection Connector
// Author: Jonathan D.A. Jewell
//
// Bidirectional Forwarding Detection for rapid link/path failure detection.
// Provides typed client bindings for the proven-bfd protocol.

module bfd

import os
import time
import net

// --- BFD session state ---

// BfdState represents the BFD session state machine.
pub enum BfdState {
	admin_down
	down
	init
	up
}

// --- Data structures ---

// BfdSession defines a BFD session with a peer.
pub struct BfdSession {
pub:
	local_discr     u32
	remote_discr    u32
	local_addr      string
	remote_addr     string
	state           BfdState
	desired_min_tx  u32      // Desired minimum TX interval (microseconds)
	required_min_rx u32      // Required minimum RX interval
	detect_mult     u8       // Detection multiplier
}

// BfdConfig holds BFD daemon configuration.
pub struct BfdConfig {
pub:
	listen_addr     string = "0.0.0.0"
	listen_port     int = 3784
	multihop_port   int = 4784
	echo_mode       bool = false
}

// BfdManager manages BFD sessions.
pub struct BfdManager {
mut:
	config   BfdConfig
	sessions []BfdSession
}

// --- Manager lifecycle ---

// new_bfd_manager creates a new BFD manager.
pub fn new_bfd_manager(config BfdConfig) &BfdManager {
	return &BfdManager{
		config:   config
		sessions: []BfdSession{}
	}
}

// add_session registers a new BFD session.
pub fn (mut m BfdManager) add_session(session BfdSession) ! {
	if session.remote_addr.len == 0 {
		return error("remote address must not be empty")
	}
	m.sessions << session
	println("[bfd] added session to ${session.remote_addr} (detect_mult=${session.detect_mult})")
}

// get_state returns the state of a session by local discriminator.
pub fn (m &BfdManager) get_state(local_discr u32) ?BfdState {
	for s in m.sessions {
		if s.local_discr == local_discr {
			return s.state
		}
	}
	return none
}

// --- Tests ---

fn test_empty_remote_rejected() {
	mut mgr := new_bfd_manager(BfdConfig{})
	mgr.add_session(BfdSession{ local_discr: 1, remote_discr: 0, local_addr: "10.0.0.1", remote_addr: "", state: .down, desired_min_tx: 300000, required_min_rx: 300000, detect_mult: 3 }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
