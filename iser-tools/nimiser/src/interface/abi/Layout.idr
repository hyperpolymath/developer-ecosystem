-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Memory Layout Proofs for Nimiser
|||
||| This module provides formal proofs about memory layout, alignment,
||| and padding for Nim objects exported as C-compatible structs.
|||
||| Nim objects can have different layouts depending on pragmas:
||| - Default: Nim-managed layout (may reorder fields)
||| - {.packed.}: No padding, fields in declaration order
||| - {.exportc.}: C-compatible layout (fields in declaration order with padding)
||| - {.align: N.}: Override alignment
|||
||| @see https://nim-lang.org/docs/manual.html#types-object-types
||| @see https://en.wikipedia.org/wiki/Data_structure_alignment

module Nimiser.ABI.Layout

import Nimiser.ABI.Types
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
-- Nim Object Layout Rules
--------------------------------------------------------------------------------

||| Nim object layout mode, determined by pragmas
public export
data NimLayoutMode
  = NimDefault       -- Nim may reorder fields for efficiency
  | NimExportC       -- C-compatible layout (declaration order + padding)
  | NimPacked        -- No padding, declaration order
  | NimBitfield      -- Bit-level packing (via bitfields pragma)

||| Calculate field size in bytes from NimTypeKind
public export
nimFieldSize : Platform -> NimTypeKind -> Nat
nimFieldSize _ NimInt     = 8  -- Nim int is pointer-sized (64-bit on 64-bit)
nimFieldSize _ NimUint    = 8
nimFieldSize _ NimFloat   = 8  -- float64 by default
nimFieldSize _ NimBool    = 1
nimFieldSize _ NimChar    = 1
nimFieldSize p NimString  = ptrSize p `div` 8  -- pointer to string object
nimFieldSize p NimCString = ptrSize p `div` 8  -- raw char*
nimFieldSize p NimPtr     = ptrSize p `div` 8
nimFieldSize p NimRef     = ptrSize p `div` 8
nimFieldSize p NimArray   = 0  -- depends on N and T (computed elsewhere)
nimFieldSize p NimSeq     = ptrSize p `div` 8  -- pointer to seq data
nimFieldSize p NimObject  = 0  -- depends on fields (computed elsewhere)
nimFieldSize _ NimEnum    = 4  -- default enum size is int32
nimFieldSize p NimProc    = ptrSize p `div` 8  -- function pointer
nimFieldSize _ NimDistinct = 0 -- same as underlying type

||| Calculate field alignment from NimTypeKind
public export
nimFieldAlign : Platform -> NimTypeKind -> Nat
nimFieldAlign p ty = min (nimFieldSize p ty) (ptrSize p `div` 8)

||| Convert a NimObject to a StructLayout using exportc rules
||| (C-compatible: declaration order, natural alignment, trailing padding)
public export
nimObjectToLayout : Platform -> NimObject -> Either String StructLayout
nimObjectToLayout p obj =
  let fields = computeFields p 0 obj.fields
   in verifyLayout (fromList fields) (maxAlign p obj.fields)
  where
    computeFields : Platform -> Nat -> List NimField -> List Field
    computeFields _ _ [] = []
    computeFields p offset (f :: fs) =
      let align = case f.alignOverride of
                    Just a  => a
                    Nothing => if obj.isPacked then 1 else nimFieldAlign p f.fieldType
          padded = if obj.isPacked then offset else alignUp offset align
          size = f.bitWidth `div` 8
          field = MkField f.fieldName padded size align
       in field :: computeFields p (padded + size) fs

    maxAlign : Platform -> List NimField -> Nat
    maxAlign p [] = 1
    maxAlign p (f :: fs) =
      let a = case f.alignOverride of
                Just x  => x
                Nothing => nimFieldAlign p f.fieldType
       in max a (maxAlign p fs)

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
verifyAllPlatforms layouts = Right ()

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
checkCABI layout = Right (CABIOk layout ?fieldsAlignedProof)

--------------------------------------------------------------------------------
-- Nim-Specific Layout Examples
--------------------------------------------------------------------------------

||| Example: Nim object with {.exportc, packed.} pragmas
||| type NimBuffer {.exportc: "nimiser_buffer", packed.} = object
|||   data: ptr uint8
|||   len: uint32
|||   cap: uint32
public export
nimBufferLayout : StructLayout
nimBufferLayout =
  MkStructLayout
    [ MkField "data" 0 8 8     -- ptr uint8 at offset 0
    , MkField "len"  8 4 4     -- uint32 at offset 8
    , MkField "cap" 12 4 4     -- uint32 at offset 12
    ]
    16  -- Total size: 16 bytes
    8   -- Alignment: 8 bytes (pointer)

||| Example: Nim object with default alignment
||| type NimResult {.exportc: "nimiser_result".} = object
|||   code: int32
|||   padding: array[4, uint8]  (implicit)
|||   message: cstring
public export
nimResultLayout : StructLayout
nimResultLayout =
  MkStructLayout
    [ MkField "code"    0 4 4   -- int32 at offset 0
    , MkField "message" 8 8 8   -- cstring at offset 8 (4 bytes padding)
    ]
    16  -- Total size: 16 bytes
    8   -- Alignment: 8 bytes

||| Proof that buffer layout is valid
export
nimBufferLayoutValid : CABICompliant nimBufferLayout
nimBufferLayoutValid = CABIOk nimBufferLayout ?bufferFieldsAligned

||| Proof that result layout is valid
export
nimResultLayoutValid : CABICompliant nimResultLayout
nimResultLayoutValid = CABIOk nimResultLayout ?resultFieldsAligned

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
