-- SPDX-License-Identifier: MPL-2.0
||| Foreign Function Interface to ECHIDNA Rust library
|||
||| This module provides the low-level FFI bindings to the ECHIDNA
||| shared library. Users should prefer the high-level interfaces
||| in Echidna.Prover.* modules.
module Echidna.FFI

import Echidna.Prover
import System.FFI
import Data.Maybe

%default total

-- FFI support library name
%foreign "C:echidna_init,libechidna"
prim__echidna_init : PrimIO Int

%foreign "C:echidna_shutdown,libechidna"
prim__echidna_shutdown : PrimIO ()

%foreign "C:echidna_version,libechidna"
prim__echidna_version : PrimIO String

-- Z3 FFI
%foreign "C:z3_is_available,libechidna"
prim__z3_is_available : PrimIO Int

%foreign "C:z3_version,libechidna"
prim__z3_version : PrimIO String

%foreign "C:z3_prove,libechidna"
prim__z3_prove : String -> String -> PrimIO String

%foreign "C:z3_check_sat,libechidna"
prim__z3_check_sat : String -> PrimIO Int

-- CVC5 FFI
%foreign "C:cvc5_is_available,libechidna"
prim__cvc5_is_available : PrimIO Int

%foreign "C:cvc5_version,libechidna"
prim__cvc5_version : PrimIO String

%foreign "C:cvc5_prove,libechidna"
prim__cvc5_prove : String -> String -> PrimIO String

-- Generic prover FFI (routes through ECHIDNA's prover abstraction)
%foreign "C:echidna_prove,libechidna"
prim__echidna_prove : String -> String -> String -> PrimIO String

%foreign "C:echidna_verify,libechidna"
prim__echidna_verify : String -> String -> PrimIO Int

||| Initialize ECHIDNA library
export
echidnaInit : IO Bool
echidnaInit = do
  result <- primIO prim__echidna_init
  pure (result == 0)

||| Shutdown ECHIDNA library
export
echidnaShutdown : IO ()
echidnaShutdown = primIO prim__echidna_shutdown

||| Get ECHIDNA version
export
echidnaVersionFFI : IO String
echidnaVersionFFI = primIO prim__echidna_version

||| Check if Z3 is available
export
z3IsAvailableFFI : IO Bool
z3IsAvailableFFI = do
  result <- primIO prim__z3_is_available
  pure (result /= 0)

||| Get Z3 version
export
z3VersionFFI : IO String
z3VersionFFI = primIO prim__z3_version

||| Check if needle is contained in haystack
partial
isInfixOf : String -> String -> Bool
isInfixOf needle haystack =
  let needleLen = length needle
      haystackLen = length haystack
  in if needleLen > haystackLen
       then False
       else checkAt 0 needleLen haystackLen needle haystack
  where
    checkAt : Nat -> Nat -> Nat -> String -> String -> Bool
    checkAt idx needleLen haystackLen needle haystack =
      if idx + needleLen > haystackLen
        then False
        else if substr idx needleLen haystack == needle
          then True
          else checkAt (S idx) needleLen haystackLen needle haystack

||| Parse proof result from JSON response
partial
parseProofResult : ProverKind -> Theorem -> String -> Either ProverError ProofResult
parseProofResult prover thm response =
  -- TODO: Implement proper JSON parsing
  -- For now, check for simple status indicators
  if "proven" `isInfixOf` response
    then Right $ MkProofResult prover thm Proven (Just response) 0 1.0
    else if "counterexample" `isInfixOf` response
      then Right $ MkProofResult prover thm (Counterexample response) Nothing 0 0.0
      else if "timeout" `isInfixOf` response
        then Left Timeout
        else Right $ MkProofResult prover thm Inconclusive Nothing 0 0.5

||| Prove using Z3 via FFI
export
partial
z3ProveFFI : Theorem -> IO (Either ProverError ProofResult)
z3ProveFFI thm = do
  response <- primIO $ prim__z3_prove thm.statement (show thm.format)
  pure $ parseProofResult Z3 thm response

||| Check satisfiability using Z3 via FFI
export
z3CheckSatFFI : String -> IO (Either ProverError Bool)
z3CheckSatFFI formula = do
  result <- primIO $ prim__z3_check_sat formula
  pure $ case result of
    0 => Right False  -- UNSAT
    1 => Right True   -- SAT
    _ => Left (Unknown "Unknown satisfiability result")

||| Prove with custom Z3 configuration via FFI
export
partial
z3ProveWithConfigFFI : config -> Theorem -> IO (Either ProverError ProofResult)
z3ProveWithConfigFFI config thm = do
  -- TODO: Pass configuration to FFI
  z3ProveFFI thm

||| Generic prove via ECHIDNA's prover abstraction
export
partial
echidnaProveFFI : ProverKind -> Theorem -> IO (Either ProverError ProofResult)
echidnaProveFFI prover thm = do
  response <- primIO $ prim__echidna_prove (show prover) thm.statement (show thm.format)
  pure $ parseProofResult prover thm response

||| Verify an existing proof via FFI
export
echidnaVerifyFFI : ProofResult -> IO (Either ProverError Bool)
echidnaVerifyFFI result = do
  case result.proofTerm of
    Nothing => pure $ Left (InvalidInput "No proof term to verify")
    Just term => do
      verified <- primIO $ prim__echidna_verify term (show result.prover)
      pure $ Right (verified /= 0)
