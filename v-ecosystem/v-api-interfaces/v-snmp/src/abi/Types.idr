-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-snmp protocol.
-- SNMPv2c/v3 (RFC 3416/3414) PDU types, value types, OID
-- encoding, and USM security model structures.

module Types

import Data.List

||| SNMP protocol version.
public export
data SnmpVersion : Type where
  V1  : SnmpVersion  -- SNMPv1 (RFC 1157, legacy)
  V2c : SnmpVersion  -- SNMPv2c (RFC 3416, community-based)
  V3  : SnmpVersion  -- SNMPv3 (RFC 3414, USM security)

||| SNMP PDU type.
public export
data PduType : Type where
  GetRequest     : PduType
  GetNextRequest : PduType
  GetResponse    : PduType
  SetRequest     : PduType
  GetBulkRequest : PduType
  TrapV2         : PduType

||| ASN.1 value type in an SNMP variable binding.
public export
data ValueType : Type where
  IntegerVal       : ValueType
  StringVal        : ValueType
  OidVal           : ValueType
  Counter32Val     : ValueType
  Gauge32Val       : ValueType
  TimeticksVal     : ValueType
  Counter64Val     : ValueType
  NullVal          : ValueType
  NoSuchObject     : ValueType
  NoSuchInstance   : ValueType
  EndOfMibView     : ValueType

||| An SNMP Object Identifier.
public export
record OID where
  constructor MkOID
  value : String

||| A variable binding (OID + typed value).
public export
record VarBind where
  constructor MkVarBind
  oid       : OID
  valueType : ValueType
  intValue  : Integer
  strValue  : String

||| SNMPv3 USM security parameters.
public export
record UsmParams where
  constructor MkUsmParams
  username     : String
  authProtocol : String  -- "SHA" or "MD5"
  privProtocol : String  -- "AES" or "DES"
  engineId     : List Bits8
  engineBoots  : Nat
  engineTime   : Nat
