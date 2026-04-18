module Echidna.Prover.PRISM

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| PRISM version
export
PRISMVersion : IO String
PRISMVersion = primIO prim__prism_version

||| Check if PRISM is available
export
PRISMIsAvailable : IO Bool
PRISMIsAvailable = primIO prim__prism_is_available

||| Prove using PRISM
export
partial
PRISMProve : Theorem -> IO (Either ProverError ProofResult)
PRISMProve thm = do
  available <- PRISMIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable PRISM)
    else do
      -- Check format compatibility
      if not (supportsFormat PRISM thm.format)
        then pure $ Left (InvalidInput $ PRISM does not support format:  ++ show thm.format)
        else primIO $ prim__prism_prove thm.statement (show thm.format)

||| PRISM prover implementation
public export
partial
[PRISMProver] Prover PRISM where
  prove thm = PRISMProve thm
  checkSat formula = primIO $ prim__prism_check_sat formula
  version = PRISMVersion
  isAvailable = PRISMIsAvailable
