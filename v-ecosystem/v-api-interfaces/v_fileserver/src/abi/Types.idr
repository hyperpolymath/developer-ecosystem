-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-fileserver protocol.
-- File server types: file metadata, directory listings, quota
-- status, and transfer session descriptors.

module Types

import Data.List

||| File server backend protocol.
public export
data FsBackend : Type where
  FTP    : FsBackend
  SFTP   : FsBackend
  WebDAV : FsBackend

||| File entry kind.
public export
data FileKind : Type where
  Regular   : FileKind
  Directory : FileKind
  Symlink   : FileKind
  Special   : FileKind

||| File metadata.
public export
record FileMeta where
  constructor MkFileMeta
  path       : String
  name       : String
  kind       : FileKind
  sizeBytes  : Bits64
  modifiedAt : Bits64

||| Storage quota status.
public export
record QuotaStatus where
  constructor MkQuotaStatus
  usedBytes  : Bits64
  limitBytes : Bits64
  fileCount  : Bits64
