-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-stun protocol.
-- STUN message types, attribute types, address families,
-- and transaction structures for NAT traversal (RFC 8489).

module Types

import Data.List
import Data.Vect

||| STUN message type.
public export
data MessageType : Type where
  BindingRequest   : MessageType
  BindingResponse  : MessageType
  BindingErrorResp : MessageType

||| Address family for mapped addresses.
public export
data AddressFamily : Type where
  IPv4 : AddressFamily
  IPv6 : AddressFamily

||| 96-bit STUN transaction ID.
public export
TransactionId : Type
TransactionId = Vect 12 Bits8

||| Discovered reflexive address.
public export
record MappedAddress where
  constructor MkMappedAddress
  family : AddressFamily
  port   : Bits16
  addr   : List Bits8
