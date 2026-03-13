-- SPDX-License-Identifier: MPL-2.0
-- Alloy model finder configuration

||| Alloy model finder configuration
||| Part of the Tier 4 Model checkers in ECHIDNA
module Echidna.Prover.Alloy

import Echidna.Prover

%default total

||| Alloy-specific configuration
public export
record AlloyConfig where
  constructor MkAlloyConfig
  ||| Path to Alloy
  alloyPath : String
  ||| SAT solver to use
  solver : String
  ||| Scope for search
  scope : Nat

||| Default Alloy configuration
public export
defaultAlloyConfig : AlloyConfig
defaultAlloyConfig = MkAlloyConfig "/usr/bin/alloy" "sat4j" 10

||| Get the prover kind for Alloy
public export
alloyKind : ProverKind
alloyKind = Alloy
