-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-websocket protocol.
-- WebSocket message types, connection states, and room membership.

module Types

import Data.List

||| WebSocket opcode as defined by RFC 6455 section 5.2.
public export
data Opcode : Type where
  Continuation : Opcode
  Text         : Opcode
  Binary       : Opcode
  Close        : Opcode
  Ping         : Opcode
  Pong         : Opcode

||| Lifecycle state of a WebSocket connection.
public export
data ConnState : Type where
  Connecting : ConnState  -- TCP up, upgrade not yet sent
  Open       : ConnState  -- Upgrade accepted, frames may flow
  Closing    : ConnState  -- Close sent, awaiting peer ack
  Closed     : ConnState  -- Fully terminated

||| A WebSocket frame with opcode, fin bit, and payload.
public export
record Frame where
  constructor MkFrame
  opcode     : Opcode
  fin        : Bool
  payload    : List Bits8
  payloadLen : Nat

||| Unique identifier for a connected client.
public export
record ClientId where
  constructor MkClientId
  value : String

||| Named room grouping clients for broadcast delivery.
public export
record Room where
  constructor MkRoom
  name    : String
  members : List ClientId

||| Close status code per RFC 6455 section 7.4.1.
public export
data CloseCode : Type where
  NormalClosure   : CloseCode                                         -- 1000
  GoingAway       : CloseCode                                         -- 1001
  ProtocolError   : CloseCode                                         -- 1002
  UnsupportedData : CloseCode                                         -- 1003
  AppDefined      : (code : Nat) -> {auto prf : LTE 4000 code} -> CloseCode
