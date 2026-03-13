-- SPDX-License-Identifier: MPL-2.0
-- HOL Light theorem prover configuration

||| HOL Light interactive theorem prover configuration
||| Part of the Tier 3 Specialized provers in ECHIDNA
module Echidna.Prover.HOLLight

import Echidna.Prover

%default total

||| HOL Light-specific configuration
public export
record HOLLightConfig where
  constructor MkHOLLightConfig
  ||| Path to HOL Light
  holPath : String
  ||| Load multivariate analysis
  loadMultivariate : Bool
  ||| Timeout in milliseconds
  timeout : Nat

||| Default HOL Light configuration
public export
defaultHOLLightConfig : HOLLightConfig
defaultHOLLightConfig = MkHOLLightConfig "/usr/share/hol-light" False 60000

||| Get the prover kind for HOL Light
public export
holLightKind : ProverKind
holLightKind = HOLLight
