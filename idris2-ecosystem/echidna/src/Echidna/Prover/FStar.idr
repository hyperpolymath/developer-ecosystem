module Echidna.Prover.FStar

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| FStar version
export
FStarVersion : IO String
FStarVersion = primIO prim__fstar_version

||| Check if FStar is available
export
FStarIsAvailable : IO Bool
FStarIsAvailable = primIO prim__fstar_is_available

||| Prove using FStar
export
partial
FStarProve : Theorem -> IO (Either ProverError ProofResult)
FStarProve thm = do
  available <- FStarIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable FStar)
    else do
      -- Check format compatibility
      if not (supportsFormat FStar thm.format)
        then pure $ Left (InvalidInput $ FStar does not support format:  ++ show thm.format)
        else primIO $ prim__fstar_prove thm.statement (show thm.format)

||| FStar prover implementation
public export
partial
[FStarProver] Prover FStar where
  prove thm = FStarProve thm
  checkSat formula = primIO $ prim__fstar_check_sat formula
  version = FStarVersion
  isAvailable = FStarIsAvailable
