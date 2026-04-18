module Echidna.Prover.Boolector

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| Boolector version
export
BoolectorVersion : IO String
BoolectorVersion = primIO prim__boolector_version

||| Check if Boolector is available
export
BoolectorIsAvailable : IO Bool
BoolectorIsAvailable = primIO prim__boolector_is_available

||| Prove using Boolector
export
partial
BoolectorProve : Theorem -> IO (Either ProverError ProofResult)
BoolectorProve thm = do
  available <- BoolectorIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable Boolector)
    else do
      -- Check format compatibility
      if not (supportsFormat Boolector thm.format)
        then pure $ Left (InvalidInput $ Boolector does not support format:  ++ show thm.format)
        else primIO $ prim__boolector_prove thm.statement (show thm.format)

||| Boolector prover implementation
public export
partial
[BoolectorProver] Prover Boolector where
  prove thm = BoolectorProve thm
  checkSat formula = primIO $ prim__boolector_check_sat formula
  version = BoolectorVersion
  isAvailable = BoolectorIsAvailable
