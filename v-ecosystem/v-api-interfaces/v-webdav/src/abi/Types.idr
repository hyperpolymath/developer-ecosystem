-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-webdav protocol.
-- WebDAV resource types, lock scopes, property structures,
-- and depth headers.

module Types

import Data.List

||| WebDAV resource type (collection vs non-collection).
public export
data ResourceType : Type where
  Collection    : ResourceType  -- Directory-like container (DAV:collection)
  NonCollection : ResourceType  -- Regular file resource

||| Lock scope (RFC 4918 section 6.1).
public export
data LockScope : Type where
  Exclusive : LockScope  -- Only one lock holder at a time
  Shared    : LockScope  -- Multiple concurrent lock holders

||| Lock type (RFC 4918 section 6.2).
public export
data LockType : Type where
  Write : LockType  -- Write lock (only type defined in RFC 4918)

||| Depth header value for PROPFIND and other operations.
public export
data Depth : Type where
  DepthZero     : Depth  -- Resource itself only
  DepthOne      : Depth  -- Resource and its immediate children
  DepthInfinity : Depth  -- Resource and all descendants

||| Connection lifecycle state.
public export
data ConnState : Type where
  Disconnected  : ConnState
  Connected     : ConnState
  Authenticated : ConnState

||| A WebDAV property with namespace, name, and value.
public export
record DavProperty where
  constructor MkDavProperty
  namespace : String
  name      : String
  value     : String

||| A WebDAV resource with its href and properties.
public export
record DavResource where
  constructor MkDavResource
  href         : String
  resourceType : ResourceType
  contentLength : Nat
  lastModified : String
  etag         : String
  properties   : List DavProperty

||| A WebDAV lock token with its scope, type, and timeout.
public export
record LockToken where
  constructor MkLockToken
  token   : String
  scope   : LockScope
  lockType : LockType
  owner   : String
  timeout : Nat
