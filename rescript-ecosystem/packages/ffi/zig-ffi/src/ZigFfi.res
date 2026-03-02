// SPDX-License-Identifier: AGPL-3.0-or-later
// ReScript-Zig-FFI - Core module for Zig FFI bindings

/**
 * ZigFfi provides the foundation for calling Zig libraries from ReScript.
 *
 * Architecture:
 *   ReScript → Deno FFI → Zig C ABI
 *
 * Usage:
 *   1. Build your Zig library with C exports
 *   2. Create bindings using the types below
 *   3. Call Zig functions from ReScript
 */

// Deno FFI type mappings
type ffiType = [
  | #i8
  | #u8
  | #i16
  | #u16
  | #i32
  | #u32
  | #i64
  | #u64
  | #f32
  | #f64
  | #bool
  | #pointer
  | #buffer
  | #function
  | #void
]

type symbolSpec = {
  parameters: array<ffiType>,
  result: ffiType,
  optional?: bool,
  callback?: bool,
}

type symbols = Dict.t<symbolSpec>

// Opaque type for loaded library
type library

// Opaque type for pointer
type pointer

// External bindings to Deno FFI
@scope("Deno") @val
external dlopen: (string, symbols) => library = "dlopen"

@get external symbols: library => 'a = "symbols"

@send external close: library => unit = "close"

// Pointer utilities
module Pointer = {
  @scope("Deno.UnsafePointer") @val
  external of: 'a => pointer = "of"

  @scope("Deno.UnsafePointer") @val
  external equals: (pointer, pointer) => bool = "equals"

  @scope("Deno.UnsafePointerView") @new
  external view: pointer => 'view = "UnsafePointerView"

  @send external getCString: 'view => string = "getCString"

  @send external getArrayBuffer: ('view, int) => Js.TypedArray2.ArrayBuffer.t = "getArrayBuffer"
}

// Buffer utilities for passing data to Zig
module Buffer = {
  @new external make: int => Js.TypedArray2.Uint8Array.t = "Uint8Array"

  external toPointer: Js.TypedArray2.Uint8Array.t => pointer = "%identity"

  let fromString = (str: string): Js.TypedArray2.Uint8Array.t => {
    let encoder = Js.Global.encodeURIComponent
    let _ = encoder // suppress unused warning
    // Use TextEncoder in actual implementation
    make(String.length(str))
  }
}

// Result type for FFI calls
type result<'a> =
  | Ok('a)
  | Error(string)

// Safe wrapper for FFI calls
let call = (fn: unit => 'a): result<'a> => {
  try {
    Ok(fn())
  } catch {
  | Js.Exn.Error(e) =>
    switch Js.Exn.message(e) {
    | Some(msg) => Error(msg)
    | None => Error("Unknown FFI error")
    }
  }
}
