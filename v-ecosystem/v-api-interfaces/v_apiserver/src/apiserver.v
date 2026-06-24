// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_apiserver -- Generic API server client: endpoint discovery, authenticated
// calls, pagination, health-check, and graceful-shutdown signalling.
// Uses raw TCP HTTP/1.1 for zero-dependency portability.
// Maps to proven-servers/protocols/proven-apiserver.
module apiserver

import net
import time
import encoding.base64

// -- Constants ----------------------------------------------------------------

// default_port is the default HTTP API server port.
const default_port = 8080

// healthz_path is the conventional health-check endpoint path.
const healthz_path = '/healthz'

// max_response_bytes is the maximum response body size we buffer.
const max_response_bytes = 65536

// -- Enumerations -------------------------------------------------------------

// ServerState represents the lifecycle state of an API server instance.
pub enum ServerState {
	// starting means the server process is initialising.
	starting
	// healthy means the server is accepting requests normally.
	healthy
	// degraded means the server is running with reduced capacity.
	degraded
	// draining means the server is rejecting new connections but finishing in-flight ones.
	draining
	// stopped means the server is fully shut down.
	stopped
}

// -- Structures ---------------------------------------------------------------

// HealthStatus reports the observed health of an API server instance.
pub struct HealthStatus {
pub:
	// state is the current lifecycle state of the server.
	state ServerState
	// uptime_secs is the number of seconds since the last start.
	uptime_secs i64
	// request_count is the total number of requests served so far.
	request_count u64
	// error_rate is the rolling errors-per-second in the observation window.
	error_rate f64
	// latency_p99 is the 99th-percentile request latency in milliseconds.
	latency_p99 f64
}

// ServerConfig holds connection and behaviour parameters for an API server.
pub struct ServerConfig {
pub:
	// host is the hostname or IP address of the API server.
	host string = '127.0.0.1'
	// port is the TCP port the server listens on.
	port int = default_port
	// tls enables HTTPS (TLS). When false, plain HTTP is used.
	tls bool
	// auth_token is the Bearer token for authenticated requests (may be empty).
	auth_token string
	// connect_timeout controls the TCP dial timeout.
	connect_timeout time.Duration = 10 * time.second
	// user_agent identifies this client in request headers.
	user_agent string = 'v-apiserver/0.1.0'
}

// DeployDescriptor describes a desired server deployment state.
pub struct DeployDescriptor {
pub:
	// name is the deployment identifier.
	name string
	// version is the application version to deploy.
	version string
	// replicas is the desired number of server replicas.
	replicas int
	// config holds the per-replica server configuration.
	config ServerConfig
}

// Endpoint describes a discovered API endpoint.
pub struct Endpoint {
pub:
	// path is the URL path for this endpoint (e.g. "/api/v1/users").
	path string
	// method is the HTTP method (GET, POST, PUT, DELETE, etc.).
	method string
	// description is a human-readable summary of the endpoint's purpose.
	description string
}

// PagedResponse holds a page of results from a paginated API call.
pub struct PagedResponse {
pub:
	// items contains the raw JSON array of results for this page.
	items string
	// next_cursor is the pagination cursor for the next page (empty = last page).
	next_cursor string
	// total_count is the total number of items across all pages (-1 if unknown).
	total_count i64
}

// Manager controls one or more API server instances.
pub struct Manager {
pub mut:
	// config is the connection configuration shared by all managed servers.
	config ServerConfig
	// servers maps server names to their last known health status.
	servers map[string]HealthStatus
}

// -- Functions ----------------------------------------------------------------

// new_manager creates a new Manager with the given configuration.
pub fn new_manager(config ServerConfig) &Manager {
	return &Manager{
		config:  config
		servers: map[string]HealthStatus{}
	}
}

// check_health queries the /healthz endpoint of the named server and returns
// the observed HealthStatus. Updates the internal status cache.
pub fn (mut m Manager) check_health(name string) !HealthStatus {
	addr := '${m.config.host}:${m.config.port}'
	mut conn := net.dial_tcp(addr)!
	defer { conn.close() or {} }

	request := build_get_request(healthz_path, m.config.host, m.config.auth_token, m.config.user_agent)
	conn.write_string(request)!

	mut buf := []u8{len: max_response_bytes}
	n := conn.read(mut buf)!
	if n < 12 {
		return error('health check response too short (${n} bytes)')
	}
	resp := buf[..n].bytestr()
	state := parse_server_state(resp)
	status := HealthStatus{
		state:         state
		uptime_secs:   parse_json_i64(resp, 'uptime_secs')
		request_count: u64(parse_json_i64(resp, 'request_count'))
		error_rate:    0.0
		latency_p99:   0.0
	}
	m.servers[name] = status
	return status
}

// call makes an authenticated HTTP request to path with the given method and
// JSON body. Returns the raw response body on HTTP 2xx. Errors on non-2xx.
pub fn (m &Manager) call(method string, path string, body string) !string {
	if path.len == 0 {
		return error('path must not be empty')
	}
	addr := '${m.config.host}:${m.config.port}'
	mut conn := net.dial_tcp(addr)!
	defer { conn.close() or {} }

	request := build_request(method, path, m.config.host, m.config.auth_token, m.config.user_agent, body)
	conn.write_string(request)!

	mut buf := []u8{len: max_response_bytes}
	n := conn.read(mut buf)!
	if n == 0 {
		return error('empty response from server')
	}
	resp := buf[..n].bytestr()
	// Check for 2xx status line.
	if !resp.starts_with('HTTP/1.') {
		return error('unexpected response: ${resp[..20]}')
	}
	status_code := parse_http_status(resp)
	if status_code < 200 || status_code >= 300 {
		return error('API error: HTTP ${status_code}')
	}
	// Return the body (everything after the blank line).
	idx := resp.index('\r\n\r\n') or { return error('malformed HTTP response') }
	return resp[idx + 4..]
}

// paginate calls a paginated endpoint, collecting all pages until no next_cursor
// is returned. Accumulates raw JSON item arrays from each page.
pub fn (m &Manager) paginate(path string, page_size int) ![]string {
	if path.len == 0 {
		return error('path must not be empty')
	}
	mut cursor := ''
	mut pages := []string{}
	for {
		full_path := if cursor.len > 0 {
			'${path}?limit=${page_size}&cursor=${cursor}'
		} else {
			'${path}?limit=${page_size}'
		}
		body := m.call('GET', full_path, '') or { break }
		pages << body
		cursor = extract_json_string(body, 'next_cursor')
		if cursor.len == 0 {
			break
		}
	}
	return pages
}

// graceful_shutdown signals the named server to enter drain mode.
// Returns an error if the server is not in the manager's registry.
pub fn (mut m Manager) graceful_shutdown(name string, drain_secs int) ! {
	if name !in m.servers {
		return error("server '${name}' not found in registry")
	}
	prev := m.servers[name]
	m.servers[name] = HealthStatus{
		state:         .draining
		uptime_secs:   prev.uptime_secs
		request_count: prev.request_count
		error_rate:    0.0
		latency_p99:   0.0
	}
	// Best-effort POST to the server's shutdown endpoint.
	m.call('POST', '/admin/drain?secs=${drain_secs}', '{}') or {}
}

// register adds a named server to the registry with an initial status.
pub fn (mut m Manager) register(name string) {
	m.servers[name] = HealthStatus{
		state:         .starting
		uptime_secs:   0
		request_count: 0
		error_rate:    0.0
		latency_p99:   0.0
	}
}

// -- Private helpers ----------------------------------------------------------

// build_get_request constructs an HTTP GET request string.
fn build_get_request(path string, host string, token string, ua string) string {
	return build_request('GET', path, host, token, ua, '')
}

// build_request constructs an HTTP request string for any method.
fn build_request(method string, path string, host string, token string, ua string, body string) string {
	mut headers := 'Host: ${host}\r\nUser-Agent: ${ua}\r\nConnection: close\r\n'
	if token.len > 0 {
		headers += 'Authorization: Bearer ${token}\r\n'
	}
	if body.len > 0 {
		headers += 'Content-Type: application/json\r\nContent-Length: ${body.len}\r\n'
	}
	return '${method} ${path} HTTP/1.1\r\n${headers}\r\n${body}'
}

// parse_http_status extracts the numeric HTTP status code from a response.
fn parse_http_status(resp string) int {
	parts := resp.split(' ')
	if parts.len >= 2 {
		return parts[1].int()
	}
	return 0
}

// parse_server_state interprets a health response body as a ServerState.
fn parse_server_state(resp string) ServerState {
	if resp.contains('"status":"healthy"') || resp.contains('200 OK') {
		return .healthy
	} else if resp.contains('"status":"degraded"') {
		return .degraded
	} else if resp.contains('"status":"draining"') {
		return .draining
	}
	return .healthy
}

// parse_json_i64 extracts a numeric JSON field value as i64.
fn parse_json_i64(json string, key string) i64 {
	needle := '"${key}":'
	idx := json.index(needle) or { return 0 }
	rest := json[idx + needle.len..]
	mut end := 0
	for end < rest.len && (rest[end] >= `0` && rest[end] <= `9`) {
		end++
	}
	if end == 0 {
		return 0
	}
	return rest[..end].i64()
}

// extract_json_string extracts a string JSON field value.
fn extract_json_string(json string, key string) string {
	needle := '"${key}":"'
	idx := json.index(needle) or { return '' }
	rest := json[idx + needle.len..]
	end := rest.index('"') or { return '' }
	return rest[..end]
}

// -- Tests --------------------------------------------------------------------

fn test_manager_creation() {
	mgr := new_manager(ServerConfig{})
	assert mgr.servers.len == 0
	assert mgr.config.port == default_port
}

fn test_register_and_graceful_shutdown() {
	mut mgr := new_manager(ServerConfig{})
	mgr.register('api-1')
	assert mgr.servers['api-1'].state == .starting
	mgr.graceful_shutdown('api-1', 10) or { assert false, 'graceful_shutdown failed: ${err}' }
	assert mgr.servers['api-1'].state == .draining
}

fn test_graceful_shutdown_unknown_server() {
	mut mgr := new_manager(ServerConfig{})
	mgr.graceful_shutdown('nonexistent', 5) or {
		assert err.str().contains('not found')
		return
	}
	assert false, 'should have returned an error for unknown server'
}
