// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_mcp/resources.v — Resource registration and serving.
//
// Resources are read-only data sources that MCP clients can discover
// (resources/list) and fetch (resources/read). Each resource has a
// unique URI and a handler that produces the content on demand.

module v_mcp

import x.json2 as j2

// --- Resource types ---------------------------------------------------------------

// ResourceDefinition describes a resource exposed by the MCP server.
pub struct ResourceDefinition {
pub:
	// Unique URI identifying this resource (e.g. "file:///etc/hosts").
	uri string
	// Human-readable display name.
	name string
	// Human-readable description of the resource's content.
	description string
	// MIME type of the resource content (e.g. "text/plain").
	mime_type string
}

// ResourceHandler is the callback invoked when a client reads a resource.
// Receives the resource URI and returns the content or an error.
pub type ResourceHandler = fn (uri string) !ResourceContent

// ResourceContent holds the payload returned by a resource read.
pub struct ResourceContent {
pub:
	// The URI of the resource that was read.
	uri string
	// MIME type of the returned content.
	mime_type string
	// Text content (for text-based resources).
	text string
	// Base64-encoded binary content (for binary resources).
	blob string
}

// --- Registration entry -----------------------------------------------------------

// RegisteredResource pairs a ResourceDefinition with its handler function.
// Used internally by McpServer to route resources/read requests.
struct RegisteredResource {
pub:
	// The resource's metadata.
	definition ResourceDefinition
	// The function invoked when this resource is read.
	handler ?ResourceHandler
}

// --- Serialisation helpers --------------------------------------------------------

// resource_definition_to_json converts a ResourceDefinition to a j2.Any
// object suitable for a resources/list response.
pub fn resource_definition_to_json(rd ResourceDefinition) j2.Any {
	mut obj := map[string]j2.Any{}
	obj['uri'] = j2.Any(rd.uri)
	obj['name'] = j2.Any(rd.name)
	obj['description'] = j2.Any(rd.description)
	obj['mimeType'] = j2.Any(rd.mime_type)
	return j2.Any(obj)
}

// resource_content_to_json converts a ResourceContent to a j2.Any object
// for inclusion in a resources/read response.
pub fn resource_content_to_json(rc ResourceContent) j2.Any {
	mut obj := map[string]j2.Any{}
	obj['uri'] = j2.Any(rc.uri)
	obj['mimeType'] = j2.Any(rc.mime_type)
	if rc.text.len > 0 {
		obj['text'] = j2.Any(rc.text)
	}
	if rc.blob.len > 0 {
		obj['blob'] = j2.Any(rc.blob)
	}
	return j2.Any(obj)
}
