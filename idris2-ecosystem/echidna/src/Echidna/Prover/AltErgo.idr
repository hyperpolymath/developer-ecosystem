module Echidna.Prover.AltErgo

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| AltErgo version
export
AltErgoVersion : IO String
AltErgoVersion = primIO prim__altergo_version

||| Check if AltErgo is available
export
AltErgoIsAvailable : IO Bool
AltErgoIsAvailable = primIO prim__altergo_is_available

||| Prove using AltErgo
export
partial
AltErgoProve : Theorem -> IO (Either ProverError ProofResult)
AltErgoProve thm = do
  available <- AltErgoIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable AltErgo)
    else do
      -- Check format compatibility
      if not (supportsFormat AltErgo thm.format)
        then pure $ Left (InvalidInput $ AltErgo does not support format:  ++ show thm.format)
        else primIO $ prim__altergo_prove thm.statement (show thm.format)

||| AltErgo prover implementation
public export
partial
[AltErgoProver] Prover AltErgo where
  prove thm = AltErgoProve thm
  checkSat formula = primIO $ prim__altergo_check_sat formula
  version = AltErgoVersion
  isAvailable = AltErgoIsAvailable
