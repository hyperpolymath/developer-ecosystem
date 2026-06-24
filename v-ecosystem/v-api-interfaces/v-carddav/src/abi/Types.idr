-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-carddav protocol.
-- vCard property types, address book metadata, and contact
-- structures for CardDAV access (RFC 6352).

module Types

import Data.List

||| vCard property kind.
public export
data PropertyKind : Type where
  FN    : PropertyKind  -- Formatted name
  N     : PropertyKind  -- Structured name
  Email : PropertyKind  -- Email address
  Tel   : PropertyKind  -- Telephone
  Org   : PropertyKind  -- Organisation
  Title : PropertyKind  -- Job title
  Note  : PropertyKind  -- Free-text note

||| vCard contact record.
public export
record Contact where
  constructor MkContact
  uid    : String
  fnName : String
  given  : String
  family : String
  email  : String
  tel    : String

||| Address book collection.
public export
record AddressBook where
  constructor MkAddressBook
  href        : String
  displayName : String
  ctag        : String
