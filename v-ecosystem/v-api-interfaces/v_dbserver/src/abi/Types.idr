-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-dbserver protocol.
-- Database server types: instance state, connection pools,
-- replication topology, and query routing descriptors.

module Types

import Data.List

||| Database engine backend.
public export
data DbEngine : Type where
  PostgreSQL : DbEngine
  MySQL      : DbEngine
  SQLite     : DbEngine

||| Instance lifecycle state.
public export
data InstanceState : Type where
  Provisioning : InstanceState
  Available    : InstanceState
  Maintenance  : InstanceState
  Failed       : InstanceState
  Terminated   : InstanceState

||| Database instance descriptor.
public export
record DbInstance where
  constructor MkDbInstance
  instanceId : String
  name       : String
  engine     : DbEngine
  state      : InstanceState
  port       : Bits16

||| Connection pool statistics.
public export
record ConnectionPool where
  constructor MkConnectionPool
  instanceId : String
  active     : Nat
  idle       : Nat
  maxSize    : Nat
