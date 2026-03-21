-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-tacacs protocol.
-- TACACS+ types: AAA types, auth statuses.

module Types

import Data.List

||| TACACS+ AAA service type.
public export
data AaaType : Type where
  Authentication : AaaType
  Authorization  : AaaType
  Accounting     : AaaType

||| Authentication status.
public export
data AuthStatus : Type where
  Pass        : AuthStatus
  Fail        : AuthStatus
  GetData     : AuthStatus
  GetUser     : AuthStatus
  GetPass     : AuthStatus
  ErrorStatus : AuthStatus

||| TACACS+ request.
public export
record TacacsRequest where
  constructor MkTacacsRequest
  aaaType    : AaaType
  username   : String
  remoteAddr : String
  service    : String
  args       : List String
