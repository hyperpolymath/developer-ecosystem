module Echidna.Prover.NuSMV

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| NuSMV version
export
NuSMVVersion : IO String
NuSMVVersion = primIO prim__nusmv_version

||| Check if NuSMV is available
export
NuSMVIsAvailable : IO Bool
NuSMVIsAvailable = primIO prim__nusmv_is_available

||| Prove using NuSMV
export
partial
NuSMVProve : Theorem -> IO (Either ProverError ProofResult)
NuSMVProve thm = do
  available <- NuSMVIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable NuSMV)
    else do
      -- Check format compatibility
      if not (supportsFormat NuSMV thm.format)
        then pure $ Left (InvalidInput $ NuSMV does not support format:  ++ show thm.format)
        else primIO $ prim__nusmv_prove thm.statement (show thm.format)

||| NuSMV prover implementation
public export
partial
[NuSMVProver] Prover NuSMV where
  prove thm = NuSMVProve thm
  checkSat formula = primIO $ prim__nusmv_check_sat formula
  version = NuSMVVersion
  isAvailable = NuSMVIsAvailable
