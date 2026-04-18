module Echidna.Prover.Bitwuzla

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| Bitwuzla version
export
BitwuzlaVersion : IO String
BitwuzlaVersion = primIO prim__bitwuzla_version

||| Check if Bitwuzla is available
export
BitwuzlaIsAvailable : IO Bool
BitwuzlaIsAvailable = primIO prim__bitwuzla_is_available

||| Prove using Bitwuzla
export
partial
BitwuzlaProve : Theorem -> IO (Either ProverError ProofResult)
BitwuzlaProve thm = do
  available <- BitwuzlaIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable Bitwuzla)
    else do
      -- Check format compatibility
      if not (supportsFormat Bitwuzla thm.format)
        then pure $ Left (InvalidInput $ Bitwuzla does not support format:  ++ show thm.format)
        else primIO $ prim__bitwuzla_prove thm.statement (show thm.format)

||| Bitwuzla prover implementation
public export
partial
[BitwuzlaProver] Prover Bitwuzla where
  prove thm = BitwuzlaProve thm
  checkSat formula = primIO $ prim__bitwuzla_check_sat formula
  version = BitwuzlaVersion
  isAvailable = BitwuzlaIsAvailable
