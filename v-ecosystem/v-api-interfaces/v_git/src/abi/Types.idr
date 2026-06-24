-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-git protocol.
-- Git protocol types: object identifiers, ref descriptors,
-- packfile negotiation, and transfer capabilities.

module Types

import Data.List

||| Git object type.
public export
data ObjectType : Type where
  Blob   : ObjectType
  Tree   : ObjectType
  Commit : ObjectType
  Tag    : ObjectType

||| Transfer protocol.
public export
data TransferProtocol : Type where
  SmartHTTP : TransferProtocol
  SSH       : TransferProtocol
  GitNative : TransferProtocol

||| Git object identifier.
public export
record ObjectId where
  constructor MkObjectId
  hash : String
  algo : String

||| Git reference.
public export
record Ref where
  constructor MkRef
  name       : String
  target     : ObjectId
  isSymbolic : Bool

||| Commit descriptor.
public export
record CommitInfo where
  constructor MkCommitInfo
  commitId  : ObjectId
  tree      : ObjectId
  author    : String
  message   : String
  timestamp : Bits64
