-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-ssh-bastion protocol.
-- SSH bastion types: auth methods, session states, policies.

module Types

import Data.List

||| SSH authentication method.
public export
data AuthMethod : Type where
  PublicKey   : AuthMethod
  Certificate : AuthMethod
  MFA         : AuthMethod
  FIDO2       : AuthMethod

||| Bastion session state.
public export
data SessionState : Type where
  Connecting    : SessionState
  Authenticated : SessionState
  Active        : SessionState
  Recording     : SessionState
  Closed        : SessionState

||| Access policy.
public export
record AccessPolicy where
  constructor MkAccessPolicy
  name         : String
  allowedUsers : List String
  allowedHosts : List String
  requireMfa   : Bool
  record       : Bool
