module Echidna.Prover.ACL2

import Echidna.Prover
import Echidna.Prover.Types
import Echidna.FFI

%default total

||| ACL2 version
export
ACL2Version : IO String
ACL2Version = primIO prim__acl2_version

||| Check if ACL2 is available
export
ACL2IsAvailable : IO Bool
ACL2IsAvailable = primIO prim__acl2_is_available

||| Prove using ACL2
export
partial
ACL2Prove : Theorem -> IO (Either ProverError ProofResult)
ACL2Prove thm = do
  available <- ACL2IsAvailable
  if not available
    then pure $ Left (ProverNotAvailable ACL2)
    else do
      -- Check format compatibility
      if not (supportsFormat ACL2 thm.format)
        then pure $ Left (InvalidInput $ ACL2 does not support format:  ++ show thm.format)
        else primIO $ prim__acl2_prove thm.statement (show thm.format)

||| ACL2 prover implementation
public export
partial
[ACL2Prover] Prover ACL2 where
  prove thm = ACL2Prove thm
  checkSat formula = primIO $ prim__acl2_check_sat formula
  version = ACL2Version
  isAvailable = ACL2IsAvailable
