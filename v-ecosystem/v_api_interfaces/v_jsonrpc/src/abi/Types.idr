-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-jsonrpc protocol.
-- JSON-RPC 2.0 request/response types, error codes, batch requests.

module Types

import Data.List

||| Minimal JSON value subset for RPC payloads.
public export
data JsonValue : Type where
  JsonNull   : JsonValue
  JsonBool   : Bool -> JsonValue
  JsonInt    : Integer -> JsonValue
  JsonString : String -> JsonValue
  JsonArray  : List JsonValue -> JsonValue
  JsonObject : List (String, JsonValue) -> JsonValue

||| Request identifier (string, number, or null for notifications).
public export
data RequestId : Type where
  IdNum  : Integer -> RequestId
  IdStr  : String -> RequestId
  IdNull : RequestId

||| Standard JSON-RPC 2.0 error codes (spec section 5.1).
public export
data ErrorCode : Type where
  ParseError     : ErrorCode  -- -32700
  InvalidRequest : ErrorCode  -- -32600
  MethodNotFound : ErrorCode  -- -32601
  InvalidParams  : ErrorCode  -- -32602
  InternalError  : ErrorCode  -- -32603
  ServerError    : (code : Integer) -> ErrorCode  -- [-32099..-32000]

||| Structured error object attached to failure responses.
public export
record RpcError where
  constructor MkRpcError
  code    : ErrorCode
  message : String
  errData : Maybe JsonValue

||| A single JSON-RPC 2.0 request.
public export
record Request where
  constructor MkRequest
  method : String
  params : Maybe JsonValue
  reqId  : RequestId

||| A JSON-RPC 2.0 response (exactly one of result or error).
public export
data Response : Type where
  Success : (reqId : RequestId) -> (result : JsonValue) -> Response
  Failure : (reqId : RequestId) -> (err : RpcError) -> Response

||| Non-empty batch of requests sent as a JSON array.
public export
record Batch where
  constructor MkBatch
  first : Request
  rest  : List Request
