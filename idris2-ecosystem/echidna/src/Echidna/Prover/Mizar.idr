-- SPDX-License-Identifier: MPL-2.0
-- Mizar theorem prover configuration

||| Mizar mathematical proof system configuration
||| Part of the Tier 3 Specialized provers in ECHIDNA
module Echidna.Prover.Mizar

import Echidna.Prover

%default total

||| Mizar-specific configuration
public export
record MizarConfig where
  constructor MkMizarConfig
  ||| Path to Mizar installation
  mizarPath : String
  ||| Use Mizar Mathematical Library
  useMML : Bool
  ||| Timeout in milliseconds
  timeout : Nat

||| Default Mizar configuration
public export
defaultMizarConfig : MizarConfig
defaultMizarConfig = MkMizarConfig "/usr/share/mizar" True 60000

||| Get the prover kind for Mizar
public export
mizarKind : ProverKind
mizarKind = Mizar
