-- SPDX-License-Identifier: MPL-2.0
||| Unified prover interface for ECHIDNA's 12 theorem provers
|||
||| This module provides type-safe access to:
||| - SMT Solvers: Z3, CVC5
||| - Dependent Type Provers: Agda, Coq/Rocq, Lean 4
||| - Classical Provers: Isabelle, HOL Light, HOL4, Mizar
||| - First-Order ATP: Vampire, E Prover
||| - Model Checkers: TLC (TLA+), Alloy
module Echidna.Prover

import Data.List
import Data.String

%default total

||| Supported theorem provers
public export
data ProverKind
  = Z3         -- SMT solver
  | CVC5       -- SMT solver
  | Agda       -- Dependent type theory
  | Coq        -- Interactive theorem prover (Rocq)
  | Lean4      -- Functional programming and proving
  | Isabelle   -- Higher-order logic
  | Metamath   -- Plain text verifier
  | HOLLight   -- Classical higher-order logic
  | Mizar      -- Mathematical vernacular
  | PVS        -- Specification and verification
  | ACL2       -- Applicative Common Lisp
  | HOL4       -- Higher-order logic
  | Vampire    -- First-order ATP
  | EProver    -- First-order ATP
  | TLC        -- TLA+ model checker
  | Alloy      -- Relational model checker

public export
Show ProverKind where
  show Z3       = "Z3"
  show CVC5     = "CVC5"
  show Agda     = "Agda"
  show Coq      = "Coq"
  show Lean4    = "Lean4"
  show Isabelle = "Isabelle"
  show Metamath = "Metamath"
  show HOLLight = "HOL Light"
  show Mizar    = "Mizar"
  show PVS      = "PVS"
  show ACL2     = "ACL2"
  show HOL4     = "HOL4"
  show Vampire  = "Vampire"
  show EProver  = "E Prover"
  show TLC      = "TLC"
  show Alloy    = "Alloy"

public export
Eq ProverKind where
  Z3 == Z3 = True
  CVC5 == CVC5 = True
  Agda == Agda = True
  Coq == Coq = True
  Lean4 == Lean4 = True
  Isabelle == Isabelle = True
  Metamath == Metamath = True
  HOLLight == HOLLight = True
  Mizar == Mizar = True
  PVS == PVS = True
  ACL2 == ACL2 = True
  HOL4 == HOL4 = True
  Vampire == Vampire = True
  EProver == EProver = True
  TLC == TLC = True
  Alloy == Alloy = True
  _ == _ = False

||| Input format for theorems
public export
data TheoremFormat
  = SMTLib      -- SMT-LIB 2 format
  | TPTP        -- TPTP format for ATP
  | NaturalLang -- Natural language (for neural translation)
  | Idris2      -- Idris2 type signature
  | Lean4Syntax -- Lean 4 syntax
  | CoqSyntax   -- Coq/Gallina syntax
  | AgdaSyntax  -- Agda syntax
  | TLAPlus     -- TLA+ specification
  | AlloySyntax -- Alloy specification

public export
Show TheoremFormat where
  show SMTLib      = "SMT-LIB"
  show TPTP        = "TPTP"
  show NaturalLang = "Natural Language"
  show Idris2      = "Idris2"
  show Lean4Syntax = "Lean4"
  show CoqSyntax   = "Coq"
  show AgdaSyntax  = "Agda"
  show TLAPlus     = "TLA+"
  show AlloySyntax = "Alloy"

public export
Eq TheoremFormat where
  SMTLib == SMTLib = True
  TPTP == TPTP = True
  NaturalLang == NaturalLang = True
  Idris2 == Idris2 = True
  Lean4Syntax == Lean4Syntax = True
  CoqSyntax == CoqSyntax = True
  AgdaSyntax == AgdaSyntax = True
  TLAPlus == TLAPlus = True
  AlloySyntax == AlloySyntax = True
  _ == _ = False

||| A theorem to be proven
public export
record Theorem where
  constructor MkTheorem
  ||| The theorem statement
  statement : String
  ||| The input format
  format : TheoremFormat
  ||| Optional context/dependencies
  context : Maybe String
  ||| Optional hints for proof search
  hints : List String

||| Create a simple theorem
public export
theorem : String -> TheoremFormat -> Theorem
theorem stmt fmt = MkTheorem stmt fmt Nothing []

||| Prover errors
public export
data ProverError
  = Timeout
  | Unsatisfiable
  | Unknown String
  | ParseError String
  | ConnectionError String
  | ProverNotAvailable ProverKind
  | InvalidInput String

public export
Show ProverError where
  show Timeout = "Prover timeout"
  show Unsatisfiable = "Theorem is unsatisfiable"
  show (Unknown msg) = "Unknown: " ++ msg
  show (ParseError msg) = "Parse error: " ++ msg
  show (ConnectionError msg) = "Connection error: " ++ msg
  show (ProverNotAvailable p) = "Prover not available: " ++ show p
  show (InvalidInput msg) = "Invalid input: " ++ msg

||| Proof status
public export
data ProofStatus
  = Proven        -- Theorem proven
  | Counterexample String  -- Counterexample found
  | Inconclusive  -- Could not determine
  | ProofError ProverError

public export
Show ProofStatus where
  show Proven = "Proven"
  show (Counterexample ce) = "Counterexample: " ++ ce
  show Inconclusive = "Inconclusive"
  show (ProofError e) = "Error: " ++ show e

||| Result of a proof attempt
public export
record ProofResult where
  constructor MkProofResult
  ||| Which prover was used
  prover : ProverKind
  ||| The theorem that was proven
  theorem : Theorem
  ||| Proof status
  status : ProofStatus
  ||| Proof term/witness (if available)
  proofTerm : Maybe String
  ||| Time taken in milliseconds
  timeTaken : Nat
  ||| Confidence score (0.0 to 1.0) from neural component
  confidence : Double

||| Check if a proof was successful
public export
isProven : ProofResult -> Bool
isProven r = case r.status of
  Proven => True
  _ => False

||| Interface for theorem provers
public export
interface Prover (p : ProverKind) where
  ||| Prove a theorem
  prove : Theorem -> IO (Either ProverError ProofResult)

  ||| Check satisfiability (for SMT solvers)
  checkSat : String -> IO (Either ProverError Bool)

  ||| Get prover version
  version : IO String

  ||| Check if prover is available
  isAvailable : IO Bool

||| Supported formats for each prover
public export
supportedFormats : ProverKind -> List TheoremFormat
supportedFormats Z3       = [SMTLib, NaturalLang]
supportedFormats CVC5     = [SMTLib, NaturalLang]
supportedFormats Agda     = [AgdaSyntax, NaturalLang]
supportedFormats Coq      = [CoqSyntax, NaturalLang]
supportedFormats Lean4    = [Lean4Syntax, NaturalLang]
supportedFormats Isabelle = [NaturalLang]  -- Isabelle/Isar
supportedFormats Metamath = [NaturalLang]
supportedFormats HOLLight = [NaturalLang]
supportedFormats Mizar    = [NaturalLang]
supportedFormats PVS      = [NaturalLang]
supportedFormats ACL2     = [NaturalLang]
supportedFormats HOL4     = [NaturalLang]
supportedFormats Vampire  = [TPTP, NaturalLang]
supportedFormats EProver  = [TPTP, NaturalLang]
supportedFormats TLC      = [TLAPlus, NaturalLang]
supportedFormats Alloy    = [AlloySyntax, NaturalLang]

||| Check if a prover supports a format
public export
supportsFormat : ProverKind -> TheoremFormat -> Bool
supportsFormat p f = f `elem` supportedFormats p
