// SPDX-License-Identifier: MPL-2.0
// Google protobuf well-known types with JSON mapping
// https://protobuf.dev/programming-guides/proto3/#json

// Timestamp - RFC 3339 string in JSON
module Timestamp = {
  // Date is represented as Js.Date.t in ReScript
  // JSON format: "2017-01-15T01:30:15.01Z"

  let toJson = (date: Js.Date.t): Js.Json.t => {
    Js.Json.string(Js.Date.toISOString(date))
  }

  let fromJson = (json: Js.Json.t): option<Js.Date.t> => {
    switch Js.Json.decodeString(json) {
    | Some(s) =>
      let date = Js.Date.fromString(s)
      // Check if date is valid
      if Float.isNaN(Js.Date.getTime(date)) {
        None
      } else {
        Some(date)
      }
    | None => None
    }
  }

  // Create from seconds/nanos (internal proto representation)
  let fromSecondsNanos = (seconds: bigint, nanos: int): Js.Date.t => {
    let millis = BigInt.toFloat(seconds) *. 1000.0 +. Int.toFloat(nanos) /. 1000000.0
    Js.Date.fromFloat(millis)
  }

  // Get seconds/nanos from date (internal proto representation)
  let toSecondsNanos = (date: Js.Date.t): (bigint, int) => {
    let millis = Js.Date.getTime(date)
    let seconds = BigInt.fromFloat(Math.floor(millis /. 1000.0))
    let nanos = Float.toInt(mod_float(millis, 1000.0) *. 1000000.0)
    (seconds, nanos)
  }
}

// Duration - "Xs" format in JSON (where X is seconds with optional nanos)
module Duration = {
  // Duration is represented as float (seconds) in ReScript
  // JSON format: "1.5s" or "3600s"

  let toJson = (seconds: float): Js.Json.t => {
    // Format as "Xs" with up to 9 decimal places
    let str = if Float.toInt(seconds) == 0 && seconds != 0.0 {
      Float.toString(seconds) ++ "s"
    } else {
      let intPart = Float.toInt(Math.floor(seconds))
      let fracPart = seconds -. Int.toFloat(intPart)
      if fracPart == 0.0 {
        Int.toString(intPart) ++ "s"
      } else {
        Float.toString(seconds) ++ "s"
      }
    }
    Js.Json.string(str)
  }

  let fromJson = (json: Js.Json.t): option<float> => {
    switch Js.Json.decodeString(json) {
    | Some(s) =>
      // Remove trailing 's'
      if String.endsWith(s, "s") {
        let numPart = String.slice(s, ~start=0, ~end=-1)
        Float.fromString(numPart)
      } else {
        None
      }
    | None => None
    }
  }

  // Create from seconds/nanos (internal proto representation)
  let fromSecondsNanos = (seconds: bigint, nanos: int): float => {
    BigInt.toFloat(seconds) +. Int.toFloat(nanos) /. 1000000000.0
  }

  // Get seconds/nanos from duration
  let toSecondsNanos = (duration: float): (bigint, int) => {
    let seconds = BigInt.fromFloat(Math.floor(duration))
    let nanos = Float.toInt(mod_float(duration, 1.0) *. 1000000000.0)
    (seconds, nanos)
  }
}

// Struct - JSON object
module Struct = {
  // Struct is represented as Js.Dict.t<Js.Json.t> in ReScript
  // JSON format: just a regular JSON object

  let toJson = (dict: Js.Dict.t<Js.Json.t>): Js.Json.t => {
    Js.Json.object_(dict)
  }

  let fromJson = (json: Js.Json.t): option<Js.Dict.t<Js.Json.t>> => {
    Js.Json.decodeObject(json)
  }
}

// Any - special type with @type field
module Any = {
  type t = {
    typeUrl: string,
    value: Js.Json.t,
  }

  // JSON format: {"@type": "type.googleapis.com/...", ...fields}
  let toJson = (any: t): Js.Json.t => {
    let dict = Js.Dict.empty()
    Js.Dict.set(dict, "@type", Js.Json.string(any.typeUrl))
    // Merge value fields into dict
    switch Js.Json.decodeObject(any.value) {
    | Some(valueDict) =>
      Js.Dict.entries(valueDict)->Array.forEach(((key, value)) => {
        Js.Dict.set(dict, key, value)
      })
    | None => ()
    }
    Js.Json.object_(dict)
  }

  let fromJson = (json: Js.Json.t): option<t> => {
    switch Js.Json.decodeObject(json) {
    | Some(obj) =>
      switch Js.Dict.get(obj, "@type") {
      | Some(typeJson) =>
        switch Js.Json.decodeString(typeJson) {
        | Some(typeUrl) =>
          // Remove @type from value object
          let valueDict = Js.Dict.empty()
          Js.Dict.entries(obj)->Array.forEach(((key, value)) => {
            if key != "@type" {
              Js.Dict.set(valueDict, key, value)
            }
          })
          Some({
            typeUrl,
            value: Js.Json.object_(valueDict),
          })
        | None => None
        }
      | None => None
      }
    | None => None
    }
  }

  // Create Any from type URL and message
  let make = (~typeUrl: string, ~value: Js.Json.t): t => {
    {typeUrl, value}
  }
}

// Empty - empty object
module Empty = {
  // Empty is represented as unit in ReScript
  // JSON format: {}

  let toJson = (_: unit): Js.Json.t => {
    Js.Json.object_(Js.Dict.empty())
  }

  let fromJson = (_json: Js.Json.t): option<unit> => {
    Some()
  }
}
