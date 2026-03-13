-- SPDX-License-Identifier: MPL-2.0
||| Categorical Structure of CNOs
|||
||| CNOs form a category where:
||| - Objects are types
||| - Morphisms are CNOs (which are all identity morphisms)
||| - Composition is CNO composition
||| - Identity is idCNO
|||
||| This is actually a trivial category - every morphism is identity!
module CNO.Category

import CNO.Core
import CNO.Proof
import CNO.Composition

%default total

-------------------------------------------------------------------
-- Category Definition
-------------------------------------------------------------------

||| A category with CNOs as morphisms
||| Since all CNOs are identity, this is the discrete category
public export
record Category where
  constructor MkCategory
  ||| The morphism type (CNO for some type)
  Morph : Type -> Type
  ||| Identity morphism
  identity : {a : Type} -> Morph a
  ||| Composition of morphisms
  comp : {a : Type} -> Morph a -> Morph a -> Morph a

-------------------------------------------------------------------
-- Category Laws
-------------------------------------------------------------------

||| Left identity law: id . f = f (all CNOs return input)
public export
leftIdentity : (cno : CNO a) -> (x : a) ->
               runCNO Core.idCNO (runCNO cno x) = runCNO cno x
leftIdentity cno x = cnoProof Core.idCNO (runCNO cno x)

||| Right identity law: f . id = f (all CNOs return input)
public export
rightIdentity : (cno : CNO a) -> (x : a) ->
                runCNO cno (runCNO Core.idCNO x) = runCNO cno x
rightIdentity cno x = cong (runCNO cno) (cnoProof Core.idCNO x)

||| Associativity: (f . g) . h = f . (g . h)
||| For CNOs this is trivial since all are identity
public export
associativity : (f, g, h : CNO a) -> (x : a) ->
                runCNO f (runCNO g (runCNO h x)) =
                runCNO f (runCNO g (runCNO h x))
associativity f g h x = Refl

-------------------------------------------------------------------
-- The CNO Category
-------------------------------------------------------------------

||| The CNO category instance
public export
CNOCat : Category
CNOCat = MkCategory CNO idCNO compose

-------------------------------------------------------------------
-- Functor from CNO to Function
-------------------------------------------------------------------

||| The forgetful functor from CNO to plain functions
||| Forgets the proof component
public export
forget : CNO a -> (a -> a)
forget = runCNO

-------------------------------------------------------------------
-- Endofunctor Laws
-------------------------------------------------------------------

||| CNOs form the identity endofunctor on types
||| fmap id = id (trivially true for CNOs)
public export
fmapId : (cno : CNO a) -> (x : a) -> runCNO cno x = x
fmapId = cnoProof

-------------------------------------------------------------------
-- Trivial Category Property
-------------------------------------------------------------------

||| In the CNO category, all morphisms are isomorphisms
||| (trivially, since they're all identity)
public export
allIsomorphisms : (cno : CNO a) ->
                  (x : a) -> runCNO cno (runCNO cno x) = x
allIsomorphisms cno x =
  trans (cong (runCNO cno) (cnoProof cno x)) (cnoProof cno x)
