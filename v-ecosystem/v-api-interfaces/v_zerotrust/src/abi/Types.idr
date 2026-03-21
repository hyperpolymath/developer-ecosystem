-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-zerotrust protocol.
-- Zero-trust types: trust levels, verification methods, policies.

module Types

import Data.List

||| Trust assessment level.
public export
data TrustLevel : Type where
  Untrusted   : TrustLevel
  Conditional : TrustLevel
  Verified    : TrustLevel
  Elevated    : TrustLevel

||| Verification method.
public export
data VerificationType : Type where
  Identity   : VerificationType
  Device     : VerificationType
  Context    : VerificationType
  Continuous : VerificationType

||| Zero-trust policy.
public export
record ZtPolicy where
  constructor MkZtPolicy
  name             : String
  requiredTrust    : TrustLevel
  verifications    : List VerificationType
  maxSessionMins   : Nat
  microsegment     : Bool
