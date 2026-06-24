-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-amqp protocol.
-- AMQP 0-9-1 frame types, method classes, exchange types,
-- delivery modes, and message properties for reliable messaging.

module Types

import Data.List

||| AMQP frame type identifier.
public export
data FrameType : Type where
  MethodFrame    : FrameType  -- Method invocation
  HeaderFrame    : FrameType  -- Content header
  BodyFrame      : FrameType  -- Content body
  HeartbeatFrame : FrameType  -- Keepalive

||| AMQP exchange routing strategy.
public export
data ExchangeType : Type where
  Direct  : ExchangeType  -- Exact routing key match
  Topic   : ExchangeType  -- Pattern-based routing
  Fanout  : ExchangeType  -- Broadcast to all queues
  Headers : ExchangeType  -- Header attribute matching

||| Delivery mode for message persistence.
public export
data DeliveryMode : Type where
  Transient  : DeliveryMode  -- Lost on broker restart
  Persistent : DeliveryMode  -- Survives broker restart

||| Queue declaration parameters.
public export
record QueueDeclare where
  constructor MkQueueDeclare
  name       : String
  durable    : Bool
  exclusive  : Bool
  autoDelete : Bool

||| Message publication parameters.
public export
record PublishParams where
  constructor MkPublishParams
  exchange   : String
  routingKey : String
  mandatory  : Bool
  immediate  : Bool

||| AMQP wire frame.
public export
record Frame where
  constructor MkFrame
  frameType : FrameType
  channel   : Bits16
  payload   : List Bits8
