-- SPDX-License-Identifier: MPL-2.0
||| Certified Null Operations
|||
||| A CNO is an operation that provably has no effect - the identity
||| transformation encoded as a type with proof obligations.
|||
||| This is the Idris2 implementation of concepts from the absolute-zero
||| formal verification project, bringing CNO proofs to dependent types.
module CNO

import public CNO.Core
import public CNO.Proof
import public CNO.Category
import public CNO.Composition
import public CNO.Reversible
import public CNO.Verified

%default total

-------------------------------------------------------------------
-- Quick Start
-------------------------------------------------------------------

||| Create a CNO from a function and proof it's identity
||| @ f The function to wrap
||| @ prf Proof that f is the identity function
public export
mkCNO : (f : a -> a) -> (prf : (x : a) -> f x = x) -> CNO a
mkCNO = MkCNO

||| The trivial CNO - literally the identity function
public export
trivial : CNO a
trivial = MkCNO Prelude.id (\x => Refl)

||| Compose two CNOs (the result is also a CNO)
public export
(.) : CNO a -> CNO a -> CNO a
(.) = compose

||| Apply a CNO to a value (always returns the same value)
public export
apply : CNO a -> a -> a
apply cno x = runCNO cno x

-------------------------------------------------------------------
-- Re-exports for convenience
-------------------------------------------------------------------

public export
CNOCategory : Category
CNOCategory = MkCategory CNO trivial compose
