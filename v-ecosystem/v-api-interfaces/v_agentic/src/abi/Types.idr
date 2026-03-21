-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-agentic protocol.
-- Autonomous agent orchestration types: capabilities, tasks, statuses.

module Types

import Data.List

||| Agent capability permission.
public export
data Capability : Type where
  Read      : Capability
  Write     : Capability
  Execute   : Capability
  Delegate  : Capability
  Supervise : Capability

||| Agent lifecycle status.
public export
data AgentStatus : Type where
  Idle       : AgentStatus
  Running    : AgentStatus
  Suspended  : AgentStatus
  Terminated : AgentStatus
  Error      : AgentStatus

||| Agent specification.
public export
record AgentSpec where
  constructor MkAgentSpec
  agentId        : String
  name           : String
  capabilities   : List Capability
  maxDelegation  : Nat

||| Agent task.
public export
record AgentTask where
  constructor MkAgentTask
  taskId   : String
  agentId  : String
  status   : AgentStatus
