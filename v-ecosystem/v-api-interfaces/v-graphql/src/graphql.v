// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem GraphQL Runtime
//
// Exposes Gnosis stateful artefact rendering via GraphQL:
//   query { render(template: "...", scmPath: "...") { output keysCount } }
//   query { context(scmPath: "...") { count entries { key value } } }
//   query { health { healthy version } }

module graphql

import net.http
import os

// GraphQLHandler implements http.Handler for the Gnosis GraphQL API.
struct GraphQLHandler {
	port int
}

pub fn (mut h GraphQLHandler) handle(req http.Request) http.Response {
	path := req.url.all_before('?')
	if path != '/graphql' {
		return json_response(404, '{"error":"Use /graphql endpoint"}')
	}

	if req.method == .get {
		return graphiql_page()
	}
	if req.method != .post {
		return json_response(405, '{"error":"POST or GET required"}')
	}

	query := json_field(req.data, 'query')
	if query.len == 0 {
		return json_response(400, '{"errors":[{"message":"Missing query field"}]}')
	}

	return resolve(query, req.data)
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
	println('V-GraphQL Server starting on port ${s.port}...')
	println('  POST /graphql  — execute GraphQL queries')
	println('  GET  /graphql  — GraphiQL playground')
	mut server := http.Server{
		addr: ':${s.port}'
		handler: &GraphQLHandler{port: s.port}
	}
	server.listen_and_serve()
}

fn resolve(query string, data string) http.Response {
	if query.contains('health') {
		return resolve_health()
	}
	if query.contains('context') {
		scm_path := extract_arg(query, 'scmPath')
		return resolve_context(scm_path)
	}
	if query.contains('render') {
		template := extract_arg(query, 'template')
		template_path := extract_arg(query, 'templatePath')
		scm_path := extract_arg(query, 'scmPath')
		mode_val := extract_arg(query, 'mode')
		mode := if mode_val.len > 0 { mode_val } else { 'plain' }
		return resolve_render(template, template_path, scm_path, mode)
	}
	if query.contains('__schema') {
		return resolve_schema()
	}

	return json_response(200, '{"errors":[{"message":"Unknown query. Available: render, context, health"}]}')
}

fn resolve_render(template string, template_path string, scm_path string, mode string) http.Response {
	result := gnosis_render(template, template_path, scm_path, mode)
	if result.err.len > 0 {
		return json_response(200, '{"errors":[{"message":"${esc(result.err)}"}]}')
	}
	return json_response(200, '{"data":{"render":{"output":"${esc(result.output)}","keysCount":${result.keys_count}}}}')
}

fn resolve_context(scm_path string) http.Response {
	result := gnosis_dump_context(scm_path)
	if result.err.len > 0 {
		return json_response(200, '{"errors":[{"message":"${esc(result.err)}"}]}')
	}

	mut entries := []string{}
	for e in result.entries {
		entries << '{"key":"${esc(e.key)}","value":"${esc(e.value)}"}'
	}

	return json_response(200, '{"data":{"context":{"count":${result.entries.len},"entries":[${entries.join(",")}]}}}')
}

fn resolve_health() http.Response {
	result := gnosis_health()
	status := if result.healthy { 'true' } else { 'false' }
	return json_response(200, '{"data":{"health":{"healthy":${status},"version":"${esc(result.version)}","gnosisPath":"${esc(result.gnosis_path)}"}}}')
}

fn resolve_schema() http.Response {
	return json_response(200, '{"data":{"__schema":{"types":[' +
		'{"name":"Query","fields":["render","context","health"]},' +
		'{"name":"RenderResult","fields":["output","keysCount"]},' +
		'{"name":"ContextResult","fields":["count","entries"]},' +
		'{"name":"ContextEntry","fields":["key","value"]},' +
		'{"name":"HealthResult","fields":["healthy","version","gnosisPath"]}' +
		']}}}')
}

fn graphiql_page() http.Response {
	html := '<!DOCTYPE html>
<html><head><title>Gnosis GraphQL</title></head>
<body style="font-family:monospace;padding:2em">
<h2>Gnosis GraphQL API</h2>
<p>POST queries to /graphql with JSON body:</p>
<pre>{ "query": "{ health { healthy version } }" }

{ "query": "{ context(scmPath: \\"/path/.machine_readable\\") { count entries { key value } } }" }

{ "query": "{ render(template: \\"# (:name)\\", scmPath: \\"/path/.machine_readable\\") { output keysCount } }" }
</pre></body></html>'

	return http.new_response(
		status: .ok
		header: http.new_header(key: .content_type, value: 'text/html')
		body: html
	)
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
			return GnosisRenderResult{err: 'template or templatePath required'}
		}
		tmp_file = os.join_path(os.temp_dir(), 'gnosis-gql-${os.getpid()}.md')
		os.write_file(tmp_file, template) or {
			return GnosisRenderResult{err: 'Failed to write temp template: ${err}'}
		}
		tpl_path = tmp_file
	}

	out_path := os.join_path(os.temp_dir(), 'gnosis-gql-out-${os.getpid()}.md')
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

fn extract_arg(query string, arg_name string) string {
	needle := '${arg_name}:'
	idx := query.index(needle) or { return '' }
	tail := query[idx + needle.len..].trim_space()
	if tail.len == 0 {
		return ''
	}
	if tail[0] == `"` {
		end := tail[1..].index('"') or { return '' }
		return tail[1..end + 1]
	}
	mut end := tail.len
	for i, c in tail {
		if c == `,` || c == `)` || c == ` ` {
			end = i
			break
		}
	}
	return tail[..end]
}
