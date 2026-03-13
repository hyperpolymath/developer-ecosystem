-- SPDX-License-Identifier: MPL-2.0
||| CNO Proof Types
|||
||| Types and lemmas for working with CNO proofs.
||| Provides machinery for constructing and composing identity proofs.
module CNO.Proof

import CNO.Core

%default total

-------------------------------------------------------------------
-- Proof Types (using records instead of type aliases for clarity)
-------------------------------------------------------------------

||| A proof that a function is the identity
||| We use a record wrapper for better type inference
public export
record IdentityProof (a : Type) (f : a -> a) where
  constructor MkIdentityProof
  runIdentityProof : (x : a) -> f x = x

||| A proof that two functions compose to identity
public export
record ComposeProof (a : Type) (f : a -> a) (g : a -> a) where
  constructor MkComposeProof
  runComposeProof : (x : a) -> f (g x) = x

||| A proof that a function is its own inverse
public export
record InverseProof (a : Type) (f : a -> a) where
  constructor MkInverseProof
  runInverseProof : (x : a) -> f (f x) = x

-------------------------------------------------------------------
-- Proof Constructors
-------------------------------------------------------------------

||| The identity function is identity (reflexivity)
public export
idIsIdentity : IdentityProof a Prelude.id
idIsIdentity = MkIdentityProof (\x => Refl)

-------------------------------------------------------------------
-- Proof Combinators
-------------------------------------------------------------------

||| If f is identity and g is identity, f . g is identity
public export
composeIdentity : IdentityProof a f -> IdentityProof a g -> IdentityProof a (f . g)
composeIdentity pf pg = MkIdentityProof prover
  where
    prover : (x : a) -> f (g x) = x
    prover x =
      let step1 = cong f (runIdentityProof pg x)
          step2 = runIdentityProof pf x
      in trans step1 step2

||| If f is identity, applying it twice is still identity
public export
doubleIdentity : IdentityProof a f -> IdentityProof a (f . f)
doubleIdentity pf = composeIdentity pf pf

-------------------------------------------------------------------
-- CNO from Proofs
-------------------------------------------------------------------

||| Construct a CNO from an identity proof record
public export
fromIdentityProof : (f : a -> a) -> IdentityProof a f -> CNO a
fromIdentityProof f pf = MkCNO f (runIdentityProof pf)

||| Extract the identity proof from a CNO as a record
public export
CNOIdentityProof : (cno : CNO a) -> IdentityProof a (runCNO cno)
CNOIdentityProof cno = MkIdentityProof (cnoProof cno)

-------------------------------------------------------------------
-- Proof Witnesses
-------------------------------------------------------------------

||| Witness that a CNO has been verified
public export
data CNOWitness : CNO a -> Type where
  ||| A CNO is witnessed by its internal proof
  Witnessed : (cno : CNO a) -> CNOWitness cno

||| Extract witness from any CNO (always succeeds since CNO contains proof)
public export
witness : (cno : CNO a) -> CNOWitness cno
witness cno = Witnessed cno
