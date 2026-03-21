-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-authserver protocol.
-- Authentication server types: credential stores, token claims,
-- session descriptors, MFA challenges, and RBAC policies.

module Types

import Data.List

||| Authentication token type.
public export
data TokenType : Type where
  AccessToken  : TokenType
  RefreshToken : TokenType
  IdToken      : TokenType

||| Multi-factor authentication method.
public export
data MfaMethod : Type where
  TOTP  : MfaMethod
  FIDO2 : MfaMethod
  SMS   : MfaMethod
  Email : MfaMethod

||| JWT token claims.
public export
record TokenClaims where
  constructor MkTokenClaims
  subject   : String
  issuer    : String
  audience  : String
  issuedAt  : Bits64
  expiresAt : Bits64

||| Authenticated session descriptor.
public export
record Session where
  constructor MkSession
  sessionId   : String
  userId      : String
  mfaVerified : Bool
