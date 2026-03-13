-- SPDX-License-Identifier: MPL-2.0
||| Core CNO Tests
|||
||| These tests verify the fundamental CNO properties.
||| If this module compiles, the proofs are valid.
module TestCore

import CNO
import CNO.Core
import CNO.Proof
import CNO.Composition

%default total

-------------------------------------------------------------------
-- Test: Identity CNO
-------------------------------------------------------------------

||| The identity CNO returns its input
testIdCNO : (x : Nat) -> runCNO Core.idCNO x = x
testIdCNO x = cnoProof Core.idCNO x

||| Identity CNO with different types
testIdCNOString : (s : String) -> runCNO Core.idCNO s = s
testIdCNOString s = cnoProof Core.idCNO s

testIdCNOList : (xs : List a) -> runCNO Core.idCNO xs = xs
testIdCNOList xs = cnoProof Core.idCNO xs

-------------------------------------------------------------------
-- Test: Custom CNO Construction
-------------------------------------------------------------------

||| A trivial CNO that we construct manually
myCNO : CNO Nat
myCNO = MkCNO id (\x => Refl)

testMyCNO : (x : Nat) -> runCNO TestCore.myCNO x = x
testMyCNO x = cnoProof TestCore.myCNO x

-------------------------------------------------------------------
-- Test: CNO Composition
-------------------------------------------------------------------

||| Composing two CNOs yields a CNO
testComposition : (x : Nat) -> runCNO (compose Core.idCNO Core.idCNO) x = x
testComposition x = cnoProof (compose Core.idCNO Core.idCNO) x

||| Multiple compositions
testTripleComposition : (x : Nat) ->
                        runCNO (compose Core.idCNO (compose Core.idCNO Core.idCNO)) x = x
testTripleComposition x = cnoProof (compose Core.idCNO (compose Core.idCNO Core.idCNO)) x

-------------------------------------------------------------------
-- Test: N-ary Composition
-------------------------------------------------------------------

||| Compose 5 copies of idCNO
testComposeN : (x : Nat) -> runCNO (composeN 5 Core.idCNO) x = x
testComposeN x = cnoProof (composeN 5 Core.idCNO) x

||| Compose 0 copies yields idCNO
testComposeZero : (x : Nat) -> runCNO (composeN 0 Core.idCNO) x = x
testComposeZero x = cnoProof (composeN 0 Core.idCNO) x

-------------------------------------------------------------------
-- Test: Parallel Composition
-------------------------------------------------------------------

||| Parallel composition on pairs (using idCNO for same types)
testParallelNat : (x : Nat) -> (y : Nat) ->
                  runCNO (parallel Core.idCNO Core.idCNO) (x, y) = (x, y)
testParallelNat x y = cnoProof (parallel Core.idCNO Core.idCNO) (x, y)

-------------------------------------------------------------------
-- Test: Sum Composition
-------------------------------------------------------------------

||| Sum composition on Either (same types for simplicity)
testSumLeft : (x : Nat) ->
              runCNO (sumCNO {a=Nat} {b=Nat} Core.idCNO Core.idCNO) (Left x) = Left x
testSumLeft x = cnoProof (sumCNO {a=Nat} {b=Nat} Core.idCNO Core.idCNO) (Left x)

testSumRight : (y : Nat) ->
               runCNO (sumCNO {a=Nat} {b=Nat} Core.idCNO Core.idCNO) (Right y) = Right y
testSumRight y = cnoProof (sumCNO {a=Nat} {b=Nat} Core.idCNO Core.idCNO) (Right y)

-------------------------------------------------------------------
-- Test: CNOs are Equivalent
-------------------------------------------------------------------

||| Any two CNOs produce the same result
testEquivalence : (c1, c2 : CNO Nat) -> (x : Nat) ->
                  runCNO c1 x = runCNO c2 x
testEquivalence c1 c2 x = cnosEquivalent c1 c2 x
