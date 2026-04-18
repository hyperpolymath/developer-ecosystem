module Echidna.Prover.SPAS

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| SPAS version
export
SPASVersion : IO String
SPASVersion = primIO prim__spas_version

||| Check if SPAS is available
export
SPASIsAvailable : IO Bool
SPASIsAvailable = primIO prim__spas_is_available

||| Prove using SPAS
export
partial
SPASProve : Theorem -> IO (Either ProverError ProofResult)
SPASProve thm = do
  available <- SPASIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable SPAS)
    else do
      -- Check format compatibility
      if not (supportsFormat SPAS thm.format)
        then pure $ Left (InvalidInput $ SPAS does not support format:  ++ show thm.format)
        else primIO $ prim__spas_prove thm.statement (show thm.format)

||| SPAS prover implementation
public export
partial
[SPASProver] Prover SPAS where
  prove thm = SPASProve thm
  checkSat formula = primIO $ prim__spas_check_sat formula
  version = SPASVersion
  isAvailable = SPASIsAvailable
