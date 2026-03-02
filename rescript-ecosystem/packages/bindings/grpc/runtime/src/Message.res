// SPDX-License-Identifier: MPL-2.0
// Base message type definitions for generated protobuf messages

// Trait-like module type for all generated messages
module type Encodable = {
  type t
  let encode: t => Js.Typed_array.Uint8Array.t
  let decode: Js.Typed_array.Uint8Array.t => t
}

// Wire types for protobuf encoding
module WireType = {
  type t =
    | Varint      // 0 - int32, int64, uint32, uint64, sint32, sint64, bool, enum
    | Fixed64     // 1 - fixed64, sfixed64, double
    | LengthDelim // 2 - string, bytes, embedded messages, packed repeated
    | StartGroup  // 3 - deprecated
    | EndGroup    // 4 - deprecated
    | Fixed32     // 5 - fixed32, sfixed32, float

  let toInt = (wt: t): int => {
    switch wt {
    | Varint => 0
    | Fixed64 => 1
    | LengthDelim => 2
    | StartGroup => 3
    | EndGroup => 4
    | Fixed32 => 5
    }
  }

  let fromInt = (i: int): option<t> => {
    switch i {
    | 0 => Some(Varint)
    | 1 => Some(Fixed64)
    | 2 => Some(LengthDelim)
    | 3 => Some(StartGroup)
    | 4 => Some(EndGroup)
    | 5 => Some(Fixed32)
    | _ => None
    }
  }
}

// Field tag encoding (field number << 3 | wire type)
module Tag = {
  let make = (fieldNumber: int, wireType: WireType.t): int => {
    lor(lsl(fieldNumber, 3), WireType.toInt(wireType))
  }

  let fieldNumber = (tag: int): int => {
    lsr(tag, 3)
  }

  let wireType = (tag: int): option<WireType.t> => {
    WireType.fromInt(land(tag, 0x7))
  }
}

// Varint encoding helpers
module Varint = {
  // Encode a varint to bytes
  let encode = (value: int): array<int> => {
    let result = []
    let v = ref(value)
    while v.contents > 127 {
      result->Array.push(lor(land(v.contents, 0x7f), 0x80))->ignore
      v := lsr(v.contents, 7)
    }
    result->Array.push(v.contents)->ignore
    result
  }

  // ZigZag encoding for signed integers
  let zigzagEncode = (value: int): int => {
    lxor(lsl(value, 1), asr(value, 31))
  }

  let zigzagDecode = (value: int): int => {
    lxor(lsr(value, 1), -land(value, 1))
  }
}

// Proto3 JSON serialization helpers
module Json = {
  // Null-safe field getter
  let getField = (obj: Js.Dict.t<Js.Json.t>, key: string): option<Js.Json.t> => {
    Js.Dict.get(obj, key)
  }

  // Type-safe extractors
  let asString = (json: Js.Json.t): option<string> => {
    Js.Json.decodeString(json)
  }

  let asInt = (json: Js.Json.t): option<int> => {
    Js.Json.decodeNumber(json)->Option.map(Float.toInt)
  }

  let asBool = (json: Js.Json.t): option<bool> => {
    Js.Json.decodeBoolean(json)
  }

  let asArray = (json: Js.Json.t): option<array<Js.Json.t>> => {
    Js.Json.decodeArray(json)
  }

  let asObject = (json: Js.Json.t): option<Js.Dict.t<Js.Json.t>> => {
    Js.Json.decodeObject(json)
  }
}
