-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-opcua protocol.
-- OPC UA node identifiers, data types, security modes,
-- session states, and subscription structures.

module Types

import Data.List

||| OPC UA node identifier type (Part 6, section 5.2.2.9).
public export
data NodeIdType : Type where
  Numeric : NodeIdType  -- Namespace index + unsigned integer
  String_ : NodeIdType  -- Namespace index + string
  Guid    : NodeIdType  -- Namespace index + GUID
  Opaque  : NodeIdType  -- Namespace index + ByteString

||| OPC UA node class (Part 3, section 8.30).
public export
data NodeClass : Type where
  Object         : NodeClass
  Variable       : NodeClass
  Method         : NodeClass
  ObjectType     : NodeClass
  VariableType   : NodeClass
  ReferenceType  : NodeClass
  DataType       : NodeClass
  View           : NodeClass

||| OPC UA security mode for the session channel.
public export
data SecurityMode : Type where
  SecurityNone        : SecurityMode  -- No security
  SecuritySign        : SecurityMode  -- Messages signed
  SecuritySignEncrypt : SecurityMode  -- Messages signed and encrypted

||| OPC UA session lifecycle state.
public export
data SessionState : Type where
  Closed    : SessionState
  Creating  : SessionState
  Active    : SessionState
  Closing   : SessionState

||| OPC UA data value with status and timestamps.
public export
record DataValue where
  constructor MkDataValue
  value          : String         -- String-encoded value
  statusCode     : Nat
  sourceTimestamp : String
  serverTimestamp : String

||| A node in the OPC UA address space.
public export
record NodeInfo where
  constructor MkNodeInfo
  nodeId      : String
  nodeClass   : NodeClass
  browseName  : String
  displayName : String
  description : String

||| Subscription parameters for monitored items.
public export
record SubscriptionParams where
  constructor MkSubscriptionParams
  publishingInterval : Nat     -- Milliseconds
  lifetimeCount      : Nat
  maxKeepAliveCount  : Nat
  maxNotifications   : Nat
  priority           : Nat
