-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-cli protocol.
-- CLI management types: command descriptors, argument definitions,
-- flag specifications, and subcommand routing tables.

module Types

import Data.List

||| CLI argument kind.
public export
data ArgKind : Type where
  FlagBool   : ArgKind
  FlagString : ArgKind
  FlagInt    : ArgKind
  Positional : ArgKind

||| Argument definition.
public export
record ArgDef where
  constructor MkArgDef
  name     : String
  kind     : ArgKind
  required : Bool
  help     : String

||| Command descriptor.
public export
record Command where
  constructor MkCommand
  name        : String
  description : String
  args        : List ArgDef

||| Parsed argument result.
public export
record ParsedArgs where
  constructor MkParsedArgs
  command     : String
  positionals : List String
