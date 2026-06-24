-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-loadbalancer protocol.
-- LB types: algorithms, backend health, pools.

module Types

import Data.List

||| Load balancing algorithm.
public export
data LbAlgorithm : Type where
  RoundRobin       : LbAlgorithm
  LeastConnections : LbAlgorithm
  Weighted         : LbAlgorithm
  IpHash           : LbAlgorithm
  Random           : LbAlgorithm

||| Backend health status.
public export
data BackendHealth : Type where
  Healthy     : BackendHealth
  Unhealthy   : BackendHealth
  Draining    : BackendHealth
  Maintenance : BackendHealth

||| Backend server.
public export
record Backend where
  constructor MkBackend
  backendId : String
  address   : String
  port      : Bits16
  weight    : Nat
  health    : BackendHealth
