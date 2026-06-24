-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-container protocol.
-- Container runtime types: container state, image references,
-- volume mounts, network config, and resource limits.

module Types

import Data.List

||| OCI container lifecycle state.
public export
data ContainerState : Type where
  Created  : ContainerState
  Running  : ContainerState
  Paused   : ContainerState
  Stopped  : ContainerState
  Removing : ContainerState

||| Container image reference.
public export
record ImageRef where
  constructor MkImageRef
  registry   : String
  repository : String
  tag        : String
  digest     : String

||| Resource limits (cgroups).
public export
record ResourceLimits where
  constructor MkResourceLimits
  cpuShares  : Nat
  memLimitMb : Nat
  pidsLimit  : Nat

||| Volume mount descriptor.
public export
record VolumeMount where
  constructor MkVolumeMount
  hostPath      : String
  containerPath : String
  readOnly      : Bool
