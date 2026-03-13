-- SPDX-License-Identifier: MPL-2.0
||| Echidna Examples
|||
||| Practical examples of using Echidna's theorem prover interface.
||| These examples demonstrate common proof patterns and prover usage.
module Echidna.Examples

import Echidna
import Echidna.Prover

%default total

-------------------------------------------------------------------
-- Basic Theorem Construction
-------------------------------------------------------------------

||| Simple SMT-LIB theorem asserting equality
public export
equalityTheorem : Theorem
equalityTheorem = MkTheorem
  "(assert (= (+ 1 1) 2))"
  SMTLib
  Nothing
  []

||| Arithmetic theorem with hints
public export
arithmeticTheorem : Theorem
arithmeticTheorem = MkTheorem
  "(assert (forall ((x Int)) (= (+ x 0) x)))"
  SMTLib
  (Just "integer arithmetic")
  ["identity", "additive"]

||| Using the helper function for quick theorems
public export
quickTheorem : Theorem
quickTheorem = theorem "(assert true)" SMTLib

-------------------------------------------------------------------
-- TPTP Format (First-Order ATP)
-------------------------------------------------------------------

||| A TPTP theorem for first-order provers
public export
tptpTheorem : Theorem
tptpTheorem = MkTheorem
  "fof(identity, axiom, ![X]: (add(X, zero) = X))."
  TPTP
  (Just "arithmetic")
  []

||| TPTP theorem for transitive relations
public export
transitivityTheorem : Theorem
transitivityTheorem = MkTheorem
  "fof(trans, conjecture, ![X,Y,Z]: ((less(X,Y) & less(Y,Z)) => less(X,Z)))."
  TPTP
  (Just "order theory")
  ["transitivity"]

-------------------------------------------------------------------
-- TLA+ Specifications
-------------------------------------------------------------------

||| A TLA+ safety property
public export
tlaSafetyTheorem : Theorem
tlaSafetyTheorem = MkTheorem
  "THEOREM Spec => []TypeInvariant"
  TLAPlus
  (Just "system specification")
  ["invariant", "safety"]

||| TLA+ liveness property
public export
tlaLivenessTheorem : Theorem
tlaLivenessTheorem = MkTheorem
  "THEOREM Spec => <>(response = TRUE)"
  TLAPlus
  (Just "liveness")
  ["eventually"]

-------------------------------------------------------------------
-- Dependent Type Provers
-------------------------------------------------------------------

||| Lean4 syntax theorem
public export
lean4Theorem : Theorem
lean4Theorem = MkTheorem
  "theorem add_comm : forall a b : Nat, a + b = b + a"
  Lean4Syntax
  (Just "nat arithmetic")
  ["comm", "induction"]

||| Coq syntax theorem
public export
coqTheorem : Theorem
coqTheorem = MkTheorem
  "Theorem plus_n_O : forall n : nat, n = n + 0."
  CoqSyntax
  (Just "Peano arithmetic")
  ["reflexivity"]

||| Agda syntax theorem
public export
agdaTheorem : Theorem
agdaTheorem = MkTheorem
  "+-identityʳ : (n : Nat) -> n + zero == n"
  AgdaSyntax
  (Just "natural numbers")
  ["identity"]

-------------------------------------------------------------------
-- Natural Language Theorems
-------------------------------------------------------------------

||| Natural language theorem (for neural translation)
public export
naturalLangTheorem : Theorem
naturalLangTheorem = MkTheorem
  "For all natural numbers n, n plus zero equals n"
  NaturalLang
  (Just "elementary arithmetic")
  ["identity", "zero"]

||| More complex natural language statement
public export
naturalLangComplex : Theorem
naturalLangComplex = MkTheorem
  "If a function f is continuous on [a,b] and differentiable on (a,b), then there exists c in (a,b) such that f'(c) = (f(b) - f(a)) / (b - a)"
  NaturalLang
  (Just "mean value theorem")
  ["calculus", "continuity", "differentiability"]

-------------------------------------------------------------------
-- Proof Results and Status
-------------------------------------------------------------------

||| Example of a successful proof result
public export
exampleSuccessResult : ProofResult
exampleSuccessResult = MkProofResult
  Z3                                -- prover used
  equalityTheorem                   -- theorem
  Proven                            -- status
  (Just "(proof\n  (mp ...)\n)")    -- proof term
  42                                -- time in ms
  0.99                              -- confidence

||| Example of a counterexample result
public export
exampleCounterexample : ProofResult
exampleCounterexample = MkProofResult
  CVC5                                      -- prover
  (theorem "(assert (> 1 2))" SMTLib)       -- false theorem
  (Counterexample "1 = 1, 2 = 2, 1 <= 2")   -- counterexample
  Nothing                                   -- no proof
  15                                        -- time in ms
  0.0                                       -- no confidence

||| Example of a timeout result
public export
exampleTimeout : ProofResult
exampleTimeout = MkProofResult
  Vampire
  tptpTheorem
  (ProofError Timeout)
  Nothing
  30000
  0.0

-------------------------------------------------------------------
-- Format Checking
-------------------------------------------------------------------

||| Check if Z3 can handle our theorem format
public export
canZ3Handle : Theorem -> Bool
canZ3Handle thm = supportsFormat Z3 (format thm)

||| Check if any SMT solver can handle a theorem
public export
canSmtHandle : Theorem -> Bool
canSmtHandle thm = supportsFormat Z3 (format thm) || supportsFormat CVC5 (format thm)

||| Find all provers that support a format
public export
proversForFormat : TheoremFormat -> List ProverKind
proversForFormat fmt = filter (\p => supportsFormat p fmt)
  [Z3, CVC5, Lean4, Coq, Agda, Isabelle, HOLLight, Mizar, Vampire, EProver, TLC, Alloy]

-------------------------------------------------------------------
-- Prover Selection
-------------------------------------------------------------------

||| Select best prover for SMT-LIB
public export
bestSmtProver : ProverKind
bestSmtProver = Z3

||| Select best prover for TPTP (first-order)
public export
bestAtpProver : ProverKind
bestAtpProver = Vampire

||| Select best prover for dependent types
public export
bestDependentProver : ProverKind
bestDependentProver = Lean4

-------------------------------------------------------------------
-- Configuration Examples
-------------------------------------------------------------------

||| Fast configuration (short timeout, no neural)
public export
fastConfig : EchidnaConfig
fastConfig = MkConfig
  { host = "localhost"
  , port = 8080
  , timeout = 5000
  , useNeural = False
  , aspects = []
  }

||| Production configuration
public export
prodConfig : EchidnaConfig
prodConfig = MkConfig
  { host = "echidna.example.com"
  , port = 443
  , timeout = 60000
  , useNeural = True
  , aspects = []
  }

||| Local development configuration
public export
devConfig : EchidnaConfig
devConfig = defaultConfig

