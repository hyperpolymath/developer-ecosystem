-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-bgp protocol.
-- BGP-4 message types, FSM states, path attributes, and
-- NLRI structures for inter-AS routing (RFC 4271).

module Types

import Data.List

||| BGP finite state machine state.
public export
data FsmState : Type where
  Idle        : FsmState
  Connect     : FsmState
  Active      : FsmState
  OpenSent    : FsmState
  OpenConfirm : FsmState
  Established : FsmState

||| BGP message type.
public export
data MessageType : Type where
  Open         : MessageType
  Update       : MessageType
  Notification : MessageType
  Keepalive    : MessageType

||| BGP origin attribute.
public export
data Origin : Type where
  IGP        : Origin
  EGP        : Origin
  Incomplete : Origin

||| IP prefix (network/length).
public export
record Prefix where
  constructor MkPrefix
  network : String
  length  : Bits8

||| BGP path attribute.
public export
record PathAttribute where
  constructor MkPathAttribute
  typeCode : Bits8
  value    : List Bits8
