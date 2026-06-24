// SPDX-License-Identifier: MPL-2.0
// VeriSimDB gRPC-Web API Gateway
//
// Exposes VeriSimDB hexad storage via gRPC-style RPC on port 9091:
//   POST /verisimdb.HexadService/Store      — store a hexad
//   POST /verisimdb.HexadService/StoreBatch  — store multiple hexads
//   POST /verisimdb.HexadService/Query       — query hexads by tool
//   POST /verisimdb.HexadService/Get         — get hexad by ID
//   POST /verisimdb.HexadService/Health      — health check
//
// Uses JSON-over-HTTP as transport (gRPC-Web compatible).
// Full HTTP/2 + Protobuf transport planned via Zig FFI.
//
// Hexads are stored as individual JSON files under a configurable data
// directory (VERISIMDB_DATA_DIR env var, default: verisimdb-data/hexads/).

module verisimdb_grpc

import net.http
import os

// --- Core Interfaces ---

pub interface Service {
	name string
}

pub interface Message {
	marshal_json() string
}

// GRPCHandler implements http.Handler for gRPC-Web style JSON-over-HTTP.
struct GRPCHandler {
	port     int
	data_dir string
}

pub fn (mut h GRPCHandler) handle(req http.Request) http.Response {
	if req.method != .post {
		return grpc_response(405, '{"error":"POST required for RPC calls"}')
	}

	path := req.url.all_before('?')
	return match path {
		'/verisimdb.HexadService/Store' { handle_store(req, h.data_dir) }
		'/verisimdb.HexadService/StoreBatch' { handle_store_batch(req, h.data_dir) }
		'/verisimdb.HexadService/Query' { handle_query(req, h.data_dir) }
		'/verisimdb.HexadService/Get' { handle_get(req, h.data_dir) }
		'/verisimdb.HexadService/Health' { handle_health(h.data_dir) }
		else {
			grpc_response(404, '{"error":"Unknown method: ${esc(path)}","available":["/verisimdb.HexadService/Store","/verisimdb.HexadService/StoreBatch","/verisimdb.HexadService/Query","/verisimdb.HexadService/Get","/verisimdb.HexadService/Health"]}')
		}
	}
}

pub struct Server {
pub mut:
	port     int
	services []Service
}

pub fn new_server(port int) &Server {
	return &Server{
		port: port
	}
}

pub fn (mut s Server) register_service(svc Service) {
	s.services << svc
}

pub fn (s Server) start() {
	data_dir := hexads_dir()
	println('VeriSimDB gRPC Server starting on port ${s.port}...')
	println('  Data directory: ${data_dir}')
	println('  POST /verisimdb.HexadService/Store      — store hexad')
	println('  POST /verisimdb.HexadService/StoreBatch  — store batch')
	println('  POST /verisimdb.HexadService/Query       — query hexads')
	println('  POST /verisimdb.HexadService/Get         — get by ID')
	println('  POST /verisimdb.HexadService/Health      — health check')
	println('  (JSON-over-HTTP transport, gRPC-Web compatible)')
	mut server := http.Server{
		addr: ':${s.port}'
		handler: &GRPCHandler{port: s.port, data_dir: data_dir}
	}
	server.listen_and_serve()
}

pub fn (s Server) handle_call(method string, payload string) string {
	data_dir := hexads_dir()
	return match method {
		'Store' {
			id := json_field(payload, 'id')
			if id.len == 0 {
				'{"error":"Hexad must have an id field"}'
			} else {
				ensure_data_dir(data_dir)
				file_path := os.join_path(data_dir, '${id}.json')
				os.write_file(file_path, payload) or {
					'{"error":"Failed to write hexad: ${esc(err.msg())}"}'
					return '{"error":"Write failed"}'
				}
				'{"stored":true,"id":"${esc(id)}"}'
			}
		}
		'Get' {
			id := json_field(payload, 'id')
			if id.len == 0 {
				'{"error":"id field required"}'
			} else {
				file_path := os.join_path(data_dir, '${id}.json')
				content := os.read_file(file_path) or {
					'{"error":"Hexad not found","id":"${esc(id)}"}'
					return '{"error":"Not found"}'
				}
				content
			}
		}
		'Health' {
			count := count_hexads(data_dir)
			'{"status":"SERVING","hexad_count":${count}}'
		}
		else { '{"error":"Unknown method"}' }
	}
}

// --- Route Handlers ---

fn handle_store(req http.Request, data_dir string) http.Response {
	if req.data.len == 0 {
		return grpc_response(400, '{"error":"Request body required"}')
	}

	id := json_field(req.data, 'id')
	if id.len == 0 {
		return grpc_response(400, '{"error":"Hexad must have an id field"}')
	}

	ensure_data_dir(data_dir)
	file_path := os.join_path(data_dir, '${id}.json')
	os.write_file(file_path, req.data) or {
		return grpc_response(500, '{"error":"Failed to write hexad: ${esc(err.msg())}"}')
	}

	return grpc_response(200, '{"stored":true,"id":"${esc(id)}"}')
}

fn handle_store_batch(req http.Request, data_dir string) http.Response {
	if req.data.len == 0 {
		return grpc_response(400, '{"error":"Request body required"}')
	}

	ensure_data_dir(data_dir)

	// Expect {"hexads": [...]} wrapper
	body := req.data.trim_space()

	// Find the array content within the hexads field
	hexads_start := body.index('"hexads"') or {
		return grpc_response(400, '{"error":"Expected hexads field containing array"}')
	}
	arr_start := body.index_after('[', hexads_start)
	if arr_start < 0 {
		return grpc_response(400, '{"error":"Expected hexads array"}')
	}
	arr_end := body.last_index(']') or {
		return grpc_response(400, '{"error":"Malformed hexads array"}')
	}

	inner := body[arr_start + 1..arr_end].trim_space()
	if inner.len == 0 {
		return grpc_response(200, '{"stored":0,"ids":[]}')
	}

	items := split_json_array(inner)
	mut stored_ids := []string{}
	mut errors := []string{}

	for item in items {
		hexad := item.trim_space()
		id := json_field(hexad, 'id')
		if id.len == 0 {
			errors << '"missing id"'
			continue
		}
		file_path := os.join_path(data_dir, '${id}.json')
		os.write_file(file_path, hexad) or {
			errors << '"write failed: ${esc(id)}"'
			continue
		}
		stored_ids << '"${esc(id)}"'
	}

	mut result := '{"stored":${stored_ids.len},"ids":[${stored_ids.join(",")}]'
	if errors.len > 0 {
		result += ',"errors":[${errors.join(",")}]'
	}
	result += '}'

	return grpc_response(200, result)
}

fn handle_query(req http.Request, data_dir string) http.Response {
	tool := json_field(req.data, 'tool')
	limit := json_field_int(req.data, 'limit')
	effective_limit := if limit > 0 { limit } else { 100 }

	if !os.exists(data_dir) {
		return grpc_response(200, '{"hexads":[],"count":0}')
	}

	files := os.ls(data_dir) or {
		return grpc_response(500, '{"error":"Failed to list data directory"}')
	}

	mut results := []string{}
	for f in files {
		if !f.ends_with('.json') {
			continue
		}
		if results.len >= effective_limit {
			break
		}

		file_path := os.join_path(data_dir, f)
		content := os.read_file(file_path) or { continue }

		if tool.len > 0 {
			hexad_tool := json_field(content, 'tool')
			if hexad_tool != tool {
				continue
			}
		}

		results << content
	}

	return grpc_response(200, '{"hexads":[${results.join(",")}],"count":${results.len}}')
}

fn handle_get(req http.Request, data_dir string) http.Response {
	id := json_field(req.data, 'id')
	if id.len == 0 {
		return grpc_response(400, '{"error":"id field required"}')
	}

	file_path := os.join_path(data_dir, '${id}.json')
	content := os.read_file(file_path) or {
		return grpc_response(404, '{"error":"Hexad not found","id":"${esc(id)}"}')
	}

	return grpc_response(200, content)
}

fn handle_health(data_dir string) http.Response {
	count := count_hexads(data_dir)
	latest := latest_hexad_id(data_dir)
	return grpc_response(200, '{"status":"SERVING","hexad_count":${count},"latest_hexad":"${esc(latest)}"}')
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
				start = i + 1
				for start < s.len && (s[start] == `,` || s[start] == ` ` || s[start] == `\n` || s[start] == `\t`) {
					start++
				}
			}
		}
	}
	return items
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

fn grpc_response(status_code int, body string) http.Response {
	return http.new_response(
		status: validated_status(status_code)
		header: http.new_header(key: .content_type, value: 'application/grpc+json')
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
