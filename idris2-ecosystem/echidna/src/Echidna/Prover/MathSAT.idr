module Echidna.Prover.MathSAT

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| MathSAT version
export
MathSATVersion : IO String
MathSATVersion = primIO prim__mathsat_version

||| Check if MathSAT is available
export
MathSATIsAvailable : IO Bool
MathSATIsAvailable = primIO prim__mathsat_is_available

||| Prove using MathSAT
export
partial
MathSATProve : Theorem -> IO (Either ProverError ProofResult)
MathSATProve thm = do
  available <- MathSATIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable MathSAT)
    else do
      -- Check format compatibility
      if not (supportsFormat MathSAT thm.format)
        then pure $ Left (InvalidInput $ MathSAT does not support format:  ++ show thm.format)
        else primIO $ prim__mathsat_prove thm.statement (show thm.format)

||| MathSAT prover implementation
public export
partial
[MathSATProver] Prover MathSAT where
  prove thm = MathSATProve thm
  checkSat formula = primIO $ prim__mathsat_check_sat formula
  version = MathSATVersion
  isAvailable = MathSATIsAvailable
