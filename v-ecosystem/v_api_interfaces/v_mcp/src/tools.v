// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_mcp/tools.v — Tool registration, dispatch, and result types.
//
// Tools are the primary extension point of an MCP server. Each tool
// has a name, description, JSON Schema for its inputs, and a handler
// function that produces a ToolResult.

module v_mcp

import x.json2 as j2

// --- Tool types -------------------------------------------------------------------

// ToolDefinition describes a tool that the server exposes to MCP clients.
// The input_schema follows JSON Schema and is sent during tools/list.
pub struct ToolDefinition {
pub:
	// Machine-readable tool name (must be unique per server).
	name string
	// Human-readable description of what the tool does.
	description string
	// JSON Schema describing the tool's expected parameters.
	input_schema map[string]j2.Any
}

// ToolHandler is the callback signature for tool execution.
// Receives the parsed params map and returns a ToolResult or an error.
pub type ToolHandler = fn (params map[string]j2.Any) !ToolResult

// ToolResult holds the output of a tool invocation.
pub struct ToolResult {
pub:
	// Content items returned by the tool.
	content []Content
	// Whether the tool invocation resulted in an error.
	is_error bool
}

// Content represents a single content item in a tool result or resource.
pub struct Content {
pub:
	// The kind of content (text, image, resource, embedding).
	content_type ContentType
	// Text payload (used when content_type is .text).
	text string
	// Base64-encoded binary data (used when content_type is .image).
	data string
	// MIME type of the content (e.g. "text/plain", "image/png").
	mime_type string
	// Resource URI (used when content_type is .resource).
	uri string
}

// --- Registration entry -----------------------------------------------------------

// RegisteredTool pairs a ToolDefinition with its handler function.
// Used internally by McpServer to route tool/call requests.
struct RegisteredTool {
pub:
	// The tool's metadata and schema.
	definition ToolDefinition
	// The function invoked when this tool is called.
	handler ?ToolHandler
}

// --- Serialisation helpers --------------------------------------------------------

// tool_definition_to_json converts a ToolDefinition to a j2.Any object
// suitable for inclusion in a tools/list response.
pub fn tool_definition_to_json(td ToolDefinition) j2.Any {
	mut obj := map[string]j2.Any{}
	obj['name'] = j2.Any(td.name)
	obj['description'] = j2.Any(td.description)
	obj['inputSchema'] = j2.Any(td.input_schema.clone())
	return j2.Any(obj)
}

// content_to_json converts a Content value to a j2.Any object
// for inclusion in a tool result or resource response.
pub fn content_to_json(c Content) j2.Any {
	mut obj := map[string]j2.Any{}
	obj['type'] = j2.Any(c.content_type.type_name())
	match c.content_type {
		.text {
			obj['text'] = j2.Any(c.text)
		}
		.image {
			obj['data'] = j2.Any(c.data)
			if c.mime_type.len > 0 {
				obj['mimeType'] = j2.Any(c.mime_type)
			}
		}
		.resource {
			mut res := map[string]j2.Any{}
			res['uri'] = j2.Any(c.uri)
			if c.text.len > 0 {
				res['text'] = j2.Any(c.text)
			}
			if c.mime_type.len > 0 {
				res['mimeType'] = j2.Any(c.mime_type)
			}
			obj['resource'] = j2.Any(res)
		}
		.embedding {
			obj['data'] = j2.Any(c.data)
		}
	}
	return j2.Any(obj)
}

// tool_result_to_json converts a ToolResult to a j2.Any object
// for use as the result field of a JSON-RPC response.
pub fn tool_result_to_json(tr ToolResult) j2.Any {
	mut obj := map[string]j2.Any{}
	mut items := []j2.Any{}
	for c in tr.content {
		items << content_to_json(c)
	}
	obj['content'] = j2.Any(items)
	obj['isError'] = j2.Any(tr.is_error)
	return j2.Any(obj)
}

// --- Convenience constructors -----------------------------------------------------

// text_content creates a Content with text payload.
pub fn text_content(text string) Content {
	return Content{
		content_type: .text
		text: text
	}
}

// image_content creates a Content with base64 image data and MIME type.
pub fn image_content(base64_data string, mime string) Content {
	return Content{
		content_type: .image
		data: base64_data
		mime_type: mime
	}
}

// text_result creates a non-error ToolResult containing a single text item.
pub fn text_result(text string) ToolResult {
	return ToolResult{
		content: [text_content(text)]
	}
}

// error_result creates an error ToolResult containing a single text message.
pub fn error_result(message string) ToolResult {
	return ToolResult{
		content: [text_content(message)]
		is_error: true
	}
}
