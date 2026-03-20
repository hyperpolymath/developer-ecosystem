// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_mcp/types.v — Core protocol types for the Model Context Protocol.
//
// Maps directly to the Idris2 ABI at proven-servers/protocols/proven-mcp.
// All enums are exhaustive and match the ABI's closed sum types exactly.

module v_mcp

// --- Protocol constants -----------------------------------------------------------

// mcp_version is the MCP protocol version this implementation conforms to.
pub const mcp_version = '2025-03-26'

// max_content_size is the maximum payload size in bytes (10 MiB).
pub const max_content_size = 10_485_760

// default_timeout_seconds is the default request timeout in seconds.
pub const default_timeout_seconds = 30

// --- MessageType ------------------------------------------------------------------

// MessageType enumerates every JSON-RPC method defined by the MCP specification.
// Covers the full lifecycle: initialisation, keepalive, tool/resource/prompt
// operations, subscriptions, notifications, and cancellation.
pub enum MessageType {
	// Client sends capabilities and protocol version.
	initialize
	// Server acknowledges initialisation.
	initialized
	// Keepalive ping.
	ping
	// Client requests execution of a named tool.
	call_tool
	// Server returns the result of a tool call.
	tool_result
	// Client requests the list of available tools.
	list_tools
	// Client requests the list of available resources.
	list_resources
	// Client requests the contents of a specific resource.
	read_resource
	// Client requests the list of available prompts.
	list_prompts
	// Client requests a specific prompt template.
	get_prompt
	// Client subscribes to resource change notifications.
	subscribe
	// Client unsubscribes from resource change notifications.
	unsubscribe
	// Server sends an asynchronous notification.
	notification
	// Client cancels a pending request.
	cancel
}

// method_name returns the MCP JSON-RPC method string for a MessageType.
// These strings appear on the wire in the "method" field of JSON-RPC messages.
pub fn (mt MessageType) method_name() string {
	return match mt {
		.initialize { 'initialize' }
		.initialized { 'notifications/initialized' }
		.ping { 'ping' }
		.call_tool { 'tools/call' }
		.tool_result { 'tools/result' }
		.list_tools { 'tools/list' }
		.list_resources { 'resources/list' }
		.read_resource { 'resources/read' }
		.list_prompts { 'prompts/list' }
		.get_prompt { 'prompts/get' }
		.subscribe { 'resources/subscribe' }
		.unsubscribe { 'resources/unsubscribe' }
		.notification { 'notifications/message' }
		.cancel { '$/cancelRequest' }
	}
}

// message_type_from_method resolves a wire method string to a MessageType.
// Returns none if the method is not recognised.
pub fn message_type_from_method(method string) ?MessageType {
	return match method {
		'initialize' { MessageType.initialize }
		'notifications/initialized' { MessageType.initialized }
		'ping' { MessageType.ping }
		'tools/call' { MessageType.call_tool }
		'tools/result' { MessageType.tool_result }
		'tools/list' { MessageType.list_tools }
		'resources/list' { MessageType.list_resources }
		'resources/read' { MessageType.read_resource }
		'prompts/list' { MessageType.list_prompts }
		'prompts/get' { MessageType.get_prompt }
		'resources/subscribe' { MessageType.subscribe }
		'resources/unsubscribe' { MessageType.unsubscribe }
		'notifications/message' { MessageType.notification }
		'$/cancelRequest' { MessageType.cancel }
		else { none }
	}
}

// --- Transport --------------------------------------------------------------------

// Transport enumerates the transport layers over which MCP messages may be
// carried. Stdio is the original and most widely supported; SSE, WebSocket,
// and StreamableHTTP target browser/network scenarios.
pub enum Transport {
	// Standard input/output — the original MCP transport.
	stdio
	// Server-Sent Events over HTTP.
	sse
	// Full-duplex WebSocket connection.
	websocket
	// Streamable HTTP (newest MCP transport).
	streamable_http
}

// --- ContentType ------------------------------------------------------------------

// ContentType describes the kind of content carried in an MCP tool result
// or resource response.
pub enum ContentType {
	// Plain or structured text content.
	text
	// Image content (base64-encoded or URI).
	image
	// A reference to an MCP resource.
	resource
	// A dense vector embedding.
	embedding
}

// type_name returns the MCP wire name for a ContentType.
pub fn (ct ContentType) type_name() string {
	return match ct {
		.text { 'text' }
		.image { 'image' }
		.resource { 'resource' }
		.embedding { 'embedding' }
	}
}

// --- ErrorCode --------------------------------------------------------------------

// ErrorCode defines the standard JSON-RPC error codes used in MCP error
// responses. Numeric values follow the JSON-RPC 2.0 specification and
// MCP extensions.
pub enum ErrorCode {
	// The request could not be parsed as valid JSON (-32700).
	parse_error      = -32700
	// The request is valid JSON but semantically invalid (-32600).
	invalid_request  = -32600
	// The requested method does not exist (-32601).
	method_not_found = -32601
	// The method parameters are invalid (-32602).
	invalid_params   = -32602
	// An internal server error occurred (-32603).
	internal_error   = -32603
	// The request timed out (-32000, MCP extension).
	timeout          = -32000
}

// --- Capability -------------------------------------------------------------------

// Capability enumerates the server capabilities that may be advertised during
// the MCP initialisation handshake.
pub enum Capability {
	// Server provides callable tools.
	tools
	// Server provides readable resources.
	resources
	// Server provides prompt templates.
	prompts
	// Server supports structured logging.
	logging
	// Server supports LLM sampling requests.
	sampling
}

// capability_name returns the MCP wire name for a Capability.
pub fn (c Capability) capability_name() string {
	return match c {
		.tools { 'tools' }
		.resources { 'resources' }
		.prompts { 'prompts' }
		.logging { 'logging' }
		.sampling { 'sampling' }
	}
}
