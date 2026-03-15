// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem JSON-RPC 2.0 Server
// Author: Jonathan D.A. Jewell
//
// Implements JSON-RPC 2.0 (the wire protocol MCP uses) over HTTP.
// Supports single and batch requests, typed error responses, and
// pluggable method handlers registered at startup.
//
//   POST /                — JSON-RPC endpoint
//   GET  /health          — health check

module jsonrpc

import json
import net.http

// --- JSON-RPC 2.0 types ---

// Request represents a single JSON-RPC 2.0 request object.
pub struct Request {
pub:
	jsonrpc string = '2.0'
	method  string
	id      json.Any = json.null
	params  json.Any = json.null
}

// Response is the JSON-RPC 2.0 response envelope.
pub struct Response {
pub:
	jsonrpc string = '2.0'
	id      json.Any
	result  json.Any    = json.null
	error   ?ErrorObj
}

// ErrorObj carries structured error information per the spec.
pub struct ErrorObj {
pub:
	code    int
	message string
	data    json.Any = json.null
}

// Standard error codes defined by JSON-RPC 2.0.
pub const parse_error = -32700
pub const invalid_request = -32600
pub const method_not_found = -32601
pub const invalid_params = -32602
pub const internal_error = -32603

// --- Handler registry ---

// HandlerFn is the signature every method handler must satisfy.
// It receives parsed params and returns either a result or an error.
pub type HandlerFn = fn (params json.Any) !(json.Any)

// Router maps method names to handler functions.
pub struct Router {
mut:
	handlers map[string]HandlerFn
}

// new_router creates an empty router.
pub fn new_router() &Router {
	return &Router{}
}

// register binds a method name to a handler function.
pub fn (mut r Router) register(method string, handler HandlerFn) {
	r.handlers[method] = handler
}

// dispatch invokes the handler for the given method, returning a
// well-formed JSON-RPC response. Unknown methods produce -32601.
pub fn (r &Router) dispatch(req Request) Response {
	handler := r.handlers[req.method] or {
		return error_response(req.id, method_not_found, 'Method not found: ${req.method}')
	}
	result := handler(req.params) or {
		return error_response(req.id, internal_error, '${err}')
	}
	return Response{
		id: req.id
		result: result
	}
}

// --- Request parsing ---

// parse_request decodes a single JSON-RPC request from raw JSON text.
fn parse_request(raw json.Any) !Request {
	obj := raw.as_map()
	version := obj['jsonrpc'] or { return error('missing jsonrpc') }.str()
	if version != '2.0' {
		return error('jsonrpc must be "2.0"')
	}
	method := obj['method'] or { return error('missing method') }.str()
	if method.len == 0 {
		return error('empty method')
	}
	id := obj['id'] or { json.null }
	params := obj['params'] or { json.null }
	return Request{
		method: method
		id: id
		params: params
	}
}

// process_raw handles raw HTTP body text: detects batch vs single,
// parses, dispatches, and returns the JSON response string.
pub fn (r &Router) process_raw(body string) string {
	parsed := json.decode(body) or {
		return encode_response(error_response(json.null, parse_error, 'Parse error'))
	}

	// Batch request — JSON array at top level
	if parsed.type_name() == 'array' {
		arr := parsed.arr()
		if arr.len == 0 {
			return encode_response(error_response(json.null, invalid_request, 'Empty batch'))
		}
		mut results := []string{}
		for item in arr {
			req := parse_request(item) or {
				results << encode_response(error_response(json.null, invalid_request, '${err}'))
				continue
			}
			results << encode_response(r.dispatch(req))
		}
		return '[${results.join(",")}]'
	}

	// Single request
	req := parse_request(parsed) or {
		return encode_response(error_response(json.null, invalid_request, '${err}'))
	}
	return encode_response(r.dispatch(req))
}

// --- HTTP server ---

// ServerHandler implements http.Handler for the JSON-RPC endpoint.
struct ServerHandler {
	router &Router
}

pub fn (h ServerHandler) handle(req http.Request) http.Response {
	path := req.url.all_before('?')
	if path == '/health' {
		return json_resp(200, '{"status":"ok","protocol":"json-rpc-2.0","methods":${h.router.handlers.keys().len}}')
	}
	if req.method != .post {
		return json_resp(405, '{"error":"POST required"}')
	}
	result := h.router.process_raw(req.data)
	return json_resp(200, result)
}

// Server wraps the HTTP listener and the method router.
pub struct Server {
pub mut:
	port   int
	router &Router
}

// new_server creates a JSON-RPC server on the given port.
pub fn new_server(port int) &Server {
	return &Server{
		port: port
		router: new_router()
	}
}

// start begins listening for JSON-RPC requests.
pub fn (s Server) start() {
	println('[v-jsonrpc] listening on :${s.port}')
	mut srv := http.Server{
		addr: ':${s.port}'
		handler: &ServerHandler{router: s.router}
	}
	srv.listen_and_serve()
}

// --- Helpers ---

fn error_response(id json.Any, code int, message string) Response {
	return Response{
		id: id
		error: ErrorObj{
			code: code
			message: message
		}
	}
}

fn encode_response(resp Response) string {
	mut parts := ['{"jsonrpc":"2.0"']
	parts << ',"id":${resp.id.str()}'
	if err := resp.error {
		parts << ',"error":{"code":${err.code},"message":"${esc(err.message)}"}'
	} else {
		parts << ',"result":${resp.result.str()}'
	}
	parts << '}'
	return parts.join('')
}

fn json_resp(status_code int, body string) http.Response {
	return http.new_response(
		status: unsafe { http.Status(status_code) }
		header: http.new_header(key: .content_type, value: 'application/json')
		body: body
	)
}

fn esc(s string) string {
	return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
}

// --- Example usage ---

fn test_dispatch_unknown_method() {
	r := new_router()
	resp := r.dispatch(Request{ method: 'missing', id: json.Any(1) })
	err_obj := resp.error or {
		assert false, 'expected error'
		return
	}
	assert err_obj.code == method_not_found
}
