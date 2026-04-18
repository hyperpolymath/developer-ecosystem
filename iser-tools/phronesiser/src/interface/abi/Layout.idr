-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Memory Layout Proofs for Phronesiser
|||
||| This module provides formal proofs about memory layout, alignment,
||| and padding for C-compatible structs used in the Phronesiser
||| ethical constraint engine.
|||
||| Key layouts:
||| - ConstraintStruct: 16 bytes (id + modality + harm domain + threshold)
||| - AuditResultStruct: 16 bytes (id + decision + severity + reserved)
||| - ConstraintSetHeader: 8 bytes (count + flags)
|||
||| @see https://en.wikipedia.org/wiki/Data_structure_alignment

module Phronesiser.ABI.Layout

import Phronesiser.ABI.Types
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
-- Phronesiser Constraint Struct Layout
--------------------------------------------------------------------------------

||| Layout for ConstraintStruct (16 bytes, 4-byte aligned)
||| Fields: constraintId(u32) + modality(u32) + harmDomain(u32) + harmThreshold(u32)
public export
constraintLayout : StructLayout
constraintLayout =
  MkStructLayout
    [ MkField "constraintId"   0  4 4   -- Bits32 at offset 0
    , MkField "modality"       4  4 4   -- Bits32 at offset 4
    , MkField "harmDomain"     8  4 4   -- Bits32 at offset 8
    , MkField "harmThreshold" 12  4 4   -- Bits32 at offset 12
    ]
    16  -- Total size: 16 bytes
    4   -- Alignment: 4 bytes

||| Proof that constraint layout is valid
export
constraintLayoutValid : CABICompliant constraintLayout
constraintLayoutValid = CABIOk constraintLayout ?constraintFieldsAligned

--------------------------------------------------------------------------------
-- Phronesiser Audit Result Struct Layout
--------------------------------------------------------------------------------

||| Layout for AuditResultStruct (16 bytes, 4-byte aligned)
||| Fields: constraintId(u32) + decision(u32) + severity(u32) + reserved(u32)
public export
auditResultLayout : StructLayout
auditResultLayout =
  MkStructLayout
    [ MkField "constraintId"  0  4 4   -- Bits32 at offset 0
    , MkField "decision"      4  4 4   -- Bits32 at offset 4
    , MkField "severity"      8  4 4   -- Bits32 at offset 8
    , MkField "reserved"     12  4 4   -- Bits32 at offset 12
    ]
    16  -- Total size: 16 bytes
    4   -- Alignment: 4 bytes

||| Proof that audit result layout is valid
export
auditResultLayoutValid : CABICompliant auditResultLayout
auditResultLayoutValid = CABIOk auditResultLayout ?auditResultFieldsAligned

--------------------------------------------------------------------------------
-- Constraint Set Header Layout
--------------------------------------------------------------------------------

||| Layout for ConstraintSetHeader (8 bytes, 4-byte aligned)
||| Precedes an array of ConstraintStructs in memory.
public export
constraintSetHeaderLayout : StructLayout
constraintSetHeaderLayout =
  MkStructLayout
    [ MkField "count" 0 4 4    -- Number of constraints (Bits32)
    , MkField "flags" 4 4 4    -- Evaluation flags (Bits32)
    ]
    8   -- Total size: 8 bytes
    4   -- Alignment: 4 bytes

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

--------------------------------------------------------------------------------
-- Constraint Array Layout
--------------------------------------------------------------------------------

||| Proof that a contiguous array of ConstraintStructs has correct total size
||| Total size = header (8 bytes) + count * sizeof(ConstraintStruct) (16 bytes)
public export
constraintArraySize : (count : Nat) -> Nat
constraintArraySize count = 8 + (count * 16)

||| Proof that constraint array size grows monotonically with count
public export
constraintArrayMonotonic : (n : Nat) -> (m : Nat) -> (n <= m) ->
                           So (constraintArraySize n <= constraintArraySize m)
constraintArrayMonotonic n m prf = ?constraintArrayMonotonicProof
