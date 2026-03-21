-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-airgap protocol.
-- Air-gapped transfer types: chunk manifests, integrity hashes,
-- device enumerations, and transfer session state.

module Types

import Data.List

||| Transfer direction for air-gapped exchanges.
public export
data TransferDirection : Type where
  ExportOut : TransferDirection  -- Data leaving secure enclave
  ImportIn  : TransferDirection  -- Data entering secure enclave

||| Hash algorithm used for chunk integrity.
public export
data HashAlgo : Type where
  SHA256 : HashAlgo
  SHA512 : HashAlgo

||| Chunk manifest describing a complete transfer.
public export
record ChunkManifest where
  constructor MkChunkManifest
  transferId  : String
  totalChunks : Nat
  hashAlgo    : HashAlgo
  rootHash    : String

||| Single data chunk within a transfer.
public export
record Chunk where
  constructor MkChunk
  index : Nat
  hash  : String
  size  : Nat
