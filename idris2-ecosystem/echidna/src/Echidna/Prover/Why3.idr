module Echidna.Prover.Why3

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| Why3 version
export
Why3Version : IO String
Why3Version = primIO prim__why3_version

||| Check if Why3 is available
export
Why3IsAvailable : IO Bool
Why3IsAvailable = primIO prim__why3_is_available

||| Prove using Why3
export
partial
Why3Prove : Theorem -> IO (Either ProverError ProofResult)
Why3Prove thm = do
  available <- Why3IsAvailable
  if not available
    then pure $ Left (ProverNotAvailable Why3)
    else do
      -- Check format compatibility
      if not (supportsFormat Why3 thm.format)
        then pure $ Left (InvalidInput $ Why3 does not support format:  ++ show thm.format)
        else primIO $ prim__why3_prove thm.statement (show thm.format)

||| Why3 prover implementation
public export
partial
[Why3Prover] Prover Why3 where
  prove thm = Why3Prove thm
  checkSat formula = primIO $ prim__why3_check_sat formula
  version = Why3Version
  isAvailable = Why3IsAvailable
