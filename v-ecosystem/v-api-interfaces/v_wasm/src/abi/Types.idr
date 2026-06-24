-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-wasm protocol.
-- WASM types: targets, WIT worlds, modules.

module Types

import Data.List

||| WebAssembly target.
public export
data WasmTarget : Type where
  Wasm32 : WasmTarget
  Wasm64 : WasmTarget

||| WIT world type.
public export
data WitWorldType : Type where
  Command : WitWorldType
  Reactor : WitWorldType
  Proxy   : WitWorldType

||| WASM module.
public export
record WasmModule where
  constructor MkWasmModule
  name      : String
  path      : String
  target    : WasmTarget
  sizeBytes : Integer
  imports   : List String
  exports   : List String
