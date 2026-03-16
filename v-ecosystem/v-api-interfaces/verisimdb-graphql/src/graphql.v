// SPDX-License-Identifier: PMPL-1.0-or-later
// VeriSimDB GraphQL API Gateway
//
// Exposes VeriSimDB hexad storage via GraphQL on port 9092:
//   mutation { storeHexad(hexad: "...") { id } }
//   query { hexads(tool: "panic-attack", limit: 10) { id schema createdAt semantic { totalWeakPoints criticalCount } } }
//   query { hexad(id: "pa-...") { ... full hexad ... } }
//   query { health { healthy hexadCount latestHexad } }
//   query { __schema { types { name fields } } }
//   GET /graphql — GraphiQL playground
//
// Hexads are stored as individual JSON files under a configurable data
// directory (VERISIMDB_DATA_DIR env var, default: verisimdb-data/hexads/).

module graphql

import net.http
import os

// GraphQLHandler implements http.Handler for the VeriSimDB GraphQL API.
struct GraphQLHandler {
	port     int
	data_dir string
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

	return resolve(query, req.data, h.data_dir)
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
	println('VeriSimDB GraphQL Server starting on port ${s.port}...')
	println('  Data directory: ${data_dir}')
	println('  POST /graphql  — execute GraphQL queries/mutations')
	println('  GET  /graphql  — GraphiQL playground')
	mut server := http.Server{
		addr: ':${s.port}'
		handler: &GraphQLHandler{port: s.port, data_dir: data_dir}
	}
	server.listen_and_serve()
}

// --- Resolver Dispatch ---

fn resolve(query string, data string, data_dir string) http.Response {
	// Mutations
	if query.contains('storeHexad') {
		return resolve_store_hexad(query, data, data_dir)
	}
	// Queries — order matters: check specific before general
	if query.contains('__schema') {
		return resolve_schema()
	}
	if query.contains('health') {
		return resolve_health(data_dir)
	}
	// hexad (singular, by ID) — must check before hexads (plural)
	if query.contains('hexad(') && !query.contains('hexads(') {
		id := extract_arg(query, 'id')
		return resolve_hexad_by_id(id, data_dir)
	}
	if query.contains('hexads') {
		tool := extract_arg(query, 'tool')
		limit_str := extract_arg(query, 'limit')
		limit := if limit_str.len > 0 { limit_str.int() } else { 100 }
		return resolve_hexads(tool, limit, data_dir)
	}

	return json_response(200, '{"errors":[{"message":"Unknown query. Available: storeHexad (mutation), hexads, hexad, health, __schema"}]}')
}

// --- Mutation Resolvers ---

fn resolve_store_hexad(query string, data string, data_dir string) http.Response {
	// The hexad JSON is passed via a variables field or inline.
	// Support: mutation { storeHexad(hexad: "...escaped json...") { id } }
	// Also support variables: {"hexad": {...}}
	hexad_json := json_field(data, 'hexad')
	variables_hexad := json_nested_object(data, 'variables', 'hexad')

	hexad_data := if hexad_json.len > 0 {
		// Unescape the inline string
		hexad_json.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')
	} else if variables_hexad.len > 0 {
		variables_hexad
	} else {
		// Try extracting from the query argument itself
		arg := extract_arg(query, 'hexad')
		if arg.len > 0 {
			arg.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')
		} else {
			return json_response(200, '{"errors":[{"message":"hexad argument required for storeHexad mutation"}]}')
		}
	}

	id := json_field(hexad_data, 'id')
	if id.len == 0 {
		return json_response(200, '{"errors":[{"message":"Hexad must have an id field"}]}')
	}

	ensure_data_dir(data_dir)
	file_path := os.join_path(data_dir, '${id}.json')
	os.write_file(file_path, hexad_data) or {
		return json_response(200, '{"errors":[{"message":"Failed to write hexad: ${esc(err.msg())}"}]}')
	}

	return json_response(200, '{"data":{"storeHexad":{"id":"${esc(id)}","stored":true}}}')
}

// --- Query Resolvers ---

fn resolve_hexads(tool string, limit int, data_dir string) http.Response {
	if !os.exists(data_dir) {
		return json_response(200, '{"data":{"hexads":[]}}')
	}

	files := os.ls(data_dir) or {
		return json_response(200, '{"errors":[{"message":"Failed to list data directory"}]}')
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

		if tool.len > 0 {
			hexad_tool := json_field(content, 'tool')
			if hexad_tool != tool {
				continue
			}
		}

		// Build a GraphQL-shaped response for each hexad
		results << hexad_to_graphql(content)
	}

	return json_response(200, '{"data":{"hexads":[${results.join(",")}]}}')
}

fn resolve_hexad_by_id(id string, data_dir string) http.Response {
	if id.len == 0 {
		return json_response(200, '{"errors":[{"message":"id argument required"}]}')
	}

	file_path := os.join_path(data_dir, '${id}.json')
	content := os.read_file(file_path) or {
		return json_response(200, '{"errors":[{"message":"Hexad not found","id":"${esc(id)}"}]}')
	}

	return json_response(200, '{"data":{"hexad":${content}}}')
}

fn resolve_health(data_dir string) http.Response {
	count := count_hexads(data_dir)
	latest := latest_hexad_id(data_dir)
	return json_response(200, '{"data":{"health":{"healthy":true,"hexadCount":${count},"latestHexad":"${esc(latest)}"}}}')
}

fn resolve_schema() http.Response {
	return json_response(200, '{"data":{"__schema":{"types":[' +
		'{"name":"Query","fields":["hexads","hexad","health"]},' +
		'{"name":"Mutation","fields":["storeHexad"]},' +
		'{"name":"Hexad","fields":["id","schema","tool","createdAt","semantic"]},' +
		'{"name":"HexadSemantic","fields":["totalWeakPoints","criticalCount","highCount","mediumCount","lowCount","infoCount"]},' +
		'{"name":"HexadList","fields":["hexads"]},' +
		'{"name":"StoreResult","fields":["id","stored"]},' +
		'{"name":"Health","fields":["healthy","hexadCount","latestHexad"]}' +
		']}}}')
}

fn graphiql_page() http.Response {
	html := '<!DOCTYPE html>
<html><head><title>VeriSimDB GraphQL</title></head>
<body style="font-family:monospace;padding:2em">
<h2>VeriSimDB GraphQL API</h2>
<p>POST queries to /graphql with JSON body:</p>
<pre>{ "query": "{ health { healthy hexadCount latestHexad } }" }

{ "query": "{ hexads(tool: \\"panic-attack\\", limit: 10) { id schema createdAt } }" }

{ "query": "{ hexad(id: \\"pa-001\\") { id tool schema createdAt } }" }

{ "query": "mutation { storeHexad(hexad: \\"..json..\\") { id stored } }" }

{ "query": "{ __schema { types { name fields } } }" }
</pre>
<p>Hexad data directory: <code>VERISIMDB_DATA_DIR</code> env var (default: verisimdb-data/hexads/)</p>
</body></html>'

	return http.new_response(
		status: .ok
		header: http.new_header(key: .content_type, value: 'text/html')
		body: html
	)
}

// --- Hexad GraphQL Projection ---
// Extracts known fields from raw hexad JSON and builds a GraphQL-shaped object.

fn hexad_to_graphql(raw string) string {
	id := json_field(raw, 'id')
	schema := json_field(raw, 'schema')
	tool := json_field(raw, 'tool')
	created_at := json_field(raw, 'createdAt')

	// Extract semantic sub-object fields
	total_weak := json_field_int(raw, 'totalWeakPoints')
	critical := json_field_int(raw, 'criticalCount')
	high := json_field_int(raw, 'highCount')
	medium := json_field_int(raw, 'mediumCount')
	low := json_field_int(raw, 'lowCount')
	info := json_field_int(raw, 'infoCount')

	return '{"id":"${esc(id)}","schema":"${esc(schema)}","tool":"${esc(tool)}","createdAt":"${esc(created_at)}","semantic":{"totalWeakPoints":${total_weak},"criticalCount":${critical},"highCount":${high},"mediumCount":${medium},"lowCount":${low},"infoCount":${info}}}'
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

// --- JSON Helpers ---

fn json_nested_object(data string, outer_key string, inner_key string) string {
	// Find the outer key, then find the inner key within it
	outer_needle := '"${outer_key}":'
	outer_idx := data.index(outer_needle) or { return '' }
	outer_tail := data[outer_idx + outer_needle.len..]

	inner_needle := '"${inner_key}":'
	inner_idx := outer_tail.index(inner_needle) or { return '' }
	inner_tail := outer_tail[inner_idx + inner_needle.len..].trim_space()

	if inner_tail.len == 0 || inner_tail[0] != `{` {
		return ''
	}

	// Find matching closing brace
	mut depth := 0
	for i, c in inner_tail {
		if c == `{` {
			depth++
		} else if c == `}` {
			depth--
			if depth == 0 {
				return inner_tail[..i + 1]
			}
		}
	}
	return ''
}

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
		if c == `,` || c == `)` || c == ` ` || c == `}` {
			end = i
			break
		}
	}
	return tail[..end]
}
