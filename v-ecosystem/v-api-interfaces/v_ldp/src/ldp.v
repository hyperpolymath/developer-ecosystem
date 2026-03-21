// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Linked Data Platform containers and resource management Connector
// Author: Jonathan D.A. Jewell
//
// Linked Data Platform containers and resource management.
// Provides typed client bindings for the proven-ldp protocol.

module ldp

import os
import time
import net

// --- Container type ---

// LdpContainerType classifies the LDP container.
pub enum LdpContainerType {
	basic        // ldp:BasicContainer
	direct       // ldp:DirectContainer
	indirect     // ldp:IndirectContainer
}

// --- Data structures ---

// LdpResource represents a Linked Data Platform resource.
pub struct LdpResource {
pub:
	uri         string
	content_type string = "text/turtle"
	etag        string
	body        string
}

// LdpContainer represents an LDP container.
pub struct LdpContainer {
pub:
	uri            string
	container_type LdpContainerType
	members        []string   // Member URIs
}

// LdpConfig holds LDP client parameters.
pub struct LdpConfig {
pub:
	base_url    string
	auth_token  string
}

// LdpClient manages LDP resources and containers.
pub struct LdpClient {
mut:
	config      LdpConfig
	resources   []LdpResource
	containers  []LdpContainer
}

// --- Client lifecycle ---

// new_ldp_client creates a new LDP client.
pub fn new_ldp_client(config LdpConfig) &LdpClient {
	return &LdpClient{
		config:     config
		resources:  []LdpResource{}
		containers: []LdpContainer{}
	}
}

// create_resource creates an LDP resource.
pub fn (mut c LdpClient) create_resource(res LdpResource) ! {
	if res.uri.len == 0 {
		return error("resource URI must not be empty")
	}
	c.resources << res
	println("[ldp] created resource: ${res.uri} (${res.content_type})")
}

// create_container creates an LDP container.
pub fn (mut c LdpClient) create_container(cont LdpContainer) ! {
	if cont.uri.len == 0 {
		return error("container URI must not be empty")
	}
	c.containers << cont
	println("[ldp] created ${cont.container_type} container: ${cont.uri}")
}

// --- Tests ---

fn test_empty_uri_rejected() {
	mut client := new_ldp_client(LdpConfig{ base_url: "http://localhost:8080", auth_token: "test" })
	client.create_resource(LdpResource{ uri: "", content_type: "text/turtle", etag: "", body: "" }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
