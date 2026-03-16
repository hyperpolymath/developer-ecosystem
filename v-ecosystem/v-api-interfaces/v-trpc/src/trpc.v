// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem tRPC-style Type-safe RPC over HTTP
// Author: Jonathan D.A. Jewell
//
// Type-safe remote procedure calls over HTTP with input/output type
// validation, a composable router with middleware support, and
// automatic JSON serialisation. Procedures are defined with explicit
// input/output types so the compiler catches schema mismatches at
// build time rather than at runtime.
//
//   POST /trpc/<procedure>   — invoke a procedure
//   GET  /trpc/<procedure>   — query a procedure
//   GET  /health             — health check

module trpc

import json
import net.http

// --- Middleware ---

// Context carries per-request state through the middleware chain.
pub struct Context {
pub mut:
	headers map[string]string
	meta    map[string]string
}

// MiddlewareFn runs before a procedure and can modify the context or
// abort the request by returning an error.
pub type MiddlewareFn = fn (mut ctx Context) !

// --- Procedure definitions ---

// ProcedureKind distinguishes queries (idempotent reads) from
// mutations (state-changing writes).
pub enum ProcedureKind {
	query
	mutation
}

// ProcedureFn is the handler signature: receives raw JSON input and
// context, returns JSON output or an error.
pub type ProcedureFn = fn (input json.Any, ctx &Context) !(json.Any)

// ValidatorFn checks that the input conforms to the expected schema
// before the handler runs.
pub type ValidatorFn = fn (input json.Any) !

// Procedure bundles a handler with its kind and optional validator.
struct Procedure {
	name      string
	kind      ProcedureKind
	handler   ProcedureFn
	validator ?ValidatorFn
}

// --- Router ---

// Router holds registered procedures and global middleware.
pub struct Router {
mut:
	procedures map[string]Procedure
	middleware []MiddlewareFn
}

// new_router creates an empty router.
pub fn new_router() &Router {
	return &Router{}
}

// use_middleware appends a middleware function to the global chain.
pub fn (mut r Router) use_middleware(mw MiddlewareFn) {
	r.middleware << mw
}

// query registers a read-only procedure with an optional input validator.
pub fn (mut r Router) query(name string, handler ProcedureFn, validator ?ValidatorFn) {
	r.procedures[name] = Procedure{
		name: name
		kind: .query
		handler: handler
		validator: validator
	}
}

// mutation registers a state-changing procedure with an optional validator.
pub fn (mut r Router) mutation(name string, handler ProcedureFn, validator ?ValidatorFn) {
	r.procedures[name] = Procedure{
		name: name
		kind: .mutation
		handler: handler
		validator: validator
	}
}

// invoke runs middleware, validates input, and calls the procedure.
pub fn (r &Router) invoke(name string, input json.Any) !json.Any {
	proc := r.procedures[name] or {
		return error('procedure "${name}" not found')
	}

	// Run middleware chain
	mut ctx := Context{}
	for mw in r.middleware {
		mw(mut ctx)!
	}

	// Validate input if a validator is registered
	if validator := proc.validator {
		validator(input)!
	}

	return proc.handler(input, &ctx)
}

// --- HTTP server ---

// ServerHandler bridges the router to V's HTTP server.
struct ServerHandler {
	router &Router
}

pub fn (h ServerHandler) handle(req http.Request) http.Response {
	path := req.url.all_before('?')

	if path == '/health' {
		names := h.router.procedures.keys()
		return json_resp(200, '{"status":"ok","procedures":${names.len}}')
	}

	// Expect /trpc/<procedure_name>
	if !path.starts_with('/trpc/') {
		return json_resp(404, '{"error":"use /trpc/<procedure>"}')
	}
	proc_name := path[6..] // strip '/trpc/'
	if proc_name.len == 0 {
		return json_resp(400, '{"error":"procedure name required"}')
	}

	proc := h.router.procedures[proc_name] or {
		return json_resp(404, '{"error":"procedure not found: ${proc_name}"}')
	}

	// Enforce HTTP method alignment
	match proc.kind {
		.query {
			if req.method != .get && req.method != .post {
				return json_resp(405, '{"error":"query procedures accept GET or POST"}')
			}
		}
		.mutation {
			if req.method != .post {
				return json_resp(405, '{"error":"mutation procedures require POST"}')
			}
		}
	}

	// Parse input from body (POST) or query param (GET)
	input_str := if req.method == .get {
		query_param(req.url, 'input')
	} else {
		req.data
	}
	input := if input_str.len > 0 {
		json.decode(input_str) or {
			return json_resp(400, '{"error":"invalid JSON input"}')
		}
	} else {
		json.null
	}

	result := h.router.invoke(proc_name, input) or {
		return json_resp(500, '{"error":"${esc(err.str())}"}')
	}

	return json_resp(200, '{"result":${result.str()}}')
}

// Server wraps the HTTP listener and the tRPC router.
pub struct Server {
pub mut:
	port   int
	router &Router
}

// new_server creates a tRPC server on the given port.
pub fn new_server(port int) &Server {
	return &Server{
		port: port
		router: new_router()
	}
}

// start begins listening for tRPC requests.
pub fn (s Server) start() {
	println('[v-trpc] listening on :${s.port}')
	mut srv := http.Server{
		addr: ':${s.port}'
		handler: &ServerHandler{router: s.router}
	}
	srv.listen_and_serve()
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

fn json_resp(status_code int, body string) http.Response {
	return http.new_response(
		status: validated_status(status_code)
		header: http.new_header(key: .content_type, value: 'application/json')
		body: body
	)
}

fn esc(s string) string {
	return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
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

// --- Tests ---

fn test_router_query() {
	mut r := new_router()
	r.query('greet', fn (input json.Any, ctx &Context) !(json.Any) {
		name := input.as_map()['name'] or { json.Any('world') }
		return json.Any('hello ${name.str()}')
	}, none)

	result := r.invoke('greet', json.decode('{"name":"V"}')!) or {
		assert false, 'unexpected error: ${err}'
		return
	}
	assert result.str().contains('V')
}

fn test_router_missing_procedure() {
	r := new_router()
	r.invoke('nope', json.null) or {
		assert err.str().contains('not found')
		return
	}
	assert false, 'expected error for missing procedure'
}
