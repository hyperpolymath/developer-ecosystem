-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-ids protocol.
-- IDS types: detection modes, alert severities, rules.

module Types

||| Detection analysis mode.
public export
data DetectionMode : Type where
  Signature : DetectionMode
  Anomaly   : DetectionMode
  Hybrid    : DetectionMode

||| Alert severity.
public export
data AlertSeverity : Type where
  Info     : AlertSeverity
  Low      : AlertSeverity
  Medium   : AlertSeverity
  High     : AlertSeverity
  Critical : AlertSeverity

||| IDS rule.
public export
record IdsRule where
  constructor MkIdsRule
  sid      : Nat
  name     : String
  mode     : DetectionMode
  pattern  : String
  severity : AlertSeverity
