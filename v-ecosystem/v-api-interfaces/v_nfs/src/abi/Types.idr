-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-nfs protocol.
-- NFS types: versions, security flavours, exports.

module Types

import Data.List

||| NFS protocol version.
public export
data NfsVersion : Type where
  V3  : NfsVersion
  V4  : NfsVersion
  V41 : NfsVersion
  V42 : NfsVersion

||| NFS export security flavour.
public export
data ExportSecurity : Type where
  Sys   : ExportSecurity
  Krb5  : ExportSecurity
  Krb5i : ExportSecurity
  Krb5p : ExportSecurity

||| NFS export.
public export
record NfsExport where
  constructor MkNfsExport
  path     : String
  clients  : List String
  security : ExportSecurity
  readOnly : Bool
