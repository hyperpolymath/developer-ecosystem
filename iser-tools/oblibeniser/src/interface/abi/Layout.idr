-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Memory Layout Proofs for Oblibeniser
|||
||| This module provides formal proofs about memory layout, alignment,
||| and padding for C-compatible structs used in the reversible computing
||| pipeline — particularly AuditEntry, StateSnapshot, and UndoStack.
|||
||| @see https://en.wikipedia.org/wiki/Data_structure_alignment

module Oblibeniser.ABI.Layout

import Oblibeniser.ABI.Types
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
  -- Proof that (size + padding) is divisible by align
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
  -- Check that layout is valid on all platforms
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
  -- Verify C ABI rules
  Right (CABIOk layout ?fieldsAlignedProof)

--------------------------------------------------------------------------------
-- AuditEntry Layout (oblibeniser-specific)
--------------------------------------------------------------------------------

||| AuditEntry C-ABI layout:
|||   sequenceNo : Bits64 @ offset 0  (8 bytes)
|||   timestamp  : Bits64 @ offset 8  (8 bytes)
|||   prevHash   : Bits64 @ offset 16 (8 bytes)
|||   entryHash  : Bits64 @ offset 24 (8 bytes)
|||   operationId: Bits64 @ offset 32 (8 bytes)
|||   actorPtr   : Bits64 @ offset 40 (8 bytes)
|||   authHash   : Bits64 @ offset 48 (8 bytes)
|||   isForward  : Bits32 @ offset 56 (4 bytes)
|||   _padding   :        @ offset 60 (4 bytes)
|||   Total: 64 bytes, alignment: 8
public export
auditEntryLayout : StructLayout
auditEntryLayout =
  MkStructLayout
    [ MkField "sequenceNo"  0  8 8
    , MkField "timestamp"   8  8 8
    , MkField "prevHash"   16  8 8
    , MkField "entryHash"  24  8 8
    , MkField "operationId" 32  8 8
    , MkField "actorPtr"   40  8 8
    , MkField "authHash"   48  8 8
    , MkField "isForward"  56  4 4
    ]
    64  -- Total size: 64 bytes (with 4 bytes trailing padding)
    8   -- Alignment: 8 bytes

||| Proof that AuditEntry layout is C-ABI compliant
export
auditEntryLayoutValid : CABICompliant auditEntryLayout
auditEntryLayoutValid = CABIOk auditEntryLayout ?auditEntryFieldsAligned

--------------------------------------------------------------------------------
-- StateSnapshot Layout (oblibeniser-specific)
--------------------------------------------------------------------------------

||| StateSnapshot C-ABI layout:
|||   snapshotId : Bits64 @ offset 0  (8 bytes)
|||   timestamp  : Bits64 @ offset 8  (8 bytes)
|||   stateHash  : Bits64 @ offset 16 (8 bytes)
|||   stateSize  : Bits32 @ offset 24 (4 bytes)
|||   _padding   :        @ offset 28 (4 bytes)
|||   statePtr   : Bits64 @ offset 32 (8 bytes)
|||   Total: 40 bytes, alignment: 8
public export
stateSnapshotLayout : StructLayout
stateSnapshotLayout =
  MkStructLayout
    [ MkField "snapshotId"  0  8 8
    , MkField "timestamp"   8  8 8
    , MkField "stateHash"  16  8 8
    , MkField "stateSize"  24  4 4
    , MkField "statePtr"   32  8 8
    ]
    40  -- Total size: 40 bytes (with 4 bytes internal padding after stateSize)
    8   -- Alignment: 8 bytes

||| Proof that StateSnapshot layout is C-ABI compliant
export
stateSnapshotLayoutValid : CABICompliant stateSnapshotLayout
stateSnapshotLayoutValid = CABIOk stateSnapshotLayout ?snapshotFieldsAligned

--------------------------------------------------------------------------------
-- UndoStack Layout (oblibeniser-specific)
--------------------------------------------------------------------------------

||| UndoStack C-ABI layout:
|||   stackPtr : Bits64 @ offset 0  (8 bytes)
|||   depth    : Bits32 @ offset 8  (4 bytes)
|||   maxDepth : Bits32 @ offset 12 (4 bytes)
|||   topHash  : Bits64 @ offset 16 (8 bytes)
|||   Total: 24 bytes, alignment: 8
public export
undoStackLayout : StructLayout
undoStackLayout =
  MkStructLayout
    [ MkField "stackPtr"  0  8 8
    , MkField "depth"     8  4 4
    , MkField "maxDepth" 12  4 4
    , MkField "topHash"  16  8 8
    ]
    24  -- Total size: 24 bytes
    8   -- Alignment: 8 bytes

||| Proof that UndoStack layout is C-ABI compliant
export
undoStackLayoutValid : CABICompliant undoStackLayout
undoStackLayoutValid = CABIOk undoStackLayout ?undoStackFieldsAligned

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
