// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@uncurried

/**
 * MCP Server infrastructure for building MCP servers.
 */

open Protocol

/** Server info */
type serverInfo = {
  name: string,
  version: string,
}

/** Server capabilities */
type capabilities = {
  tools?: bool,
  resources?: bool,
  prompts?: bool,
}

/** Tool handler function */
type toolHandler = Dict.t<JSON.t> => promise<toolResult>

/** Registered tool with handler */
type registeredTool = {
  definition: tool,
  handler: toolHandler,
}

/** MCP Server state */
type t = {
  info: serverInfo,
  capabilities: capabilities,
  tools: Dict.t<registeredTool>,
  resources: Dict.t<resource>,
  prompts: Dict.t<prompt>,
}

/** Create a new MCP server */
let make = (~name: string, ~version: string): t => {
  {
    info: {name, version},
    capabilities: {tools: true, resources: false, prompts: false},
    tools: Dict.make(),
    resources: Dict.make(),
    prompts: Dict.make(),
  }
}

/** Register a tool */
let registerTool = (server: t, definition: tool, handler: toolHandler): t => {
  server.tools->Dict.set(definition.name, {definition, handler})
  {...server, capabilities: {...server.capabilities, tools: true}}
}

/** Register a resource */
let registerResource = (server: t, resource: resource): t => {
  server.resources->Dict.set(resource.uri, resource)
  {...server, capabilities: {...server.capabilities, resources: true}}
}

/** Register a prompt */
let registerPrompt = (server: t, prompt: prompt): t => {
  server.prompts->Dict.set(prompt.name, prompt)
  {...server, capabilities: {...server.capabilities, prompts: true}}
}

/** Get list of tools */
let listTools = (server: t): array<tool> => {
  server.tools->Dict.valuesToArray->Array.map(rt => rt.definition)
}

/** Get list of resources */
let listResources = (server: t): array<resource> => {
  server.resources->Dict.valuesToArray
}

/** Get list of prompts */
let listPrompts = (server: t): array<prompt> => {
  server.prompts->Dict.valuesToArray
}

/** Call a tool by name */
let callTool = async (server: t, name: string, args: Dict.t<JSON.t>): toolResult => {
  switch server.tools->Dict.get(name) {
  | Some(registeredTool) =>
    try {
      await registeredTool.handler(args)
    } catch {
    | Exn.Error(e) =>
      let message = Exn.message(e)->Option.getOr("Unknown error")
      error(`Tool '${name}' failed: ${message}`)
    | _ => error(`Tool '${name}' failed with unknown error`)
    }
  | None => error(`Unknown tool: ${name}`)
  }
}

/** Handle MCP JSON-RPC request */
let handleRequest = async (server: t, method: string, params: option<JSON.t>): JSON.t => {
  switch method {
  | "initialize" =>
    let response = Dict.make()
    response->Dict.set("protocolVersion", JSON.Encode.string("2024-11-05"))

    let serverInfo = Dict.make()
    serverInfo->Dict.set("name", JSON.Encode.string(server.info.name))
    serverInfo->Dict.set("version", JSON.Encode.string(server.info.version))
    response->Dict.set("serverInfo", JSON.Encode.object(serverInfo))

    let caps = Dict.make()
    if server.capabilities.tools->Option.getOr(false) {
      caps->Dict.set("tools", JSON.Encode.object(Dict.make()))
    }
    if server.capabilities.resources->Option.getOr(false) {
      caps->Dict.set("resources", JSON.Encode.object(Dict.make()))
    }
    if server.capabilities.prompts->Option.getOr(false) {
      caps->Dict.set("prompts", JSON.Encode.object(Dict.make()))
    }
    response->Dict.set("capabilities", JSON.Encode.object(caps))

    JSON.Encode.object(response)

  | "tools/list" =>
    let tools = listTools(server)->Array.map(t => {
      let obj = Dict.make()
      obj->Dict.set("name", JSON.Encode.string(t.name))
      obj->Dict.set("description", JSON.Encode.string(t.description))

      let schema = Dict.make()
      schema->Dict.set("type", JSON.Encode.string(t.inputSchema.type_))
      switch t.inputSchema.properties {
      | Some(props) => schema->Dict.set("properties", JSON.Encode.object(props))
      | None => ()
      }
      switch t.inputSchema.required {
      | Some(req) => schema->Dict.set("required", JSON.Encode.array(req, JSON.Encode.string))
      | None => ()
      }
      obj->Dict.set("inputSchema", JSON.Encode.object(schema))

      JSON.Encode.object(obj)
    })

    let response = Dict.make()
    response->Dict.set("tools", JSON.Encode.array(tools, x => x))
    JSON.Encode.object(response)

  | "tools/call" =>
    let (name, args) = switch params {
    | Some(JSON.Object(p)) =>
      let n = switch p->Dict.get("name") {
      | Some(JSON.String(s)) => s
      | _ => ""
      }
      let a = switch p->Dict.get("arguments") {
      | Some(JSON.Object(o)) => o
      | _ => Dict.make()
      }
      (n, a)
    | _ => ("", Dict.make())
    }

    let result = await callTool(server, name, args)

    let response = Dict.make()
    let contentArr = result.content->Array.map(c => {
      let obj = Dict.make()
      obj->Dict.set("type", JSON.Encode.string(c.type_))
      switch c.text {
      | Some(t) => obj->Dict.set("text", JSON.Encode.string(t))
      | None => ()
      }
      switch c.data {
      | Some(d) => obj->Dict.set("data", JSON.Encode.string(d))
      | None => ()
      }
      switch c.mimeType {
      | Some(m) => obj->Dict.set("mimeType", JSON.Encode.string(m))
      | None => ()
      }
      JSON.Encode.object(obj)
    })
    response->Dict.set("content", JSON.Encode.array(contentArr, x => x))
    switch result.isError {
    | Some(true) => response->Dict.set("isError", JSON.Encode.bool(true))
    | _ => ()
    }
    JSON.Encode.object(response)

  | _ =>
    let err = Dict.make()
    err->Dict.set("error", JSON.Encode.string(`Unknown method: ${method}`))
    JSON.Encode.object(err)
  }
}
