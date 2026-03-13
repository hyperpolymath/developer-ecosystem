-- SPDX-License-Identifier: MPL-2.0
-- E Prover theorem prover configuration

||| E Prover automatic theorem prover configuration
||| Part of the Tier 3 Automated provers in ECHIDNA
module Echidna.Prover.EProver

import Echidna.Prover

%default total

||| E Prover-specific configuration
public export
record EProverConfig where
  constructor MkEProverConfig
  ||| Path to eprover
  eproverPath : String
  ||| Time limit in seconds
  timeLimit : Nat
  ||| Memory limit in MB
  memoryLimit : Nat
  ||| Auto-schedule mode
  autoSchedule : Bool

||| Default E Prover configuration
public export
defaultEProverConfig : EProverConfig
defaultEProverConfig = MkEProverConfig "/usr/bin/eprover" 60 4096 True

||| Get the prover kind for E Prover
public export
eProverKind : ProverKind
eProverKind = EProver
