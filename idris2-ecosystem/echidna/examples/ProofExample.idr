-- SPDX-License-Identifier: MPL-2.0
||| Proof Example
|||
||| Demonstrates how to use echidna to prove theorems.
module Examples.ProofExample

import Echidna
import Echidna.Prover
import Echidna.Prover.Z3

%default total

-------------------------------------------------------------------
-- Example 1: Simple SMT-LIB Theorem
-------------------------------------------------------------------

||| A simple arithmetic theorem
simpleTheorem : Theorem
simpleTheorem = MkTheorem
  "add_commutative"
  "(forall ((x Int) (y Int)) (= (+ x y) (+ y x)))"
  SMTLib

||| Prove the theorem (IO action)
proveSimple : IO (Either ProverError ProofResult)
proveSimple = prove @{Z3Prover} simpleTheorem

-------------------------------------------------------------------
-- Example 2: Using SMT-LIB Builder
-------------------------------------------------------------------

||| Build a theorem using helpers
builtTheorem : Theorem
builtTheorem = MkTheorem
  "add_identity"
  (SMTLib.forall [("x", "Int")] (SMTLib.equals "(+ x 0)" "x"))
  SMTLib

-------------------------------------------------------------------
-- Example 3: Satisfiability Check
-------------------------------------------------------------------

||| Check if a formula is satisfiable
satCheck : IO (Either ProverError Bool)
satCheck = checkSat @{Z3Prover} "(and (> x 0) (< x 10))"

-------------------------------------------------------------------
-- Example 4: Multi-Prover Strategy
-------------------------------------------------------------------

||| Try multiple provers
tryMultiple : Theorem -> IO (Either ProverError ProofResult)
tryMultiple thm = do
  -- Try Z3 first
  z3Result <- prove @{Z3Prover} thm
  case z3Result of
    Right proof => pure (Right proof)
    Left _ => do
      -- Could try other provers here
      pure (Left (ProverError "All provers failed"))

-------------------------------------------------------------------
-- Example 5: Complex Theorem
-------------------------------------------------------------------

||| A more complex theorem about lists
listTheorem : Theorem
listTheorem = MkTheorem
  "append_nil_identity"
  """
  (declare-sort List 0)
  (declare-fun nil () List)
  (declare-fun append (List List) List)
  (assert (forall ((xs List)) (= (append xs nil) xs)))
  (check-sat)
  """
  SMTLib

-------------------------------------------------------------------
-- Example 6: Prover Configuration
-------------------------------------------------------------------

||| Configure echidna with custom settings
customConfig : EchidnaConfig
customConfig = MkConfig
  { host = "localhost"
  , port = 8080
  , timeout = 30000  -- 30 seconds
  , useNeural = True
  , aspects = [Algebraic, SetTheoretic]
  }

||| Create a session with custom config
customSession : IO (Either SessionError Session)
customSession = createSession customConfig

-------------------------------------------------------------------
-- Example 7: Aspect-Tagged Proofs
-------------------------------------------------------------------

||| Tag theorems with mathematical aspects
algebraTheorem : Theorem
algebraTheorem = MkTheorem
  "group_identity"
  "(forall ((x G)) (= (op x e) x))"
  SMTLib

||| Request specific aspect from proof
proofWithAspects : Theorem -> List Aspect -> IO (Either ProverError ProofResult)
proofWithAspects thm aspects = prove @{Z3Prover} thm

