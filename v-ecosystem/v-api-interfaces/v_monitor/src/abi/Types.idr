-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-monitor protocol.
-- Monitoring types: check types, alert states, escalation.

module Types

import Data.List

||| Check classification.
public export
data CheckType : Type where
  HTTP   : CheckType
  TCP    : CheckType
  ICMP   : CheckType
  DNS    : CheckType
  Script : CheckType

||| Alert state machine.
public export
data AlertState : Type where
  Ok           : AlertState
  Warning      : AlertState
  Critical     : AlertState
  Unknown      : AlertState
  Acknowledged : AlertState

||| Monitor check.
public export
record MonitorCheck where
  constructor MkMonitorCheck
  name         : String
  checkType    : CheckType
  target       : String
  intervalSecs : Nat
  state        : AlertState

||| Escalation policy.
public export
record EscalationPolicy where
  constructor MkEscalationPolicy
  name      : String
  channels  : List String
  delaySecs : Nat
