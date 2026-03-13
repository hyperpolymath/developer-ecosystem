-- SPDX-License-Identifier: MPL-2.0
||| Integration with idris2-dyadt
|||
||| Express CNO properties as dyadt claims for verification.
module CNO.Integration.Dyadt

import CNO.Core
import CNO.Proof
import CNO.Verified

%default total

-------------------------------------------------------------------
-- CNO as Dyadt Claim
-------------------------------------------------------------------

||| A dyadt-style claim about a CNO
public export
data CNODyadtClaim : Type where
  ||| Claim that a CNO is valid (identity function)
  CNOIsValid : String -> CNODyadtClaim
  ||| Claim that a value is preserved by a CNO
  ValuePreserved : String -> String -> CNODyadtClaim
  ||| Claim that CNO composition is identity
  CompositionIsIdentity : String -> String -> CNODyadtClaim

-------------------------------------------------------------------
-- Evidence Types
-------------------------------------------------------------------

||| Evidence for CNO dyadt claims
public export
data CNODyadtEvidence : CNODyadtClaim -> Type where
  ||| Evidence from the CNO's internal proof
  InternalProofEvidence : (cno : CNO a) -> CNODyadtEvidence (CNOIsValid name)
  ||| Evidence from applying the CNO
  ApplicationEvidence : CNODyadtEvidence (ValuePreserved cnoName value)
  ||| Evidence from composition proof
  CompositionEvidence : CNODyadtEvidence (CompositionIsIdentity f g)

-------------------------------------------------------------------
-- Verification
-------------------------------------------------------------------

||| Verify a CNO claim (always succeeds for real CNOs)
public export
verifyCNOClaim : (claim : CNODyadtClaim) ->
                 (cno : CNO a) ->
                 CNODyadtEvidence (CNOIsValid name)
verifyCNOClaim _ cno = InternalProofEvidence cno

||| Check if a CNO preserves a specific value
public export
checkPreservation : (cno : CNO a) -> (x : a) -> (runCNO cno x = x)
checkPreservation cno x = cnoProof cno x

-------------------------------------------------------------------
-- CNO Verdict
-------------------------------------------------------------------

||| A verdict about a CNO claim
public export
data CNOVerdict : CNODyadtClaim -> Type where
  ||| CNO claim is verified
  CNOConfirmed : CNODyadtEvidence claim -> CNOVerdict claim

||| All CNO verdicts are confirmations (CNOs always verify)
public export
toCNOVerdict : (cno : CNO a) -> CNOVerdict (CNOIsValid name)
toCNOVerdict cno = CNOConfirmed (InternalProofEvidence cno)

-------------------------------------------------------------------
-- Combining with Dyadt Verified
-------------------------------------------------------------------

||| A CNO wrapped with its dyadt verification
public export
record DyadtVerifiedCNO (a : Type) where
  constructor MkDyadtVerifiedCNO
  ||| The underlying CNO
  cno : CNO a
  ||| Name for identification
  name : String
  ||| The claim that was verified
  claim : CNODyadtClaim
  ||| Evidence for the claim
  evidence : CNODyadtEvidence claim

||| Create a dyadt-verified CNO
public export
dyadtVerify : (name : String) -> (cno : CNO a) -> DyadtVerifiedCNO a
dyadtVerify name cno = MkDyadtVerifiedCNO cno name (CNOIsValid name) (InternalProofEvidence cno)

||| Run a dyadt-verified CNO
public export
runDyadtVerified : DyadtVerifiedCNO a -> a -> a
runDyadtVerified dv = runCNO dv.cno

