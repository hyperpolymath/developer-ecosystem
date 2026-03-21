-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-dns protocol.
-- DNS record types, query classes, response codes, and message
-- structures for domain name resolution (RFC 1035).

module Types

import Data.List

||| DNS resource record type.
public export
data RecordType : Type where
  A     : RecordType  -- IPv4 address
  AAAA  : RecordType  -- IPv6 address
  CNAME : RecordType  -- Canonical name
  MX    : RecordType  -- Mail exchange
  TXT   : RecordType  -- Text record
  SRV   : RecordType  -- Service locator
  NS    : RecordType  -- Name server
  SOA   : RecordType  -- Start of authority
  PTR   : RecordType  -- Pointer (reverse)

||| DNS query class.
public export
data QueryClass : Type where
  ClassIN : QueryClass  -- Internet
  ClassCH : QueryClass  -- Chaos
  ClassHS : QueryClass  -- Hesiod

||| DNS response code.
public export
data ResponseCode : Type where
  NoError  : ResponseCode
  FormErr  : ResponseCode
  ServFail : ResponseCode
  NXDomain : ResponseCode
  NotImpl  : ResponseCode
  Refused  : ResponseCode

||| DNS message header.
public export
record Header where
  constructor MkHeader
  queryId   : Bits16
  flags     : Bits16
  qdCount   : Bits16
  anCount   : Bits16

||| DNS resource record.
public export
record ResourceRecord where
  constructor MkResourceRecord
  name   : String
  rtype  : RecordType
  rclass : QueryClass
  ttl    : Bits32
  rdata  : List Bits8
