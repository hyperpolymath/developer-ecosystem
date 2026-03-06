// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@uncurried

/**
 * MCP (Model Context Protocol) types and utilities.
 * Provides common infrastructure for building MCP servers.
 */

/** Content types for tool results */
type contentType =
  | Text
  | Image
  | Resource

/** A single content item in a tool result */
type content = {
  @as("type") type_: string,
  text?: string,
  data?: string,
  mimeType?: string,
}

/** Result of a tool invocation */
type toolResult = {
  content: array<content>,
  isError?: bool,
}

/** Tool input schema (JSON Schema) */
type inputSchema = {
  @as("type") type_: string,
  properties?: Dict.t<JSON.t>,
  required?: array<string>,
}

/** A tool definition */
type tool = {
  name: string,
  description: string,
  inputSchema: inputSchema,
}

/** Resource definition */
type resource = {
  uri: string,
  name: string,
  description?: string,
  mimeType?: string,
}

/** Prompt argument */
type promptArgument = {
  name: string,
  description?: string,
  required?: bool,
}

/** Prompt definition */
type prompt = {
  name: string,
  description?: string,
  arguments?: array<promptArgument>,
}

// Result builders

/** Create a successful text result */
let success = (text: string): toolResult => {
  {content: [{type_: "text", text}]}
}

/** Create a successful JSON result */
let successJson = (data: JSON.t): toolResult => {
  {content: [{type_: "text", text: JSON.stringify(data)}]}
}

/** Create an error result */
let error = (message: string): toolResult => {
  {content: [{type_: "text", text: message}], isError: true}
}

/** Create a multi-content result */
let multi = (items: array<content>): toolResult => {
  {content: items}
}

/** Create a text content item */
let text = (value: string): content => {
  {type_: "text", text: value}
}

/** Create an image content item */
let image = (base64Data: string, mimeType: string): content => {
  {type_: "image", data: base64Data, mimeType}
}

// Schema builders

/** Create an object schema */
let objectSchema = (
  ~properties: Dict.t<JSON.t>,
  ~required: array<string>=[],
): inputSchema => {
  {
    type_: "object",
    properties,
    required,
  }
}

/** Create a string property schema */
let stringProp = (~description: string=""): JSON.t => {
  let obj = Dict.make()
  obj->Dict.set("type", JSON.Encode.string("string"))
  if description != "" {
    obj->Dict.set("description", JSON.Encode.string(description))
  }
  JSON.Encode.object(obj)
}

/** Create a number property schema */
let numberProp = (~description: string=""): JSON.t => {
  let obj = Dict.make()
  obj->Dict.set("type", JSON.Encode.string("number"))
  if description != "" {
    obj->Dict.set("description", JSON.Encode.string(description))
  }
  JSON.Encode.object(obj)
}

/** Create a boolean property schema */
let boolProp = (~description: string=""): JSON.t => {
  let obj = Dict.make()
  obj->Dict.set("type", JSON.Encode.string("boolean"))
  if description != "" {
    obj->Dict.set("description", JSON.Encode.string(description))
  }
  JSON.Encode.object(obj)
}

/** Create an array property schema */
let arrayProp = (~items: JSON.t, ~description: string=""): JSON.t => {
  let obj = Dict.make()
  obj->Dict.set("type", JSON.Encode.string("array"))
  obj->Dict.set("items", items)
  if description != "" {
    obj->Dict.set("description", JSON.Encode.string(description))
  }
  JSON.Encode.object(obj)
}

/** Create an enum property schema */
let enumProp = (~values: array<string>, ~description: string=""): JSON.t => {
  let obj = Dict.make()
  obj->Dict.set("type", JSON.Encode.string("string"))
  obj->Dict.set("enum", JSON.Encode.array(values, JSON.Encode.string))
  if description != "" {
    obj->Dict.set("description", JSON.Encode.string(description))
  }
  JSON.Encode.object(obj)
}

// Argument parsing helpers

/** Get a required string argument */
let getArg = (args: Dict.t<JSON.t>, name: string): option<string> => {
  switch args->Dict.get(name) {
  | Some(JSON.String(s)) => Some(s)
  | _ => None
  }
}

/** Get a required string argument or error */
let requireArg = (args: Dict.t<JSON.t>, name: string): result<string, string> => {
  switch getArg(args, name) {
  | Some(s) => Ok(s)
  | None => Error(`Missing required argument: ${name}`)
  }
}

/** Get an optional int argument */
let getIntArg = (args: Dict.t<JSON.t>, name: string): option<int> => {
  switch args->Dict.get(name) {
  | Some(JSON.Number(n)) => Some(Float.toInt(n))
  | Some(JSON.String(s)) => Int.fromString(s, ~radix=10)
  | _ => None
  }
}

/** Get an optional bool argument */
let getBoolArg = (args: Dict.t<JSON.t>, name: string): option<bool> => {
  switch args->Dict.get(name) {
  | Some(JSON.Boolean(b)) => Some(b)
  | Some(JSON.String("true")) => Some(true)
  | Some(JSON.String("false")) => Some(false)
  | _ => None
  }
}

/** Get an optional array argument */
let getArrayArg = (args: Dict.t<JSON.t>, name: string): option<array<JSON.t>> => {
  switch args->Dict.get(name) {
  | Some(JSON.Array(arr)) => Some(arr)
  | _ => None
  }
}
