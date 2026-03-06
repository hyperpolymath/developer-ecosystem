// WebAssembly compilation and runtime support
// This module provides helpers for WASM compilation targets

// WASM memory management
module Memory = {
  type t

  @new external create: {"initial": int, "maximum": int} => t = "WebAssembly.Memory"
  @get external buffer: t => Js.Typed_array.ArrayBuffer.t = "buffer"
  @send external grow: (t, int) => int = "grow"

  // Get a Uint8Array view of memory
  let asUint8Array = (memory: t): Js.Typed_array.Uint8Array.t => {
    Js.Typed_array.Uint8Array.fromBuffer(buffer(memory))
  }

  // Copy bytes from ReScript to WASM memory at given offset
  let copyToWasm = (memory: t, offset: int, data: Js.Typed_array.Uint8Array.t): unit => {
    let view = asUint8Array(memory)
    let len = Js.Typed_array.Uint8Array.length(data)
    for i in 0 to len - 1 {
      let byte = Js.Typed_array.Uint8Array.unsafe_get(data, i)
      Js.Typed_array.Uint8Array.unsafe_set(view, offset + i, byte)
    }
  }

  // Copy bytes from WASM memory to ReScript
  let copyFromWasm = (memory: t, offset: int, len: int): Js.Typed_array.Uint8Array.t => {
    let view = asUint8Array(memory)
    Js.Typed_array.Uint8Array.subarray(view, ~start=offset, ~end_=offset + len)
  }
}

// WASM instance
module Instance = {
  type t
  type exports

  @get external exports: t => exports = "exports"
}

// WASM allocator protocol - expected exports from WASM modules
module Allocator = {
  // Type for WASM pointer (offset into linear memory)
  type ptr = int

  // Expected function signatures from WASM module exports
  type allocFn = int => ptr           // alloc(size) -> ptr
  type freeFn = ptr => unit           // free(ptr)
  type reallocFn = (ptr, int) => ptr  // realloc(ptr, new_size) -> ptr

  // Allocator instance wrapping WASM exports
  type t = {
    alloc: allocFn,
    free: freeFn,
    realloc: option<reallocFn>,
  }

  // Create allocator from WASM instance exports
  let fromExports = (exports: Instance.exports): t => {
    let allocFn: allocFn = %raw(`exports.alloc`)
    let freeFn: freeFn = %raw(`exports.free`)
    let reallocFn: option<reallocFn> = %raw(`exports.realloc ? exports.realloc : undefined`)
    {alloc: allocFn, free: freeFn, realloc: reallocFn}
  }
}

// WASM table (for indirect function calls)
module Table = {
  type t

  @new external create: {"initial": int, "element": string} => t = "WebAssembly.Table"
  @send external get: (t, int) => 'a = "get"
  @send external set: (t, int, 'a) => unit = "set"
  @send external grow: (t, int) => int = "grow"
}

// WASM module
module Module = {
  type t

  @scope("WebAssembly") @val
  external compile: Js.Typed_array.ArrayBuffer.t => promise<t> = "compile"

  @scope("WebAssembly") @val
  external instantiate: (t, 'imports) => promise<Instance.t> = "instantiate"
}

// Compilation configuration
type compileConfig = {
  optimize: bool,
  debug: bool,
  target: [#wasm32 | #wasm64],
  features: array<string>,
}

// Helper to load and instantiate WASM module
let loadModule = async (path: string, ~imports=?, ()): promise<Instance.t> => {
  let bytes = await Deno.Fs.readFile(path)
  let buffer = Js.Typed_array.Uint8Array.buffer(bytes)
  let module_ = await Module.compile(buffer)
  let importsObj = switch imports {
  | Some(i) => i
  | None => Js.Obj.empty()
  }
  let inst = await Module.instantiate(module_, importsObj)
  Promise.resolve(inst)
}
