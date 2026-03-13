-- SPDX-License-Identifier: MPL-2.0
||| Integration with idris2-cno
|||
||| Claims about CNO properties that can be verified using dyadt.
||| This module bridges idris2-cno's type-level proofs with dyadt's
||| claim verification system.
module Dyadt.Integration.CNO

import Dyadt.Claim
import Dyadt.Evidence
import Dyadt.Verdict

-- Import from idris2-cno
import CNO
import CNO.Core
import CNO.Proof

-- Not marked total due to Evidence module constraints

-------------------------------------------------------------------
-- Dyadt Claims about CNOs
-------------------------------------------------------------------

||| Dyadt claims specifically about CNO properties
||| Named with Dyadt prefix to avoid collision with CNO.Verified.CNOClaim
public export
data DyadtCNOClaim : Type where
  ||| Claim that a named function is a CNO (identity)
  FunctionIsCNO : (funcName : String) -> DyadtCNOClaim
  ||| Claim that CNO composition is valid
  CompositionIsCNO : (f : String) -> (g : String) -> DyadtCNOClaim
  ||| Claim that a CNO preserves some invariant
  PreservesInvariant : (cnoName : String) -> (invariant : String) -> DyadtCNOClaim

-------------------------------------------------------------------
-- Evidence for Dyadt CNO Claims
-------------------------------------------------------------------

||| Evidence for dyadt CNO claims
public export
data DyadtCNOEvidence : DyadtCNOClaim -> Type where
  ||| Evidence from idris2-cno's type-level proof
  FromCNOProof : {0 a : Type} -> (theCno : CNO a) -> DyadtCNOEvidence (FunctionIsCNO funcName)
  ||| Evidence from composition proof
  FromCompositionProof : DyadtCNOEvidence (CompositionIsCNO f g)
  ||| Evidence from invariant preservation
  FromInvariantProof : DyadtCNOEvidence (PreservesInvariant cnoName inv)

-------------------------------------------------------------------
-- Convert to General Dyadt Claims
-------------------------------------------------------------------

||| Convert a dyadt CNO claim to a general dyadt Claim
public export
toDyadtClaim : DyadtCNOClaim -> Claim
toDyadtClaim (FunctionIsCNO funcName) =
  Custom ("cno_identity_" ++ funcName) []
toDyadtClaim (CompositionIsCNO f g) =
  Custom ("cno_composition_" ++ f ++ "_" ++ g) []
toDyadtClaim (PreservesInvariant cnoName inv) =
  Custom ("cno_preserves_" ++ cnoName ++ "_" ++ inv) []

-------------------------------------------------------------------
-- Bridge from idris2-cno to Dyadt Verification
-------------------------------------------------------------------

||| Wrap an idris2-cno CNO with dyadt verification metadata
public export
record CNOWithDyadtClaim (a : Type) where
  constructor MkCNOWithDyadtClaim
  ||| The underlying CNO from idris2-cno
  theCNO : CNO a
  ||| Name for this CNO
  cnoName : String
  ||| The dyadt claim about this CNO
  dyadtClaim : DyadtCNOClaim
  ||| Evidence for the claim
  evidence : DyadtCNOEvidence dyadtClaim

||| Create a dyadt-wrapped CNO
public export
wrapWithDyadt : {0 a : Type} -> (cnoName : String) -> (theCno : CNO a) -> CNOWithDyadtClaim a
wrapWithDyadt cnoName theCno =
  MkCNOWithDyadtClaim theCno cnoName (FunctionIsCNO cnoName) (FromCNOProof theCno)

||| Run a dyadt-wrapped CNO (delegates to runCNO)
public export
runWrapped : CNOWithDyadtClaim a -> a -> a
runWrapped wrapped = runCNO wrapped.theCNO

||| Extract the identity proof from the wrapped CNO
public export
extractProof : (wrapped : CNOWithDyadtClaim a) -> (x : a) -> runCNO wrapped.theCNO x = x
extractProof wrapped x = cnoProof wrapped.theCNO x

-------------------------------------------------------------------
-- CNO Chain Claims
-------------------------------------------------------------------

||| Claim that a chain of CNOs (by name) is valid
public export
chainClaim : List String -> Claim
chainClaim [] = Custom "empty_cno_chain" []
chainClaim [x] = Custom ("cno_identity_" ++ x) []
chainClaim (x :: y :: rest) =
  And (Custom ("cno_composition_" ++ x ++ "_" ++ y) [])
      (chainClaim (y :: rest))

||| Evidence for a CNO chain (by name)
public export
data ChainEvidence : (names : List String) -> Type where
  EmptyChain : ChainEvidence []
  SingleCNO : {0 theName : String} -> ChainEvidence [theName]
  ConsChain : {0 x, y : String} -> {0 rest : List String} ->
              ChainEvidence (y :: rest) -> ChainEvidence (x :: y :: rest)

