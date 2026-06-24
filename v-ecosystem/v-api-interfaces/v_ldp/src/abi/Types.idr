-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-ldp protocol.
-- LDP types: container types, resources.

module Types

import Data.List

||| LDP container type.
public export
data LdpContainerType : Type where
  Basic    : LdpContainerType
  Direct   : LdpContainerType
  Indirect : LdpContainerType

||| LDP resource.
public export
record LdpResource where
  constructor MkLdpResource
  uri         : String
  contentType : String
  etag        : String

||| LDP container.
public export
record LdpContainer where
  constructor MkLdpContainer
  uri           : String
  containerType : LdpContainerType
  members       : List String
