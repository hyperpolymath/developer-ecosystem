-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-nts protocol.
-- NTS types: AEAD algorithms, cookies.

module Types

||| NTS AEAD algorithm.
public export
data AeadAlgorithm : Type where
  AES_SIV_CMAC_256 : AeadAlgorithm
  AES_SIV_CMAC_384 : AeadAlgorithm
  AES_SIV_CMAC_512 : AeadAlgorithm

||| NTS cookie.
public export
record NtsCookie where
  constructor MkNtsCookie
  server      : String
  expiryEpoch : Integer
