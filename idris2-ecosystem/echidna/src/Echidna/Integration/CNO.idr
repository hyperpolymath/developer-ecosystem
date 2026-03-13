-- SPDX-License-Identifier: MPL-2.0
||| Integration with idris2-cno
|||
||| Use ECHIDNA theorem provers to verify CNO properties.
module Echidna.Integration.CNO

import Echidna
import Echidna.Prover
import Echidna.Prover.Z3

%default total

-------------------------------------------------------------------
-- CNO Theorem Templates
-------------------------------------------------------------------

||| Encode a CNO identity claim as SMT-LIB
||| Returns an SMT-LIB string asserting forall x. f(x) = x
public export
cnoIdentitySMTLib : (funcName : String) -> (sortName : String) -> String
cnoIdentitySMTLib funcName sortName =
  "(assert (forall ((x " ++ sortName ++ ")) (= (" ++ funcName ++ " x) x)))"

||| Encode a CNO composition claim as SMT-LIB
public export
cnoCompositionSMTLib : (f : String) -> (g : String) -> (sort : String) -> String
cnoCompositionSMTLib f g sort =
  "(assert (forall ((x " ++ sort ++ ")) (= (" ++ f ++ " (" ++ g ++ " x)) x)))"

||| Encode a CNO inverse claim as SMT-LIB
public export
cnoInverseSMTLib : (funcName : String) -> (sortName : String) -> String
cnoInverseSMTLib funcName sortName =
  "(assert (forall ((x " ++ sortName ++ ")) (= (" ++ funcName ++ " (" ++ funcName ++ " x)) x)))"

-------------------------------------------------------------------
-- CNO Theorem Creation
-------------------------------------------------------------------

||| Create a theorem for CNO identity property
public export
cnoIdentityTheorem : (funcName : String) -> (sortName : String) -> Theorem
cnoIdentityTheorem funcName sortName =
  MkTheorem (cnoIdentitySMTLib funcName sortName) SMTLib Nothing []

||| Create a theorem for CNO composition property
public export
cnoCompositionTheorem : (f : String) -> (g : String) -> (sort : String) -> Theorem
cnoCompositionTheorem f g sort =
  MkTheorem (cnoCompositionSMTLib f g sort) SMTLib Nothing []

-------------------------------------------------------------------
-- CNO Verification
-------------------------------------------------------------------

||| Prove that a function is a CNO using Z3
public export
partial
proveCNOIdentity : (funcName : String) ->
                   (sortName : String) ->
                   IO (Either ProverError ProofResult)
proveCNOIdentity funcName sortName =
  z3Prove (cnoIdentityTheorem funcName sortName)

||| Prove CNO composition preserves identity
public export
partial
proveCNOComposition : (f : String) -> (g : String) -> (sort : String) ->
                      IO (Either ProverError ProofResult)
proveCNOComposition f g sort =
  z3Prove (cnoCompositionTheorem f g sort)
