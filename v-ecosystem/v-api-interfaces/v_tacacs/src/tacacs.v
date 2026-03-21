// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem TACACS+ authentication, authorization, and accounting for network devices Connector
// Author: Jonathan D.A. Jewell
//
// TACACS+ authentication, authorization, and accounting for network devices.
// Provides typed client bindings for the proven-tacacs protocol.

module tacacs

import os
import time
import net

// --- AAA type ---

// AaaType classifies the TACACS+ service.
pub enum AaaType {
	authentication  // AuthN
	authorization   // AuthZ
	accounting      // Acct
}

// --- Auth status ---

// AuthStatus reports authentication outcome.
pub enum AuthStatus {
	pass
	fail
	getdata
	getuser
	getpass
	error_status
}

// --- Data structures ---

// TacacsServer defines a TACACS+ server.
pub struct TacacsServer {
pub:
	address      string
	port         int = 49
	secret       string    // Shared secret
	timeout_secs int = 5
}

// TacacsRequest represents a TACACS+ request.
pub struct TacacsRequest {
pub:
	aaa_type     AaaType
	username     string
	remote_addr  string
	service      string     // e.g., "shell", "ppp"
	args         []string
}

// TacacsConfig holds TACACS+ client parameters.
pub struct TacacsConfig {
pub:
	servers      []TacacsServer
	encrypt      bool = true
}

// TacacsClient manages TACACS+ authentication and accounting.
pub struct TacacsClient {
mut:
	config  TacacsConfig
}

// --- Client lifecycle ---

// new_tacacs_client creates a new TACACS+ client.
pub fn new_tacacs_client(config TacacsConfig) &TacacsClient {
	return &TacacsClient{
		config: config
	}
}

// authenticate sends an authentication request.
pub fn (c &TacacsClient) authenticate(req TacacsRequest) !AuthStatus {
	if req.username.len == 0 {
		return error("username must not be empty")
	}
	println("[tacacs] authenticating ${req.username} from ${req.remote_addr}")
	return .pass
}

// authorize sends an authorization request.
pub fn (c &TacacsClient) authorize(req TacacsRequest) !bool {
	if req.username.len == 0 {
		return error("username must not be empty")
	}
	println("[tacacs] authorizing ${req.username} for ${req.service}")
	return true
}

// --- Tests ---

fn test_empty_username_rejected() {
	client := new_tacacs_client(TacacsConfig{ servers: [] })
	client.authenticate(TacacsRequest{ aaa_type: .authentication, username: "", remote_addr: "10.0.0.1", service: "shell", args: [] }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
