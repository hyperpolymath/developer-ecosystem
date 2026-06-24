// SPDX-License-Identifier: MPL-2.0 AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("Tests for Tea_Json module")

// Node.js test bindings
@module("node:test") external test: (string, unit => unit) => unit = "test"
@module("node:assert") external strictEqual: ('a, 'a) => unit = "strictEqual"
@module("node:assert") external deepStrictEqual: ('a, 'a) => unit = "deepStrictEqual"
@module("node:assert") external ok: bool => unit = "ok"
@module("node:assert") external fail: string => unit = "fail"

// ============================================================================
// Helper
// ============================================================================

let assertOk = result =>
  switch result {
  | Ok(_) => ok(true)
  | Error(err) => fail(Tea_Json.errorToString(err))
  }

let assertError = result =>
  switch result {
  | Ok(_) => fail("Expected error but got Ok")
  | Error(_) => ok(true)
  }

let assertEqualResult = (result, expected) =>
  switch result {
  | Ok(value) => deepStrictEqual(value, expected)
  | Error(err) => fail(Tea_Json.errorToString(err))
  }

// ============================================================================
// Tests for string decoder
// ============================================================================

test("string decoder succeeds on string", () => {
  let json = JSON.Encode.string("hello")
  assertEqualResult(Tea_Json.decodeValue(Tea_Json.string, json), "hello")
})

test("string decoder fails on number", () => {
  let json = JSON.Encode.float(42.0)
  assertError(Tea_Json.decodeValue(Tea_Json.string, json))
})

// ============================================================================
// Tests for int decoder
// ============================================================================

test("int decoder succeeds on integer", () => {
  let json = JSON.Encode.float(42.0)
  assertEqualResult(Tea_Json.decodeValue(Tea_Json.int, json), 42)
})

test("int decoder fails on float", () => {
  let json = JSON.Encode.float(42.5)
  assertError(Tea_Json.decodeValue(Tea_Json.int, json))
})

test("int decoder fails on string", () => {
  let json = JSON.Encode.string("42")
  assertError(Tea_Json.decodeValue(Tea_Json.int, json))
})

// ============================================================================
// Tests for float decoder
// ============================================================================

test("float decoder succeeds on number", () => {
  let json = JSON.Encode.float(3.14)
  assertEqualResult(Tea_Json.decodeValue(Tea_Json.float, json), 3.14)
})

test("float decoder fails on string", () => {
  let json = JSON.Encode.string("3.14")
  assertError(Tea_Json.decodeValue(Tea_Json.float, json))
})

// ============================================================================
// Tests for bool decoder
// ============================================================================

test("bool decoder succeeds on true", () => {
  let json = JSON.Encode.bool(true)
  assertEqualResult(Tea_Json.decodeValue(Tea_Json.bool, json), true)
})

test("bool decoder succeeds on false", () => {
  let json = JSON.Encode.bool(false)
  assertEqualResult(Tea_Json.decodeValue(Tea_Json.bool, json), false)
})

test("bool decoder fails on string", () => {
  let json = JSON.Encode.string("true")
  assertError(Tea_Json.decodeValue(Tea_Json.bool, json))
})

// ============================================================================
// Tests for field decoder
// ============================================================================

test("field decoder extracts field from object", () => {
  let json = JSON.parseOrThrow(`{"name": "Alice"}`)
  let decoder = Tea_Json.field("name", Tea_Json.string)
  assertEqualResult(Tea_Json.decodeValue(decoder, json), "Alice")
})

test("field decoder fails on missing field", () => {
  let json = JSON.parseOrThrow(`{"other": "value"}`)
  let decoder = Tea_Json.field("name", Tea_Json.string)
  assertError(Tea_Json.decodeValue(decoder, json))
})

test("field decoder fails on non-object", () => {
  let json = JSON.Encode.string("not an object")
  let decoder = Tea_Json.field("name", Tea_Json.string)
  assertError(Tea_Json.decodeValue(decoder, json))
})

// ============================================================================
// Tests for array decoder
// ============================================================================

test("array decoder succeeds on array of strings", () => {
  let json = JSON.parseOrThrow(`["a", "b", "c"]`)
  let decoder = Tea_Json.array(Tea_Json.string)
  assertEqualResult(Tea_Json.decodeValue(decoder, json), ["a", "b", "c"])
})

test("array decoder succeeds on empty array", () => {
  let json = JSON.parseOrThrow(`[]`)
  let decoder = Tea_Json.array(Tea_Json.int)
  assertEqualResult(Tea_Json.decodeValue(decoder, json), [])
})

test("array decoder fails if element fails", () => {
  let json = JSON.parseOrThrow(`[1, "two", 3]`)
  let decoder = Tea_Json.array(Tea_Json.int)
  assertError(Tea_Json.decodeValue(decoder, json))
})

// ============================================================================
// Tests for map decoder
// ============================================================================

test("map transforms decoded value", () => {
  let json = JSON.Encode.float(5.0)
  let decoder = Tea_Json.map(x => x * 2, Tea_Json.int)
  assertEqualResult(Tea_Json.decodeValue(decoder, json), 10)
})

// ============================================================================
// Tests for map2 decoder
// ============================================================================

test("map2 combines two fields", () => {
  let json = JSON.parseOrThrow(`{"x": 10, "y": 20}`)
  let decoder = Tea_Json.map2(
    (x, y) => x + y,
    Tea_Json.field("x", Tea_Json.int),
    Tea_Json.field("y", Tea_Json.int),
  )
  assertEqualResult(Tea_Json.decodeValue(decoder, json), 30)
})

// ============================================================================
// Tests for oneOf decoder
// ============================================================================

test("oneOf succeeds with first matching decoder", () => {
  let json = JSON.Encode.string("hello")
  // Both decoders must return same type - use string for both
  let decoder = Tea_Json.oneOf([
    Tea_Json.map(x => `int:${Belt.Int.toString(x)}`, Tea_Json.int),
    Tea_Json.map(s => s, Tea_Json.string),
  ])
  assertEqualResult(Tea_Json.decodeValue(decoder, json), "hello")
})

test("oneOf fails if none match", () => {
  let json = JSON.Encode.bool(true)
  // Both decoders return int
  let decoder = Tea_Json.oneOf([Tea_Json.int, Tea_Json.map(_ => 0, Tea_Json.string)])
  assertError(Tea_Json.decodeValue(decoder, json))
})

// ============================================================================
// Tests for optional decoder
// ============================================================================

test("optional returns Some for valid value", () => {
  let json = JSON.Encode.string("hello")
  let decoder = Tea_Json.optional(Tea_Json.string)
  assertEqualResult(Tea_Json.decodeValue(decoder, json), Some("hello"))
})

test("optional returns None for null", () => {
  let json = JSON.Encode.null
  let decoder = Tea_Json.optional(Tea_Json.string)
  assertEqualResult(Tea_Json.decodeValue(decoder, json), None)
})

// ============================================================================
// Tests for decodeString
// ============================================================================

test("decodeString parses and decodes JSON string", () => {
  assertEqualResult(Tea_Json.decodeString(Tea_Json.int, "42"), 42)
})

test("decodeString fails on invalid JSON", () => {
  assertError(Tea_Json.decodeString(Tea_Json.int, "not json"))
})

// ============================================================================
// Tests for succeed and fail
// ============================================================================

test("succeed always returns the given value", () => {
  let json = JSON.Encode.null
  let decoder = Tea_Json.succeed(42)
  assertEqualResult(Tea_Json.decodeValue(decoder, json), 42)
})

test("fail always returns an error", () => {
  let json = JSON.Encode.null
  let decoder = Tea_Json.fail("always fails")
  assertError(Tea_Json.decodeValue(decoder, json))
})

// ============================================================================
// Tests for errorToString
// ============================================================================

test("errorToString formats Failure error", () => {
  let err = Tea_Json.Failure("test error", JSON.Encode.null)
  let str = Tea_Json.errorToString(err)
  ok(String.includes(str, "test error"))
})
