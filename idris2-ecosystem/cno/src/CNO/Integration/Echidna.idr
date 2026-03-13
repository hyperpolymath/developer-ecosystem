-- SPDX-License-Identifier: MPL-2.0
||| Integration with idris2-echidna
|||
||| Use theorem provers to verify CNO properties for complex cases.
module CNO.Integration.Echidna

import CNO.Core
import CNO.Proof

%default total

-------------------------------------------------------------------
-- Theorem Prover Support
-------------------------------------------------------------------

||| A theorem about a CNO that can be sent to a prover
public export
record CNOTheorem where
  constructor MkCNOTheorem
  ||| Name of the theorem
  name : String
  ||| The SMT-LIB formula
  formula : String
  ||| What this theorem proves
  property : String

-------------------------------------------------------------------
-- Standard CNO Theorems
-------------------------------------------------------------------

||| Theorem: f is identity
public export
identityTheorem : (funcName : String) -> (sortName : String) -> CNOTheorem
identityTheorem fn sort = MkCNOTheorem
  ("identity_" ++ fn)
  ("(forall ((x " ++ sort ++ ")) (= (" ++ fn ++ " x) x))")
  "Function is identity"

||| Theorem: composition of CNOs is identity
public export
compositionTheorem : (f : String) -> (g : String) -> (sort : String) -> CNOTheorem
compositionTheorem f g sort = MkCNOTheorem
  ("compose_" ++ f ++ "_" ++ g)
  ("(forall ((x " ++ sort ++ ")) (= (" ++ f ++ " (" ++ g ++ " x)) x))")
  "Composition is identity"

||| Theorem: f is its own inverse
public export
selfInverseTheorem : (funcName : String) -> (sortName : String) -> CNOTheorem
selfInverseTheorem fn sort = MkCNOTheorem
  ("self_inverse_" ++ fn)
  ("(forall ((x " ++ sort ++ ")) (= (" ++ fn ++ " (" ++ fn ++ " x)) x))")
  "Function is self-inverse"

-------------------------------------------------------------------
-- Proof Obligations
-------------------------------------------------------------------

||| A proof obligation for CNO verification
public export
data ProofObligation
  = ||| Must prove function is identity
    ProveIdentity String String  -- funcName, sortName
  | ||| Must prove composition is identity
    ProveComposition String String String  -- f, g, sort
  | ||| Must prove no information loss
    ProveInformationPreserving String String
  | ||| Custom proof obligation
    CustomObligation String

||| Convert obligation to theorem
public export
toTheorem : ProofObligation -> CNOTheorem
toTheorem (ProveIdentity f s) = identityTheorem f s
toTheorem (ProveComposition f g s) = compositionTheorem f g s
toTheorem (ProveInformationPreserving f s) = MkCNOTheorem
  ("info_preserving_" ++ f)
  ("(forall ((x " ++ s ++ ") (y " ++ s ++ ")) " ++
   "(=> (= (" ++ f ++ " x) (" ++ f ++ " y)) (= x y)))")
  "Function preserves information"
toTheorem (CustomObligation formula) = MkCNOTheorem "custom" formula "Custom property"

-------------------------------------------------------------------
-- Prover-Backed CNO Construction
-------------------------------------------------------------------

||| Result of proving a CNO property
public export
data ProverCNOResult a
  = ||| Successfully proved - CNO is valid
    ProvedCNO (CNO a) String  -- The CNO and proof hash
  | ||| Failed to prove
    FailedToProve String
  | ||| Proof timed out
    ProofTimeout

||| Create a CNO if proof succeeds
||| In practice, this would call out to echidna
public export
mkProvedCNO : (f : a -> a) ->
              (prf : (x : a) -> f x = x) ->
              (proofHash : String) ->
              ProverCNOResult a
mkProvedCNO f prf hash = ProvedCNO (MkCNO f prf) hash

-------------------------------------------------------------------
-- Proof-Carrying CNO
-------------------------------------------------------------------

||| A CNO that carries its external proof
public export
record ProofCarryingCNO (a : Type) where
  constructor MkProofCarryingCNO
  ||| The CNO
  cno : CNO a
  ||| Hash/reference to external proof
  proofRef : String
  ||| Which prover generated the proof
  prover : String
  ||| Proof obligations that were discharged
  discharged : List ProofObligation

||| Create a proof-carrying CNO
public export
withExternalProof : CNO a -> String -> String -> List ProofObligation -> ProofCarryingCNO a
withExternalProof = MkProofCarryingCNO

||| Extract the CNO (discarding proof metadata)
public export
extractCNO : ProofCarryingCNO a -> CNO a
extractCNO = cno

