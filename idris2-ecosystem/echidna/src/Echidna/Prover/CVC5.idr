-- SPDX-License-Identifier: MPL-2.0
-- CVC5 SMT solver configuration

||| CVC5 SMT solver configuration
||| Part of the Tier 1 SMT solvers in ECHIDNA
module Echidna.Prover.CVC5

import Echidna.Prover

%default total

||| CVC5-specific configuration
public export
record CVC5Config where
  constructor MkCVC5Config
  ||| Logic to use (e.g., "QF_LIA", "ALL")
  logic : String
  ||| Timeout in milliseconds
  timeout : Nat
  ||| Enable proof production
  produceProofs : Bool
  ||| Enable model production
  produceModels : Bool

||| Default CVC5 configuration
public export
defaultCVC5Config : CVC5Config
defaultCVC5Config = MkCVC5Config "ALL" 30000 True True

||| Get the prover kind for CVC5
public export
cvc5Kind : ProverKind
cvc5Kind = CVC5
