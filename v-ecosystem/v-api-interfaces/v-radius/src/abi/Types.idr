-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-radius protocol.
-- RADIUS (RFC 2865/2866) packet types, attribute types, and
-- AAA (Authentication, Authorisation, Accounting) structures.

module Types

import Data.List

||| RADIUS packet type (code field).
public export
data PacketType : Type where
  AccessRequest      : PacketType
  AccessAccept       : PacketType
  AccessReject       : PacketType
  AccountingRequest  : PacketType
  AccountingResponse : PacketType
  AccessChallenge    : PacketType

||| RADIUS attribute data type.
public export
data AttrDataType : Type where
  TextAttr    : AttrDataType  -- UTF-8 string
  StringAttr  : AttrDataType  -- Opaque octets
  AddressAttr : AttrDataType  -- IPv4 address (4 bytes)
  IntegerAttr : AttrDataType  -- 32-bit unsigned integer
  TimeAttr    : AttrDataType  -- 32-bit Unix timestamp

||| A RADIUS attribute-value pair.
public export
record Attribute where
  constructor MkAttribute
  attrType : Bits8
  dat      : List Bits8

||| A complete RADIUS packet.
public export
record Packet where
  constructor MkPacket
  code          : PacketType
  identifier    : Bits8
  authenticator : List Bits8   -- 16 bytes
  attributes    : List Attribute

||| Authentication result.
public export
record AuthResult where
  constructor MkAuthResult
  accepted     : Bool
  replyMessage : String
  challenge    : Bool
  state        : List Bits8
