-- SPDX-License-Identifier: MPL-2.0
||| Integration with idris2-dyadt
|||
||| Use ECHIDNA theorem provers to verify claims from idris2-dyadt.
module Echidna.Integration.Dyadt

import Echidna
import Echidna.Prover
import Echidna.Prover.Z3

%default total

-------------------------------------------------------------------
-- Claim Encoding
-------------------------------------------------------------------

||| Encode a claim as SMT-LIB formula
public export
encodeClaimSMTLib : (name : String) -> (formula : String) -> Theorem
encodeClaimSMTLib name formula = MkTheorem formula SMTLib Nothing []

-------------------------------------------------------------------
-- Verification Strategies
-------------------------------------------------------------------

||| Strategy for verifying claims
public export
data VerificationStrategy
  = ||| Try a single prover
    SingleProver ProverKind
  | ||| Try multiple provers in order
    MultiProver (List ProverKind)
  | ||| Use the fastest available prover
    Fastest

-------------------------------------------------------------------
-- Prove Claims
-------------------------------------------------------------------

||| Prove a claim using Z3
public export
partial
proveClaimZ3 : (formula : String) -> IO (Either ProverError ProofResult)
proveClaimZ3 formula = z3Prove (MkTheorem formula SMTLib Nothing [])

||| Prove a claim with strategy (currently only Z3 is implemented)
public export
partial
proveWithStrategy : VerificationStrategy -> Theorem -> IO (Either ProverError ProofResult)
proveWithStrategy (SingleProver Z3) thm = z3Prove thm
proveWithStrategy (SingleProver _) thm = pure (Left (Unknown "Only Z3 prover is currently implemented"))
proveWithStrategy (MultiProver []) thm = pure (Left (Unknown "No provers specified"))
proveWithStrategy (MultiProver (Z3 :: _)) thm = z3Prove thm
proveWithStrategy (MultiProver (_ :: rest)) thm = proveWithStrategy (MultiProver rest) thm
proveWithStrategy Fastest thm = z3Prove thm

-------------------------------------------------------------------
-- Verification Results
-------------------------------------------------------------------

||| Result of claim verification
public export
data ClaimVerifyResult
  = ||| Claim verified with proof
    ClaimVerified String
  | ||| Claim verification failed
    ClaimFailed String
  | ||| Verification timeout
    ClaimTimeout

||| Show instance for ClaimVerifyResult
public export
Show ClaimVerifyResult where
  show (ClaimVerified name) = "Verified: " ++ name
  show (ClaimFailed reason) = "Failed: " ++ reason
  show ClaimTimeout = "Timeout"
