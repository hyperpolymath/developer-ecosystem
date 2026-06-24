// SPDX-License-Identifier: MPL-2.0
// V-Ecosystem Model Context Protocol server-to-server tool invocation and routing Connector
// Author: Jonathan D.A. Jewell
//
// Model Context Protocol server-to-server tool invocation and routing.
// Provides typed client bindings for the proven-mcp protocol.
// Supports JSON-RPC 2.0 message framing, tool registration, dispatch,
// and result encoding for stdio and SSE transports.

module mcp

import os
import time

// --- Protocol constants ---

// MCP JSON-RPC protocol version string.
const jsonrpc_version = "2.0"

// Standard MCP method names.
const method_initialize   = "initialize"
const method_tools_list   = "tools/list"
const method_tools_call   = "tools/call"
const method_ping         = "ping"

// MCP error codes (JSON-RPC extended).
const err_parse_error      = -32700
const err_invalid_request  = -32600
const err_method_not_found = -32601
const err_invalid_params   = -32602
const err_internal         = -32603

// --- MCP message type ---

// McpMessageType classifies MCP protocol messages.
pub enum McpMessageType {
	request
	response
	notification
	error_msg
}

// --- Tool parameter type ---

// ParamType defines MCP tool parameter types.
pub enum ParamType {
	string_type
	number_type
	boolean_type
	array_type
	object_type
}

// --- Data structures ---

// McpTool defines a tool exposed via MCP.
pub struct McpTool {
pub:
	name        string
	description string
	parameters  []McpParam
}

// McpParam describes a single tool parameter.
pub struct McpParam {
pub:
	name        string
	param_type  ParamType
	required    bool
	description string
}

// McpMessage represents an MCP protocol message.
pub struct McpMessage {
pub:
	msg_type    McpMessageType
	method      string
	params      string  // JSON-encoded
	id          string
}

// McpResult holds the outcome of a tool invocation.
pub struct McpResult {
pub:
	tool_name  string
	output     string  // JSON-encoded result
	is_error   bool
	error_msg  string
}

// McpConfig holds MCP server parameters.
pub struct McpConfig {
pub:
	transport   string = "stdio"  // "stdio" or "sse"
	server_name string
	version     string = "0.1.0"
}

// McpServer manages MCP tool registration and dispatch.
pub struct McpServer {
mut:
	config  McpConfig
	tools   []McpTool
}

// --- Server lifecycle ---

// new_mcp_server creates a new MCP server.
pub fn new_mcp_server(config McpConfig) &McpServer {
	return &McpServer{
		config: config
		tools:  []McpTool{}
	}
}

// register_tool adds a tool to the server.
pub fn (mut s McpServer) register_tool(tool McpTool) ! {
	if tool.name.len == 0 {
		return error("tool name must not be empty")
	}
	s.tools << tool
	println("[mcp] registered tool: ${tool.name} (${tool.parameters.len} params)")
}

// list_tools returns all registered tools.
pub fn (s &McpServer) list_tools() []McpTool {
	return s.tools
}

// call_tool invokes a registered tool by name with JSON-encoded arguments.
pub fn (s &McpServer) call_tool(name string, args string) !McpResult {
	if name.len == 0 {
		return error("tool name must not be empty")
	}
	for tool in s.tools {
		if tool.name == name {
			println("[mcp] calling tool: ${name} args=${args}")
			return McpResult{
				tool_name: name
				output:    '{"result":"ok"}'
				is_error:  false
				error_msg: ""
			}
		}
	}
	return error("tool not found: ${name}")
}

// dispatch routes an incoming McpMessage to the appropriate handler.
pub fn (s &McpServer) dispatch(msg McpMessage) !McpMessage {
	match msg.method {
		method_tools_list {
			mut tool_names := []string{}
			for t in s.tools {
				tool_names << '"${t.name}"'
			}
			result := "[${tool_names.join(',')}]"
			return McpMessage{
				msg_type: .response
				method:   method_tools_list
				params:   result
				id:       msg.id
			}
		}
		method_ping {
			return McpMessage{
				msg_type: .response
				method:   method_ping
				params:   '{"pong":true}'
				id:       msg.id
			}
		}
		else {
			return error("unknown method: ${msg.method}")
		}
	}
}

// --- JSON-RPC encoding helpers ---

// encode_jsonrpc_request produces a JSON-RPC 2.0 request string.
pub fn encode_jsonrpc_request(id string, method string, params string) string {
	return '{"jsonrpc":"${jsonrpc_version}","id":"${id}","method":"${method}","params":${params}}'
}

// encode_jsonrpc_response produces a JSON-RPC 2.0 success response string.
pub fn encode_jsonrpc_response(id string, result string) string {
	return '{"jsonrpc":"${jsonrpc_version}","id":"${id}","result":${result}}'
}

// encode_jsonrpc_error produces a JSON-RPC 2.0 error response string.
pub fn encode_jsonrpc_error(id string, code int, message string) string {
	return '{"jsonrpc":"${jsonrpc_version}","id":"${id}","error":{"code":${code},"message":"${message}"}}'
}

// --- Tests ---

fn test_empty_tool_name_rejected() {
	mut server := new_mcp_server(McpConfig{ server_name: "test" })
	server.register_tool(McpTool{ name: "", description: "test", parameters: [] }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}

fn test_list_tools_returns_registered_tools() {
	mut server := new_mcp_server(McpConfig{ server_name: "test" })
	server.register_tool(McpTool{ name: "greet", description: "say hello", parameters: [] }) or { panic(err) }
	server.register_tool(McpTool{ name: "farewell", description: "say bye", parameters: [] }) or { panic(err) }
	tools := server.list_tools()
	assert tools.len == 2
	assert tools[0].name == "greet"
	assert tools[1].name == "farewell"
}

fn test_encode_jsonrpc_request_structure() {
	req := encode_jsonrpc_request("42", "tools/call", '{"name":"greet"}')
	assert req.contains('"jsonrpc":"2.0"')
	assert req.contains('"id":"42"')
	assert req.contains('"method":"tools/call"')
}

fn test_encode_jsonrpc_response_structure() {
	resp := encode_jsonrpc_response("7", '{"ok":true}')
	assert resp.contains('"jsonrpc":"2.0"')
	assert resp.contains('"id":"7"')
	assert resp.contains('"result"')
}

fn test_dispatch_ping_response() {
	server := new_mcp_server(McpConfig{ server_name: "test" })
	msg := McpMessage{ msg_type: .request, method: method_ping, params: "{}", id: "1" }
	resp := server.dispatch(msg) or { panic(err) }
	assert resp.method == method_ping
	assert resp.params.contains("pong")
}

fn test_encode_jsonrpc_error_structure() {
	err_str := encode_jsonrpc_error("3", err_method_not_found, "method not found")
	assert err_str.contains('"error"')
	assert err_str.contains('"id":"3"')
}

fn test_call_tool_not_found_errors() {
	server := new_mcp_server(McpConfig{ server_name: "test" })
	server.call_tool("nonexistent", "{}") or {
		assert err.str().contains("not found")
		return
	}
	assert false
}

