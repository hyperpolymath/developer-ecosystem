-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-backup protocol.
-- Multi-backend backup types (Restic, BorgBackup, rsync),
-- snapshot structures, retention policies, and integrity checks.

module Types

import Data.List

||| Backup backend selection.
public export
data Backend : Type where
  Restic : Backend   -- Restic REST API or local repository
  Borg   : Backend   -- BorgBackup (local or SSH)
  Rsync  : Backend   -- rsync over SSH

||| Snapshot status.
public export
data SnapshotStatus : Type where
  Complete  : SnapshotStatus
  Partial   : SnapshotStatus
  Corrupted : SnapshotStatus
  Pruned    : SnapshotStatus

||| Compression algorithm selection.
public export
data Compression : Type where
  NoCompression : Compression
  Lz4           : Compression
  Zstd          : Compression
  AutoCompress  : Compression

||| A backup snapshot with metadata.
public export
record Snapshot where
  constructor MkSnapshot
  snapshotId : String
  timestamp  : Nat          -- Unix timestamp
  hostname   : String
  paths      : List String
  tags       : List String
  sizeBytes  : Nat
  status     : SnapshotStatus

||| Retention policy for snapshot pruning.
public export
record RetentionPolicy where
  constructor MkRetentionPolicy
  keepDaily   : Nat
  keepWeekly  : Nat
  keepMonthly : Nat
  maxAgeDays  : Nat

||| Integrity check result.
public export
record CheckResult where
  constructor MkCheckResult
  passed      : Bool
  errors      : List String
  packsChecked : Nat
  dataChecked  : Nat
