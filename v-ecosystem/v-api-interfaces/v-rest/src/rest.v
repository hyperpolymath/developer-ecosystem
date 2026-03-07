// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem REST Runtime
//
// Exposes Gnosis stateful artefact rendering via REST endpoints:
//   POST /render          — render a template against 6scm data
//   GET  /context         — dump all resolved context keys
//   GET  /health          — engine health check
//   GET  /                — API discovery

module rest

import net.http
import os

// GnosisHandler implements http.Handler for the Gnosis REST API.
struct GnosisHandler {
	port int
}

pub fn (mut h GnosisHandler) handle(req http.Request) http.Response {
	path := req.url.all_before('?')
	return match path {
		'/' { handle_info() }
		'/render' { handle_render(req) }
		'/context' { handle_context(req) }
		'/health' { handle_health() }
		else {
			json_response(404, '{"error":"Not found","endpoints":["/render","/context","/health"]}')
		}
	}
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
	println('V-REST Server starting on port ${s.port}...')
	println('  POST /render          — render template')
	println('  GET  /context?scm=P   — dump 6scm context')
	println('  GET  /health          — engine health')
	mut server := http.Server{
		addr: ':${s.port}'
		handler: &GnosisHandler{port: s.port}
	}
	server.listen_and_serve()
}

fn handle_info() http.Response {
	return json_response(200, '{"service":"gnosis-rest","version":"1.1.0","endpoints":["/render","/context","/health"]}')
}

fn handle_render(req http.Request) http.Response {
	if req.method != .post {
		return json_response(405, '{"error":"POST required"}')
	}

	template := json_field(req.data, 'template')
	template_path := json_field(req.data, 'template_path')
	scm_path := json_field(req.data, 'scm_path')
	mode := json_field_or(req.data, 'mode', 'plain')

	if template.len == 0 && template_path.len == 0 {
		return json_response(400, '{"error":"template or template_path required"}')
	}

	result := gnosis_render(template, template_path, scm_path, mode)

	if result.err.len > 0 {
		return json_response(500, '{"error":"${esc(result.err)}"}')
	}

	return json_response(200, '{"output":"${esc(result.output)}","keys_count":${result.keys_count}}')
}

fn handle_context(req http.Request) http.Response {
	scm_path := query_param(req.url, 'scm')
	result := gnosis_dump_context(scm_path)

	if result.err.len > 0 {
		return json_response(500, '{"error":"${esc(result.err)}"}')
	}

	mut entries := []string{}
	for e in result.entries {
		entries << '{"key":"${esc(e.key)}","value":"${esc(e.value)}"}'
	}

	return json_response(200, '{"count":${result.entries.len},"entries":[${entries.join(",")}]}')
}

fn handle_health() http.Response {
	result := gnosis_health()
	code := if result.healthy { 200 } else { 503 }
	status := if result.healthy { 'ok' } else { 'unavailable' }
	return json_response(code, '{"status":"${status}","version":"${esc(result.version)}","gnosis_path":"${esc(result.gnosis_path)}"}')
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

	if tpl_path.len == 0 {
		if template.len == 0 {
			return GnosisRenderResult{err: 'template or template_path required'}
		}
		tmp_file = os.join_path(os.temp_dir(), 'gnosis-tpl-${os.getpid()}.md')
		os.write_file(tmp_file, template) or {
			return GnosisRenderResult{err: 'Failed to write temp template: ${err}'}
		}
		tpl_path = tmp_file
	}

	out_path := os.join_path(os.temp_dir(), 'gnosis-out-${os.getpid()}.md')
	mut args := if mode == 'badges' { '--badges' } else { '--plain' }
	if scm_path.len > 0 {
		args += ' --scm-path ${scm_path}'
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
	mut args := '--dump-context'
	if scm_path.len > 0 {
		args += ' --scm-path ${scm_path}'
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

fn json_response(status_code int, body string) http.Response {
	return http.new_response(
		status: unsafe { http.Status(status_code) }
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
