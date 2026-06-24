-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-apiserver protocol.
-- API server management types: server state, health status,
-- configuration, and deployment descriptors.

module Types

import Data.List

||| API server lifecycle state.
public export
data ServerState : Type where
  Starting : ServerState
  Healthy  : ServerState
  Degraded : ServerState
  Draining : ServerState
  Stopped  : ServerState

||| Health status report.
public export
record HealthStatus where
  constructor MkHealthStatus
  state        : ServerState
  uptimeSecs   : Bits64
  requestCount : Bits64
  errorRate    : Double

||| Server configuration.
public export
record ServerConfig where
  constructor MkServerConfig
  bindAddr : String
  port     : Bits16
  maxConns : Nat
