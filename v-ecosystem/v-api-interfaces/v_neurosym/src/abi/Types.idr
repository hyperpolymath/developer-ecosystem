-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-neurosym protocol.
-- Neurosym CI/CD types: scan types, finding severities.

module Types

||| CI/CD scan type.
public export
data ScanType : Type where
  Security    : ScanType
  Compliance  : ScanType
  Quality     : ScanType
  SupplyChain : ScanType

||| Finding severity.
public export
data FindingSeverity : Type where
  Info     : FindingSeverity
  Low      : FindingSeverity
  Medium   : FindingSeverity
  High     : FindingSeverity
  Critical : FindingSeverity

||| Scan rule.
public export
record ScanRule where
  constructor MkScanRule
  ruleId   : String
  name     : String
  scanType : ScanType
  pattern  : String
  severity : FindingSeverity
