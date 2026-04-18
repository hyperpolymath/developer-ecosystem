module Echidna.Prover.Yices

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| Yices version
export
YicesVersion : IO String
YicesVersion = primIO prim__yices_version

||| Check if Yices is available
export
YicesIsAvailable : IO Bool
YicesIsAvailable = primIO prim__yices_is_available

||| Prove using Yices
export
partial
YicesProve : Theorem -> IO (Either ProverError ProofResult)
YicesProve thm = do
  available <- YicesIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable Yices)
    else do
      -- Check format compatibility
      if not (supportsFormat Yices thm.format)
        then pure $ Left (InvalidInput $ Yices does not support format:  ++ show thm.format)
        else primIO $ prim__yices_prove thm.statement (show thm.format)

||| Yices prover implementation
public export
partial
[YicesProver] Prover Yices where
  prove thm = YicesProve thm
  checkSat formula = primIO $ prim__yices_check_sat formula
  version = YicesVersion
  isAvailable = YicesIsAvailable
