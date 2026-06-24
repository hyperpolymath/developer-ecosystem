-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-ptp protocol.
-- PTP message types, clock classes, timestamp format,
-- and port identity for precision time sync (IEEE 1588).

module Types

import Data.List
import Data.Vect

||| PTP message type.
public export
data MessageType : Type where
  Sync       : MessageType
  DelayReq   : MessageType
  FollowUp   : MessageType
  DelayResp  : MessageType
  Announce   : MessageType

||| PTP clock class.
public export
data ClockClass : Type where
  PrimaryReference : ClockClass  -- 6
  Holdover         : ClockClass  -- 7
  AppSpecific      : ClockClass  -- 13
  DefaultClass     : ClockClass  -- 248
  SlaveOnly        : ClockClass  -- 255

||| PTP timestamp (seconds + nanoseconds).
public export
record Timestamp where
  constructor MkTimestamp
  secondsMsb : Bits16
  seconds    : Bits32
  nanoseconds : Bits32

||| 8-byte clock identity.
public export
ClockIdentity : Type
ClockIdentity = Vect 8 Bits8

||| Port identity (clock + port number).
public export
record PortIdentity where
  constructor MkPortIdentity
  clockId    : ClockIdentity
  portNumber : Bits16
