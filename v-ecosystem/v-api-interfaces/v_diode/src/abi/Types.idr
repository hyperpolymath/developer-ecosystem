-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-diode protocol.
-- Data diode types: flow direction, transfer segments,
-- FEC parameters, and compliance audit records.

module Types

import Data.List

||| Unidirectional flow direction.
public export
data FlowDirection : Type where
  LowToHigh : FlowDirection  -- Low-security to high-security
  HighToLow : FlowDirection  -- High-security to low-security

||| Forward error correction parameters.
public export
record FecConfig where
  constructor MkFecConfig
  dataShards   : Nat
  parityShards : Nat

||| Transfer segment.
public export
record TransferSegment where
  constructor MkTransferSegment
  sequence : Bits64
  hash     : String
  fecGroup : Bits16

||| Compliance audit record.
public export
record AuditRecord where
  constructor MkAuditRecord
  timestamp  : Bits64
  transferId : String
  direction  : FlowDirection
  verified   : Bool
