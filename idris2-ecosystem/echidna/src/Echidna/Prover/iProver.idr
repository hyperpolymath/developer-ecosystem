module Echidna.Prover.iProver

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| iProver version
export
iProverVersion : IO String
iProverVersion = primIO prim__iprover_version

||| Check if iProver is available
export
iProverIsAvailable : IO Bool
iProverIsAvailable = primIO prim__iprover_is_available

||| Prove using iProver
export
partial
iProverProve : Theorem -> IO (Either ProverError ProofResult)
iProverProve thm = do
  available <- iProverIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable iProver)
    else do
      -- Check format compatibility
      if not (supportsFormat iProver thm.format)
        then pure $ Left (InvalidInput $ iProver does not support format:  ++ show thm.format)
        else primIO $ prim__iprover_prove thm.statement (show thm.format)

||| iProver prover implementation
public export
partial
[iProverProver] Prover iProver where
  prove thm = iProverProve thm
  checkSat formula = primIO $ prim__iprover_check_sat formula
  version = iProverVersion
  isAvailable = iProverIsAvailable
