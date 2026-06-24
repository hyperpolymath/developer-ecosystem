-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-ldap protocol.
-- LDAPv3 (RFC 4511) operation types, search scopes, result codes,
-- entry structures, and modification operations.

module Types

import Data.List

||| LDAP search scope as defined in RFC 4511 section 4.5.1.2.
public export
data SearchScope : Type where
  BaseObject   : SearchScope  -- Search only the named entry
  SingleLevel  : SearchScope  -- Search one level below base DN
  WholeSubtree : SearchScope  -- Search entire subtree from base DN

||| LDAP alias dereferencing policy (section 4.5.1.3).
public export
data DerefAliases : Type where
  NeverDeref      : DerefAliases
  DerefInSearch   : DerefAliases
  DerefFindingBase : DerefAliases
  DerefAlways     : DerefAliases

||| LDAP result code (section 4.1.9).
public export
data ResultCode : Type where
  Success                : ResultCode
  OperationsError        : ResultCode
  ProtocolError          : ResultCode
  TimeLimitExceeded      : ResultCode
  SizeLimitExceeded      : ResultCode
  CompareFalse           : ResultCode
  CompareTrue            : ResultCode
  AuthMethodNotSupported : ResultCode
  StrongerAuthRequired   : ResultCode
  NoSuchObject           : ResultCode
  InvalidDNSyntax        : ResultCode
  InsufficientAccess     : ResultCode
  Busy                   : ResultCode
  Unavailable            : ResultCode
  UnwillingToPerform     : ResultCode
  EntryAlreadyExists     : ResultCode

||| Modification operation type (section 4.6).
public export
data ModOp : Type where
  AddValues     : ModOp  -- Add one or more values to the attribute
  DeleteValues  : ModOp  -- Remove specified values from the attribute
  ReplaceValues : ModOp  -- Replace all existing values

||| Authentication mechanism for BIND requests.
public export
data AuthMethod : Type where
  SimpleAuth : AuthMethod              -- Plaintext password (section 4.2)
  SaslAuth   : (mechanism : String) -> AuthMethod  -- SASL mechanism name

||| Connection lifecycle state for an LDAP session.
public export
data ConnState : Type where
  Disconnected : ConnState
  Connected    : ConnState  -- TCP up, not yet bound
  Bound        : ConnState  -- Successfully authenticated

||| A named attribute with one or more string values.
public export
record Attribute where
  constructor MkAttribute
  name   : String
  values : List String

||| A directory entry identified by its distinguished name.
public export
record Entry where
  constructor MkEntry
  dn         : String
  attributes : List Attribute

||| A modification pairing an operation with an attribute.
public export
record Modification where
  constructor MkModification
  operation : ModOp
  attribute : Attribute

||| Search request parameters.
public export
record SearchRequest where
  constructor MkSearchRequest
  baseDn      : String
  scope       : SearchScope
  deref       : DerefAliases
  sizeLimit   : Nat
  timeLimit   : Nat
  typesOnly   : Bool
  filterStr   : String
  attributes  : List String
