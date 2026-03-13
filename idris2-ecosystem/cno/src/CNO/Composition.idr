-- SPDX-License-Identifier: MPL-2.0
||| CNO Composition
|||
||| Composition of CNOs preserves the CNO property.
||| Since CNOs are identity functions, composition is trivial
||| but the proofs are instructive.
module CNO.Composition

import CNO.Core
import CNO.Proof

%default total

-------------------------------------------------------------------
-- Helper to compose raw proofs
-------------------------------------------------------------------

||| Compose two raw identity proofs
composeProofs : {f, g : a -> a} ->
                ((x : a) -> f x = x) ->
                ((x : a) -> g x = x) ->
                (x : a) -> f (g x) = x
composeProofs pf pg x =
  let step1 = cong f (pg x)
      step2 = pf x
  in trans step1 step2

-------------------------------------------------------------------
-- Basic Composition
-------------------------------------------------------------------

||| Compose two CNOs into a single CNO
||| The composed CNO is also identity (id . id = id)
public export
compose : CNO a -> CNO a -> CNO a
compose (MkCNO f pf) (MkCNO g pg) =
  MkCNO (f . g) (composeProofs pf pg)

-- Forward composition (left to right)
public export
infixr 9 >>>

public export
(>>>) : CNO a -> CNO a -> CNO a
c1 >>> c2 = compose c2 c1

-- Backward composition (right to left)
public export
infixr 9 <<<

public export
(<<<) : CNO a -> CNO a -> CNO a
(<<<) = compose

-------------------------------------------------------------------
-- Composition Laws
-------------------------------------------------------------------

||| All CNOs return their input
public export
cnoReturnsInput : (cno : CNO a) -> (x : a) -> runCNO cno x = x
cnoReturnsInput cno x = cnoProof cno x

||| Any two CNOs give the same result (both return input)
public export
cnosEquivalent : (c1, c2 : CNO a) -> (x : a) -> runCNO c1 x = runCNO c2 x
cnosEquivalent c1 c2 x = trans (cnoProof c1 x) (sym (cnoProof c2 x))

-------------------------------------------------------------------
-- N-ary Composition
-------------------------------------------------------------------

||| Compose a list of CNOs
public export
composeAll : List (CNO a) -> CNO a
composeAll [] = idCNO
composeAll (c :: cs) = compose c (composeAll cs)

||| Compose n copies of a CNO
public export
composeN : Nat -> CNO a -> CNO a
composeN Z cno = idCNO
composeN (S n) cno = compose cno (composeN n cno)

||| Composing any number of CNOs still gives identity
public export
composeNIsId : (n : Nat) -> (cno : CNO a) -> (x : a) ->
               runCNO (composeN n cno) x = x
composeNIsId n cno x = cnoProof (composeN n cno) x

-------------------------------------------------------------------
-- Parallel Composition (Product)
-------------------------------------------------------------------

||| Compose CNOs in parallel on a pair type
public export
parallel : CNO a -> CNO b -> CNO (a, b)
parallel (MkCNO f pf) (MkCNO g pg) =
  MkCNO (\(x, y) => (f x, g y))
        (\(x, y) => rewrite pf x in rewrite pg y in Refl)

-- Infix parallel composition
public export
infixr 3 ***

public export
(***) : CNO a -> CNO b -> CNO (a, b)
(***) = parallel

-------------------------------------------------------------------
-- Sum Composition (Either)
-------------------------------------------------------------------

||| Compose CNOs on sum types
public export
sumCNO : CNO a -> CNO b -> CNO (Either a b)
sumCNO (MkCNO f pf) (MkCNO g pg) =
  MkCNO (either (Left . f) (Right . g))
        (\case
           Left x => cong Left (pf x)
           Right y => cong Right (pg y))

-- Infix sum composition
public export
infixr 2 +++

public export
(+++) : CNO a -> CNO b -> CNO (Either a b)
(+++) = sumCNO
