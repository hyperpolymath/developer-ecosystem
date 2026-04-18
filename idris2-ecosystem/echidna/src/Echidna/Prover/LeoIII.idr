module Echidna.Prover.LeoIII

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| LeoIII version
export
LeoIIIVersion : IO String
LeoIIIVersion = primIO prim__leoiii_version

||| Check if LeoIII is available
export
LeoIIIIsAvailable : IO Bool
LeoIIIIsAvailable = primIO prim__leoiii_is_available

||| Prove using LeoIII
export
partial
LeoIIIProve : Theorem -> IO (Either ProverError ProofResult)
LeoIIIProve thm = do
  available <- LeoIIIIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable LeoIII)
    else do
      -- Check format compatibility
      if not (supportsFormat LeoIII thm.format)
        then pure $ Left (InvalidInput $ LeoIII does not support format:  ++ show thm.format)
        else primIO $ prim__leoiii_prove thm.statement (show thm.format)

||| LeoIII prover implementation
public export
partial
[LeoIIIProver] Prover LeoIII where
  prove thm = LeoIIIProve thm
  checkSat formula = primIO $ prim__leoiii_check_sat formula
  version = LeoIIIVersion
  isAvailable = LeoIIIIsAvailable
