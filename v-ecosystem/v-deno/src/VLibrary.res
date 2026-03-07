// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
// V Library wrapper for Deno FFI

open Ffi

type t = {
  path: string,
  lib: library,
}

let load = async (path: string, symbols: Dict.t<symbolDef>): t => {
  let lib = open_(path, symbols)
  {path: path, lib: lib}
}

let call = (vlib: t, name: string, args: array<'a>): 'b => {
  %raw(`
    const fn = vlib.lib.symbols[name];
    if (!fn) throw new Error("Symbol not found: " + name);
    return fn(...args);
  `)
}

let unload = (vlib: t): unit => {
  close(vlib.lib)
}

// V type helpers
module VString = {
  // Convert ReScript string to C string pointer
  let toPointer = (s: string): 'pointer => {
    %raw(`new TextEncoder().encode(s + "\0")`)
  }

  // Convert C string pointer to ReScript string
  let fromPointer = (ptr: 'pointer, len: int): string => {
    %raw(`
      const view = new Deno.UnsafePointerView(ptr);
      return view.getCString(0);
    `)
  }
}

module VArray = {
  // V arrays need length + pointer
  type vArray<'a> = {
    data: 'pointer,
    len: int,
  }

  let fromArray = (arr: array<int>): vArray<int> => {
    %raw(`
      const data = new Int32Array(arr);
      return { data: data, len: arr.length };
    `)
  }
}
