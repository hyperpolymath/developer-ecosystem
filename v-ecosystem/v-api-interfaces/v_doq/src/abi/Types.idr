-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-doq protocol.
-- DNS over QUIC types: QUIC stream handles, DoQ messages,
-- connection state, and TLS session descriptors.

module Types

import Data.List

||| QUIC connection state.
public export
data QuicState : Type where
  Initial     : QuicState
  Handshaking : QuicState
  Connected   : QuicState
  Draining    : QuicState
  Closed      : QuicState

||| DoQ query descriptor.
public export
record DoqQuery where
  constructor MkDoqQuery
  queryId  : Bits16
  name     : String
  qtype    : Bits16
  streamId : Bits64

||| DoQ response descriptor.
public export
record DoqResponse where
  constructor MkDoqResponse
  queryId   : Bits16
  rcode     : Bits8
  answers   : Nat
  latencyUs : Bits64
