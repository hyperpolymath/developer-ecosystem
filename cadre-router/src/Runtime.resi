/* Runtime.resi — Stage 1 public surface (frozen once implemented) */

module Error: {
  type t
  let toString: t => string
}

module Trap: {
  type t
  let toString: t => string
}

module Value: {
  type t
  type kind = I32 | I64 | F32 | F64

  let i32: int => t
  let i64: Int64.t => t
  let f32: float => t
  let f64: float => t

  let kind: t => kind
}

module Module_: {
  type t
  let load: Uint8Array.t => Result.t<t, Error.t>
}

module Imports: {
  type t
  /* Smallest explicit import model: namespace -> name -> function */
  type func = array<Value.t> => Result.t<array<Value.t>, Trap.t>

  let empty: unit => t
  let addFunc: (t, ~moduleName: string, ~name: string, func) => t
}

module Instance: {
  type t

  let instantiate: (Module_.t, ~imports: Imports.t) => Result.t<t, Error.t>

  /* Export lookup is explicit and optional */
  type func
  let exportFunc: (t, ~name: string) => option<func>
  let call: (func, array<Value.t>) => Result.t<array<Value.t>, Trap.t>

  type memory
  let exportMemory: t => option<memory>
}

module Memory: {
  /* Only operate on exported memory, explicit by design */
  let byteLength: Instance.memory => int
  let viewU8: Instance.memory => Uint8Array.t
}
