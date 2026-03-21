-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-ws protocol.
-- WebSocket types: frame types, connection states.

module Types

||| WebSocket frame type.
public export
data WsFrameType : Type where
  Text   : WsFrameType
  Binary : WsFrameType
  Ping   : WsFrameType
  Pong   : WsFrameType
  Close  : WsFrameType

||| WebSocket connection state.
public export
data WsState : Type where
  Connecting : WsState
  Open       : WsState
  Closing    : WsState
  Closed     : WsState

||| WebSocket connection.
public export
record WsConnection where
  constructor MkWsConnection
  connId      : String
  url         : String
  state       : WsState
  subprotocol : String
