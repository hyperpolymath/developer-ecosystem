-- SPDX-License-Identifier: MPL-2.0
-- Isabelle/HOL theorem prover configuration

||| Isabelle/HOL interactive theorem prover configuration
||| Part of the Tier 2 Interactive provers in ECHIDNA
module Echidna.Prover.Isabelle

import Echidna.Prover

%default total

||| Isabelle-specific configuration
public export
record IsabelleConfig where
  constructor MkIsabelleConfig
  ||| Path to isabelle
  isabellePath : String
  ||| Logic to use (HOL, FOL, ZF)
  logic : String
  ||| Use Sledgehammer
  useSledgehammer : Bool
  ||| Timeout in milliseconds
  timeout : Nat

||| Default Isabelle configuration
public export
defaultIsabelleConfig : IsabelleConfig
defaultIsabelleConfig = MkIsabelleConfig "/usr/bin/isabelle" "HOL" True 120000

||| Get the prover kind for Isabelle
public export
isabelleKind : ProverKind
isabelleKind = Isabelle
