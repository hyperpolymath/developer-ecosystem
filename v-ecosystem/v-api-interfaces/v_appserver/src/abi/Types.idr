-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-appserver protocol.
-- Application server types: process state, deployment slots,
-- resource quotas, and log aggregation handles.

module Types

import Data.List

||| Application process lifecycle state.
public export
data ProcessState : Type where
  Pending    : ProcessState
  Running    : ProcessState
  Suspended  : ProcessState
  Crashed    : ProcessState
  Terminated : ProcessState

||| Resource quota limits.
public export
record ResourceQuota where
  constructor MkResourceQuota
  maxCpuPct   : Double
  maxMemBytes : Bits64
  maxProcs    : Nat

||| Deployment slot descriptor.
public export
record DeploySlot where
  constructor MkDeploySlot
  slotId   : String
  appName  : String
  version  : String
  isActive : Bool
