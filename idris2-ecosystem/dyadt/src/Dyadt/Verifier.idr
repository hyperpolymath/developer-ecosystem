-- SPDX-License-Identifier: MPL-2.0
||| The Verifier: Checking Claims
|||
||| This module provides the machinery for actually verifying claims,
||| either at compile time (via elaboration) or at runtime.
module Dyadt.Verifier

import Dyadt.Claim
import Dyadt.Evidence
import Dyadt.Verdict
import System.File
import System
import Data.String
import Data.List
import Data.Maybe

-- Not marked total due to Evidence module constraints

||| Result of a runtime verification attempt
public export
data VerificationResult : Claim -> Type where
  ||| Verification succeeded
  Confirmed : Evidence claim -> VerificationResult claim
  ||| Verification failed with a reason
  Refuted : String -> VerificationResult claim
  ||| Could not determine (e.g., file not accessible)
  Inconclusive : String -> VerificationResult claim

||| Convert a successful verification to Verified
public export
toVerified : VerificationResult claim -> Maybe (Verified claim)
toVerified (Confirmed ev) = Just (MkVerified ev)
toVerified (Refuted _) = Nothing
toVerified (Inconclusive _) = Nothing

||| Check if verification was successful
public export
isConfirmed : VerificationResult claim -> Bool
isConfirmed (Confirmed _) = True
isConfirmed _ = False

||| Helper to join strings with space
joinWords : List String -> String
joinWords [] = ""
joinWords [x] = x
joinWords (x :: xs) = x ++ " " ++ joinWords xs

||| Runtime verification of a claim
export
partial
verifyClaimRuntime : (claim : Claim) -> IO (VerificationResult claim)
verifyClaimRuntime (FileExists path) = do
  Right _ <- openFile path Read
    | Left _ => pure (Refuted $ "File does not exist: " ++ path)
  pure (Confirmed FileExistsEvidence)

verifyClaimRuntime (DirectoryExists path) = do
  -- Check if path exists and is a directory
  -- Simplified: just check if we can test it
  0 <- system $ "test -d " ++ path
    | _ => pure (Refuted $ "Directory does not exist: " ++ path)
  pure (Confirmed DirectoryExistsEvidence)

verifyClaimRuntime (CommandSucceeds cmd args) = do
  let fullCmd = cmd ++ " " ++ joinWords args
  0 <- system fullCmd
    | code => pure (Refuted $ "Command failed with exit code: " ++ show code)
  pure (Confirmed CommandSucceedsEvidence)

verifyClaimRuntime (EnvVarSet name) = do
  Just _ <- getEnv name
    | Nothing => pure (Refuted $ "Environment variable not set: " ++ name)
  pure (Confirmed EnvVarSetEvidence)

verifyClaimRuntime (EnvVarEquals name expected) = do
  Just actual <- getEnv name
    | Nothing => pure (Refuted $ "Environment variable not set: " ++ name)
  if actual == expected
    then pure (Confirmed EnvVarEqualsEvidence)
    else pure (Refuted $ "Expected " ++ expected ++ " but got " ++ actual)

verifyClaimRuntime (GitClean repoPath) = do
  let path = fromMaybe "." repoPath
  let cmd = "git -C " ++ path ++ " status --porcelain"
  0 <- system $ cmd ++ " | grep -q ."
    | 1 => pure (Confirmed GitCleanEvidence)  -- grep returns 1 when no match (clean)
    | _ => pure (Refuted "Working directory has uncommitted changes")
  pure (Refuted "Working directory has uncommitted changes")

verifyClaimRuntime (And a b) = do
  Confirmed evA <- verifyClaimRuntime a
    | Refuted msg => pure (Refuted msg)
    | Inconclusive msg => pure (Inconclusive msg)
  Confirmed evB <- verifyClaimRuntime b
    | Refuted msg => pure (Refuted msg)
    | Inconclusive msg => pure (Inconclusive msg)
  pure (Confirmed (BothEvidence evA evB))

verifyClaimRuntime (Or a b) = do
  result <- verifyClaimRuntime a
  case result of
    Confirmed evA => pure (Confirmed (LeftEvidence evA))
    _ => do
      result2 <- verifyClaimRuntime b
      case result2 of
        Confirmed evB => pure (Confirmed (RightEvidence evB))
        Refuted msg => pure (Refuted msg)
        Inconclusive msg => pure (Inconclusive msg)

verifyClaimRuntime claim =
  pure (Inconclusive $ "Runtime verification not implemented for this claim type")

||| The Verifier interface for runtime verification
public export
interface RuntimeVerifier where
  ||| Verify a claim at runtime
  verifyRuntime : (claim : Claim) -> IO (VerificationResult claim)

||| Default runtime verifier implementation
public export
partial
[DefaultVerifier] RuntimeVerifier where
  verifyRuntime = verifyClaimRuntime

||| Verify and require - returns Verified or fails at runtime
export
partial
verifyOrFail : (claim : Claim) -> IO (Verified claim)
verifyOrFail claim = do
  result <- verifyClaimRuntime claim
  case toVerified result of
    Just v => pure v
    Nothing => do
      putStrLn "Verification failed"
      exitFailure

||| Verify multiple claims
export
partial
verifyAllRuntime : (claims : List Claim) -> IO (Maybe (VerifiedAll claims))
verifyAllRuntime [] = pure (Just (MkVerifiedAll AllNil))
verifyAllRuntime (c :: cs) = do
  Confirmed ev <- verifyClaimRuntime c
    | _ => pure Nothing
  Just (MkVerifiedAll evs) <- verifyAllRuntime cs
    | Nothing => pure Nothing
  pure (Just (MkVerifiedAll (AllCons ev evs)))
