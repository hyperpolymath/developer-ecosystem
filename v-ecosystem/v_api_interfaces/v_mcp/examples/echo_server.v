// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// examples/echo_server.v — Minimal MCP echo tool server.
//
// Demonstrates the full v_mcp server lifecycle:
//   1. Create a server with name and version.
//   2. Register a tool ("echo") with a JSON Schema and handler.
//   3. Register a resource ("echo://info") for discovery.
//   4. Start serving on stdio transport.
//
// Run:
//   v run examples/echo_server.v
//
// Then send Content-Length-framed JSON-RPC messages on stdin, e.g.:
//
//   Content-Length: 95\r\n
//   \r\n
//   {"jsonrpc":"2.0","id":"1","method":"initialize","params":{"protocolVersion":"2025-03-26"}}
//
//   Content-Length: 53\r\n
//   \r\n
//   {"jsonrpc":"2.0","id":"2","method":"tools/list"}
//
//   Content-Length: 108\r\n
//   \r\n
//   {"jsonrpc":"2.0","id":"3","method":"tools/call","params":{"name":"echo","arguments":{"message":"Hello!"}}}

module main

import v_mcp
import x.json2 as j2

fn main() {
	mut server := v_mcp.new_server('echo-server', '0.1.0')

	// --- Register the "echo" tool ------------------------------------------------

	// Build the JSON Schema for the echo tool's input.
	mut msg_prop := map[string]j2.Any{}
	msg_prop['type'] = j2.Any('string')
	msg_prop['description'] = j2.Any('The message to echo back')

	mut properties := map[string]j2.Any{}
	properties['message'] = j2.Any(msg_prop)

	mut schema := map[string]j2.Any{}
	schema['type'] = j2.Any('object')
	schema['properties'] = j2.Any(properties)
	schema['required'] = j2.Any([j2.Any('message')])

	server.add_tool(
		v_mcp.ToolDefinition{
			name: 'echo'
			description: 'Echoes the provided message back to the caller. Useful for testing MCP connectivity.'
			input_schema: schema
		},
		echo_handler,
	)

	// --- Register an informational resource --------------------------------------

	server.add_resource(
		v_mcp.ResourceDefinition{
			uri: 'echo://info'
			name: 'Echo Server Info'
			description: 'Returns information about this echo server.'
			mime_type: 'text/plain'
		},
		info_handler,
	)

	// --- Start serving -----------------------------------------------------------

	server.serve() or {
		v_mcp.log_to_stderr('Server error: ${err}')
	}
}

// echo_handler extracts the "message" param and returns it as text content.
fn echo_handler(params map[string]j2.Any) !v_mcp.ToolResult {
	msg_val := params['message'] or {
		return v_mcp.error_result('Missing required parameter: "message"')
	}
	message := msg_val.str()
	if message.len == 0 {
		return v_mcp.error_result('Parameter "message" must not be empty')
	}
	return v_mcp.text_result('Echo: ${message}')
}

// info_handler returns a plain text description of the server.
fn info_handler(uri string) !v_mcp.ResourceContent {
	return v_mcp.ResourceContent{
		uri: uri
		mime_type: 'text/plain'
		text: 'Echo MCP Server v0.1.0 — a minimal Model Context Protocol server written in V.\nProtocol version: ${v_mcp.mcp_version}'
	}
}
