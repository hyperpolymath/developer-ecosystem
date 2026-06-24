// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_mcp/tests/mcp_test.v — Protocol conformance tests for v_mcp.
//
// Validates that protocol types, JSON-RPC serialisation, tool registration,
// capability advertisement, and error code mapping all behave correctly
// per the MCP specification and the proven-mcp Idris2 ABI.

import v_mcp
import x.json2 as j2

// --- MessageType exhaustiveness ---------------------------------------------------

// test_message_type_method_names verifies that every MessageType variant
// maps to a non-empty wire method name.
fn test_message_type_method_names() {
	variants := [
		v_mcp.MessageType.initialize,
		v_mcp.MessageType.initialized,
		v_mcp.MessageType.ping,
		v_mcp.MessageType.call_tool,
		v_mcp.MessageType.tool_result,
		v_mcp.MessageType.list_tools,
		v_mcp.MessageType.list_resources,
		v_mcp.MessageType.read_resource,
		v_mcp.MessageType.list_prompts,
		v_mcp.MessageType.get_prompt,
		v_mcp.MessageType.subscribe,
		v_mcp.MessageType.unsubscribe,
		v_mcp.MessageType.notification,
		v_mcp.MessageType.cancel,
	]

	// All 14 MessageType variants must be present (matches Idris2 ABI).
	assert variants.len == 14, 'Expected 14 MessageType variants, got ${variants.len}'

	for variant in variants {
		name := variant.method_name()
		assert name.len > 0, 'MessageType variant has empty method name'
	}
}

// test_message_type_roundtrip verifies that method name -> MessageType
// lookup is the inverse of MessageType -> method name.
fn test_message_type_roundtrip() {
	variants := [
		v_mcp.MessageType.initialize,
		v_mcp.MessageType.initialized,
		v_mcp.MessageType.ping,
		v_mcp.MessageType.call_tool,
		v_mcp.MessageType.tool_result,
		v_mcp.MessageType.list_tools,
		v_mcp.MessageType.list_resources,
		v_mcp.MessageType.read_resource,
		v_mcp.MessageType.list_prompts,
		v_mcp.MessageType.get_prompt,
		v_mcp.MessageType.subscribe,
		v_mcp.MessageType.unsubscribe,
		v_mcp.MessageType.notification,
		v_mcp.MessageType.cancel,
	]

	for variant in variants {
		name := variant.method_name()
		recovered := v_mcp.message_type_from_method(name) or {
			assert false, 'Failed to recover MessageType from method "${name}"'
			return
		}
		assert recovered == variant, 'Roundtrip failed for ${name}'
	}
}

// test_unknown_method_returns_none verifies that an unrecognised method
// string returns none.
fn test_unknown_method_returns_none() {
	if _ := v_mcp.message_type_from_method('bogus/method') {
		assert false, 'Expected none for unknown method'
	}
}

// --- JSON-RPC serialisation roundtrip ---------------------------------------------

// test_jsonrpc_request_encode_decode verifies that encoding a request
// to JSON and decoding it back produces the same values.
fn test_jsonrpc_request_encode_decode() {
	mut params := map[string]j2.Any{}
	params['key'] = j2.Any('value')

	original := v_mcp.JsonRpcRequest{
		id: j2.Any('req-1')
		method: 'tools/list'
		params: j2.Any(params)
	}

	encoded := v_mcp.encode_request(original)
	assert encoded.contains('"jsonrpc"')
	assert encoded.contains('"2.0"')
	assert encoded.contains('"tools/list"')

	decoded := v_mcp.decode_request(encoded) or {
		assert false, 'Failed to decode request: ${err}'
		return
	}

	assert decoded.method == 'tools/list'
	assert decoded.id.str() == 'req-1'
}

// test_jsonrpc_response_encode_success verifies that a success response
// serialises correctly with a result field and no error field.
fn test_jsonrpc_response_encode_success() {
	mut result := map[string]j2.Any{}
	result['status'] = j2.Any('ok')

	resp := v_mcp.make_success_response(j2.Any('id-42'), j2.Any(result))
	encoded := v_mcp.encode_response(resp)

	assert encoded.contains('"result"')
	assert !encoded.contains('"error"')
	assert encoded.contains('"id-42"')
}

// test_jsonrpc_response_encode_error verifies that an error response
// serialises correctly with an error field and no result field.
fn test_jsonrpc_response_encode_error() {
	resp := v_mcp.make_error_response(j2.Any('id-99'), .method_not_found,
		'No such method', j2.Null{})
	encoded := v_mcp.encode_response(resp)

	assert encoded.contains('"error"')
	assert encoded.contains('-32601')
	assert encoded.contains('No such method')
}

// test_jsonrpc_decode_rejects_bad_version verifies that a message with
// the wrong jsonrpc version is rejected.
fn test_jsonrpc_decode_rejects_bad_version() {
	bad := '{"jsonrpc":"1.0","method":"ping","id":"x"}'
	if _ := v_mcp.decode_request(bad) {
		assert false, 'Expected error for bad jsonrpc version'
	}
}

// test_jsonrpc_decode_rejects_missing_method verifies that a message
// without a method field is rejected.
fn test_jsonrpc_decode_rejects_missing_method() {
	bad := '{"jsonrpc":"2.0","id":"x"}'
	if _ := v_mcp.decode_request(bad) {
		assert false, 'Expected error for missing method'
	}
}

// --- Tool registration and lookup -------------------------------------------------

// test_tool_registration verifies that tools can be added to a server
// and appear in the tools list.
fn test_tool_registration() {
	mut server := v_mcp.new_server('test-server', '0.1.0')

	mut schema := map[string]j2.Any{}
	schema['type'] = j2.Any('object')

	server.add_tool(
		v_mcp.ToolDefinition{
			name: 'echo'
			description: 'Echoes input back'
			input_schema: schema
		},
		fn (params map[string]j2.Any) !v_mcp.ToolResult {
			msg := (params['message'] or { j2.Any('') }).str()
			return v_mcp.text_result(msg)
		},
	)

	assert server.tools.len == 1
	assert server.tools[0].definition.name == 'echo'
	assert server.tools[0].definition.description == 'Echoes input back'
}

// test_tool_definition_json verifies JSON serialisation of tool definitions.
fn test_tool_definition_json() {
	mut schema := map[string]j2.Any{}
	schema['type'] = j2.Any('object')

	td := v_mcp.ToolDefinition{
		name: 'calculator'
		description: 'Does maths'
		input_schema: schema
	}

	j := v_mcp.tool_definition_to_json(td)
	s := j.json_str()
	assert s.contains('"calculator"')
	assert s.contains('"Does maths"')
	assert s.contains('"inputSchema"')
}

// --- Capability advertisement -----------------------------------------------------

// test_capability_inference verifies that capabilities are correctly
// inferred from registered tools, resources, and prompts.
fn test_capability_inference() {
	mut server := v_mcp.new_server('cap-test', '1.0.0')

	mut schema := map[string]j2.Any{}
	server.add_tool(
		v_mcp.ToolDefinition{ name: 't', description: 'd', input_schema: schema },
		fn (p map[string]j2.Any) !v_mcp.ToolResult {
			return v_mcp.text_result('')
		},
	)

	server.add_resource(
		v_mcp.ResourceDefinition{
			uri: 'test://r'
			name: 'r'
			description: 'd'
			mime_type: 'text/plain'
		},
		fn (uri string) !v_mcp.ResourceContent {
			return v_mcp.ResourceContent{ uri: uri, mime_type: 'text/plain', text: '' }
		},
	)

	// Trigger capability inference (normally done in serve()).
	server.capabilities = server.infer_capabilities()

	assert v_mcp.Capability.tools in server.capabilities
	assert v_mcp.Capability.resources in server.capabilities
	assert v_mcp.Capability.prompts !in server.capabilities
}

// --- Error code mapping -----------------------------------------------------------

// test_error_codes verifies that ErrorCode enum values match the JSON-RPC
// 2.0 specification numeric codes.
fn test_error_codes() {
	assert int(v_mcp.ErrorCode.parse_error) == -32700
	assert int(v_mcp.ErrorCode.invalid_request) == -32600
	assert int(v_mcp.ErrorCode.method_not_found) == -32601
	assert int(v_mcp.ErrorCode.invalid_params) == -32602
	assert int(v_mcp.ErrorCode.internal_error) == -32603
	assert int(v_mcp.ErrorCode.timeout) == -32000
}

// --- Content helpers --------------------------------------------------------------

// test_text_content creates text content and verifies fields.
fn test_text_content() {
	c := v_mcp.text_content('hello world')
	assert c.content_type == .text
	assert c.text == 'hello world'
}

// test_text_result creates a text result and verifies structure.
fn test_text_result() {
	r := v_mcp.text_result('output')
	assert r.content.len == 1
	assert r.content[0].text == 'output'
	assert r.is_error == false
}

// test_error_result creates an error result and verifies the flag.
fn test_error_result() {
	r := v_mcp.error_result('something broke')
	assert r.content.len == 1
	assert r.content[0].text == 'something broke'
	assert r.is_error == true
}

// --- Protocol constants -----------------------------------------------------------

// test_protocol_constants verifies that protocol constants match the
// proven-mcp Idris2 ABI values.
fn test_protocol_constants() {
	assert v_mcp.mcp_version == '2025-03-26'
	assert v_mcp.max_content_size == 10_485_760
	assert v_mcp.default_timeout_seconds == 30
}

// --- Content serialisation --------------------------------------------------------

// test_content_to_json_text verifies JSON output for text content.
fn test_content_to_json_text() {
	c := v_mcp.text_content('test output')
	j := v_mcp.content_to_json(c)
	s := j.json_str()
	assert s.contains('"text"')
	assert s.contains('"test output"')
}

// test_tool_result_to_json verifies JSON output for a tool result.
fn test_tool_result_to_json() {
	r := v_mcp.text_result('result data')
	j := v_mcp.tool_result_to_json(r)
	s := j.json_str()
	assert s.contains('"content"')
	assert s.contains('"isError"')
	assert s.contains('"result data"')
}
