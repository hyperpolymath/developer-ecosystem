-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-configmgmt protocol.
-- Configuration management types: resource states, convergence
-- results, drift reports, and module descriptors.

module Types

import Data.List

||| Managed resource state.
public export
data ResourceState : Type where
  Present : ResourceState
  Absent  : ResourceState
  Running : ResourceState
  Stopped : ResourceState
  Enabled : ResourceState

||| Convergence result.
public export
data ConvergeResult : Type where
  Unchanged : ConvergeResult
  Changed   : ConvergeResult
  Failed    : ConvergeResult
  Skipped   : ConvergeResult

||| Managed resource.
public export
record Resource where
  constructor MkResource
  name    : String
  kind    : String
  desired : ResourceState

||| Drift report entry.
public export
record DriftReport where
  constructor MkDriftReport
  resourceName : String
  expected     : String
  actual       : String
  drifted      : Bool
