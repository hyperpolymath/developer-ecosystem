// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_mcp/server.v — MCP server core.
//
// Provides the main McpServer struct which manages capability
// negotiation, tool/resource/prompt registration, and the
// request routing loop. The server reads JSON-RPC messages from
// the configured transport and dispatches them to registered handlers.

module v_mcp

import x.json2 as j2

// --- McpServer --------------------------------------------------------------------

// McpServer is the central MCP server. It holds registered tools,
// resources, and prompts, and runs the main message loop over the
// configured transport.
pub struct McpServer {
pub mut:
	// Human-readable server name sent during initialisation.
	name string
	// Server version string sent during initialisation.
	version string
	// Capabilities to advertise to the client.
	capabilities []Capability
	// Registered tools (name -> handler + definition).
	tools []RegisteredTool
	// Registered resources (uri -> handler + definition).
	resources []RegisteredResource
	// Registered prompts (name -> handler + definition).
	prompts []RegisteredPrompt
	// Active transport (currently only stdio is implemented).
	transport Transport
	// Whether the server has completed initialisation handshake.
	initialized bool
}

// new_server creates a new McpServer with the given name and version.
// Defaults to stdio transport. Capabilities are inferred from
// registered tools, resources, and prompts when serve() is called.
pub fn new_server(name string, version string) &McpServer {
	return &McpServer{
		name: name
		version: version
		transport: .stdio
	}
}

// add_tool registers a tool with the server. The tool will appear in
// tools/list responses and its handler will be invoked for tools/call
// requests matching the tool name.
pub fn (mut s McpServer) add_tool(definition ToolDefinition, handler ToolHandler) {
	s.tools << RegisteredTool{
		definition: definition
		handler: handler
	}
}

// add_resource registers a resource with the server. The resource will
// appear in resources/list responses and its handler will be invoked
// for resources/read requests matching the resource URI.
pub fn (mut s McpServer) add_resource(definition ResourceDefinition, handler ResourceHandler) {
	s.resources << RegisteredResource{
		definition: definition
		handler: handler
	}
}

// add_prompt registers a prompt with the server. The prompt will appear
// in prompts/list responses and its handler will be invoked for
// prompts/get requests matching the prompt name.
pub fn (mut s McpServer) add_prompt(definition PromptDefinition, handler PromptHandler) {
	s.prompts << RegisteredPrompt{
		definition: definition
		handler: handler
	}
}

// serve starts the main message loop. Reads JSON-RPC messages from the
// transport, routes them to the appropriate handler, and writes
// responses back. Runs until stdin is closed or an unrecoverable
// error occurs.
pub fn (mut s McpServer) serve() ! {
	// Infer capabilities from registrations.
	s.capabilities = s.infer_capabilities()

	log_to_stderr('MCP server "${s.name}" v${s.version} starting on stdio transport...')

	for {
		raw := read_message() or {
			log_to_stderr('Transport read error: ${err}')
			break
		}

		request := decode_request(raw) or {
			// Send parse error response (no id available).
			resp := make_error_response(j2.Null{}, .parse_error, '${err}', j2.Null{})
			write_message(encode_response(resp))
			continue
		}

		response := s.handle_request(request)
		write_message(encode_response(response))
	}
}

// --- Request routing --------------------------------------------------------------

// handle_request dispatches a parsed JSON-RPC request to the appropriate
// handler based on the method name. Returns a JsonRpcResponse.
fn (mut s McpServer) handle_request(req JsonRpcRequest) JsonRpcResponse {
	msg_type := message_type_from_method(req.method) or {
		return make_error_response(req.id, .method_not_found,
			'Unknown method: ${req.method}', j2.Null{})
	}

	return match msg_type {
		.initialize { s.handle_initialize(req) }
		.ping { s.handle_ping(req) }
		.list_tools { s.handle_list_tools(req) }
		.call_tool { s.handle_call_tool(req) }
		.list_resources { s.handle_list_resources(req) }
		.read_resource { s.handle_read_resource(req) }
		.list_prompts { s.handle_list_prompts(req) }
		.get_prompt { s.handle_get_prompt(req) }
		.initialized {
			// Notification — client acknowledges init. We mark the flag
			// and return an empty success since we must return a value.
			s.initialized = true
			make_success_response(req.id, j2.Null{})
		}
		else {
			make_error_response(req.id, .method_not_found,
				'Method not yet implemented: ${req.method}', j2.Null{})
		}
	}
}

// --- Handler implementations ------------------------------------------------------

// handle_initialize processes the initialize request. Returns the server's
// name, version, protocol version, and advertised capabilities.
fn (s McpServer) handle_initialize(req JsonRpcRequest) JsonRpcResponse {
	mut caps := map[string]j2.Any{}
	for cap in s.capabilities {
		caps[cap.capability_name()] = j2.Any(map[string]j2.Any{})
	}

	mut result := map[string]j2.Any{}
	result['protocolVersion'] = j2.Any(mcp_version)

	mut server_info := map[string]j2.Any{}
	server_info['name'] = j2.Any(s.name)
	server_info['version'] = j2.Any(s.version)
	result['serverInfo'] = j2.Any(server_info)
	result['capabilities'] = j2.Any(caps)

	return make_success_response(req.id, j2.Any(result))
}

// handle_ping responds to a keepalive ping with an empty result.
fn (s McpServer) handle_ping(req JsonRpcRequest) JsonRpcResponse {
	return make_success_response(req.id, j2.Any(map[string]j2.Any{}))
}

// handle_list_tools returns all registered tool definitions.
fn (s McpServer) handle_list_tools(req JsonRpcRequest) JsonRpcResponse {
	mut tool_list := []j2.Any{}
	for t in s.tools {
		tool_list << tool_definition_to_json(t.definition)
	}

	mut result := map[string]j2.Any{}
	result['tools'] = j2.Any(tool_list)
	return make_success_response(req.id, j2.Any(result))
}

// handle_call_tool looks up a tool by name and invokes its handler.
fn (s McpServer) handle_call_tool(req JsonRpcRequest) JsonRpcResponse {
	params := req.params.as_map()

	tool_name_val := params['name'] or {
		return make_error_response(req.id, .invalid_params,
			'Missing "name" parameter for tools/call', j2.Null{})
	}
	tool_name := tool_name_val.str()

	// Find the registered tool.
	for t in s.tools {
		if t.definition.name == tool_name {
			// Extract the arguments map.
			args_val := params['arguments'] or { j2.Any(map[string]j2.Any{}) }
			args := args_val.as_map()

			handler := t.handler or {
				return make_error_response(req.id, .internal_error,
					'Tool "${tool_name}" has no handler', j2.Null{})
			}
			result := handler(args) or {
				return make_success_response(req.id,
					tool_result_to_json(error_result('${err}')))
			}
			return make_success_response(req.id, tool_result_to_json(result))
		}
	}

	return make_error_response(req.id, .invalid_params,
		'Unknown tool: ${tool_name}', j2.Null{})
}

// handle_list_resources returns all registered resource definitions.
fn (s McpServer) handle_list_resources(req JsonRpcRequest) JsonRpcResponse {
	mut resource_list := []j2.Any{}
	for r in s.resources {
		resource_list << resource_definition_to_json(r.definition)
	}

	mut result := map[string]j2.Any{}
	result['resources'] = j2.Any(resource_list)
	return make_success_response(req.id, j2.Any(result))
}

// handle_read_resource looks up a resource by URI and invokes its handler.
fn (s McpServer) handle_read_resource(req JsonRpcRequest) JsonRpcResponse {
	params := req.params.as_map()

	uri_val := params['uri'] or {
		return make_error_response(req.id, .invalid_params,
			'Missing "uri" parameter for resources/read', j2.Null{})
	}
	uri := uri_val.str()

	for r in s.resources {
		if r.definition.uri == uri {
			handler := r.handler or {
				return make_error_response(req.id, .internal_error,
					'Resource "${uri}" has no handler', j2.Null{})
			}
			content := handler(uri) or {
				return make_error_response(req.id, .internal_error,
					'Resource handler error: ${err}', j2.Null{})
			}

			mut contents := []j2.Any{}
			contents << resource_content_to_json(content)

			mut result := map[string]j2.Any{}
			result['contents'] = j2.Any(contents)
			return make_success_response(req.id, j2.Any(result))
		}
	}

	return make_error_response(req.id, .invalid_params,
		'Unknown resource: ${uri}', j2.Null{})
}

// handle_list_prompts returns all registered prompt definitions.
fn (s McpServer) handle_list_prompts(req JsonRpcRequest) JsonRpcResponse {
	mut prompt_list := []j2.Any{}
	for p in s.prompts {
		prompt_list << prompt_definition_to_json(p.definition)
	}

	mut result := map[string]j2.Any{}
	result['prompts'] = j2.Any(prompt_list)
	return make_success_response(req.id, j2.Any(result))
}

// handle_get_prompt looks up a prompt by name and invokes its handler.
fn (s McpServer) handle_get_prompt(req JsonRpcRequest) JsonRpcResponse {
	params := req.params.as_map()

	prompt_name_val := params['name'] or {
		return make_error_response(req.id, .invalid_params,
			'Missing "name" parameter for prompts/get', j2.Null{})
	}
	prompt_name := prompt_name_val.str()

	for p in s.prompts {
		if p.definition.name == prompt_name {
			// Extract string arguments from the params.
			args_val := params['arguments'] or { j2.Any(map[string]j2.Any{}) }
			raw_args := args_val.as_map()
			mut string_args := map[string]string{}
			for k, v in raw_args {
				string_args[k] = v.str()
			}

			handler := p.handler or {
				return make_error_response(req.id, .internal_error,
					'Prompt "${prompt_name}" has no handler', j2.Null{})
			}
			result := handler(string_args) or {
				return make_error_response(req.id, .internal_error,
					'Prompt handler error: ${err}', j2.Null{})
			}
			return make_success_response(req.id, prompt_result_to_json(result))
		}
	}

	return make_error_response(req.id, .invalid_params,
		'Unknown prompt: ${prompt_name}', j2.Null{})
}

// --- Capability inference ---------------------------------------------------------

// infer_capabilities builds the capability list from what has been registered.
pub fn (s McpServer) infer_capabilities() []Capability {
	mut caps := []Capability{}
	if s.tools.len > 0 {
		caps << .tools
	}
	if s.resources.len > 0 {
		caps << .resources
	}
	if s.prompts.len > 0 {
		caps << .prompts
	}
	return caps
}
