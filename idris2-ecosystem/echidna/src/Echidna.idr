-- SPDX-License-Identifier: MPL-2.0
||| Idris2 bindings to ECHIDNA - Extensible Cognitive Hybrid Intelligence
||| for Deductive Neural Assistance
|||
||| ECHIDNA provides access to 12 theorem provers through a unified interface,
||| combining neural proof synthesis with symbolic verification.
|||
||| ## Quick Start
|||
||| ```idris
||| import Echidna
||| import Echidna.Prover.Z3
|||
||| example : IO (Either ProverError ProofResult)
||| example = do
|||   let theorem = MkTheorem "forall x. x + 0 = x" SMTLib
|||   prove Z3 theorem
||| ```
module Echidna

import public Echidna.Prover
import public Echidna.Aspect

||| ECHIDNA version
public export
echidnaVersion : String
echidnaVersion = "0.1.0"

||| Prover tiers based on ECHIDNA's architecture
public export
data ProverTier = Tier1  -- Core SMT + dependently typed (Z3, CVC5, Agda, Coq, Lean, Isabelle)
               | Tier2  -- Classical provers (Metamath, HOL Light, Mizar)
               | Tier3  -- Specialized (PVS, ACL2)
               | Tier4  -- Legacy (HOL4)

||| Get the tier for a prover
public export
proverTier : ProverKind -> ProverTier
proverTier Z3        = Tier1
proverTier CVC5      = Tier1
proverTier Agda      = Tier1
proverTier Coq       = Tier1
proverTier Lean4     = Tier1
proverTier Isabelle  = Tier1
proverTier Metamath  = Tier2
proverTier HOLLight  = Tier2
proverTier Mizar     = Tier2
proverTier PVS       = Tier3
proverTier ACL2      = Tier3
proverTier HOL4      = Tier4
proverTier Vampire   = Tier1
proverTier EProver   = Tier1
proverTier TLC       = Tier2
proverTier Alloy     = Tier2

||| Configuration for ECHIDNA connection
public export
record EchidnaConfig where
  constructor MkConfig
  ||| Host where ECHIDNA is running
  host : String
  ||| Port for the ECHIDNA service
  port : Nat
  ||| Timeout in milliseconds
  timeout : Nat
  ||| Whether to use neural proof synthesis
  useNeural : Bool
  ||| Aspect tags to apply
  aspects : List Aspect

||| Default configuration
public export
defaultConfig : EchidnaConfig
defaultConfig = MkConfig
  { host = "localhost"
  , port = 8080
  , timeout = 30000
  , useNeural = True
  , aspects = []
  }

||| ECHIDNA session handle
export
data EchidnaSession : Type where
  MkSession : (sessionId : String) -> (config : EchidnaConfig) -> EchidnaSession

||| Connect to ECHIDNA
export
connect : EchidnaConfig -> IO (Either String EchidnaSession)

||| Disconnect from ECHIDNA
export
disconnect : EchidnaSession -> IO ()

||| Prove a theorem using the best available prover
export
proveAuto : EchidnaSession -> Theorem -> IO (Either ProverError ProofResult)

||| Prove using multiple provers in parallel (consensus)
export
proveConsensus : EchidnaSession -> List ProverKind -> Theorem -> IO (Either ProverError (List ProofResult))

||| Verify an existing proof
export
verifyProof : EchidnaSession -> ProofResult -> IO (Either ProverError Bool)
