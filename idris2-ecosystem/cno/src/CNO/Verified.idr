-- SPDX-License-Identifier: MPL-2.0
||| Verified CNOs
|||
||| Integration with idris2-dyadt for runtime verification of CNO properties.
||| Also provides compile-time verification via type checking.
module CNO.Verified

import CNO.Core
import CNO.Proof
import Data.Vect

%default total

-------------------------------------------------------------------
-- Verification Claims for CNOs
-------------------------------------------------------------------

||| A claim that a function is a CNO
public export
data CNOClaim : Type where
  ||| Claim that a specific function is identity
  FunctionIsCNO : String -> CNOClaim
  ||| Claim that composition preserves CNO property
  CompositionPreservesCNO : CNOClaim
  ||| Claim about information preservation
  PreservesInformation : CNOClaim

-------------------------------------------------------------------
-- Evidence Types
-------------------------------------------------------------------

||| Evidence for CNO claims
public export
data CNOEvidence : CNOClaim -> Type where
  ||| Evidence from the internal proof
  InternalProof : CNO a -> CNOEvidence (FunctionIsCNO name)
  ||| Evidence that composition works
  CompositionEvidence : CNOEvidence CompositionPreservesCNO
  ||| Evidence of information preservation
  InfoPreservationEvidence : CNOEvidence PreservesInformation

-------------------------------------------------------------------
-- Verified CNO Wrapper
-------------------------------------------------------------------

||| A verified CNO carries its proof explicitly in the type
public export
record VerifiedCNO (a : Type) where
  constructor MkVerifiedCNO
  ||| The underlying CNO
  cno : CNO a
  ||| A name/identifier for the CNO
  name : String

||| Create a verified CNO
public export
verified : (name : String) -> CNO a -> VerifiedCNO a
verified = flip MkVerifiedCNO

||| Run a verified CNO
public export
runVerified : VerifiedCNO a -> a -> a
runVerified vcno = runCNO vcno.cno

-------------------------------------------------------------------
-- Compile-Time Verification
-------------------------------------------------------------------

||| If this type-checks, the CNO is verified
||| The type system enforces that the proof is valid
public export
0 TypeChecked : CNO a -> Type
TypeChecked cno = (x : a) -> runCNO cno x = x

||| Extract the compile-time verification
public export
compileTimeVerified : (cno : CNO a) -> TypeChecked cno
compileTimeVerified = cnoProof

-------------------------------------------------------------------
-- Verification Results
-------------------------------------------------------------------

||| Result of verifying a CNO at runtime
public export
data VerifyResult : Type where
  ||| CNO verified successfully
  Verified : VerifyResult
  ||| Verification failed (should never happen for real CNOs)
  Failed : String -> VerifyResult

||| Verify a CNO (always succeeds since CNO contains proof)
public export
verifyCNO : CNO a -> VerifyResult
verifyCNO cno = Verified  -- The proof is in the type!

-------------------------------------------------------------------
-- Chains of Verified Operations
-------------------------------------------------------------------

||| A chain of verified CNOs
public export
data CNOChain : Nat -> Type -> Type where
  ||| Empty chain (identity)
  Nil : CNOChain 0 a
  ||| Add a CNO to the chain
  (::) : VerifiedCNO a -> CNOChain n a -> CNOChain (S n) a

||| Run an entire chain
public export
runChain : CNOChain n a -> a -> a
runChain [] x = x
runChain (vcno :: rest) x = runVerified vcno (runChain rest x)

||| A chain of CNOs is still identity
public export
chainIsIdentity : (chain : CNOChain n a) -> (x : a) -> runChain chain x = x
chainIsIdentity [] x = Refl
chainIsIdentity (vcno :: rest) x =
  trans (cnoProof vcno.cno (runChain rest x)) (chainIsIdentity rest x)

-------------------------------------------------------------------
-- Verified CNO Examples
-------------------------------------------------------------------

||| The identity CNO, verified
public export
verifiedId : VerifiedCNO a
verifiedId = MkVerifiedCNO idCNO "identity"

||| A no-op CNO with a custom name
public export
noop : String -> VerifiedCNO a
noop name = MkVerifiedCNO idCNO name

