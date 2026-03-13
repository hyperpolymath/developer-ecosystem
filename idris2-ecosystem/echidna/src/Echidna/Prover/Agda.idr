-- SPDX-License-Identifier: MPL-2.0
-- Agda theorem prover configuration

||| Agda dependently-typed theorem prover configuration
||| Part of the Tier 2 Interactive provers in ECHIDNA
module Echidna.Prover.Agda

import Echidna.Prover

%default total

||| Agda-specific configuration
public export
record AgdaConfig where
  constructor MkAgdaConfig
  ||| Path to agda
  agdaPath : String
  ||| Use standard library
  useStdLib : Bool
  ||| Timeout in milliseconds
  timeout : Nat

||| Default Agda configuration
public export
defaultAgdaConfig : AgdaConfig
defaultAgdaConfig = MkAgdaConfig "/usr/bin/agda" True 60000

||| Get the prover kind for Agda
public export
agdaKind : ProverKind
agdaKind = Agda
