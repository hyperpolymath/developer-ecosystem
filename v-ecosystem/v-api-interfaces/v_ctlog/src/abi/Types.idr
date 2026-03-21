-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-ctlog protocol.
-- Certificate Transparency types: SCT records, Merkle proofs,
-- log entries, and consistency proof descriptors.

module Types

import Data.List

||| CT log entry type.
public export
data LogEntryType : Type where
  X509Entry    : LogEntryType
  PrecertEntry : LogEntryType

||| SCT validation status.
public export
data SctStatus : Type where
  Valid   : SctStatus
  Invalid : SctStatus
  Unknown : SctStatus
  Expired : SctStatus

||| Signed Certificate Timestamp.
public export
record SignedCertTimestamp where
  constructor MkSCT
  version   : Bits8
  logId     : List Bits8
  timestamp : Bits64
  signature : List Bits8

||| Merkle inclusion proof.
public export
record MerkleProof where
  constructor MkMerkleProof
  leafIndex : Bits64
  treeSize  : Bits64
  hashes    : List (List Bits8)
