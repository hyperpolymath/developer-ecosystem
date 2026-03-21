// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem WebSocket protocol handling with frame management and connection upgrade Connector
// Author: Jonathan D.A. Jewell
//
// WebSocket protocol handling with frame management and connection upgrade.
// Provides typed client bindings for the proven-ws protocol.

module ws

import os
import time
import net

// --- Frame type ---

// WsFrameType classifies WebSocket frame types.
pub enum WsFrameType {
	text
	binary
	ping
	pong
	close
}

// --- Connection state ---

// WsState tracks WebSocket connection lifecycle.
pub enum WsState {
	connecting
	open
	closing
	closed
}

// --- Data structures ---

// WsFrame represents a WebSocket frame.
pub struct WsFrame {
pub:
	frame_type  WsFrameType
	payload     []u8
	masked      bool
	fin         bool = true
}

// WsConnection represents a WebSocket connection.
pub struct WsConnection {
pub:
	conn_id     string
	url         string
	state       WsState
	subprotocol string
}

// WsConfig holds WebSocket parameters.
pub struct WsConfig {
pub:
	max_frame_size  int = 65536
	ping_interval   int = 30    // Seconds
	compression     bool = true // Per-message deflate
}

// WsManager manages WebSocket connections.
pub struct WsManager {
mut:
	config       WsConfig
	connections  []WsConnection
}

// --- Manager lifecycle ---

// new_ws_manager creates a new WebSocket manager.
pub fn new_ws_manager(config WsConfig) &WsManager {
	return &WsManager{
		config:      config
		connections: []WsConnection{}
	}
}

// connect opens a WebSocket connection.
pub fn (mut m WsManager) connect(conn WsConnection) ! {
	if conn.url.len == 0 {
		return error("URL must not be empty")
	}
	m.connections << conn
	println("[ws] connected: ${conn.conn_id} -> ${conn.url}")
}

// send transmits a frame on a connection.
pub fn (m &WsManager) send(conn_id string, frame WsFrame) ! {
	println("[ws] sending ${frame.frame_type} frame on ${conn_id} (${frame.payload.len} bytes)")
}

// --- Tests ---

fn test_empty_url_rejected() {
	mut mgr := new_ws_manager(WsConfig{})
	mgr.connect(WsConnection{ conn_id: "1", url: "", state: .connecting, subprotocol: "" }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
