-- SPDX-License-Identifier: MPL-2.0
-- Vampire theorem prover configuration

||| Vampire automatic theorem prover configuration
||| Part of the Tier 3 Automated provers in ECHIDNA
module Echidna.Prover.Vampire

import Echidna.Prover

%default total

||| Vampire-specific configuration
public export
record VampireConfig where
  constructor MkVampireConfig
  ||| Path to vampire
  vampirePath : String
  ||| Time limit in seconds
  timeLimit : Nat
  ||| Memory limit in MB
  memoryLimit : Nat
  ||| Mode (casc, portfolio, etc.)
  mode : String

||| Default Vampire configuration
public export
defaultVampireConfig : VampireConfig
defaultVampireConfig = MkVampireConfig "/usr/bin/vampire" 60 4096 "casc"

||| Get the prover kind for Vampire
public export
vampireKind : ProverKind
vampireKind = Vampire
