-- SPDX-License-Identifier: MPL-2.0
||| Core CNO Types
|||
||| A Certified Null Operation (CNO) is a function bundled with a proof
||| that it is the identity function. This module defines the core type.
module CNO.Core

%default total

-------------------------------------------------------------------
-- The CNO Type
-------------------------------------------------------------------

||| A Certified Null Operation on type `a`
|||
||| A CNO wraps a function `a -> a` along with a proof that the function
||| is extensionally equal to the identity function. This means:
||| - The function can be applied
||| - The result is guaranteed to equal the input
||| - The compiler can verify this at compile time
|||
||| @ a The type the CNO operates on
public export
data CNO : Type -> Type where
  ||| Construct a CNO from a function and identity proof
  ||| @ f The function (must be identity)
  ||| @ prf Proof that f x = x for all x
  MkCNO : (f : a -> a) -> (prf : (x : a) -> f x = x) -> CNO a

-------------------------------------------------------------------
-- Extractors
-------------------------------------------------------------------

||| Extract the underlying function from a CNO
public export
runCNO : CNO a -> a -> a
runCNO (MkCNO f _) = f

||| Extract the identity proof from a CNO
public export
cnoProof : (cno : CNO a) -> (x : a) -> runCNO cno x = x
cnoProof (MkCNO _ prf) = prf

-------------------------------------------------------------------
-- The Identity CNO
-------------------------------------------------------------------

||| The canonical identity CNO
||| This is the simplest CNO - literally `id` with `Refl` as proof
public export
idCNO : CNO a
idCNO = MkCNO id (\x => Refl)

-------------------------------------------------------------------
-- CNO Equality
-------------------------------------------------------------------

||| Two CNOs are equal if their underlying functions are extensionally equal
||| (which they always are, since both are identity)
public export
cnoEq : (c1, c2 : CNO a) -> (x : a) -> runCNO c1 x = runCNO c2 x
cnoEq c1 c2 x = trans (cnoProof c1 x) (sym (cnoProof c2 x))

-------------------------------------------------------------------
-- Show Instance
-------------------------------------------------------------------

public export
Show (CNO a) where
  show _ = "<CNO: identity>"

-------------------------------------------------------------------
-- Decidable Equality (trivially true)
-------------------------------------------------------------------

||| Any two CNOs are behaviorally equivalent
public export
cnoBehavioralEq : (c1, c2 : CNO a) -> (x : a) -> runCNO c1 x = runCNO c2 x
cnoBehavioralEq = cnoEq

