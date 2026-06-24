-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-doh protocol.
-- DNS-over-HTTPS record types, response structures, and
-- resolver configuration for encrypted DNS (RFC 8484).

module Types

import Data.List

||| DNS record type (shared with standard DNS).
public export
data RecordType : Type where
  A     : RecordType  -- IPv4
  AAAA  : RecordType  -- IPv6
  CNAME : RecordType  -- Canonical name
  MX    : RecordType  -- Mail exchange
  TXT   : RecordType  -- Text record
  SRV   : RecordType  -- Service locator

||| DoH answer record.
public export
record DnsAnswer where
  constructor MkDnsAnswer
  name  : String
  rtype : RecordType
  ttl   : Bits32
  rdata : String

||| DoH response.
public export
record DohResponse where
  constructor MkDohResponse
  status  : Nat
  answers : List DnsAnswer
