-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-mqtt protocol.
-- MQTT 3.1.1 packet types, QoS levels, topic filters, connection states.

module Types

import Data.List

||| Quality of Service level (MQTT 3.1.1 section 4.3).
public export
data QoS : Type where
  AtMostOnce  : QoS  -- QoS 0: fire and forget
  AtLeastOnce : QoS  -- QoS 1: acknowledged delivery
  ExactlyOnce : QoS  -- QoS 2: four-step handshake

||| MQTT control packet type (4-bit code, upper nibble of byte 1).
public export
data PacketType : Type where
  Connect     : PacketType
  ConnAck     : PacketType
  Publish     : PacketType
  PubAck      : PacketType
  PubRec      : PacketType
  PubRel      : PacketType
  PubComp     : PacketType
  Subscribe   : PacketType
  SubAck      : PacketType
  Unsubscribe : PacketType
  UnsubAck    : PacketType
  PingReq     : PacketType
  PingResp    : PacketType
  Disconnect  : PacketType

||| CONNACK return codes (section 3.2.2.3).
public export
data ConnReturnCode : Type where
  Accepted           : ConnReturnCode
  BadProtocolVersion : ConnReturnCode
  IdentifierRejected : ConnReturnCode
  ServerUnavailable  : ConnReturnCode
  BadCredentials     : ConnReturnCode
  NotAuthorised      : ConnReturnCode

||| Client connection lifecycle state.
public export
data ConnState : Type where
  Disconnected : ConnState
  Connecting   : ConnState
  Connected    : ConnState

||| Topic filter for subscriptions (may contain + and # wildcards).
public export
record TopicFilter where
  constructor MkTopicFilter
  pattern : String
  qos     : QoS

||| A PUBLISH message with delivery metadata.
public export
record PublishMsg where
  constructor MkPublishMsg
  topic    : String
  payload  : List Bits8
  qos      : QoS
  retain   : Bool
  packetId : Nat
