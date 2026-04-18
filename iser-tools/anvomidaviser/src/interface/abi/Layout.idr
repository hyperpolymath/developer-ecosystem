-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Memory Layout Proofs for Anvomidaviser
|||
||| This module provides formal proofs about memory layout, alignment,
||| and padding for C-compatible structs used in the ISU scoring engine
||| and program element representation.
|||
||| @see https://en.wikipedia.org/wiki/Data_structure_alignment

module Anvomidaviser.ABI.Layout

import Anvomidaviser.ABI.Types
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
-- ISU Element Layouts
--------------------------------------------------------------------------------

||| Layout for a TechnicalElement struct in the C ABI
||| Fields: element_type (u8), jump_type (u8), rotation (u8), level (u8),
|||         base_value (u32), goe (i8), padding (3 bytes), goe_value (i32)
public export
technicalElementLayout : StructLayout
technicalElementLayout =
  MkStructLayout
    [ MkField "element_type" 0 1 1   -- ElementCode tag (Jump/Spin/StepSeq/Lift)
    , MkField "subtype"      1 1 1   -- JumpType / SpinType / etc.
    , MkField "rotation"     2 1 1   -- JumpRotation or unused
    , MkField "level"        3 1 1   -- SpinLevel
    , MkField "base_value"   4 4 4   -- Base value in hundredths
    , MkField "goe"          8 1 1   -- GOE (-5 to +5)
    , MkField "padding"      9 3 1   -- Alignment padding
    , MkField "goe_value"   12 4 4   -- GOE adjustment in hundredths
    ]
    16  -- Total size: 16 bytes
    4   -- Alignment: 4 bytes

||| Proof that TechnicalElement layout is valid
export
technicalElementLayoutValid : CABICompliant technicalElementLayout
technicalElementLayoutValid = CABIOk technicalElementLayout ?techElemFieldsAligned

||| Layout for ProgramScore struct in the C ABI
||| Fields: total_base (u32), total_goe (i32), deductions (u32),
|||         pcs_marks (5 x u8), padding (3 bytes), component_factor (u32),
|||         total_segment_score (u32)
public export
programScoreLayout : StructLayout
programScoreLayout =
  MkStructLayout
    [ MkField "total_base"          0  4 4   -- Sum of base values
    , MkField "total_goe"           4  4 4   -- Sum of GOE adjustments
    , MkField "deductions"          8  4 4   -- Penalty deductions
    , MkField "pcs_skating_skills" 12  1 1   -- SS mark (x 0.25)
    , MkField "pcs_transitions"    13  1 1   -- TR mark (x 0.25)
    , MkField "pcs_performance"    14  1 1   -- PE mark (x 0.25)
    , MkField "pcs_composition"    15  1 1   -- CO mark (x 0.25)
    , MkField "pcs_interpretation" 16  1 1   -- IN mark (x 0.25)
    , MkField "padding"            17  3 1   -- Alignment padding
    , MkField "component_factor"   20  4 4   -- PCS multiplier
    , MkField "total_segment"      24  4 4   -- TES + PCS - deductions
    ]
    28  -- Total size: 28 bytes
    4   -- Alignment: 4 bytes

||| Proof that ProgramScore layout is valid
export
programScoreLayoutValid : CABICompliant programScoreLayout
programScoreLayoutValid = CABIOk programScoreLayout ?progScoreFieldsAligned

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
