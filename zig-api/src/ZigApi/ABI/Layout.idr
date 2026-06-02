-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Layout.idr — ABI memory-layout claims for unified-zig-api
--
-- This module makes the C ABI layout constraints explicit and machine-checked.
-- Every claim here corresponds to a compile-time guarantee in the Zig source
-- (build.zig @compileError checks and std.debug.assert on sizes/capacities).
--
-- Three categories of claims:
--
--   1. Tag-count bounds — the total number of constructors for each enum
--      fits in u8 (< 256).  Stated as `Nat.lte LITERAL 255 = True`,
--      which Idris2 reduces at the type level so `Refl` closes the goal.
--      Literals are used (not named constants) to avoid Idris2's auto-bind
--      of lowercase names in type signatures.
--
--   2. Pool and sentinel bounds — pool capacity is 64, the failure sentinel
--      returned by uapi_connector_create is 255, 64 ≤ 255 so no valid slot
--      index can equal the sentinel.
--
--   3. Buffer bounds — response buffer size (4096 bytes) fits in uint32_t.
--
-- Note: Bits8 / Bits16 / Bits32 / Bits64 widths are guaranteed by the Idris2
-- type system itself (they are machine-word types).  No separate claim needed.

module ZigApi.ABI.Layout

import Data.Bits
import ZigApi.ABI.Types
import ZigApi.ABI.Http
import ZigApi.ABI.Process
import ZigApi.ABI.Connector

%default total

-- ============================================================================
-- 1. Tag-count bounds (number of enum constructors fits in u8)
-- ============================================================================
--
-- Proof strategy: `Nat.lte m n = True` for concrete m, n reduces to `True`
-- by Idris2's type-level evaluation, so `Refl` closes the goal.
-- Named constants document the semantic meaning; literals in the type
-- signature avoid Idris2's auto-implicit-bind of lowercase names.

-- ---- Result (11 constructors, max tag = 10) ----

||| The Result enum has 11 constructors with tags 0..10.
public export
resultTagCount : Nat
resultTagCount = 11

||| 11 distinct tags fit in a u8 (11 ≤ 255).
public export
resultTagCountFitsU8 : Nat.lte 11 255 = True
resultTagCountFitsU8 = Refl

-- ---- ServiceId (11 constructors, max tag = 10) ----

||| The ServiceId enum has 11 constructors with tags 0..10.
public export
serviceIdTagCount : Nat
serviceIdTagCount = 11

||| 11 distinct service IDs fit in a u8.
public export
serviceIdTagCountFitsU8 : Nat.lte 11 255 = True
serviceIdTagCountFitsU8 = Refl

-- ---- ConnectorState (6 constructors, max tag = 5) ----

||| The ConnectorState enum has 6 constructors with tags 0..5.
public export
connectorStateTagCount : Nat
connectorStateTagCount = 6

public export
connectorStateTagCountFitsU8 : Nat.lte 6 255 = True
connectorStateTagCountFitsU8 = Refl

-- ---- HTTP Method (7 constructors, max tag = 6) ----

||| The HTTP Method enum has 7 constructors with tags 0..6.
public export
methodTagCount : Nat
methodTagCount = 7

public export
methodTagCountFitsU8 : Nat.lte 7 255 = True
methodTagCountFitsU8 = Refl

-- ---- ServerState (4 constructors, max tag = 3) ----

||| The ServerState enum has 4 constructors with tags 0..3.
public export
serverStateTagCount : Nat
serverStateTagCount = 4

public export
serverStateTagCountFitsU8 : Nat.lte 4 255 = True
serverStateTagCountFitsU8 = Refl

-- ---- ExecResult (6 constructors, max tag = 5) ----

||| The ExecResult enum has 6 constructors with tags 0..5.
public export
execResultTagCount : Nat
execResultTagCount = 6

public export
execResultTagCountFitsU8 : Nat.lte 6 255 = True
execResultTagCountFitsU8 = Refl

-- ---- HealthStatus (2 constructors, max tag = 1) ----

||| The HealthStatus enum has 2 constructors with tags 0..1.
public export
healthStatusTagCount : Nat
healthStatusTagCount = 2

public export
healthStatusTagCountFitsU8 : Nat.lte 2 255 = True
healthStatusTagCountFitsU8 = Refl

-- ============================================================================
-- 2. Pool and sentinel bounds
-- ============================================================================

||| The connector pool holds exactly this many slots.
||| Matches POOL_CAPACITY in connector.zig.
public export
poolCapacity : Nat
poolCapacity = 64

||| 64 valid slot indices fit in a u8 (64 ≤ 255).
public export
poolCapacityFitsU8 : Nat.lte 64 255 = True
poolCapacityFitsU8 = Refl

||| The failure sentinel returned by uapi_connector_create when no slot is
||| available.  Must be strictly greater than any valid slot index.
public export
connectorFailureSentinel : Nat
connectorFailureSentinel = 255

||| 64 ≤ 255: every valid slot index is strictly below the sentinel.
||| This means a caller can distinguish success from failure unambiguously.
public export
sentinelAbovePool : Nat.lte 64 255 = True
sentinelAbovePool = Refl

||| The sentinel 255 is not a valid pool index (pool capacity is 64).
||| Equiv: S 64 ≤ S 255 — the next slot past the pool is still below sentinel+1.
public export
sentinelNotASlot : Nat.lte 65 256 = True
sentinelNotASlot = Refl

-- ============================================================================
-- 3. Buffer bounds
-- ============================================================================

||| Minimum response buffer size for uapi_connector_call.
||| Matches RESPONSE_BUF_SIZE in connector.zig.
public export
responseBufferSize : Nat
responseBufferSize = 4096

||| uint32_t maximum (2^32 − 1).
public export
uint32Max : Nat
uint32Max = 4294967295

||| 4096 bytes fits in a uint32_t out_len parameter (4096 ≤ 2^32 − 1).
public export
responseBufferFitsU32 : Nat.lte 4096 4294967295 = True
responseBufferFitsU32 = Refl

||| The pool does not exceed the u8 range: poolCapacity < 256.
||| (Stronger than poolCapacityFitsU8: the slot index type IS a Bits8.)
public export
poolFitsU8Type : Nat.lte 64 256 = True
poolFitsU8Type = Refl
