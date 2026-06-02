-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Connector.idr — Service connector types for unified-zig-api
--
-- The 11 hyperpolymath service connectors, each identified by a Bits8 tag
-- matching the Zig `pub const ServiceId = enum(u8)` in connectors/connector.zig.
-- Each connector exposes a standard interface: create/health/call/destroy.

module ZigApi.ABI.Connector

import Data.Bits
import ZigApi.ABI.Types

%default total

-- ============================================================================
-- ServiceId  (Zig: pub const ServiceId = enum(u8))
-- ============================================================================

||| The 11 hyperpolymath services that have Zig connector implementations.
public export
data ServiceId
  = AmbientOps   -- 0  container orchestration
  | BoJ          -- 1  BoJ MCP server
  | Burble       -- 2  WebRTC media platform
  | Echidna      -- 3  formal verification orchestrator
  | Gossamer     -- 4  window management
  | GrooveBridge -- 5  Groove inter-service protocol
  | Hypatia      -- 6  CI/CD neurosymbolic engine
  | IDApTIK      -- 7  adaptive tutoring
  | Reposystem   -- 8  repository automation
  | Stapeln      -- 9  container platform
  | VeriSimDB    -- 10 formal verification database

public export
serviceIdTag : ServiceId -> Bits8
serviceIdTag AmbientOps   = 0
serviceIdTag BoJ          = 1
serviceIdTag Burble       = 2
serviceIdTag Echidna      = 3
serviceIdTag Gossamer     = 4
serviceIdTag GrooveBridge = 5
serviceIdTag Hypatia      = 6
serviceIdTag IDApTIK      = 7
serviceIdTag Reposystem   = 8
serviceIdTag Stapeln      = 9
serviceIdTag VeriSimDB    = 10

public export
serviceIdFromTag : Bits8 -> Maybe ServiceId
serviceIdFromTag 0  = Just AmbientOps
serviceIdFromTag 1  = Just BoJ
serviceIdFromTag 2  = Just Burble
serviceIdFromTag 3  = Just Echidna
serviceIdFromTag 4  = Just Gossamer
serviceIdFromTag 5  = Just GrooveBridge
serviceIdFromTag 6  = Just Hypatia
serviceIdFromTag 7  = Just IDApTIK
serviceIdFromTag 8  = Just Reposystem
serviceIdFromTag 9  = Just Stapeln
serviceIdFromTag 10 = Just VeriSimDB
serviceIdFromTag _  = Nothing

public export
serviceIdRoundtrip : (s : ServiceId) -> serviceIdFromTag (serviceIdTag s) = Just s
serviceIdRoundtrip AmbientOps   = Refl
serviceIdRoundtrip BoJ          = Refl
serviceIdRoundtrip Burble       = Refl
serviceIdRoundtrip Echidna      = Refl
serviceIdRoundtrip Gossamer     = Refl
serviceIdRoundtrip GrooveBridge = Refl
serviceIdRoundtrip Hypatia      = Refl
serviceIdRoundtrip IDApTIK      = Refl
serviceIdRoundtrip Reposystem   = Refl
serviceIdRoundtrip Stapeln      = Refl
serviceIdRoundtrip VeriSimDB    = Refl

-- ============================================================================
-- ConnectorState  (Zig: pub const ConnectorState = enum(u8))
-- ============================================================================

public export
data ConnectorState
  = Disconnected  -- 0 not yet connected
  | Connecting    -- 1 connection in progress
  | Connected     -- 2 healthy, ready to serve
  | Degraded      -- 3 connected but responding slowly
  | Failed        -- 4 unreachable or error
  | Draining      -- 5 shutting down gracefully

public export
connectorStateTag : ConnectorState -> Bits8
connectorStateTag Disconnected = 0
connectorStateTag Connecting   = 1
connectorStateTag Connected    = 2
connectorStateTag Degraded     = 3
connectorStateTag Failed       = 4
connectorStateTag Draining     = 5

public export
connectorStateFromTag : Bits8 -> Maybe ConnectorState
connectorStateFromTag 0 = Just Disconnected
connectorStateFromTag 1 = Just Connecting
connectorStateFromTag 2 = Just Connected
connectorStateFromTag 3 = Just Degraded
connectorStateFromTag 4 = Just Failed
connectorStateFromTag 5 = Just Draining
connectorStateFromTag _ = Nothing

public export
connectorStateRoundtrip : (s : ConnectorState) -> connectorStateFromTag (connectorStateTag s) = Just s
connectorStateRoundtrip Disconnected = Refl
connectorStateRoundtrip Connecting   = Refl
connectorStateRoundtrip Connected    = Refl
connectorStateRoundtrip Degraded     = Refl
connectorStateRoundtrip Failed       = Refl
connectorStateRoundtrip Draining     = Refl

-- ============================================================================
-- Default port for each service
-- ============================================================================

||| Canonical port each service listens on when running locally.
public export
defaultPort : ServiceId -> Bits16
defaultPort AmbientOps   = 8080
defaultPort BoJ          = 3000
defaultPort Burble       = 4000
defaultPort Echidna      = 8090
defaultPort Gossamer     = 9000
defaultPort GrooveBridge = 7070
defaultPort Hypatia      = 8100
defaultPort IDApTIK      = 5000
defaultPort Reposystem   = 8200
defaultPort Stapeln      = 8300
defaultPort VeriSimDB    = 9100

-- ============================================================================
-- Groove discovery manifest  (mirrors GrooveManifest in V-lang connectors)
-- ============================================================================

||| A Groove service manifest exposed at /.well-known/groove.
public export
record GrooveManifest where
  constructor MkGrooveManifest
  service  : String
  version  : String
  api_types : List String
  endpoints : List String

||| Build a default manifest for a known service.
public export
defaultManifest : ServiceId -> GrooveManifest
defaultManifest sid = MkGrooveManifest
  { service   = serviceName sid
  , version   = "0.1.0"
  , api_types = ["rest"]
  , endpoints = ["/health"]
  }
  where
    serviceName : ServiceId -> String
    serviceName AmbientOps   = "ambientops"
    serviceName BoJ          = "boj"
    serviceName Burble       = "burble"
    serviceName Echidna      = "echidna"
    serviceName Gossamer     = "gossamer"
    serviceName GrooveBridge = "groove-bridge"
    serviceName Hypatia      = "hypatia"
    serviceName IDApTIK      = "idaptik"
    serviceName Reposystem   = "reposystem"
    serviceName Stapeln      = "stapeln"
    serviceName VeriSimDB    = "verisimdb"
