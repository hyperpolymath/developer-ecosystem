// SPDX-License-Identifier: MPL-2.0
// WASM-based protobuf binary codec bindings

// Schema field descriptor type
type rec fieldType =
  | String
  | Int32
  | Int64
  | Uint32
  | Uint64
  | Sint32
  | Sint64
  | Fixed32
  | Fixed64
  | Sfixed32
  | Sfixed64
  | Float
  | Double
  | Bool
  | Bytes
  | Enum
  | Message(array<fieldDescriptor>)
and fieldDescriptor = {
  n: int,
  name: string,
  fieldType: fieldType,
  repeated: bool,
  optional: bool,
}

// WASM module interface
type wasmCodec = {
  encode: (string, string) => string,
  decode: (string, string) => string,
}

// Global WASM instance (set after loading)
let wasmInstance: ref<option<wasmCodec>> = ref(None)

// Initialize WASM module from URL or buffer
@module("./rescript_grpc_codec_bg.js")
external initWasm: unit => promise<wasmCodec> = "default"

// Convert field type to schema JSON
let fieldTypeToString = (ft: fieldType): string => {
  switch ft {
  | String => "string"
  | Int32 => "int32"
  | Int64 => "int64"
  | Uint32 => "uint32"
  | Uint64 => "uint64"
  | Sint32 => "sint32"
  | Sint64 => "sint64"
  | Fixed32 => "fixed32"
  | Fixed64 => "fixed64"
  | Sfixed32 => "sfixed32"
  | Sfixed64 => "sfixed64"
  | Float => "float"
  | Double => "double"
  | Bool => "bool"
  | Bytes => "bytes"
  | Enum => "enum"
  | Message(_) => "message"
  }
}

// Convert field descriptor to JSON object for schema
let rec fieldToJson = (field: fieldDescriptor): Js.Json.t => {
  let d = Js.Dict.empty()
  Js.Dict.set(d, "n", Js.Json.number(Int.toFloat(field.n)))
  Js.Dict.set(d, "name", Js.Json.string(field.name))
  Js.Dict.set(d, "type", Js.Json.string(fieldTypeToString(field.fieldType)))
  Js.Dict.set(d, "repeated", Js.Json.boolean(field.repeated))
  Js.Dict.set(d, "optional", Js.Json.boolean(field.optional))

  switch field.fieldType {
  | Message(nested) =>
    Js.Dict.set(d, "fields", Js.Json.array(Array.map(nested, fieldToJson)))
  | _ => ()
  }

  Js.Json.object_(d)
}

// Convert schema to JSON string
let schemaToString = (fields: array<fieldDescriptor>): string => {
  Js.Json.stringify(Js.Json.array(Array.map(fields, fieldToJson)))
}

// Encode a message to protobuf binary (base64)
let encode = (~schema: array<fieldDescriptor>, ~data: Js.Json.t): result<string, string> => {
  switch wasmInstance.contents {
  | Some(wasm) =>
    try {
      let schemaStr = schemaToString(schema)
      let dataStr = Js.Json.stringify(data)
      Ok(wasm.encode(schemaStr, dataStr))
    } catch {
    | Exn.Error(e) => Error(Exn.message(e)->Option.getOr("Encode error"))
    }
  | None => Error("WASM codec not initialized")
  }
}

// Decode protobuf binary (base64) to JSON
let decode = (~schema: array<fieldDescriptor>, ~data: string): result<Js.Json.t, string> => {
  switch wasmInstance.contents {
  | Some(wasm) =>
    try {
      let schemaStr = schemaToString(schema)
      let jsonStr = wasm.decode(schemaStr, data)
      switch Js.Json.parseExn(jsonStr) {
      | json => Ok(json)
      | exception _ => Error("Failed to parse decoded JSON")
      }
    } catch {
    | Exn.Error(e) => Error(Exn.message(e)->Option.getOr("Decode error"))
    }
  | None => Error("WASM codec not initialized")
  }
}

// Check if WASM codec is initialized
let isInitialized = (): bool => {
  Option.isSome(wasmInstance.contents)
}

// Initialize the WASM codec (call once at app startup)
let initialize = async (): result<unit, string> => {
  try {
    let wasm = await initWasm()
    wasmInstance := Some(wasm)
    Ok()
  } catch {
  | Exn.Error(e) => Error(Exn.message(e)->Option.getOr("Failed to load WASM"))
  }
}
