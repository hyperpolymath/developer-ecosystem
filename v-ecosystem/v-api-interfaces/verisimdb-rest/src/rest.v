// SPDX-License-Identifier: PMPL-1.0-or-later
// VeriSimDB REST API Gateway
//
// Exposes VeriSimDB hexad storage via REST endpoints on port 9090:
//   POST /api/v1/hexads         — store a PanicAttackHexad
//   POST /api/v1/hexads/batch   — store multiple hexads
//   GET  /api/v1/hexads?tool=X&limit=N — query hexads by tool name
//   GET  /api/v1/hexads/:id     — get hexad by ID
//   GET  /api/v1/health         — health check
//   GET  /                      — API discovery
//
// Hexads are stored as individual JSON files under a configurable data
// directory (VERISIMDB_DATA_DIR env var, default: verisimdb-data/hexads/).

module rest

import net.http
import os
import time

// VeriSimDBHandler implements http.Handler for the VeriSimDB REST API.
struct VeriSimDBHandler {
	port     int
	data_dir string
}

pub fn (mut h VeriSimDBHandler) handle(req http.Request) http.Response {
	path := req.url.all_before('?')
	// Route: GET / — API discovery
	if path == '/' && req.method == .get {
		return handle_info()
	}
	// Route: GET /api/v1/health — health check
	if path == '/api/v1/health' && req.method == .get {
		return handle_health(h.data_dir)
	}
	// Route: POST /api/v1/hexads/batch — store batch
	if path == '/api/v1/hexads/batch' && req.method == .post {
		return handle_store_batch(req, h.data_dir)
	}
	// Route: POST /api/v1/hexads — store single hexad
	if path == '/api/v1/hexads' && req.method == .post {
		return handle_store(req, h.data_dir)
	}
	// Route: GET /api/v1/hexads/:id — get by ID
	if path.starts_with('/api/v1/hexads/') && req.method == .get {
		id := path.all_after('/api/v1/hexads/')
		if id.len > 0 {
			return handle_get_by_id(id, h.data_dir)
		}
	}
	// Route: GET /api/v1/hexads — query hexads
	if path == '/api/v1/hexads' && req.method == .get {
		tool := query_param(req.url, 'tool')
		limit_str := query_param(req.url, 'limit')
		limit := if limit_str.len > 0 { limit_str.int() } else { 100 }
		return handle_query(tool, limit, h.data_dir)
	}

	return json_response(404, '{"error":"Not found","endpoints":["/api/v1/hexads","/api/v1/hexads/batch","/api/v1/health"]}')
}

pub struct Server {
pub mut:
	port int
}

pub fn new_server(port int) &Server {
	return &Server{
		port: port
	}
}

pub fn (s Server) start() {
	data_dir := hexads_dir()
	println('VeriSimDB REST Server starting on port ${s.port}...')
	println('  Data directory: ${data_dir}')
	println('  POST /api/v1/hexads         — store hexad')
	println('  POST /api/v1/hexads/batch   — store batch')
	println('  GET  /api/v1/hexads?tool=X  — query hexads')
	println('  GET  /api/v1/hexads/:id     — get by ID')
	println('  GET  /api/v1/health         — health check')
	println('  GET  /                      — API discovery')
	mut server := http.Server{
		addr: ':${s.port}'
		handler: &VeriSimDBHandler{port: s.port, data_dir: data_dir}
	}
	server.listen_and_serve()
}

// --- Route Handlers ---

fn handle_info() http.Response {
	return json_response(200, '{"service":"verisimdb-rest","version":"1.0.0","description":"VeriSimDB hexad storage gateway for panic-attack","endpoints":["/api/v1/hexads","/api/v1/hexads/batch","/api/v1/hexads/:id","/api/v1/health"]}')
}

fn handle_store(req http.Request, data_dir string) http.Response {
	if req.data.len == 0 {
		return json_response(400, '{"error":"Request body required"}')
	}

	id := json_field(req.data, 'id')
	if id.len == 0 {
		return json_response(400, '{"error":"Hexad must have an id field"}')
	}

	ensure_data_dir(data_dir)
	file_path := os.join_path(data_dir, '${id}.json')
	os.write_file(file_path, req.data) or {
		return json_response(500, '{"error":"Failed to write hexad: ${esc(err.msg())}"}')
	}

	return json_response(201, '{"stored":true,"id":"${esc(id)}","path":"${esc(file_path)}"}')
}

fn handle_store_batch(req http.Request, data_dir string) http.Response {
	if req.data.len == 0 {
		return json_response(400, '{"error":"Request body required (JSON array of hexads)"}')
	}

	ensure_data_dir(data_dir)

	// Parse the JSON array manually: split on },{ boundaries
	body := req.data.trim_space()
	if body.len < 2 || body[0] != `[` || body[body.len - 1] != `]` {
		return json_response(400, '{"error":"Body must be a JSON array"}')
	}

	inner := body[1..body.len - 1].trim_space()
	if inner.len == 0 {
		return json_response(200, '{"stored":0,"ids":[]}')
	}

	// Split array elements by finding top-level commas between objects
	items := split_json_array(inner)
	mut stored_ids := []string{}
	mut errors := []string{}

	for item in items {
		hexad := item.trim_space()
		id := json_field(hexad, 'id')
		if id.len == 0 {
			errors << '{"error":"Hexad missing id field","hexad_snippet":"${esc(hexad[..min(hexad.len, 40)])}..."}'
			continue
		}
		file_path := os.join_path(data_dir, '${id}.json')
		os.write_file(file_path, hexad) or {
			errors << '{"error":"Write failed for ${esc(id)}: ${esc(err.msg())}"}'
			continue
		}
		stored_ids << '"${esc(id)}"'
	}

	mut result := '{"stored":${stored_ids.len},"ids":[${stored_ids.join(",")}]'
	if errors.len > 0 {
		result += ',"errors":[${errors.join(",")}]'
	}
	result += '}'

	return json_response(201, result)
}

fn handle_get_by_id(id string, data_dir string) http.Response {
	file_path := os.join_path(data_dir, '${id}.json')
	content := os.read_file(file_path) or {
		return json_response(404, '{"error":"Hexad not found","id":"${esc(id)}"}')
	}
	return json_response(200, content)
}

fn handle_query(tool string, limit int, data_dir string) http.Response {
	if !os.exists(data_dir) {
		return json_response(200, '{"hexads":[],"count":0}')
	}

	files := os.ls(data_dir) or {
		return json_response(500, '{"error":"Failed to list data directory"}')
	}

	mut results := []string{}
	effective_limit := if limit > 0 { limit } else { 100 }

	for f in files {
		if !f.ends_with('.json') {
			continue
		}
		if results.len >= effective_limit {
			break
		}

		file_path := os.join_path(data_dir, f)
		content := os.read_file(file_path) or { continue }

		// If tool filter is specified, check the hexad's tool field
		if tool.len > 0 {
			hexad_tool := json_field(content, 'tool')
			if hexad_tool != tool {
				continue
			}
		}

		results << content
	}

	return json_response(200, '{"hexads":[${results.join(",")}],"count":${results.len}}')
}

fn handle_health(data_dir string) http.Response {
	hexad_count := count_hexads(data_dir)
	latest := latest_hexad_id(data_dir)
	return json_response(200, '{"healthy":true,"service":"verisimdb-rest","hexad_count":${hexad_count},"latest_hexad":"${esc(latest)}","data_dir":"${esc(data_dir)}"}')
}

// --- Data Directory Helpers ---

fn hexads_dir() string {
	env := os.getenv('VERISIMDB_DATA_DIR')
	if env.len > 0 {
		return env
	}
	return 'verisimdb-data/hexads'
}

fn ensure_data_dir(data_dir string) {
	if !os.exists(data_dir) {
		os.mkdir_all(data_dir) or {}
	}
}

fn count_hexads(data_dir string) int {
	if !os.exists(data_dir) {
		return 0
	}
	files := os.ls(data_dir) or { return 0 }
	mut count := 0
	for f in files {
		if f.ends_with('.json') {
			count++
		}
	}
	return count
}

fn latest_hexad_id(data_dir string) string {
	if !os.exists(data_dir) {
		return ''
	}
	files := os.ls(data_dir) or { return '' }
	mut latest_name := ''
	mut latest_mtime := i64(0)

	for f in files {
		if !f.ends_with('.json') {
			continue
		}
		file_path := os.join_path(data_dir, f)
		mtime := os.file_last_mod_unix(file_path)
		if mtime > latest_mtime {
			latest_mtime = mtime
			latest_name = f.all_before('.json')
		}
	}
	return latest_name
}

// --- JSON Array Splitting ---
// Splits a string of JSON objects separated by commas at the top level.
// Handles nested braces correctly.

fn split_json_array(s string) []string {
	mut items := []string{}
	mut depth := 0
	mut start := 0

	for i, c in s {
		if c == `{` {
			depth++
		} else if c == `}` {
			depth--
			if depth == 0 {
				items << s[start..i + 1]
				// Skip past the comma separator
				start = i + 1
				for start < s.len && (s[start] == `,` || s[start] == ` ` || s[start] == `\n` || s[start] == `\t`) {
					start++
				}
			}
		}
	}
	return items
}

fn min(a int, b int) int {
	return if a < b { a } else { b }
}

// --- Helpers ---

// validated_status converts an integer HTTP status code to http.Status
// with bounds checking to avoid unsafe casts.
fn validated_status(code int) http.Status {
	// HTTP status codes are 100-599; default to 200 OK if out of range.
	if code >= 100 && code <= 599 {
		return unsafe { http.Status(code) }
	}
	return .ok
}

fn json_response(status_code int, body string) http.Response {
	return http.new_response(
		status: validated_status(status_code)
		header: http.new_header(key: .content_type, value: 'application/json')
		body: body
	)
}

fn esc(s string) string {
	return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\t', '\\t')
}

fn json_field(data string, key string) string {
	needle := '"${key}":'
	idx := data.index(needle) or { return '' }
	tail := data[idx + needle.len..].trim_space()
	if tail.len == 0 || tail[0] != `"` {
		return ''
	}
	end := tail[1..].index('"') or { return '' }
	return tail[1..end + 1]
}

fn json_field_or(data string, key string, default_val string) string {
	val := json_field(data, key)
	if val.len == 0 {
		return default_val
	}
	return val
}

fn json_field_int(data string, key string) int {
	needle := '"${key}":'
	idx := data.index(needle) or { return 0 }
	tail := data[idx + needle.len..].trim_space()
	if tail.len == 0 {
		return 0
	}
	mut end := 0
	for i, c in tail {
		if c >= `0` && c <= `9` {
			end = i + 1
		} else if end > 0 {
			break
		}
	}
	if end == 0 {
		return 0
	}
	return tail[..end].int()
}

fn query_param(url string, key string) string {
	qmark := url.index('?') or { return '' }
	query := url[qmark + 1..]
	for part in query.split('&') {
		eq := part.index('=') or { continue }
		if part[..eq] == key {
			return part[eq + 1..]
		}
	}
	return ''
}
