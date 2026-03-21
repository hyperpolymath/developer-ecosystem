-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-ftp protocol.
-- FTP transfer modes, response codes, directory entry types,
-- and connection lifecycle states.

module Types

import Data.List

||| FTP transfer mode (active vs passive data channel establishment).
public export
data TransferMode : Type where
  Active  : TransferMode  -- Server connects back to client data port
  Passive : TransferMode  -- Client connects to server-provided data port

||| FTP representation type for data transfer encoding.
public export
data RepresentationType : Type where
  ASCII  : RepresentationType  -- Text mode with CRLF line endings
  Binary : RepresentationType  -- Image/binary mode, no conversion

||| FTP connection lifecycle state.
public export
data ConnState : Type where
  Disconnected  : ConnState
  Connected     : ConnState  -- Control channel established
  Authenticated : ConnState  -- USER/PASS accepted
  Transferring  : ConnState  -- Data channel active

||| FTP response code category (first digit per RFC 959).
public export
data ResponseCategory : Type where
  Preliminary   : ResponseCategory  -- 1xx: positive preliminary
  Completion    : ResponseCategory  -- 2xx: positive completion
  Intermediate  : ResponseCategory  -- 3xx: positive intermediate
  TransientNeg  : ResponseCategory  -- 4xx: transient negative
  PermanentNeg  : ResponseCategory  -- 5xx: permanent negative

||| A parsed FTP server response with numeric code and text message.
public export
record FtpResponse where
  constructor MkFtpResponse
  code    : Nat
  message : String

||| Directory entry metadata returned by LIST or MLSD commands.
public export
record DirEntry where
  constructor MkDirEntry
  name      : String
  size      : Nat
  entryType : String   -- "file", "dir", "link"
  modified  : String   -- ISO 8601 timestamp
  perms     : String   -- Unix-style permission string
