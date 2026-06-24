-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-mcp protocol.
-- MCP types: message types, tool definitions, parameters.

module Types

import Data.List

||| MCP protocol message type.
public export
data McpMessageType : Type where
  Request      : McpMessageType
  Response     : McpMessageType
  Notification : McpMessageType
  ErrorMsg     : McpMessageType

||| Tool parameter type.
public export
data ParamType : Type where
  StringType  : ParamType
  NumberType  : ParamType
  BooleanType : ParamType
  ArrayType   : ParamType
  ObjectType  : ParamType

||| MCP tool parameter.
public export
record McpParam where
  constructor MkMcpParam
  name        : String
  paramType   : ParamType
  required    : Bool
  description : String

||| MCP tool.
public export
record McpTool where
  constructor MkMcpTool
  name        : String
  description : String
  parameters  : List McpParam
