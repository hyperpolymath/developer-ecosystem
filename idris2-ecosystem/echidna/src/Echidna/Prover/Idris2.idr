module Echidna.Prover.Idris2

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| Idris2 version
export
Idris2Version : IO String
Idris2Version = primIO prim__idris2_version

||| Check if Idris2 is available
export
Idris2IsAvailable : IO Bool
Idris2IsAvailable = primIO prim__idris2_is_available

||| Prove using Idris2
export
partial
Idris2Prove : Theorem -> IO (Either ProverError ProofResult)
Idris2Prove thm = do
  available <- Idris2IsAvailable
  if not available
    then pure $ Left (ProverNotAvailable Idris2)
    else do
      -- Check format compatibility
      if not (supportsFormat Idris2 thm.format)
        then pure $ Left (InvalidInput $ Idris2 does not support format:  ++ show thm.format)
        else primIO $ prim__idris2_prove thm.statement (show thm.format)

||| Idris2 prover implementation
public export
partial
[Idris2Prover] Prover Idris2 where
  prove thm = Idris2Prove thm
  checkSat formula = primIO $ prim__idris2_check_sat formula
  version = Idris2Version
  isAvailable = Idris2IsAvailable
