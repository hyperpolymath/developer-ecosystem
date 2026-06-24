-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-dot protocol.
-- DNS over TLS types: TLS session state, DoT messages,
-- EDNS0 options, and connection parameters.

module Types

import Data.List

||| TLS enforcement mode.
public export
data TlsMode : Type where
  Strict        : TlsMode
  Opportunistic : TlsMode

||| DoT query descriptor.
public export
record DotQuery where
  constructor MkDotQuery
  queryId : Bits16
  name    : String
  qtype   : Bits16
  edns0   : Bool

||| DoT response descriptor.
public export
record DotResponse where
  constructor MkDotResponse
  queryId   : Bits16
  rcode     : Bits8
  answers   : Nat
  truncated : Bool
