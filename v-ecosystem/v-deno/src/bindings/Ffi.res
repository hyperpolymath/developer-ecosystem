// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
// Deno FFI bindings for V library loading

type ffiType =
  | I8
  | I16
  | I32
  | I64
  | U8
  | U16
  | U32
  | U64
  | F32
  | F64
  | Pointer
  | Void
  | Function

let ffiTypeToString = (t: ffiType): string => {
  switch t {
  | I8 => "i8"
  | I16 => "i16"
  | I32 => "i32"
  | I64 => "i64"
  | U8 => "u8"
  | U16 => "u16"
  | U32 => "u32"
  | U64 => "u64"
  | F32 => "f32"
  | F64 => "f64"
  | Pointer => "pointer"
  | Void => "void"
  | Function => "function"
  }
}

type symbolDef = {
  parameters: array<ffiType>,
  result: ffiType,
}

type library = {symbols: Dict.t<'fn>}

let open_ = (path: string, symbols: Dict.t<symbolDef>): library => {
  %raw(`
    const convertedSymbols = {};
    for (const [name, def] of Object.entries(symbols)) {
      convertedSymbols[name] = {
        parameters: def.parameters.map(t => {
          switch (t.TAG) {
            case 0: return "i8";
            case 1: return "i16";
            case 2: return "i32";
            case 3: return "i64";
            case 4: return "u8";
            case 5: return "u16";
            case 6: return "u32";
            case 7: return "u64";
            case 8: return "f32";
            case 9: return "f64";
            case 10: return "pointer";
            case 11: return "void";
            case 12: return "function";
            default: return "void";
          }
        }),
        result: (() => {
          switch (def.result.TAG) {
            case 0: return "i8";
            case 1: return "i16";
            case 2: return "i32";
            case 3: return "i64";
            case 4: return "u8";
            case 5: return "u16";
            case 6: return "u32";
            case 7: return "u64";
            case 8: return "f32";
            case 9: return "f64";
            case 10: return "pointer";
            case 11: return "void";
            case 12: return "function";
            default: return "void";
          }
        })()
      };
    }
    const lib = Deno.dlopen(path, convertedSymbols);
    { symbols: lib.symbols }
  `)
}

let close = (_lib: library): unit => {
  %raw(`
    // Deno doesn't have explicit close for dlopen, but we can null the reference
    // In future Deno versions, there may be lib.close()
  `)
}
