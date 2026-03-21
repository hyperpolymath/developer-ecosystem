-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-hardened protocol.
-- Hardening types: compliance levels, check results, benchmark IDs.

module Types

||| CIS benchmark compliance level.
public export
data ComplianceLevel : Type where
  Level1 : ComplianceLevel
  Level2 : ComplianceLevel
  Custom : ComplianceLevel

||| Hardening check result.
public export
data CheckResult : Type where
  Pass  : CheckResult
  Fail  : CheckResult
  Skip  : CheckResult
  Error : CheckResult

||| Hardening check.
public export
record HardeningCheck where
  constructor MkHardeningCheck
  checkId     : String
  title       : String
  level       : ComplianceLevel
  result      : CheckResult
  remediation : String
