-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-mdns protocol.
-- mDNS/DNS-SD service discovery types, record types, and
-- service instance structures for zero-config networking (RFC 6762).

module Types

import Data.List

||| DNS-SD service discovery record type.
public export
data RecordType : Type where
  A    : RecordType  -- IPv4 address
  AAAA : RecordType  -- IPv6 address
  PTR  : RecordType  -- Service type pointer
  SRV  : RecordType  -- Service location
  TXT  : RecordType  -- Service metadata

||| Discovered service instance.
public export
record ServiceInfo where
  constructor MkServiceInfo
  instanceName : String
  serviceType  : String
  domain       : String
  hostname     : String
  port         : Bits16
  txtRecords   : List (String, String)
