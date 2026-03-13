-- SPDX-License-Identifier: MPL-2.0
-- TLC model checker configuration

||| TLC model checker configuration (TLA+ toolbox)
||| Part of the Tier 4 Model checkers in ECHIDNA
module Echidna.Prover.TLC

import Echidna.Prover

%default total

||| TLC-specific configuration
public export
record TLCConfig where
  constructor MkTLCConfig
  ||| Path to TLC
  tlcPath : String
  ||| Number of workers
  workers : Nat
  ||| Check deadlocks
  checkDeadlocks : Bool
  ||| Depth limit (0 for unlimited)
  depthLimit : Nat

||| Default TLC configuration
public export
defaultTLCConfig : TLCConfig
defaultTLCConfig = MkTLCConfig "/usr/bin/tlc" 4 True 0

||| Get the prover kind for TLC
public export
tlcKind : ProverKind
tlcKind = TLC
