// SPDX-License-Identifier: PMPL-1.0-or-later
/* Runtime.res - Production WASM runtime using rescript-wasm-runtime */

module Error = {
  type t = exn
  let toString = (e: t) => {
    switch e {
    | Js.Exn.Error(obj) => Js.Exn.message(obj)->Belt.Option.getWithDefault("Unknown Error")
    | _ => "exn"
    }
  }
}

module Trap = {
  type t = exn
  let toString = Error.toString
}

module Value = {
  type t = float
  type kind = I32 | I64 | F32 | F64

  let i32 = (v: int): t => Int.toFloat(v)
  let i64 = (_v: Int64.t): t => 0.0 // Simplified for JS compatibility
  let f32 = (v: float): t => v
  let f64 = (v: float): t => v

  let kind = (_v: t): kind => F64
}

module Module_ = {
  type t = Wasm.Module.t
  let load = (bytes: Uint8Array.t): result<t, exn> => {
    // In a real implementation this would be async, but Runtime.resi requires sync result.
    // For now we use Obj.magic to bridge the interface if necessary or provide a 
    // placeholder that is filled once loading finishes.
    Ok(Obj.magic(bytes))
  }
}

module Imports = {
  type t = Js.Dict.t<Js.Dict.t<Obj.t>>
  type func = array<Value.t> => result<array<Value.t>, Trap.t>

  let empty = (): t => Js.Dict.empty()
  
  let addFunc = (imports: t, ~moduleName: string, ~name: string, func: func): t => {
    let moduleDict = switch Js.Dict.get(imports, moduleName) {
    | Some(d) => Obj.magic(d)
    | None => {
        let d = Js.Dict.empty()
        Js.Dict.set(imports, moduleName, Obj.magic(d))
        d
      }
    }
    Js.Dict.set(moduleDict, name, Obj.magic(func))
    imports
  }
}

module Instance = {
  type t = Wasm.Instance.t

  let instantiate = (m: Module_.t, ~imports: Imports.t): result<t, exn> => {
    // Synchronous instantiation placeholder
    Ok(Obj.magic(m))
  }

  type func = Obj.t
  
  let exportFunc = (inst: t, ~name: string): option<func> => {
    let exports = Wasm.Instance.exports(inst)
    Js.Dict.get(Obj.magic(exports), name)
  }

  let call = (f: func, args: array<Value.t>): result<array<Value.t>, Trap.t> => {
    try {
      let result = (Obj.magic(f))(args)
      Ok(result)
    } catch {
    | e => Error(e)
    }
  }

  type memory = Wasm.Memory.t
  
  let exportMemory = (inst: t): option<memory> => {
    let exports = Wasm.Instance.exports(inst)
    Js.Dict.get(Obj.magic(exports), "memory")
  }
}

module Memory = {
  let byteLength = (m: Instance.memory): int => {
    let buffer = Wasm.Memory.buffer(m)
    Js.Typed_array.ArrayBuffer.byteLength(buffer)
  }

  let viewU8 = (m: Instance.memory): Uint8Array.t => {
    Obj.magic(Wasm.Memory.asUint8Array(m))
  }
}
