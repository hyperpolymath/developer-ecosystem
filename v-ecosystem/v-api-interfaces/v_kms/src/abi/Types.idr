-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-kms protocol.
-- KMS types: key algorithms, lifecycle states, rotation.

module Types

||| Cryptographic key algorithm.
public export
data KeyType : Type where
  AES256GCM : KeyType
  RSA4096   : KeyType
  Ed25519   : KeyType
  MLKEM1024 : KeyType
  MLDSA87   : KeyType

||| Key lifecycle state.
public export
data KeyState : Type where
  Active               : KeyState
  Disabled             : KeyState
  ScheduledDestruction : KeyState
  Destroyed            : KeyState

||| Cryptographic key.
public export
record CryptoKey where
  constructor MkCryptoKey
  keyId     : String
  alias     : String
  keyType   : KeyType
  state     : KeyState
