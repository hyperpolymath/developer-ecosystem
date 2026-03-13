-- SPDX-License-Identifier: MPL-2.0
||| Echidna Prover Tests
|||
||| These tests verify prover type construction.
||| If this module compiles, the types are correctly defined.
module TestProver

import Echidna
import Echidna.Prover
import Echidna.Prover.Z3
import Echidna.Prover.CVC5
import Echidna.Prover.Lean

%default total

-------------------------------------------------------------------
-- Test: ProverKind Enumeration
-------------------------------------------------------------------

||| All prover kinds are distinct
testProverKinds : List ProverKind
testProverKinds = [Z3, CVC5, Lean4, Coq, Agda, Isabelle, HOLLight, Mizar, Vampire, EProver, TLC, Alloy]

-------------------------------------------------------------------
-- Test: Theorem Construction
-------------------------------------------------------------------

||| Create a simple SMT-LIB theorem
testTheorem : Theorem
testTheorem = MkTheorem "(assert (= 1 1))" SMTLib Nothing []

||| Theorem with context
testNamedTheorem : Theorem
testNamedTheorem = MkTheorem "(assert (> x 0))" SMTLib (Just "positive-x context") ["x"]

||| TLA+ theorem
testTLATheorem : Theorem
testTLATheorem = MkTheorem "THEOREM Spec => Safety" TLAPlus (Just "safety") []

||| Using the helper function
testSimpleTheorem : Theorem
testSimpleTheorem = theorem "(assert true)" SMTLib

-------------------------------------------------------------------
-- Test: TheoremFormat
-------------------------------------------------------------------

||| Core formats
testFormats : List TheoremFormat
testFormats = [SMTLib, TPTP, TLAPlus, Lean4Syntax, CoqSyntax, AgdaSyntax, NaturalLang, AlloySyntax, Idris2]

-------------------------------------------------------------------
-- Test: ProverError Types
-------------------------------------------------------------------

||| Error type coverage
testProverErrors : List ProverError
testProverErrors =
  [ ParseError "test"
  , ConnectionError "test"
  , ProverNotAvailable Z3
  , InvalidInput "test"
  , Unknown "test"
  , Timeout
  , Unsatisfiable
  ]

-------------------------------------------------------------------
-- Test: Theorem Fields
-------------------------------------------------------------------

||| Access theorem statement
testTheoremStatement : String
testTheoremStatement = statement testTheorem

||| Access theorem format
testTheoremFormat : TheoremFormat
testTheoremFormat = format testTheorem

||| Access theorem context
testTheoremContext : Maybe String
testTheoremContext = context testTheorem

||| Access theorem hints
testTheoremHints : List String
testTheoremHints = hints testTheorem

-------------------------------------------------------------------
-- Test: ProofStatus
-------------------------------------------------------------------

||| Proof status values
testProofStatuses : List ProofStatus
testProofStatuses =
  [ Proven
  , Counterexample "x = -1"
  , Inconclusive
  , ProofError Timeout
  ]

-------------------------------------------------------------------
-- Test: ProofResult Construction
-------------------------------------------------------------------

||| Create a proof result
testProofResult : ProofResult
testProofResult = MkProofResult
  Z3                          -- prover
  testTheorem                 -- theorem
  Proven                      -- status
  (Just "(proof ...)")        -- proofTerm
  100                         -- timeTaken (ms)
  0.95                        -- confidence

||| Check if proven
testIsProven : Bool
testIsProven = isProven testProofResult

-------------------------------------------------------------------
-- Test: Supported Formats
-------------------------------------------------------------------

||| Z3 supports SMT-LIB
testZ3Formats : List TheoremFormat
testZ3Formats = supportedFormats Z3

||| Check format support
testSupportsFormat : Bool
testSupportsFormat = supportsFormat Z3 SMTLib

