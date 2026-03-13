-- SPDX-License-Identifier: MPL-2.0
||| Reversible CNOs
|||
||| CNOs are inherently reversible since they're identity functions.
||| This module provides the interface for working with reversibility
||| and connects to the broader aletheia reversible operations theory.
module CNO.Reversible

import CNO.Core
import CNO.Proof

%default total

-------------------------------------------------------------------
-- Reversibility Types
-------------------------------------------------------------------

||| A reversible operation (bidirectional transformation)
||| For CNOs, forward = backward = identity
public export
record Reversible a where
  constructor MkReversible
  forward : a -> a
  backward : a -> a
  forwardBackward : (x : a) -> backward (forward x) = x
  backwardForward : (x : a) -> forward (backward x) = x

||| Every CNO is trivially reversible
public export
cnoReversible : CNO a -> Reversible a
cnoReversible (MkCNO f pf) = MkReversible f f
  (\x => trans (pf (f x)) (pf x))
  (\x => trans (pf (f x)) (pf x))

-------------------------------------------------------------------
-- Inverse
-------------------------------------------------------------------

||| The inverse of a CNO is itself (since it's identity)
public export
inverse : CNO a -> CNO a
inverse cno = cno

||| Proof that inverse is correct
public export
inverseCorrect : (cno : CNO a) -> (x : a) ->
                 runCNO (inverse cno) (runCNO cno x) = x
inverseCorrect cno x = trans (cnoProof cno _) (cnoProof cno x)

-------------------------------------------------------------------
-- Round-Trip Properties
-------------------------------------------------------------------

||| Applying a CNO and its inverse gives the original
public export
roundTrip : (cno : CNO a) -> (x : a) ->
            runCNO cno (runCNO (inverse cno) x) = x
roundTrip cno x = trans (cnoProof cno _) (cnoProof cno x)

||| A CNO is idempotent (applying twice = applying once = identity)
public export
idempotent : (cno : CNO a) -> (x : a) ->
             runCNO cno (runCNO cno x) = runCNO cno x
idempotent cno x = cong (runCNO cno) (cnoProof cno x)

-------------------------------------------------------------------
-- Reversible Composition
-------------------------------------------------------------------

||| Compose two reversibles
public export
composeReversible : Reversible a -> Reversible a -> Reversible a
composeReversible r1 r2 = MkReversible
  (r1.forward . r2.forward)
  (r2.backward . r1.backward)
  (\x => trans (cong r2.backward (r1.forwardBackward _)) (r2.forwardBackward x))
  (\x => trans (cong r1.forward (r2.backwardForward _)) (r1.backwardForward x))

-------------------------------------------------------------------
-- Lens-like Operations
-------------------------------------------------------------------

||| A CNO viewed as a lens where get and set are identity
public export
record CNOLens a where
  constructor MkCNOLens
  underlying : CNO a

||| Get (identity)
public export
get : CNOLens a -> a -> a
get lens = runCNO lens.underlying

||| Set (identity)
public export
set : CNOLens a -> a -> a -> a
set lens _ x = x  -- set ignores the "new value" since CNO is identity

||| Lens laws hold trivially for CNO lenses
public export
getLens : (lens : CNOLens a) -> (x : a) -> get lens x = x
getLens lens x = cnoProof lens.underlying x

-------------------------------------------------------------------
-- Information Preservation
-------------------------------------------------------------------

||| A CNO preserves all information (no information loss)
public export
0 InformationPreserving : CNO a -> Type
InformationPreserving cno = (x, y : a) -> runCNO cno x = runCNO cno y -> x = y

||| Proof that all CNOs preserve information
public export
cnoPreservesInfo : (cno : CNO a) -> InformationPreserving cno
cnoPreservesInfo cno x y eq =
  trans (sym (cnoProof cno x)) (trans eq (cnoProof cno y))

