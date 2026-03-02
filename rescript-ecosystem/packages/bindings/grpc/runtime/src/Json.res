// SPDX-License-Identifier: MPL-2.0
// JSON codec for proto3 JSON mapping
// https://protobuf.dev/programming-guides/proto3/#json

// JSON encoding helpers
module Encode = {
  // Encode optional field - omit if None
  let optional = (key: string, value: option<'a>, encode: 'a => Js.Json.t): array<(string, Js.Json.t)> => {
    switch value {
    | Some(v) => [(key, encode(v))]
    | None => []
    }
  }

  // Encode required field
  let required = (key: string, value: 'a, encode: 'a => Js.Json.t): (string, Js.Json.t) => {
    (key, encode(value))
  }

  // Encode repeated field - omit if empty
  let repeated = (key: string, values: array<'a>, encode: 'a => Js.Json.t): array<(string, Js.Json.t)> => {
    if Array.length(values) == 0 {
      []
    } else {
      [(key, Js.Json.array(Array.map(values, encode)))]
    }
  }

  // Primitive encoders
  let string = (s: string): Js.Json.t => Js.Json.string(s)
  let int = (i: int): Js.Json.t => Js.Json.number(Int.toFloat(i))
  let float = (f: float): Js.Json.t => Js.Json.number(f)
  let bool = (b: bool): Js.Json.t => Js.Json.boolean(b)

  // Int64/BigInt as string (proto3 JSON mapping)
  let int64 = (i: bigint): Js.Json.t => Js.Json.string(BigInt.toString(i))

  // Bytes as base64
  let bytes = (b: Js.Typed_array.Uint8Array.t): Js.Json.t => {
    // Simple base64 encoding
    let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let len = Js.Typed_array.Uint8Array.length(b)
    let result = ref("")

    let i = ref(0)
    while i.contents < len {
      let b0 = Js.Typed_array.Uint8Array.unsafe_get(b, i.contents)
      let b1 = if i.contents + 1 < len { Js.Typed_array.Uint8Array.unsafe_get(b, i.contents + 1) } else { 0 }
      let b2 = if i.contents + 2 < len { Js.Typed_array.Uint8Array.unsafe_get(b, i.contents + 2) } else { 0 }

      let c0 = lsr(b0, 2)
      let c1 = lor(lsl(land(b0, 3), 4), lsr(b1, 4))
      let c2 = lor(lsl(land(b1, 15), 2), lsr(b2, 6))
      let c3 = land(b2, 63)

      result := result.contents ++ String.charAt(chars, c0)
      result := result.contents ++ String.charAt(chars, c1)
      result := result.contents ++ (if i.contents + 1 < len { String.charAt(chars, c2) } else { "=" })
      result := result.contents ++ (if i.contents + 2 < len { String.charAt(chars, c3) } else { "=" })

      i := i.contents + 3
    }

    Js.Json.string(result.contents)
  }

  // Build object from field list
  let object = (fields: array<(string, Js.Json.t)>): Js.Json.t => {
    let dict = Js.Dict.empty()
    Array.forEach(fields, ((key, value)) => {
      Js.Dict.set(dict, key, value)
    })
    Js.Json.object_(dict)
  }

  // Flatten optional field arrays for object construction
  let fields = (required: array<(string, Js.Json.t)>, optional: array<array<(string, Js.Json.t)>>): array<(string, Js.Json.t)> => {
    Array.concat(required, Array.flat(optional))
  }
}

// JSON decoding helpers
module Decode = {
  type error =
    | MissingField(string)
    | WrongType(string, string)
    | InvalidValue(string)

  let errorToString = (err: error): string => {
    switch err {
    | MissingField(field) => `Missing required field: ${field}`
    | WrongType(field, expected) => `Field ${field}: expected ${expected}`
    | InvalidValue(msg) => `Invalid value: ${msg}`
    }
  }

  // Get field from object
  let field = (obj: Js.Dict.t<Js.Json.t>, key: string): option<Js.Json.t> => {
    Js.Dict.get(obj, key)
  }

  // Decode required field
  let required = (obj: Js.Dict.t<Js.Json.t>, key: string, decode: Js.Json.t => option<'a>): result<'a, error> => {
    switch field(obj, key) {
    | Some(json) =>
      switch decode(json) {
      | Some(v) => Ok(v)
      | None => Error(WrongType(key, "expected type"))
      }
    | None => Error(MissingField(key))
    }
  }

  // Decode optional field
  let optional = (obj: Js.Dict.t<Js.Json.t>, key: string, decode: Js.Json.t => option<'a>): result<option<'a>, error> => {
    switch field(obj, key) {
    | Some(json) =>
      switch decode(json) {
      | Some(v) => Ok(Some(v))
      | None => Error(WrongType(key, "expected type"))
      }
    | None => Ok(None)
    }
  }

  // Decode repeated field
  let repeated = (obj: Js.Dict.t<Js.Json.t>, key: string, decode: Js.Json.t => option<'a>): result<array<'a>, error> => {
    switch field(obj, key) {
    | Some(json) =>
      switch Js.Json.decodeArray(json) {
      | Some(arr) =>
        let results = Array.filterMap(arr, decode)
        if Array.length(results) == Array.length(arr) {
          Ok(results)
        } else {
          Error(WrongType(key, "array elements"))
        }
      | None => Error(WrongType(key, "array"))
      }
    | None => Ok([])
    }
  }

  // Primitive decoders
  let string = (json: Js.Json.t): option<string> => Js.Json.decodeString(json)

  let int = (json: Js.Json.t): option<int> => {
    Js.Json.decodeNumber(json)->Option.map(Float.toInt)
  }

  let float = (json: Js.Json.t): option<float> => Js.Json.decodeNumber(json)

  let bool = (json: Js.Json.t): option<bool> => Js.Json.decodeBoolean(json)

  // Int64/BigInt from string
  let int64 = (json: Js.Json.t): option<bigint> => {
    switch Js.Json.decodeString(json) {
    | Some(s) =>
      try {
        Some(BigInt.fromStringExn(s))
      } catch {
      | _ => None
      }
    | None => None
    }
  }

  // Bytes from base64
  let bytes = (json: Js.Json.t): option<Js.Typed_array.Uint8Array.t> => {
    switch Js.Json.decodeString(json) {
    | Some(s) =>
      let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
      let len = String.length(s)
      let outputLen = len * 3 / 4 - (if String.endsWith(s, "==") { 2 } else if String.endsWith(s, "=") { 1 } else { 0 })
      let result = Js.Typed_array.Uint8Array.make(Array.make(~length=outputLen, 0))

      let indexOf = (c: string): int => {
        switch String.indexOf(chars, c) {
        | i if i >= 0 => i
        | _ => 0
        }
      }

      let j = ref(0)
      let i = ref(0)
      while i.contents < len - 3 {
        let c0 = indexOf(String.charAt(s, i.contents))
        let c1 = indexOf(String.charAt(s, i.contents + 1))
        let c2 = indexOf(String.charAt(s, i.contents + 2))
        let c3 = indexOf(String.charAt(s, i.contents + 3))

        if j.contents < outputLen {
          Js.Typed_array.Uint8Array.unsafe_set(result, j.contents, lor(lsl(c0, 2), lsr(c1, 4)))
        }
        if j.contents + 1 < outputLen {
          Js.Typed_array.Uint8Array.unsafe_set(result, j.contents + 1, lor(lsl(land(c1, 15), 4), lsr(c2, 2)))
        }
        if j.contents + 2 < outputLen {
          Js.Typed_array.Uint8Array.unsafe_set(result, j.contents + 2, lor(lsl(land(c2, 3), 6), c3))
        }

        i := i.contents + 4
        j := j.contents + 3
      }

      Some(result)
    | None => None
    }
  }

  // Decode object
  let object = (json: Js.Json.t): option<Js.Dict.t<Js.Json.t>> => {
    Js.Json.decodeObject(json)
  }
}

// Codec type combining encode and decode
type codec<'a> = {
  encode: 'a => Js.Json.t,
  decode: Js.Json.t => result<'a, Decode.error>,
}

// Serialize to JSON string
let stringify = (value: 'a, encode: 'a => Js.Json.t): string => {
  Js.Json.stringify(encode(value))
}

// Parse from JSON string
let parse = (str: string, decode: Js.Json.t => result<'a, Decode.error>): result<'a, Decode.error> => {
  try {
    let json = Js.Json.parseExn(str)
    decode(json)
  } catch {
  | _ => Error(Decode.InvalidValue("Invalid JSON"))
  }
}
