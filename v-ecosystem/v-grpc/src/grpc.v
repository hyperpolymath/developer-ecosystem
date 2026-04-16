// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem gRPC Runtime
//
// Exposes Gnosis stateful artefact rendering via gRPC-style RPC:
//   gnosis.GnosisService/Render    — render a template
//   gnosis.GnosisService/Context   — dump resolved context
//   gnosis.GnosisService/Health    — health check
//
// Uses JSON-over-HTTP as transport (gRPC-Web compatible).
// Full HTTP/2 + Protobuf transport planned via Zig FFI.

module grpc

import net.http
import os

// safe_path validates that a user-supplied path contains only characters
// that are safe to pass to an external process.
// Rejects shell metacharacters that could enable command injection.
fn safe_path(s string) !string {
	if s.len == 0 {
		return s
	}
	for c in s {
		match c {
			`a`...`z`, `A`...`Z`, `0`...`9`,
			`/`, `.`, `-`, `_`, ` `, `:` {}
			else {
				return error('unsafe path character: ${c:c}')
			}
		}
	}
	return s
}

// --- Core Interfaces ---

pub interface Service {
	name string
}

pub interface Message {
	marshal_json() string
}

// GRPCHandler implements http.Handler for gRPC-Web style JSON-over-HTTP.
struct GRPCHandler {
	port int
}

pub fn (mut h GRPCHandler) handle(req http.Request) http.Response {
	if req.method != .post {
		return grpc_response(405, '{"error":"POST required for RPC calls"}')
	}

	path := req.url.all_before('?')
	return match path {
		'/gnosis.GnosisService/Render' { handle_render(req) }
		'/gnosis.GnosisService/Context' { handle_context(req) }
		'/gnosis.GnosisService/Health' { handle_health() }
		else {
			grpc_response(404, '{"error":"Unknown method: ${esc(path)}"}')
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
	println('V-gRPC Server starting on port ${s.port}...')
	println('  POST /gnosis.GnosisService/Render   — render template')
	println('  POST /gnosis.GnosisService/Context  — dump context')
	println('  POST /gnosis.GnosisService/Health   — health check')
	println('  (JSON-over-HTTP transport, gRPC-Web compatible)')
	mut server := http.Server{
		addr: ':${s.port}'
		handler: &GRPCHandler{port: s.port}
	}
	server.listen_and_serve()
}

pub fn (s Server) handle_call(method string, payload string) string {
	return match method {
		'Render' {
			template := json_field(payload, 'template')
			template_path := json_field(payload, 'template_path')
			scm_path := json_field(payload, 'scm_path')
			mode := json_field_or(payload, 'mode', 'plain')
			result := gnosis_render(template, template_path, scm_path, mode)
			if result.err.len > 0 {
				'{"error":"${esc(result.err)}"}'
			} else {
				'{"output":"${esc(result.output)}","keys_count":${result.keys_count}}'
			}
		}
		'Context' {
			scm_path := json_field(payload, 'scm_path')
			result := gnosis_dump_context(scm_path)
			if result.err.len > 0 {
				'{"error":"${esc(result.err)}"}'
			} else {
				mut entries := []string{}
				for e in result.entries {
					entries << '{"key":"${esc(e.key)}","value":"${esc(e.value)}"}'
				}
				'{"count":${result.entries.len},"entries":[${entries.join(",")}]}'
			}
		}
		'Health' {
			result := gnosis_health()
			status := if result.healthy { 'SERVING' } else { 'NOT_SERVING' }
			'{"status":"${status}","version":"${esc(result.version)}"}'
		}
		else { '{"error":"Unknown method"}' }
	}
}

fn handle_render(req http.Request) http.Response {
	template := json_field(req.data, 'template')
	template_path := json_field(req.data, 'template_path')
	scm_path := json_field(req.data, 'scm_path')
	mode := json_field_or(req.data, 'mode', 'plain')

	if template.len == 0 && template_path.len == 0 {
		return grpc_response(400, '{"error":"template or template_path required"}')
	}

	result := gnosis_render(template, template_path, scm_path, mode)
	if result.err.len > 0 {
		return grpc_response(500, '{"error":"${esc(result.err)}"}')
	}

	return grpc_response(200, '{"output":"${esc(result.output)}","keys_count":${result.keys_count}}')
}

fn handle_context(req http.Request) http.Response {
	scm_path := json_field(req.data, 'scm_path')
	result := gnosis_dump_context(scm_path)

	if result.err.len > 0 {
		return grpc_response(500, '{"error":"${esc(result.err)}"}')
	}

	mut entries := []string{}
	for e in result.entries {
		entries << '{"key":"${esc(e.key)}","value":"${esc(e.value)}"}'
	}

	return grpc_response(200, '{"count":${result.entries.len},"entries":[${entries.join(",")}]}')
}

fn handle_health() http.Response {
	result := gnosis_health()
	status := if result.healthy { 'SERVING' } else { 'NOT_SERVING' }
	return grpc_response(200, '{"status":"${status}","version":"${esc(result.version)}"}')
}

// --- Gnosis CLI integration ---

struct GnosisRenderResult {
	output     string
	keys_count int
	err        string
}

struct ContextEntry {
	key   string
	value string
}

struct GnosisContextResult {
	entries []ContextEntry
	err     string
}

struct GnosisHealthResult {
	healthy     bool
	version     string
	gnosis_path string
}

fn gnosis_bin() string {
	env := os.getenv('GNOSIS_BIN')
	if env.len > 0 {
		return env
	}
	return 'gnosis'
}

fn gnosis_render(template string, template_path string, scm_path string, mode string) GnosisRenderResult {
	bin := gnosis_bin()
	mut tpl_path := template_path
	mut tmp_file := ''

	// Validate user-supplied paths before passing to os.execute.
	if tpl_path.len > 0 {
		tpl_path = safe_path(tpl_path) or {
			return GnosisRenderResult{err: 'invalid template_path: ${err}'}
		}
	}
	safe_scm := safe_path(scm_path) or {
		return GnosisRenderResult{err: 'invalid scm_path: ${err}'}
	}
	// mode is allowlisted — anything other than 'badges' falls back to '--plain'.

	if tpl_path.len == 0 {
		if template.len == 0 {
			return GnosisRenderResult{err: 'template or template_path required'}
		}
		tmp_file = os.join_path(os.temp_dir(), 'gnosis-grpc-${os.getpid()}.md')
		os.write_file(tmp_file, template) or {
			return GnosisRenderResult{err: 'Failed to write temp template: ${err}'}
		}
		tpl_path = tmp_file
	}

	out_path := os.join_path(os.temp_dir(), 'gnosis-grpc-out-${os.getpid()}.md')
	mut args := if mode == 'badges' { '--badges' } else { '--plain' }
	if safe_scm.len > 0 {
		args += ' --scm-path ${safe_scm}'
	}
	args += ' ${tpl_path} ${out_path}'

	result := os.execute('${bin} ${args}')
	if tmp_file.len > 0 {
		os.rm(tmp_file) or {}
	}
	if result.exit_code != 0 {
		return GnosisRenderResult{err: 'Gnosis exit ${result.exit_code}: ${result.output}'}
	}

	output := os.read_file(out_path) or {
		return GnosisRenderResult{err: 'Failed to read output: ${err}'}
	}
	os.rm(out_path) or {}

	mut keys := 0
	for line in result.output.split('\n') {
		if line.contains('Keys:') {
			parts := line.trim_space().split(' ')
			if parts.len >= 2 {
				keys = parts[1].int()
			}
		}
	}

	return GnosisRenderResult{output: output, keys_count: keys}
}

fn gnosis_dump_context(scm_path string) GnosisContextResult {
	bin := gnosis_bin()
	safe_scm := safe_path(scm_path) or {
		return GnosisContextResult{err: 'invalid scm_path: ${err}'}
	}
	mut args := '--dump-context'
	if safe_scm.len > 0 {
		args += ' --scm-path ${safe_scm}'
	}

	result := os.execute('${bin} ${args}')
	if result.exit_code != 0 {
		return GnosisContextResult{err: 'Gnosis exit ${result.exit_code}: ${result.output}'}
	}

	mut entries := []ContextEntry{}
	for line in result.output.split('\n') {
		trimmed := line.trim_space()
		idx := trimmed.index(' = ') or { continue }
		entries << ContextEntry{
			key: trimmed[..idx]
			value: trimmed[idx + 3..].trim('"')
		}
	}

	return GnosisContextResult{entries: entries}
}

fn gnosis_health() GnosisHealthResult {
	bin := gnosis_bin()
	result := os.execute('${bin} --version')
	if result.exit_code != 0 {
		return GnosisHealthResult{gnosis_path: bin}
	}
	return GnosisHealthResult{
		healthy: true
		version: result.output.trim_space()
		gnosis_path: bin
	}
}

// --- Helpers ---

fn grpc_response(status_code int, body string) http.Response {
	return http.new_response(
		status: unsafe { http.Status(status_code) }
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
