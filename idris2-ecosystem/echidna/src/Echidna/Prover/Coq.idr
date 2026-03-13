-- SPDX-License-Identifier: MPL-2.0
-- Coq theorem prover configuration

||| Coq interactive theorem prover configuration
||| Part of the Tier 2 Interactive provers in ECHIDNA
module Echidna.Prover.Coq

import Echidna.Prover

%default total

||| Coq-specific configuration
public export
record CoqConfig where
  constructor MkCoqConfig
  ||| Path to coqc
  coqPath : String
  ||| Load libraries
  loadLibs : List String
  ||| Timeout in milliseconds
  timeout : Nat

||| Default Coq configuration
public export
defaultCoqConfig : CoqConfig
defaultCoqConfig = MkCoqConfig "/usr/bin/coqc" [] 60000

||| Get the prover kind for Coq
public export
coqKind : ProverKind
coqKind = Coq
