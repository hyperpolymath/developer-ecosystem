-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-ntp protocol.
-- NTPv4 (RFC 5905) timestamp format, stratum levels, leap
-- indicators, and query result structures.

module Types

||| Leap indicator values (2-bit field in NTP header).
public export
data LeapIndicator : Type where
  NoWarning      : LeapIndicator  -- No leap second adjustment
  LastMinute61   : LeapIndicator  -- Last minute of day has 61 seconds
  LastMinute59   : LeapIndicator  -- Last minute of day has 59 seconds
  AlarmCondition : LeapIndicator  -- Clock not synchronised

||| NTP mode values (3-bit field).
public export
data NtpMode : Type where
  Reserved        : NtpMode
  SymmetricActive : NtpMode
  SymmetricPassive : NtpMode
  Client          : NtpMode
  Server          : NtpMode
  Broadcast       : NtpMode

||| NTP 64-bit timestamp (seconds since 1900-01-01 + fraction).
public export
record Timestamp where
  constructor MkTimestamp
  seconds  : Bits32   -- Whole seconds since NTP epoch
  fraction : Bits32   -- Fractional second (2^-32 resolution)

||| NTP time query result with clock offset and delay.
public export
record TimeResult where
  constructor MkTimeResult
  offset      : Double   -- Clock offset in seconds
  delay       : Double   -- Round-trip delay in seconds
  stratum     : Nat      -- Server stratum level
  referenceId : String   -- Reference source identifier
  leap        : LeapIndicator
