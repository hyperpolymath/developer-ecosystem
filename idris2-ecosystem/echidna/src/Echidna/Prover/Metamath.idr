module Echidna.Prover.Metamath

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| Metamath version
export
MetamathVersion : IO String
MetamathVersion = primIO prim__metamath_version

||| Check if Metamath is available
export
MetamathIsAvailable : IO Bool
MetamathIsAvailable = primIO prim__metamath_is_available

||| Prove using Metamath
export
partial
MetamathProve : Theorem -> IO (Either ProverError ProofResult)
MetamathProve thm = do
  available <- MetamathIsAvailable
  if not available
    then pure $ Left (ProverNotAvailable Metamath)
    else do
      -- Check format compatibility
      if not (supportsFormat Metamath thm.format)
        then pure $ Left (InvalidInput $ Metamath does not support format:  ++ show thm.format)
        else primIO $ prim__metamath_prove thm.statement (show thm.format)

||| Metamath prover implementation
public export
partial
[MetamathProver] Prover Metamath where
  prove thm = MetamathProve thm
  checkSat formula = primIO $ prim__metamath_check_sat formula
  version = MetamathVersion
  isAvailable = MetamathIsAvailable
