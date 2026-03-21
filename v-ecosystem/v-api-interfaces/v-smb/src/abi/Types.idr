-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-smb protocol.
-- SMB3 command codes, share types, dialect versions,
-- and file info structures for network file sharing.

module Types

import Data.List

||| SMB3 dialect version.
public export
data Dialect : Type where
  SMB300 : Dialect  -- SMB 3.0
  SMB302 : Dialect  -- SMB 3.0.2
  SMB311 : Dialect  -- SMB 3.1.1

||| Network share type.
public export
data ShareType : Type where
  Disk  : ShareType  -- File share
  Pipe  : ShareType  -- Named pipe / IPC
  Print : ShareType  -- Printer share

||| SMB command code.
public export
data Command : Type where
  Negotiate     : Command
  SessionSetup  : Command
  TreeConnect   : Command
  Create        : Command
  Close         : Command
  Read          : Command
  Write         : Command
  QueryDir      : Command

||| File or directory metadata.
public export
record FileInfo where
  constructor MkFileInfo
  name        : String
  size        : Bits64
  isDirectory : Bool
  attributes  : Bits32
