-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-trpc protocol.
-- Procedure types (query/mutation), router, middleware chain.

module Types

import Data.List

||| Kind of tRPC procedure: read-only query or state-changing mutation.
public export
data ProcedureKind : Type where
  Query    : ProcedureKind  -- Idempotent read (GET or POST)
  Mutation : ProcedureKind  -- State-changing write (POST only)

||| Opaque value type for procedure input/output at the ABI level.
public export
data TrpcValue : Type where
  ValNull   : TrpcValue
  ValBool   : Bool -> TrpcValue
  ValInt    : Integer -> TrpcValue
  ValStr    : String -> TrpcValue
  ValArray  : List TrpcValue -> TrpcValue
  ValObject : List (String, TrpcValue) -> TrpcValue

||| Error returned when a procedure invocation fails.
public export
record TrpcError where
  constructor MkTrpcError
  code    : String        -- Machine-readable code (e.g. "NOT_FOUND")
  message : String
  errData : Maybe TrpcValue

||| Result of invoking a procedure: success or typed error.
public export
data ProcedureResult : Type where
  ProcSuccess : (output : TrpcValue) -> ProcedureResult
  ProcError   : (err : TrpcError) -> ProcedureResult

||| A registered procedure with name, kind, and validation flag.
public export
record Procedure where
  constructor MkProcedure
  name         : String
  kind         : ProcedureKind
  hasValidator : Bool

||| A middleware step in the request processing chain.
public export
record Middleware where
  constructor MkMiddleware
  name     : String  -- Human-readable name for logging
  priority : Nat     -- Lower runs first

||| Per-request context threaded through middleware and handlers.
public export
record Context where
  constructor MkContext
  headers : List (String, String)
  meta    : List (String, String)

||| Router collecting procedures and middleware into a unit.
public export
record Router where
  constructor MkRouter
  procedures : List Procedure
  middleware : List Middleware
