module Echidna.Prover.Spin

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| Spin version
export
SpinVersion : IO String
SpinVersion = primIO prim__spin_version

||| Check if Spin is available
export
SpinIsAvailable : IO Bool
SpinIsAvailable = primIO prim__spin_is_available

||| Prove using Spin
export
partial
SpinProve : Theorem -> IO (Either ProverError ProofResult)
SpinProve thm = do
  available <- SpinIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable Spin)
    else do
      -- Check format compatibility
      if not (supportsFormat Spin thm.format)
        then pure $ Left (InvalidInput $ Spin does not support format:  ++ show thm.format)
        else primIO $ prim__spin_prove thm.statement (show thm.format)

||| Spin prover implementation
public export
partial
[SpinProver] Prover Spin where
  prove thm = SpinProve thm
  checkSat formula = primIO $ prim__spin_check_sat formula
  version = SpinVersion
  isAvailable = SpinIsAvailable
