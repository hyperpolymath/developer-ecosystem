// SPDX-License-Identifier: MPL-2.0 AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
Type-safe JSON decoding inspired by Elm's Json.Decode.
Decoders are composable and provide helpful error messages with path information.
")

type rec decodeError =
  | Field(string, decodeError)
  | Index(int, decodeError)
  | OneOf(array<decodeError>)
  | Failure(string, JSON.t)

type decoder<'a>

// Primitives
let string: decoder<string>
let int: decoder<int>
let float: decoder<float>
let bool: decoder<bool>
let null: 'a => decoder<'a>

// Objects
let field: (string, decoder<'a>) => decoder<'a>
let optionalField: (string, decoder<'a>) => decoder<option<'a>>
let at: (array<string>, decoder<'a>) => decoder<'a>

// Arrays
let array: decoder<'a> => decoder<array<'a>>
let index: (int, decoder<'a>) => decoder<'a>

// Combinators
let map: ('a => 'b, decoder<'a>) => decoder<'b>
let map2: (('a, 'b) => 'c, decoder<'a>, decoder<'b>) => decoder<'c>
let map3: (('a, 'b, 'c) => 'd, decoder<'a>, decoder<'b>, decoder<'c>) => decoder<'d>
let map4: (
  ('a, 'b, 'c, 'd) => 'e,
  decoder<'a>,
  decoder<'b>,
  decoder<'c>,
  decoder<'d>,
) => decoder<'e>
let map5: (
  ('a, 'b, 'c, 'd, 'e) => 'f,
  decoder<'a>,
  decoder<'b>,
  decoder<'c>,
  decoder<'d>,
  decoder<'e>,
) => decoder<'f>
let map6: (
  ('a, 'b, 'c, 'd, 'e, 'f) => 'g,
  decoder<'a>,
  decoder<'b>,
  decoder<'c>,
  decoder<'d>,
  decoder<'e>,
  decoder<'f>,
) => decoder<'g>
let andThen: ('a => decoder<'b>, decoder<'a>) => decoder<'b>

// Alternatives
let oneOf: array<decoder<'a>> => decoder<'a>
let optional: decoder<'a> => decoder<option<'a>>
let nullable: decoder<'a> => decoder<option<'a>>

// Special decoders
let succeed: 'a => decoder<'a>
let fail: string => decoder<'a>
let value: decoder<JSON.t>

// Running decoders
let decodeValue: (decoder<'a>, JSON.t) => result<'a, decodeError>
let decodeString: (decoder<'a>, string) => result<'a, decodeError>

// Error formatting
let errorToString: decodeError => string
