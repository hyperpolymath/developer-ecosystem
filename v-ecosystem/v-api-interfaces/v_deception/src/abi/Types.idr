-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-deception protocol.
-- Cyber deception types: honeypot descriptors, canary tokens,
-- interaction alerts, and decoy service configurations.

module Types

import Data.List

||| Deception asset type.
public export
data DecoyType : Type where
  Honeypot    : DecoyType
  Honeytoken  : DecoyType
  Breadcrumb  : DecoyType
  CanaryDNS   : DecoyType
  CanaryHTTP  : DecoyType
  CanaryEmail : DecoyType
  FakeCred    : DecoyType

||| Alert severity level.
public export
data AlertSeverity : Type where
  Info     : AlertSeverity
  Warning  : AlertSeverity
  Critical : AlertSeverity

||| Deployed deception asset.
public export
record Decoy where
  constructor MkDecoy
  decoyId   : String
  kind      : DecoyType
  name      : String
  location  : String
  isActive  : Bool

||| Interaction alert.
public export
record InteractionAlert where
  constructor MkInteractionAlert
  decoyId   : String
  sourceIp  : String
  timestamp : Bits64
  severity  : AlertSeverity
