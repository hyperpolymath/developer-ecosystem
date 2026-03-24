// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
//
// V-VeriSimDB — V-lang connector for VeriSimDB octad API.
// Provides type-safe REST client for CRUD operations on octads,
// plus Groove protocol discovery for snap-on/snap-off integration.

module v_verisimdb

import net.http
import json

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

pub struct Config {
pub mut:
	base_url       string = 'http://localhost:8080'
	connect_timeout int    = 5000  // ms
	read_timeout    int    = 10000 // ms
}

pub fn new_config(port int) Config {
	return Config{
		base_url: 'http://localhost:${port}'
	}
}

// ---------------------------------------------------------------------------
// Octad types (mirrors Rust verisim-octad)
// ---------------------------------------------------------------------------

pub struct OctadStatus {
pub:
	created_at  string
	modified_at string
	version     u64
}

pub struct Octad {
pub:
	id                      string
	status                  OctadStatus
	has_graph               bool
	has_vector              bool
	has_tensor              bool
	has_semantic            bool
	has_document            bool
	has_provenance          bool
	has_spatial             bool
	version_count           u64
	provenance_chain_length u64
	title                   ?string
	body                    ?string
	metadata                ?map[string]string
	types                   ?[]string
}

pub struct CreateOctadRequest {
pub:
	title      ?string
	body       ?string
	types      ?[]string
	metadata   ?map[string]string
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

pub struct Client {
	config Config
}

pub fn new_client(config Config) &Client {
	return &Client{
		config: config
	}
}

pub fn new_default() &Client {
	return new_client(Config{})
}

// Health check
pub fn (c &Client) health() !string {
	resp := http.get('${c.config.base_url}/health') or {
		return error('VeriSimDB unreachable: ${err}')
	}
	if resp.status_code !in [200, 201] {
		return error('VeriSimDB unhealthy: HTTP ${resp.status_code}')
	}
	return resp.body
}

// Create octad
pub fn (c &Client) create(req CreateOctadRequest) !Octad {
	body := json.encode(req)
	resp := http.post_json('${c.config.base_url}/octads', body) or {
		return error('Create failed: ${err}')
	}
	if resp.status_code !in [200, 201] {
		return error('Create failed: HTTP ${resp.status_code} — ${resp.body}')
	}
	return json.decode(Octad, resp.body) or {
		return error('Decode failed: ${err}')
	}
}

// Get octad by ID
pub fn (c &Client) get(id string) !Octad {
	resp := http.get('${c.config.base_url}/octads/${id}') or {
		return error('Get failed: ${err}')
	}
	if resp.status_code == 404 {
		return error('Not found: ${id}')
	}
	if resp.status_code != 200 {
		return error('Get failed: HTTP ${resp.status_code}')
	}
	return json.decode(Octad, resp.body) or {
		return error('Decode failed: ${err}')
	}
}

// List all octads, optionally filtered by collection
pub fn (c &Client) list(collection ?string) ![]Octad {
	resp := http.get('${c.config.base_url}/octads?limit=10000') or {
		return error('List failed: ${err}')
	}
	if resp.status_code != 200 {
		return error('List failed: HTTP ${resp.status_code}')
	}
	all := json.decode([]Octad, resp.body) or {
		return error('Decode failed: ${err}')
	}
	if coll := collection {
		return all.filter(fn [coll] (o Octad) bool {
			if m := o.metadata {
				return m['collection'] or { '' } == coll
			}
			return false
		})
	}
	return all
}

// Update octad
pub fn (c &Client) update(id string, req CreateOctadRequest) !Octad {
	body := json.encode(req)
	mut config := http.FetchConfig{
		url: '${c.config.base_url}/octads/${id}'
		method: .put
		body: body
		header: http.new_header_from_map({
			'Content-Type': 'application/json'
		})
	}
	resp := http.fetch(config) or {
		return error('Update failed: ${err}')
	}
	if resp.status_code == 404 {
		return error('Not found: ${id}')
	}
	if resp.status_code !in [200, 201] {
		return error('Update failed: HTTP ${resp.status_code}')
	}
	return json.decode(Octad, resp.body) or {
		return error('Decode failed: ${err}')
	}
}

// Delete octad
pub fn (c &Client) delete(id string) ! {
	mut config := http.FetchConfig{
		url: '${c.config.base_url}/octads/${id}'
		method: .delete
	}
	resp := http.fetch(config) or {
		return error('Delete failed: ${err}')
	}
	if resp.status_code == 404 {
		return error('Not found: ${id}')
	}
	if resp.status_code != 204 {
		return error('Delete failed: HTTP ${resp.status_code}')
	}
}

// ---------------------------------------------------------------------------
// Groove protocol — snap-on/snap-off discovery
// ---------------------------------------------------------------------------

pub struct GrooveManifest {
pub:
	service     string = 'verisimdb'
	version     string = '0.1.0'
	api_types   []string = ['rest', 'grpc', 'graphql']
	health      string = '/health'
	octads      string = '/octads'
	search_text string = '/search/text'
	drift       string = '/drift/entity'
	provenance  string = '/provenance'
}

// Discover a VeriSimDB instance via Groove protocol
pub fn discover(ports ...int) ?&Client {
	scan_ports := if ports.len > 0 { ports } else { [8080, 8081, 8093, 8094, 8095] }
	for port in scan_ports {
		client := new_client(new_config(port))
		if _ := client.health() {
			return client
		}
	}
	return none
}

// Return the Groove manifest for this connector
pub fn groove_manifest() GrooveManifest {
	return GrooveManifest{}
}
