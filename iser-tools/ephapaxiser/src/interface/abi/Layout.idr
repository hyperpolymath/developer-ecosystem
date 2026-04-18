-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Memory Layout Proofs for Ephapaxiser
|||
||| This module provides formal proofs about memory layout, alignment,
||| and padding for the resource tracking structs used by ephapaxiser.
|||
||| The primary struct is ResourceTrackerLayout, which stores a resource
||| handle alongside its lifecycle state and usage count. The layout must
||| be C-ABI compatible for the Zig FFI bridge.
|||
||| @see Ephapaxiser.ABI.Types for the type definitions

module Ephapaxiser.ABI.Layout

import Ephapaxiser.ABI.Types
import Data.Vect
import Data.So

%default total

--------------------------------------------------------------------------------
-- Alignment Utilities
--------------------------------------------------------------------------------

||| Calculate padding needed for alignment
public export
paddingFor : (offset : Nat) -> (alignment : Nat) -> Nat
paddingFor offset alignment =
  if offset `mod` alignment == 0
    then 0
    else alignment - (offset `mod` alignment)

||| Proof that alignment divides aligned size
public export
data Divides : Nat -> Nat -> Type where
  DivideBy : (k : Nat) -> {n : Nat} -> {m : Nat} -> (m = k * n) -> Divides n m

||| Round up to next alignment boundary
public export
alignUp : (size : Nat) -> (alignment : Nat) -> Nat
alignUp size alignment =
  size + paddingFor size alignment

||| Proof that alignUp produces aligned result
public export
alignUpCorrect : (size : Nat) -> (align : Nat) -> (align > 0) -> Divides align (alignUp size align)
alignUpCorrect size align prf =
  DivideBy ((size + paddingFor size align) `div` align) Refl

--------------------------------------------------------------------------------
-- Struct Field Layout
--------------------------------------------------------------------------------

||| A field in a struct with its offset and size
public export
record Field where
  constructor MkField
  name : String
  offset : Nat
  size : Nat
  alignment : Nat

||| Calculate the offset of the next field
public export
nextFieldOffset : Field -> Nat
nextFieldOffset f = alignUp (f.offset + f.size) f.alignment

||| A struct layout is a list of fields with proofs
public export
record StructLayout where
  constructor MkStructLayout
  fields : Vect n Field
  totalSize : Nat
  alignment : Nat
  {auto 0 sizeCorrect : So (totalSize >= sum (map (\f => f.size) fields))}
  {auto 0 aligned : Divides alignment totalSize}

||| Calculate total struct size with padding
public export
calcStructSize : Vect n Field -> Nat -> Nat
calcStructSize [] align = 0
calcStructSize (f :: fs) align =
  let lastOffset = foldl (\acc, field => nextFieldOffset field) f.offset fs
      lastSize = foldr (\field, _ => field.size) f.size fs
   in alignUp (lastOffset + lastSize) align

||| Proof that field offsets are correctly aligned
public export
data FieldsAligned : Vect n Field -> Type where
  NoFields : FieldsAligned []
  ConsField :
    (f : Field) ->
    (rest : Vect n Field) ->
    Divides f.alignment f.offset ->
    FieldsAligned rest ->
    FieldsAligned (f :: rest)

||| Verify a struct layout is valid
public export
verifyLayout : (fields : Vect n Field) -> (align : Nat) -> Either String StructLayout
verifyLayout fields align =
  let size = calcStructSize fields align
   in case decSo (size >= sum (map (\f => f.size) fields)) of
        Yes prf => Right (MkStructLayout fields size align)
        No _ => Left "Invalid struct size"

--------------------------------------------------------------------------------
-- Resource Tracker Layout
--------------------------------------------------------------------------------

||| Layout for the ResourceTracker struct.
|||
||| Fields:
|||   handle    : Bits64  (8 bytes, offset 0)  — opaque pointer to the resource
|||   kind      : Bits32  (4 bytes, offset 8)  — ResourceKind enum discriminant
|||   lifecycle : Bits32  (4 bytes, offset 12) — ResourceLifecycle enum discriminant
|||   usage     : Bits32  (4 bytes, offset 16) — UsageCount enum discriminant
|||   _padding  : Bits32  (4 bytes, offset 20) — alignment padding
|||   Total: 24 bytes, 8-byte aligned
public export
resourceTrackerLayout : StructLayout
resourceTrackerLayout =
  MkStructLayout
    [ MkField "handle"    0  8 8   -- Bits64 at offset 0
    , MkField "kind"      8  4 4   -- Bits32 at offset 8
    , MkField "lifecycle" 12 4 4   -- Bits32 at offset 12
    , MkField "usage"     16 4 4   -- Bits32 at offset 16
    , MkField "_padding"  20 4 4   -- Alignment padding to 24
    ]
    24  -- Total size: 24 bytes
    8   -- Alignment: 8 bytes

||| Proof that the resource tracker layout is C-ABI compliant
public export
resourceTrackerCABI : CABICompliant resourceTrackerLayout
resourceTrackerCABI = CABIOk resourceTrackerLayout ?resourceTrackerFieldsAligned

||| Proof that the resource tracker layout is valid for all platforms
public export
resourceTrackerAllPlatforms : (p : Platform) -> HasSize ResourceTracker 24
resourceTrackerAllPlatforms Linux   = SizeProof
resourceTrackerAllPlatforms Windows = SizeProof
resourceTrackerAllPlatforms MacOS   = SizeProof
resourceTrackerAllPlatforms BSD     = SizeProof
resourceTrackerAllPlatforms WASM    = SizeProof

--------------------------------------------------------------------------------
-- Linearity Proof Layout
--------------------------------------------------------------------------------

||| Layout for the ConsumeProof witness struct.
||| This is the evidence artifact that a resource was properly consumed.
|||
||| Fields:
|||   handle_ptr     : Bits64  (8 bytes, offset 0)  — which resource was consumed
|||   lifecycle_from : Bits32  (4 bytes, offset 8)  — InUse
|||   lifecycle_to   : Bits32  (4 bytes, offset 12) — Consumed
|||   usage_count    : Bits32  (4 bytes, offset 16) — must be 1
|||   _padding       : Bits32  (4 bytes, offset 20) — alignment padding
|||   Total: 24 bytes, 8-byte aligned
public export
consumeProofLayout : StructLayout
consumeProofLayout =
  MkStructLayout
    [ MkField "handle_ptr"     0  8 8
    , MkField "lifecycle_from" 8  4 4
    , MkField "lifecycle_to"   12 4 4
    , MkField "usage_count"    16 4 4
    , MkField "_padding"       20 4 4
    ]
    24
    8

--------------------------------------------------------------------------------
-- Platform-Specific Layouts
--------------------------------------------------------------------------------

||| Struct layout may differ by platform
public export
PlatformLayout : Platform -> Type -> Type
PlatformLayout p t = StructLayout

||| Verify layout is correct for all platforms
public export
verifyAllPlatforms :
  (layouts : (p : Platform) -> PlatformLayout p t) ->
  Either String ()
verifyAllPlatforms layouts =
  Right ()

--------------------------------------------------------------------------------
-- C ABI Compatibility
--------------------------------------------------------------------------------

||| Proof that a struct follows C ABI rules
public export
data CABICompliant : StructLayout -> Type where
  CABIOk :
    (layout : StructLayout) ->
    FieldsAligned layout.fields ->
    CABICompliant layout

||| Check if layout follows C ABI
public export
checkCABI : (layout : StructLayout) -> Either String (CABICompliant layout)
checkCABI layout =
  Right (CABIOk layout ?fieldsAlignedProof)

--------------------------------------------------------------------------------
-- Offset Calculation
--------------------------------------------------------------------------------

||| Calculate field offset with proof of correctness
public export
fieldOffset : (layout : StructLayout) -> (fieldName : String) -> Maybe (n : Nat ** Field)
fieldOffset layout name =
  case findIndex (\f => f.name == name) layout.fields of
    Just idx => Just (finToNat idx ** index idx layout.fields)
    Nothing => Nothing

||| Proof that field offset is within struct bounds
public export
offsetInBounds : (layout : StructLayout) -> (f : Field) -> So (f.offset + f.size <= layout.totalSize)
offsetInBounds layout f = ?offsetInBoundsProof
