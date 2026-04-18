module Echidna.Prover.PVS

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| PVS version
export
PVSVersion : IO String
PVSVersion = primIO prim__pvs_version

||| Check if PVS is available
export
PVSIsAvailable : IO Bool
PVSIsAvailable = primIO prim__pvs_is_available

||| Prove using PVS
export
partial
PVSProve : Theorem -> IO (Either ProverError ProofResult)
PVSProve thm = do
  available <- PVSIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable PVS)
    else do
      -- Check format compatibility
      if not (supportsFormat PVS thm.format)
        then pure $ Left (InvalidInput $ PVS does not support format:  ++ show thm.format)
        else primIO $ prim__pvs_prove thm.statement (show thm.format)

||| PVS prover implementation
public export
partial
[PVSProver] Prover PVS where
  prove thm = PVSProve thm
  checkSat formula = primIO $ prim__pvs_check_sat formula
  version = PVSVersion
  isAvailable = PVSIsAvailable
