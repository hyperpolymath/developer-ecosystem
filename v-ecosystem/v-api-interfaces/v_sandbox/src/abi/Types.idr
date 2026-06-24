-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-sandbox protocol.
-- Sandbox types: isolation mechanisms, capabilities.

module Types

import Data.List

||| Sandbox isolation type.
public export
data SandboxType : Type where
  Seccomp  : SandboxType
  Landlock : SandboxType
  Capsicum : SandboxType
  Pledge   : SandboxType
  Wasm     : SandboxType

||| Sandbox capability.
public export
data SandboxCapability : Type where
  FsRead      : SandboxCapability
  FsWrite     : SandboxCapability
  NetConnect  : SandboxCapability
  NetListen   : SandboxCapability
  ProcessExec : SandboxCapability
  ProcessFork : SandboxCapability

||| Sandbox policy.
public export
record SandboxPolicy where
  constructor MkSandboxPolicy
  name         : String
  sandboxType  : SandboxType
  capabilities : List SandboxCapability
