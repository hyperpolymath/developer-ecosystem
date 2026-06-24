-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-odns protocol.
-- ODoH types: query types, responses.

module Types

import Data.List

||| DNS query type.
public export
data DnsQueryType : Type where
  A     : DnsQueryType
  AAAA  : DnsQueryType
  CNAME : DnsQueryType
  MX    : DnsQueryType
  TXT   : DnsQueryType
  SRV   : DnsQueryType
  NS    : DnsQueryType

||| ODoH query.
public export
record OdnsQuery where
  constructor MkOdnsQuery
  name      : String
  queryType : DnsQueryType

||| ODoH response.
public export
record OdnsResponse where
  constructor MkOdnsResponse
  name      : String
  queryType : DnsQueryType
  answers   : List String
  ttl       : Nat
