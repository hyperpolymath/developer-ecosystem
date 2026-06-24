-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-honeypot protocol.
-- Honeypot types: interaction levels, threat classification.

module Types

||| Honeypot interaction fidelity.
public export
data HoneypotType : Type where
  LowInteraction    : HoneypotType
  MediumInteraction : HoneypotType
  HighInteraction   : HoneypotType

||| Threat severity level.
public export
data ThreatLevel : Type where
  Info     : ThreatLevel
  Low      : ThreatLevel
  Medium   : ThreatLevel
  High     : ThreatLevel
  Critical : ThreatLevel

||| Honeypot service definition.
public export
record HoneypotService where
  constructor MkHoneypotService
  name     : String
  port     : Bits16
  protocol : String
  hpType   : HoneypotType
