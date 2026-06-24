// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// v_mcp/prompts.v — Prompt template registration and retrieval.
//
// Prompts allow MCP servers to expose reusable prompt templates that
// clients can discover (prompts/list) and instantiate (prompts/get)
// with named arguments.

module v_mcp

import x.json2 as j2

// --- Prompt types -----------------------------------------------------------------

// PromptDefinition describes a prompt template exposed by the server.
pub struct PromptDefinition {
pub:
	// Machine-readable prompt name (must be unique per server).
	name string
	// Human-readable description of what the prompt generates.
	description string
	// Declared arguments that the prompt template accepts.
	arguments []PromptArgument
}

// PromptArgument declares a single argument accepted by a prompt template.
pub struct PromptArgument {
pub:
	// Argument name (used as the key in the args map).
	name string
	// Human-readable description of the argument.
	description string
	// Whether this argument must be supplied by the client.
	required bool
}

// PromptHandler is the callback invoked when a client requests a prompt.
// Receives named string arguments and returns a PromptResult or an error.
pub type PromptHandler = fn (args map[string]string) !PromptResult

// PromptResult holds the rendered prompt returned to the client.
pub struct PromptResult {
pub:
	// Description of the rendered prompt.
	description string
	// The conversation messages that form the prompt.
	messages []PromptMessage
}

// PromptMessage is a single message in a rendered prompt conversation.
pub struct PromptMessage {
pub:
	// Message role — "user" or "assistant".
	role string
	// Message content.
	content Content
}

// --- Registration entry -----------------------------------------------------------

// RegisteredPrompt pairs a PromptDefinition with its handler function.
// Used internally by McpServer to route prompts/get requests.
struct RegisteredPrompt {
pub:
	// The prompt's metadata and argument declarations.
	definition PromptDefinition
	// The function invoked when this prompt is requested.
	handler ?PromptHandler
}

// --- Serialisation helpers --------------------------------------------------------

// prompt_definition_to_json converts a PromptDefinition to a j2.Any
// object suitable for a prompts/list response.
pub fn prompt_definition_to_json(pd PromptDefinition) j2.Any {
	mut obj := map[string]j2.Any{}
	obj['name'] = j2.Any(pd.name)
	obj['description'] = j2.Any(pd.description)

	mut args := []j2.Any{}
	for arg in pd.arguments {
		mut arg_obj := map[string]j2.Any{}
		arg_obj['name'] = j2.Any(arg.name)
		arg_obj['description'] = j2.Any(arg.description)
		arg_obj['required'] = j2.Any(arg.required)
		args << j2.Any(arg_obj)
	}
	obj['arguments'] = j2.Any(args)
	return j2.Any(obj)
}

// prompt_result_to_json converts a PromptResult to a j2.Any object
// for use as the result of a prompts/get response.
pub fn prompt_result_to_json(pr PromptResult) j2.Any {
	mut obj := map[string]j2.Any{}
	obj['description'] = j2.Any(pr.description)

	mut msgs := []j2.Any{}
	for msg in pr.messages {
		mut msg_obj := map[string]j2.Any{}
		msg_obj['role'] = j2.Any(msg.role)
		msg_obj['content'] = content_to_json(msg.content)
		msgs << j2.Any(msg_obj)
	}
	obj['messages'] = j2.Any(msgs)
	return j2.Any(obj)
}
