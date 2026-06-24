// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_mcp/jsonrpc.v — JSON-RPC 2.0 message framing for MCP.
//
// Provides request, response, notification, and error types with
// serialisation to/from JSON. All messages carry the mandatory
// "jsonrpc": "2.0" field.
//
// Uses V's x.json2 module for dynamic JSON manipulation via the Any
// sum type.

module v_mcp

import x.json2 as j2

// --- JSON-RPC 2.0 messages --------------------------------------------------------

// JsonRpcRequest represents an incoming JSON-RPC 2.0 request.
// The `id` field is optional (absent for notifications).
pub struct JsonRpcRequest {
pub:
	// Protocol version — always "2.0".
	jsonrpc string = '2.0'
	// Request identifier. Absent for notification messages.
	id j2.Any
	// The method name being invoked.
	method string
	// Method parameters (may be omitted).
	params j2.Any
}

// JsonRpcResponse represents an outgoing JSON-RPC 2.0 response.
// Exactly one of `result` or `error_` will be populated.
pub struct JsonRpcResponse {
pub:
	// Protocol version — always "2.0".
	jsonrpc string = '2.0'
	// Echoed request identifier.
	id j2.Any
	// Success payload (mutually exclusive with error_).
	result j2.Any
	// Error payload (mutually exclusive with result).
	error_ JsonRpcError
}

// JsonRpcError carries structured error information per JSON-RPC 2.0.
pub struct JsonRpcError {
pub:
	// Numeric error code (see ErrorCode enum for standard values).
	code int
	// Human-readable error description.
	message string
	// Optional additional error data.
	data j2.Any
}

// JsonRpcNotification represents a JSON-RPC 2.0 notification (no id, no response expected).
pub struct JsonRpcNotification {
pub:
	// Protocol version — always "2.0".
	jsonrpc string = '2.0'
	// The notification method name.
	method string
	// Notification parameters (may be omitted).
	params j2.Any
}

// --- Serialisation helpers --------------------------------------------------------

// encode_request serialises a JsonRpcRequest to a JSON string.
pub fn encode_request(req JsonRpcRequest) string {
	mut obj := map[string]j2.Any{}
	obj['jsonrpc'] = j2.Any('2.0')
	if !is_null(req.id) {
		obj['id'] = req.id
	}
	obj['method'] = j2.Any(req.method)
	if !is_null(req.params) {
		obj['params'] = req.params
	}
	return j2.Any(obj).json_str()
}

// encode_response serialises a JsonRpcResponse to a JSON string.
pub fn encode_response(resp JsonRpcResponse) string {
	mut obj := map[string]j2.Any{}
	obj['jsonrpc'] = j2.Any('2.0')
	if !is_null(resp.id) {
		obj['id'] = resp.id
	}
	if resp.error_.code != 0 {
		mut err_obj := map[string]j2.Any{}
		err_obj['code'] = j2.Any(i64(resp.error_.code))
		err_obj['message'] = j2.Any(resp.error_.message)
		if !is_null(resp.error_.data) {
			err_obj['data'] = resp.error_.data
		}
		obj['error'] = j2.Any(err_obj)
	} else {
		obj['result'] = resp.result
	}
	return j2.Any(obj).json_str()
}

// encode_notification serialises a JsonRpcNotification to a JSON string.
pub fn encode_notification(notif JsonRpcNotification) string {
	mut obj := map[string]j2.Any{}
	obj['jsonrpc'] = j2.Any('2.0')
	obj['method'] = j2.Any(notif.method)
	if !is_null(notif.params) {
		obj['params'] = notif.params
	}
	return j2.Any(obj).json_str()
}

// decode_request parses a JSON string into a JsonRpcRequest.
// Returns an error if the JSON is malformed or missing required fields.
pub fn decode_request(raw string) !JsonRpcRequest {
	parsed := j2.decode[j2.Any](raw) or {
		return error('JSON parse error: ${err}')
	}
	obj := parsed.as_map()

	version_any := obj['jsonrpc'] or { j2.Any('') }
	version := version_any.str()
	if version != '2.0' {
		return error('Expected jsonrpc "2.0", got "${version}"')
	}

	method_val := obj['method'] or { return error('Missing "method" field') }
	method := method_val.str()
	if method.len == 0 {
		return error('Empty "method" field')
	}

	return JsonRpcRequest{
		jsonrpc: '2.0'
		id: obj['id'] or { j2.Null{} }
		method: method
		params: obj['params'] or { j2.Null{} }
	}
}

// --- Error constructors -----------------------------------------------------------

// make_error_response creates a JsonRpcResponse carrying the given error code,
// message, and optional data, echoing the request id.
pub fn make_error_response(id j2.Any, code ErrorCode, message string, data j2.Any) JsonRpcResponse {
	return JsonRpcResponse{
		id: id
		error_: JsonRpcError{
			code: int(code)
			message: message
			data: data
		}
	}
}

// make_success_response creates a JsonRpcResponse with the given result payload.
pub fn make_success_response(id j2.Any, result j2.Any) JsonRpcResponse {
	return JsonRpcResponse{
		id: id
		result: result
	}
}

// --- Internal helpers -------------------------------------------------------------

// is_null checks whether a j2.Any value is the null sentinel.
fn is_null(val j2.Any) bool {
	return val is j2.Null
}
