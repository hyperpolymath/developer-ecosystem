-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-netconf protocol.
-- NETCONF datastores, RPC operations, capability types,
-- and session structures for network configuration (RFC 6241).

module Types

import Data.List

||| NETCONF configuration datastore.
public export
data Datastore : Type where
  Running   : Datastore  -- Active configuration
  Candidate : Datastore  -- Staged changes
  Startup   : Datastore  -- Boot configuration

||| NETCONF RPC operation type.
public export
data Operation : Type where
  Get        : Operation
  GetConfig  : Operation
  EditConfig : Operation
  CopyConfig : Operation
  Lock       : Operation
  Unlock     : Operation
  CloseSession : Operation
  KillSession  : Operation

||| NETCONF capability.
public export
record Capability where
  constructor MkCapability
  uri : String

||| NETCONF RPC reply.
public export
record RpcReply where
  constructor MkRpcReply
  messageId : String
  ok        : Bool
  payload   : String
  errors    : List String
