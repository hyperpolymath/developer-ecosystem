-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-siem protocol.
-- SIEM types: event sources, incident severities, correlation.

module Types

||| SIEM event source type.
public export
data EventSourceType : Type where
  Firewall    : EventSourceType
  IdsIps      : EventSourceType
  Endpoint    : EventSourceType
  Application : EventSourceType
  Cloud       : EventSourceType
  Identity    : EventSourceType

||| Incident severity.
public export
data IncidentSeverity : Type where
  Info     : IncidentSeverity
  Low      : IncidentSeverity
  Medium   : IncidentSeverity
  High     : IncidentSeverity
  Critical : IncidentSeverity

||| Correlation rule.
public export
record CorrelationRule where
  constructor MkCorrelationRule
  ruleId     : String
  name       : String
  pattern    : String
  windowSecs : Nat
  threshold  : Nat
