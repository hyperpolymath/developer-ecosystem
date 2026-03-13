-- SPDX-License-Identifier: MPL-2.0
||| Z3 SMT solver bindings
|||
||| Z3 is a high-performance SMT (Satisfiability Modulo Theories) solver
||| from Microsoft Research. It supports various theories including:
||| - Linear/nonlinear arithmetic
||| - Bit-vectors
||| - Arrays
||| - Datatypes
||| - Quantifiers
|||
||| ## Example
|||
||| ```idris
||| import Echidna.Prover.Z3
|||
||| checkArithmetic : IO (Either ProverError ProofResult)
||| checkArithmetic = do
|||   let thm = theorem "(assert (forall ((x Int)) (= (+ x 0) x)))" SMTLib
|||   prove @{Z3Prover} thm
||| ```
module Echidna.Prover.Z3

import Echidna.Prover
import Echidna.FFI
import Data.String
import Data.List

%default total

||| Get Z3 version
export
z3Version : IO String
z3Version = z3VersionFFI

||| Check if Z3 is available
export
z3IsAvailable : IO Bool
z3IsAvailable = z3IsAvailableFFI

||| Check satisfiability using Z3
export
z3CheckSat : String -> IO (Either ProverError Bool)
z3CheckSat formula = z3CheckSatFFI formula

||| Prove a theorem using Z3
export
partial
z3Prove : Theorem -> IO (Either ProverError ProofResult)
z3Prove thm = do
  available <- z3IsAvailable
  if not available
    then pure $ Left (ProverNotAvailable Z3)
    else do
      -- Check format compatibility
      if not (supportsFormat Z3 thm.format)
        then pure $ Left (InvalidInput $ "Z3 does not support format: " ++ show thm.format)
        else z3ProveFFI thm

||| Z3 prover implementation
public export
partial
[Z3Prover] Prover Z3 where
  prove thm = z3Prove thm

  checkSat formula = z3CheckSat formula

  version = z3Version

  isAvailable = z3IsAvailable

||| Z3 configuration options
public export
record Z3Config where
  constructor MkZ3Config
  ||| Timeout in milliseconds
  timeout : Nat
  ||| Random seed for reproducibility
  seed : Nat
  ||| Enable model generation
  produceModels : Bool
  ||| Enable proof generation
  produceProofs : Bool
  ||| Enable unsat core generation
  produceUnsatCores : Bool

||| Default Z3 configuration
public export
defaultZ3Config : Z3Config
defaultZ3Config = MkZ3Config
  { timeout = 30000
  , seed = 0
  , produceModels = True
  , produceProofs = True
  , produceUnsatCores = False
  }

||| Prove with custom configuration
export
partial
z3ProveWithConfig : Z3Config -> Theorem -> IO (Either ProverError ProofResult)
z3ProveWithConfig config thm = z3ProveWithConfigFFI config thm

||| SMT-LIB builder helpers
namespace SMTLib
  ||| Assert a formula
  public export
  assert : String -> String
  assert formula = "(assert " ++ formula ++ ")"

  ||| Declare a constant
  public export
  declareConst : String -> String -> String
  declareConst name sort = "(declare-const " ++ name ++ " " ++ sort ++ ")"

  ||| Declare a function
  public export
  declareFun : String -> List String -> String -> String
  declareFun name args ret =
    "(declare-fun " ++ name ++ " (" ++ unwords args ++ ") " ++ ret ++ ")"

  ||| Check satisfiability command
  public export
  checkSatCmd : String
  checkSatCmd = "(check-sat)"

  ||| Get model command
  public export
  getModel : String
  getModel = "(get-model)"

  ||| For all quantifier
  public export
  smtForall : List (String, String) -> String -> String
  smtForall bindings body =
    let bindStr = unwords (map (\(n, s) => "(" ++ n ++ " " ++ s ++ ")") bindings)
    in "(forall (" ++ bindStr ++ ") " ++ body ++ ")"

  ||| Exists quantifier
  public export
  smtExists : List (String, String) -> String -> String
  smtExists bindings body =
    let bindStr = unwords (map (\(n, s) => "(" ++ n ++ " " ++ s ++ ")") bindings)
    in "(exists (" ++ bindStr ++ ") " ++ body ++ ")"

  ||| Implication
  public export
  smtImplies : String -> String -> String
  smtImplies a b = "(=> " ++ a ++ " " ++ b ++ ")"

  ||| Conjunction
  public export
  smtAnd : List String -> String
  smtAnd xs = "(and " ++ unwords xs ++ ")"

  ||| Disjunction
  public export
  smtOr : List String -> String
  smtOr xs = "(or " ++ unwords xs ++ ")"

  ||| Negation
  public export
  smtNot : String -> String
  smtNot x = "(not " ++ x ++ ")"

  ||| Equality
  public export
  smtEq : String -> String -> String
  smtEq a b = "(= " ++ a ++ " " ++ b ++ ")"
