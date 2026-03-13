-- SPDX-License-Identifier: MPL-2.0
||| Integration with idris2-echidna
|||
||| Use ECHIDNA theorem provers to verify dyadt claims.
module Dyadt.Integration.Echidna

import Dyadt.Claim
import Dyadt.Evidence
import Dyadt.Verdict

-- Import from idris2-echidna
import Echidna
import Echidna.Prover
import Echidna.Prover.Z3

-- Not marked total due to Evidence module constraints

-------------------------------------------------------------------
-- Prover-Backed Evidence
-------------------------------------------------------------------

||| Evidence obtained from a theorem prover
||| The proof field would come from echidna's ProofResult
public export
data ProverEvidence : Claim -> Type where
  ||| Evidence from a successful proof
  MkProverEvidence : (claim : Claim) ->
                     (proverName : String) ->
                     (proofHash : String) ->
                     ProverEvidence claim

-------------------------------------------------------------------
-- Claim Encoding
-------------------------------------------------------------------

||| Encode a claim as a logical formula for theorem proving
public export
encodeAsSMTLib : Claim -> String
encodeAsSMTLib (FileExists path) =
  "(assert (file-exists \"" ++ path ++ "\"))"
encodeAsSMTLib (FileWithHash path hash) =
  "(assert (and (file-exists \"" ++ path ++ "\") (= (file-hash \"" ++ path ++ "\") \"" ++ hash ++ "\")))"
encodeAsSMTLib (GitClean Nothing) =
  "(assert (git-clean \".\" ))"
encodeAsSMTLib (GitClean (Just p)) =
  "(assert (git-clean \"" ++ p ++ "\"))"
encodeAsSMTLib (And a b) =
  "(and " ++ encodeAsSMTLib a ++ " " ++ encodeAsSMTLib b ++ ")"
encodeAsSMTLib (Or a b) =
  "(or " ++ encodeAsSMTLib a ++ " " ++ encodeAsSMTLib b ++ ")"
encodeAsSMTLib (Not c) =
  "(not " ++ encodeAsSMTLib c ++ ")"
encodeAsSMTLib claim =
  "(assert (custom-claim " ++ show claim ++ "))"

-------------------------------------------------------------------
-- Theorem-Backed Verification
-------------------------------------------------------------------

||| A claim verified by theorem proving (not runtime checks)
public export
data TheoremVerified : Claim -> Type where
  ||| Claim verified via theorem prover
  ByTheorem : ProverEvidence claim -> TheoremVerified claim

||| Convert theorem verification to standard Verified
public export
toVerified : TheoremVerified claim -> Verified claim
toVerified (ByTheorem (MkProverEvidence claim _ _)) =
-- PROOF_TODO: Replace cast with actual proof
-- PROOF_TODO: Replace cast with actual proof
  MkVerified (cast "prover-evidence")  -- Would need actual evidence construction

-------------------------------------------------------------------
-- Verification Strategies
-------------------------------------------------------------------

||| How to verify a claim
public export
data VerifyMethod
  = ||| Runtime check (default dyadt behavior)
    Runtime
  | ||| Use theorem prover
    TheoremProving String  -- Prover name
  | ||| Try runtime, fall back to theorem proving
    RuntimeThenTheorem String
  | ||| Try theorem, fall back to runtime
    TheoremThenRuntime String

||| Default verification method
public export
defaultMethod : VerifyMethod
defaultMethod = Runtime

-------------------------------------------------------------------
-- Complex Claim Support
-------------------------------------------------------------------

||| Claims that benefit from theorem proving
public export
isComplexClaim : Claim -> Bool
isComplexClaim (And (And _ _) _) = True
isComplexClaim (Or (Or _ _) _) = True
isComplexClaim (AllClaims (_ :: _ :: _ :: _)) = True
isComplexClaim (Custom _ _) = True  -- Custom claims often need provers
isComplexClaim _ = False

||| Suggest verification method based on claim complexity
public export
suggestMethod : Claim -> VerifyMethod
suggestMethod claim =
  if isComplexClaim claim
    then TheoremThenRuntime "Z3"
    else Runtime

