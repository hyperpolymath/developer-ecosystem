module Echidna.Prover.KeYmaeraX

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| KeYmaeraX version
export
KeYmaeraXVersion : IO String
KeYmaeraXVersion = primIO prim__keymaerax_version

||| Check if KeYmaeraX is available
export
KeYmaeraXIsAvailable : IO Bool
KeYmaeraXIsAvailable = primIO prim__keymaerax_is_available

||| Prove using KeYmaeraX
export
partial
KeYmaeraXProve : Theorem -> IO (Either ProverError ProofResult)
KeYmaeraXProve thm = do
  available <- KeYmaeraXIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable KeYmaeraX)
    else do
      -- Check format compatibility
      if not (supportsFormat KeYmaeraX thm.format)
        then pure $ Left (InvalidInput $ KeYmaeraX does not support format:  ++ show thm.format)
        else primIO $ prim__keymaerax_prove thm.statement (show thm.format)

||| KeYmaeraX prover implementation
public export
partial
[KeYmaeraXProver] Prover KeYmaeraX where
  prove thm = KeYmaeraXProve thm
  checkSat formula = primIO $ prim__keymaerax_check_sat formula
  version = KeYmaeraXVersion
  isAvailable = KeYmaeraXIsAvailable
