module Echidna.Prover.Dafny

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| Dafny version
export
DafnyVersion : IO String
DafnyVersion = primIO prim__dafny_version

||| Check if Dafny is available
export
DafnyIsAvailable : IO Bool
DafnyIsAvailable = primIO prim__dafny_is_available

||| Prove using Dafny
export
partial
DafnyProve : Theorem -> IO (Either ProverError ProofResult)
DafnyProve thm = do
  available <- DafnyIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable Dafny)
    else do
      -- Check format compatibility
      if not (supportsFormat Dafny thm.format)
        then pure $ Left (InvalidInput $ Dafny does not support format:  ++ show thm.format)
        else primIO $ prim__dafny_prove thm.statement (show thm.format)

||| Dafny prover implementation
public export
partial
[DafnyProver] Prover Dafny where
  prove thm = DafnyProve thm
  checkSat formula = primIO $ prim__dafny_check_sat formula
  version = DafnyVersion
  isAvailable = DafnyIsAvailable
