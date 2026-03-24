// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
//
// V-burble — V-lang connector for burble API.
// Groove-aware: supports snap-on/snap-off discovery.

module v_burble

import net.http
import json

// Configuration
pub struct Config {
pub mut:
	base_url string = 'http://localhost:4020'
}

pub fn new_config(port int) Config {
	return Config{ base_url: 'http://localhost:${port}' }
}

// Client
pub struct Client {
	config Config
}

pub fn new_client(config Config) &Client {
	return &Client{ config: config }
}

pub fn new_default() &Client {
	return new_client(Config{})
}

// Health check
pub fn (c &Client) health() !string {
	resp := http.get('${c.config.base_url}/health') or {
		return error('burble unreachable: ${err}')
	}
	if resp.status_code != 200 {
		return error('burble unhealthy: HTTP ${resp.status_code}')
	}
	return resp.body
}

// Groove discovery — scan known ports for burble
pub fn discover(ports ...int) ?&Client {
	scan_ports := if ports.len > 0 { ports } else { [4020] }
	for port in scan_ports {
		client := new_client(new_config(port))
		if _ := client.health() {
			return client
		}
	}
	return none
}

// Groove manifest
pub struct GrooveManifest {
pub:
	service   string   = 'burble'
	version   string   = '0.1.0'
	api_types []string = ['rest', 'grpc', 'graphql']
	endpoints []string = ['health', 'rooms', 'channels', 'media', 'webrtc']
}

pub fn groove_manifest() GrooveManifest {
	return GrooveManifest{}
}
