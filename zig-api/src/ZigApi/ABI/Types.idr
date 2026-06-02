-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
-- Types.idr — Core ABI types for unified-zig-api
--
-- This module defines the foundational types shared across all ZigApi modules.
-- Every Bits8 tag is the authoritative source of truth for the corresponding
-- Zig `enum(u8)` or `enum(c_int)` — no drift allowed.

module ZigApi.ABI.Types

import Data.Bits
import Data.So

%default total

-- ============================================================================
-- Platform
-- ============================================================================

||| Target platform — selects pointer width and alignment rules.
public export
data Platform = Linux | Windows | MacOS | BSD | WASM

||| The platform this module is compiled for.
public export
thisPlatform : Platform
thisPlatform = Linux

||| Pointer size in bits per platform.
public export
ptrSize : Platform -> Nat
ptrSize Linux   = 64
ptrSize Windows = 64
ptrSize MacOS   = 64
ptrSize BSD     = 64
ptrSize WASM    = 32

-- ============================================================================
-- Result / Error codes  (must match Zig `pub const Result = enum(u8)`)
-- ============================================================================

||| Fine-grained result codes for all uapi_* functions.
public export
data Result
  = Ok              -- 0  success
  | Err             -- 1  generic error
  | InvalidParam    -- 2  bad argument
  | OutOfMemory     -- 3  allocation failure
  | NullPointer     -- 4  null handle / buffer
  | PathDenied      -- 5  safe_path rejected the path
  | ProcessFailed   -- 6  subprocess exited non-zero
  | Timeout         -- 7  operation timed out
  | NotFound        -- 8  resource not found
  | AlreadyExists   -- 9  duplicate registration
  | SlotExhausted   -- 10 all pool slots occupied

||| Bijection: Result → Bits8.  Tag values match the Zig enum.
public export
resultTag : Result -> Bits8
resultTag Ok            = 0
resultTag Err           = 1
resultTag InvalidParam  = 2
resultTag OutOfMemory   = 3
resultTag NullPointer   = 4
resultTag PathDenied    = 5
resultTag ProcessFailed = 6
resultTag Timeout       = 7
resultTag NotFound      = 8
resultTag AlreadyExists = 9
resultTag SlotExhausted = 10

||| Partial inverse: Bits8 → Result.
public export
resultFromTag : Bits8 -> Maybe Result
resultFromTag 0  = Just Ok
resultFromTag 1  = Just Err
resultFromTag 2  = Just InvalidParam
resultFromTag 3  = Just OutOfMemory
resultFromTag 4  = Just NullPointer
resultFromTag 5  = Just PathDenied
resultFromTag 6  = Just ProcessFailed
resultFromTag 7  = Just Timeout
resultFromTag 8  = Just NotFound
resultFromTag 9  = Just AlreadyExists
resultFromTag 10 = Just SlotExhausted
resultFromTag _  = Nothing

-- ============================================================================
-- Handle and Slot
-- ============================================================================

||| Opaque 64-bit handle — wraps a pointer passed across the C ABI.
public export
data Handle = MkHandle Bits64

||| Pool slot index (0..63). The Zig pool holds max 64 instances.
public export
data Slot = MkSlot Bits8

||| Slot validity: index must be < 64.
public export
data ValidSlot : Slot -> Type where
  IsValid : (idx : Bits8) -> So (idx < 64) -> ValidSlot (MkSlot idx)

-- ============================================================================
-- Roundtrip lemmas
-- ============================================================================

||| Roundtrip: decoding an encoded tag recovers the original Result.
public export
resultRoundtrip : (r : Result) -> resultFromTag (resultTag r) = Just r
resultRoundtrip Ok            = Refl
resultRoundtrip Err           = Refl
resultRoundtrip InvalidParam  = Refl
resultRoundtrip OutOfMemory   = Refl
resultRoundtrip NullPointer   = Refl
resultRoundtrip PathDenied    = Refl
resultRoundtrip ProcessFailed = Refl
resultRoundtrip Timeout       = Refl
resultRoundtrip NotFound      = Refl
resultRoundtrip AlreadyExists = Refl
resultRoundtrip SlotExhausted = Refl

-- Helper: Just is an injective constructor.
justInj : {0 a, b : t} -> Just a = Just b -> a = b
justInj Refl = Refl

||| resultTag is injective: equal tags imply equal Results.
||| Proof: roundtrip through resultFromTag; no Bits8 Uninhabited instances needed.
public export
resultTagInjective : (r : Result) -> (s : Result) -> (resultTag r = resultTag s) -> r = s
resultTagInjective r s prf =
  let lhs  = resultRoundtrip r
      rhs  = resultRoundtrip s
      step = cong resultFromTag prf
      eq   = trans (sym lhs) (trans step rhs)
  in justInj eq
