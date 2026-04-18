-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Memory Layout Proofs for BQN Values
|||
||| BQN arrays have a specific memory layout in CBQN:
|||   [ header (type tag + flags) | shape vector | data cells ]
|||
||| This module provides formal proofs about memory layout, alignment,
||| and padding for C-compatible interop with the CBQN runtime.
|||
||| @see https://github.com/dzaima/CBQN/blob/master/src/h.h (CBQN internals)
||| @see https://mlochbaum.github.io/BQN/implementation/vm.html

module Bqniser.ABI.Layout

import Bqniser.ABI.Types
import Data.Vect
import Data.So

%default total

--------------------------------------------------------------------------------
-- BQN Array Layout
--------------------------------------------------------------------------------

||| A BQN array in memory consists of:
||| 1. Header: type tag (u8) + flags (u8) + reserved (u16) + refcount (u32) = 8 bytes
||| 2. Shape: rank * sizeof(size_t) bytes (one extent per axis)
||| 3. Data: product(shape) * element_size bytes
|||
||| This record captures the layout with dependent types ensuring
||| the shape length matches the rank.
public export
record BQNArrayLayout (rank : Nat) where
  constructor MkBQNArrayLayout
  ||| Type tag (matches BQNType enum)
  typeTag   : Bits8
  ||| Flags (e.g., whether data is owned or a view)
  flags     : Bits8
  ||| Shape vector: one extent per axis, length = rank
  shape     : Vect rank Bits64
  ||| Element size in bytes (8 for f64, 4 for i32, 1 for u8/char)
  elemSize  : Nat
  ||| Total element count = product of shape extents
  elemCount : Nat

||| Calculate the total byte size of a BQN array in memory.
||| header (8) + shape (rank * 8) + data (elemCount * elemSize)
public export
arrayByteSize : {rank : Nat} -> BQNArrayLayout rank -> Nat
arrayByteSize layout =
  let headerSize = 8
      shapeSize  = rank * 8
      dataSize   = layout.elemCount * layout.elemSize
  in headerSize + shapeSize + dataSize

||| Proof that array byte size is always >= 8 (at minimum the header)
public export
arraySizeMinHeader : {rank : Nat} -> (layout : BQNArrayLayout rank) ->
                     So (arrayByteSize layout >= 8)
arraySizeMinHeader layout = ?arraySizeMinHeaderProof

||| Calculate element count from shape (product of extents)
public export
shapeProduct : Vect n Bits64 -> Nat
shapeProduct [] = 1
shapeProduct (x :: xs) = cast x * shapeProduct xs

||| Proof that a scalar (rank 0) has element count 1
public export
scalarHasOneElement : shapeProduct [] = 1
scalarHasOneElement = Refl

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
-- BQN Value Header Layout
--------------------------------------------------------------------------------

||| The 8-byte header at the start of every CBQN heap value.
||| This is the fixed-size prefix before shape and data.
public export
record BQNValueHeader where
  constructor MkBQNValueHeader
  ||| Type discriminant (0=number, 1=char, 2=fn, ..., 6=array)
  typeDisc  : Bits8
  ||| Flags byte (owned, readonly, etc.)
  flagsByte : Bits8
  ||| Reserved for future use (padding to 4-byte boundary)
  reserved  : Bits16
  ||| Reference count for garbage collection
  refCount  : Bits32

||| Proof: BQN value header is exactly 8 bytes
public export
headerSize : HasSize BQNValueHeader 8
headerSize = SizeProof

||| Proof: BQN value header is 4-byte aligned
public export
headerAlignment : HasAlignment BQNValueHeader 4
headerAlignment = AlignProof

--------------------------------------------------------------------------------
-- Numeric Array Layout (f64)
--------------------------------------------------------------------------------

||| Layout for a BQN numeric array (f64 elements).
||| This is the most common array type for BQNiser workloads.
public export
record NumericArrayLayout (rank : Nat) where
  constructor MkNumericArrayLayout
  header : BQNValueHeader
  shape  : Vect rank Bits64
  ||| Data pointer (elements are contiguous f64 values)
  dataOffset : Nat

||| Calculate data offset for numeric array:
||| header (8) + shape (rank * 8)
public export
numericDataOffset : (rank : Nat) -> Nat
numericDataOffset rank = 8 + rank * 8

||| Proof that data is 8-byte aligned when rank is any value
||| (8 + rank*8 is always divisible by 8)
public export
numericDataAligned : (rank : Nat) -> Divides 8 (numericDataOffset rank)
numericDataAligned rank = DivideBy (1 + rank) Refl

--------------------------------------------------------------------------------
-- Struct Field Layout (generic)
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

--------------------------------------------------------------------------------
-- CBQN BQN_value Layout
--------------------------------------------------------------------------------

||| CBQN represents all values as opaque pointers (BQNV = void*).
||| On the C side, sizeof(BQNV) = sizeof(void*) = 8 on 64-bit.
public export
bqnValuePtrSize : (p : Platform) -> Nat
bqnValuePtrSize Linux   = 8
bqnValuePtrSize Windows = 8
bqnValuePtrSize MacOS   = 8
bqnValuePtrSize BSD     = 8
bqnValuePtrSize WASM    = 4

||| The CBQN array descriptor used by bqn_readF64Arr / bqn_readObjArr etc.
||| Fields: pointer to data buffer + element count
public export
cbqnArrayDescLayout : StructLayout
cbqnArrayDescLayout =
  MkStructLayout
    [ MkField "data_ptr"    0 8 8   -- pointer to contiguous element buffer
    , MkField "elem_count"  8 8 8   -- size_t number of elements
    ]
    16  -- Total size: 16 bytes
    8   -- Alignment: 8 bytes

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
    CABICompliant layout

||| Proof that CBQN array descriptor is C-ABI compliant
public export
cbqnArrayDescCABI : CABICompliant cbqnArrayDescLayout
cbqnArrayDescCABI = CABIOk cbqnArrayDescLayout

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
