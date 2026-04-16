// SPDX-License-Identifier: PMPL-1.0-or-later
// SafeJson  Non-throwing JSON parsing and typed field extraction
//
// Pure ReScript equivalent of proven's ProvenSafeJson module. In the
// Idris2 implementation, JSON access uses dependent types to prove
// that keys exist and values have the expected type. Here we replace
// `JSON.parseExn` (which throws on invalid input) with `parse` that
// returns `result<JSON.t, provenError>`.
//
// Critical for IDApTIK's multiplayer system (PhoenixSocket.res) where
// incoming WebSocket messages are parsed as JSON. An invalid message
// from the server must not crash the game  it should be gracefully
// rejected.
//
// Usage:
//   switch SafeJson.parse(rawMessage) {
//   | Ok(json) =>
//     let topic = SafeJson.getString(json, "topic")->Option.getOr("")
//     let event = SafeJson.getString(json, "event")->Option.getOr("")
//   | Error(err) =>
//     Console.error(ProvenError.toString(err))
//   }


//  Safe Parse
// Parses a JSON string without throwing exceptions. Returns Error
// with a structured error for invalid JSON instead of crashing.
//
// Proven equivalent: ProvenSafeJson.parse (total function, never throws)
let parse = (input: string): result<JSON.t, ProvenError.provenError> => {
  try {
    Ok(JSON.parseExn(input))
  } catch {
  | _ =>
    Error(
      ProvenError.parseFailure(
        ~operation="SafeJson.parse",
        ~message=`Invalid JSON: "${String.slice(input, ~start=0, ~end=50)}${if (
            String.length(input) > 50
          ) {
            "..."
          } else {
            ""
          }}"`,
      ),
    )
  }
}

//  Typed Field Extraction 
// Each function attempts to extract a field of the expected type from
// a JSON object. Returns None if the field doesn't exist or has the
// wrong type. This replaces the error-prone pattern of
// `Dict.get(o, key)->Option.flatMap(JSON.Decode.string)`.

// Extract a string field from a JSON value.
// Returns None if the value is not an object, the key doesn't exist,
// or the value at that key is not a string.
let getString = (json: JSON.t, key: string): option<string> => {
  switch JSON.Decode.object(json) {
  | Some(obj) =>
    switch Dict.get(obj, key) {
    | Some(v) => JSON.Decode.string(v)
    | None => None
    }
  | None => None
  }
}

// Extract a float field from a JSON value.
let getFloat = (json: JSON.t, key: string): option<float> => {
  switch JSON.Decode.object(json) {
  | Some(obj) =>
    switch Dict.get(obj, key) {
    | Some(v) => JSON.Decode.float(v)
    | None => None
    }
  | None => None
  }
}

// Extract an integer field from a JSON value (truncates floats).
let getInt = (json: JSON.t, key: string): option<int> => {
  switch getFloat(json, key) {
  | Some(f) => Some(Float.toInt(f))
  | None => None
  }
}

// Extract a boolean field from a JSON value.
let getBool = (json: JSON.t, key: string): option<bool> => {
  switch JSON.Decode.object(json) {
  | Some(obj) =>
    switch Dict.get(obj, key) {
    | Some(v) => JSON.Decode.bool(v)
    | None => None
    }
  | None => None
  }
}

// Extract a nested JSON object field.
let getObject = (json: JSON.t, key: string): option<JSON.t> => {
  switch JSON.Decode.object(json) {
  | Some(obj) =>
    switch Dict.get(obj, key) {
    | Some(v) =>
      switch JSON.Decode.object(v) {
      | Some(_) => Some(v)
      | None => None
      }
    | None => None
    }
  | None => None
  }
}

// Extract a JSON array field.
let getArray = (json: JSON.t, key: string): option<array<JSON.t>> => {
  switch JSON.Decode.object(json) {
  | Some(obj) =>
    switch Dict.get(obj, key) {
    | Some(v) => JSON.Decode.array(v)
    | None => None
    }
  | None => None
  }
}

//  Nested Path Access 
// Navigates a dotted key path (e.g. "player.stats.hp") through nested
// JSON objects. Returns None if any segment is missing or not an object.
//
// Proven equivalent: ProvenSafeJson.getPath (with path existence proof)
let getPath = (json: JSON.t, path: string): option<JSON.t> => {
  let segments = String.split(path, ".")
  let current = ref(Some(json))
  Array.forEach(segments, segment => {
    switch current.contents {
    | Some(j) =>
      switch JSON.Decode.object(j) {
      | Some(obj) => current := Dict.get(obj, segment)
      | None => current := None
      }
    | None => ()
    }
  })
  current.contents
}

//  Safe Stringify 
// Converts a JSON value to a string. Cannot fail (JSON.stringify
// always succeeds for valid JSON values).
let stringify = (json: JSON.t): string => {
  JSON.stringify(json)
}

//  Stringify with Pretty Printing 
// Uses raw JS since ReScript's JSON module doesn't expose the indent parameter
let stringifyPretty: JSON.t => string = %raw(`function(json) { return JSON.stringify(json, null, 2); }`)

//  Type Checking 
// Non-destructive type inspection for JSON values.

let isString = (json: JSON.t): bool => {
  switch JSON.Decode.string(json) {
  | Some(_) => true
  | None => false
  }
}

let isNumber = (json: JSON.t): bool => {
  switch JSON.Decode.float(json) {
  | Some(_) => true
  | None => false
  }
}

let isObject = (json: JSON.t): bool => {
  switch JSON.Decode.object(json) {
  | Some(_) => true
  | None => false
  }
}

let isArray = (json: JSON.t): bool => {
  switch JSON.Decode.array(json) {
  | Some(_) => true
  | None => false
  }
}

let isBool = (json: JSON.t): bool => {
  switch JSON.Decode.bool(json) {
  | Some(_) => true
  | None => false
  }
}

let isNull = (json: JSON.t): bool => {
  JSON.Decode.null(json)->Option.isSome
}
