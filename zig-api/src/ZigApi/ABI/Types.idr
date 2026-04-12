-- SPDX-License-Identifier: PMPL-1.0-or-later
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
data Handle = MkHandle (ptr : Bits64)

||| Pool slot index (0..63). The Zig pool holds max 64 instances.
public export
data Slot = MkSlot (idx : Bits8)

||| Slot validity: index must be < 64.
public export
data ValidSlot : Slot -> Type where
  IsValid : (idx : Bits8) -> So (idx < 64) -> ValidSlot (MkSlot idx)

-- ============================================================================
-- Roundtrip lemmas
-- ============================================================================

||| resultTag is injective: equal tags imply equal Results.
public export
resultTagInjective : (r s : Result) -> resultTag r = resultTag s -> r = s
resultTagInjective Ok           Ok           _ = Refl
resultTagInjective Err          Err          _ = Refl
resultTagInjective InvalidParam InvalidParam _ = Refl
resultTagInjective OutOfMemory  OutOfMemory  _ = Refl
resultTagInjective NullPointer  NullPointer  _ = Refl
resultTagInjective PathDenied   PathDenied   _ = Refl
resultTagInjective ProcessFailed ProcessFailed _ = Refl
resultTagInjective Timeout      Timeout      _ = Refl
resultTagInjective NotFound     NotFound     _ = Refl
resultTagInjective AlreadyExists AlreadyExists _ = Refl
resultTagInjective SlotExhausted SlotExhausted _ = Refl
-- Mismatched cases are impossible because the tags differ.
resultTagInjective Ok Err prf = absurd prf
resultTagInjective Ok InvalidParam prf = absurd prf
resultTagInjective Ok OutOfMemory prf = absurd prf
resultTagInjective Ok NullPointer prf = absurd prf
resultTagInjective Ok PathDenied prf = absurd prf
resultTagInjective Ok ProcessFailed prf = absurd prf
resultTagInjective Ok Timeout prf = absurd prf
resultTagInjective Ok NotFound prf = absurd prf
resultTagInjective Ok AlreadyExists prf = absurd prf
resultTagInjective Ok SlotExhausted prf = absurd prf
resultTagInjective Err Ok prf = absurd prf
resultTagInjective Err InvalidParam prf = absurd prf
resultTagInjective Err OutOfMemory prf = absurd prf
resultTagInjective Err NullPointer prf = absurd prf
resultTagInjective Err PathDenied prf = absurd prf
resultTagInjective Err ProcessFailed prf = absurd prf
resultTagInjective Err Timeout prf = absurd prf
resultTagInjective Err NotFound prf = absurd prf
resultTagInjective Err AlreadyExists prf = absurd prf
resultTagInjective Err SlotExhausted prf = absurd prf
resultTagInjective InvalidParam Ok prf = absurd prf
resultTagInjective InvalidParam Err prf = absurd prf
resultTagInjective InvalidParam OutOfMemory prf = absurd prf
resultTagInjective InvalidParam NullPointer prf = absurd prf
resultTagInjective InvalidParam PathDenied prf = absurd prf
resultTagInjective InvalidParam ProcessFailed prf = absurd prf
resultTagInjective InvalidParam Timeout prf = absurd prf
resultTagInjective InvalidParam NotFound prf = absurd prf
resultTagInjective InvalidParam AlreadyExists prf = absurd prf
resultTagInjective InvalidParam SlotExhausted prf = absurd prf
resultTagInjective OutOfMemory Ok prf = absurd prf
resultTagInjective OutOfMemory Err prf = absurd prf
resultTagInjective OutOfMemory InvalidParam prf = absurd prf
resultTagInjective OutOfMemory NullPointer prf = absurd prf
resultTagInjective OutOfMemory PathDenied prf = absurd prf
resultTagInjective OutOfMemory ProcessFailed prf = absurd prf
resultTagInjective OutOfMemory Timeout prf = absurd prf
resultTagInjective OutOfMemory NotFound prf = absurd prf
resultTagInjective OutOfMemory AlreadyExists prf = absurd prf
resultTagInjective OutOfMemory SlotExhausted prf = absurd prf
resultTagInjective NullPointer Ok prf = absurd prf
resultTagInjective NullPointer Err prf = absurd prf
resultTagInjective NullPointer InvalidParam prf = absurd prf
resultTagInjective NullPointer OutOfMemory prf = absurd prf
resultTagInjective NullPointer PathDenied prf = absurd prf
resultTagInjective NullPointer ProcessFailed prf = absurd prf
resultTagInjective NullPointer Timeout prf = absurd prf
resultTagInjective NullPointer NotFound prf = absurd prf
resultTagInjective NullPointer AlreadyExists prf = absurd prf
resultTagInjective NullPointer SlotExhausted prf = absurd prf
resultTagInjective PathDenied Ok prf = absurd prf
resultTagInjective PathDenied Err prf = absurd prf
resultTagInjective PathDenied InvalidParam prf = absurd prf
resultTagInjective PathDenied OutOfMemory prf = absurd prf
resultTagInjective PathDenied NullPointer prf = absurd prf
resultTagInjective PathDenied ProcessFailed prf = absurd prf
resultTagInjective PathDenied Timeout prf = absurd prf
resultTagInjective PathDenied NotFound prf = absurd prf
resultTagInjective PathDenied AlreadyExists prf = absurd prf
resultTagInjective PathDenied SlotExhausted prf = absurd prf
resultTagInjective ProcessFailed Ok prf = absurd prf
resultTagInjective ProcessFailed Err prf = absurd prf
resultTagInjective ProcessFailed InvalidParam prf = absurd prf
resultTagInjective ProcessFailed OutOfMemory prf = absurd prf
resultTagInjective ProcessFailed NullPointer prf = absurd prf
resultTagInjective ProcessFailed PathDenied prf = absurd prf
resultTagInjective ProcessFailed Timeout prf = absurd prf
resultTagInjective ProcessFailed NotFound prf = absurd prf
resultTagInjective ProcessFailed AlreadyExists prf = absurd prf
resultTagInjective ProcessFailed SlotExhausted prf = absurd prf
resultTagInjective Timeout Ok prf = absurd prf
resultTagInjective Timeout Err prf = absurd prf
resultTagInjective Timeout InvalidParam prf = absurd prf
resultTagInjective Timeout OutOfMemory prf = absurd prf
resultTagInjective Timeout NullPointer prf = absurd prf
resultTagInjective Timeout PathDenied prf = absurd prf
resultTagInjective Timeout ProcessFailed prf = absurd prf
resultTagInjective Timeout NotFound prf = absurd prf
resultTagInjective Timeout AlreadyExists prf = absurd prf
resultTagInjective Timeout SlotExhausted prf = absurd prf
resultTagInjective NotFound Ok prf = absurd prf
resultTagInjective NotFound Err prf = absurd prf
resultTagInjective NotFound InvalidParam prf = absurd prf
resultTagInjective NotFound OutOfMemory prf = absurd prf
resultTagInjective NotFound NullPointer prf = absurd prf
resultTagInjective NotFound PathDenied prf = absurd prf
resultTagInjective NotFound ProcessFailed prf = absurd prf
resultTagInjective NotFound Timeout prf = absurd prf
resultTagInjective NotFound AlreadyExists prf = absurd prf
resultTagInjective NotFound SlotExhausted prf = absurd prf
resultTagInjective AlreadyExists Ok prf = absurd prf
resultTagInjective AlreadyExists Err prf = absurd prf
resultTagInjective AlreadyExists InvalidParam prf = absurd prf
resultTagInjective AlreadyExists OutOfMemory prf = absurd prf
resultTagInjective AlreadyExists NullPointer prf = absurd prf
resultTagInjective AlreadyExists PathDenied prf = absurd prf
resultTagInjective AlreadyExists ProcessFailed prf = absurd prf
resultTagInjective AlreadyExists Timeout prf = absurd prf
resultTagInjective AlreadyExists NotFound prf = absurd prf
resultTagInjective AlreadyExists SlotExhausted prf = absurd prf
resultTagInjective SlotExhausted Ok prf = absurd prf
resultTagInjective SlotExhausted Err prf = absurd prf
resultTagInjective SlotExhausted InvalidParam prf = absurd prf
resultTagInjective SlotExhausted OutOfMemory prf = absurd prf
resultTagInjective SlotExhausted NullPointer prf = absurd prf
resultTagInjective SlotExhausted PathDenied prf = absurd prf
resultTagInjective SlotExhausted ProcessFailed prf = absurd prf
resultTagInjective SlotExhausted Timeout prf = absurd prf
resultTagInjective SlotExhausted NotFound prf = absurd prf
resultTagInjective SlotExhausted AlreadyExists prf = absurd prf

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
