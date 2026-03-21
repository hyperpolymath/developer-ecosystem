// SPDX-License-Identifier: PMPL-1.0-or-later
// V-Ecosystem Model Context Protocol server-to-server tool invocation and routing Connector
// Author: Jonathan D.A. Jewell
//
// Model Context Protocol server-to-server tool invocation and routing.
// Provides typed client bindings for the proven-mcp protocol.

module mcp

import os
import time
import net

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

// --- Tests ---

fn test_empty_tool_name_rejected() {
	mut server := new_mcp_server(McpConfig{ server_name: "test" })
	server.register_tool(McpTool{ name: "", description: "test", parameters: [] }) or {
		assert err.str().contains("must not be empty")
		return
	}
	assert false
}
