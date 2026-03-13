-- SPDX-License-Identifier: MPL-2.0
-- Lean 4 theorem prover configuration

||| Lean 4 interactive theorem prover configuration
||| Part of the Tier 2 Interactive provers in ECHIDNA
module Echidna.Prover.Lean

import Echidna.Prover

%default total

||| Lean-specific configuration
public export
record LeanConfig where
  constructor MkLeanConfig
  ||| Path to Lean installation
  leanPath : String
  ||| Mathlib available
  useMathlib : Bool
  ||| Timeout in milliseconds
  timeout : Nat

||| Default Lean configuration
public export
defaultLeanConfig : LeanConfig
defaultLeanConfig = MkLeanConfig "/usr/bin/lean" True 60000

||| Get the prover kind for Lean
public export
leanKind : ProverKind
leanKind = Lean4
