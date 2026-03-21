-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-virt protocol.
-- Virtualisation types: VM states, hypervisors.

module Types

||| VM lifecycle state.
public export
data VmState : Type where
  Defined   : VmState
  Running   : VmState
  Paused    : VmState
  Suspended : VmState
  Shutdown  : VmState
  Crashed   : VmState

||| Hypervisor backend.
public export
data Hypervisor : Type where
  KVM    : Hypervisor
  Xen    : Hypervisor
  Bhyve  : Hypervisor
  VMware : Hypervisor

||| VM specification.
public export
record VmSpec where
  constructor MkVmSpec
  name       : String
  vcpus      : Nat
  memoryMb   : Nat
  diskGb     : Nat
  hypervisor : Hypervisor
  image      : String
