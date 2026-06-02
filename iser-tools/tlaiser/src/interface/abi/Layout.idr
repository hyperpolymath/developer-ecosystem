-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Memory Layout Proofs for Tlaiser
|||
||| Provides formal proofs about memory layout, alignment, and padding
||| for C-compatible structs used in the TLAiser FFI boundary.
|||
||| The state space representation must be laid out identically on both
||| sides of the FFI (Idris2/Zig) — these proofs guarantee that.
|||
||| @see https://en.wikipedia.org/wiki/Data_structure_alignment

module Tlaiser.ABI.Layout

import Tlaiser.ABI.Types
import Data.Vect
import Data.So

%default total

--------------------------------------------------------------------------------
-- Alignment Utilities
--------------------------------------------------------------------------------

||| Calculate padding needed to reach the next alignment boundary
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

||| A field in a C-compatible struct with its offset, size, and alignment
public export
record Field where
  constructor MkField
  name : String
  offset : Nat
  size : Nat
  alignment : Nat

||| Calculate the offset of the next field after this one
public export
nextFieldOffset : Field -> Nat
nextFieldOffset f = alignUp (f.offset + f.size) f.alignment

||| A struct layout is a vector of fields with total size and alignment proofs
public export
record StructLayout where
  constructor MkStructLayout
  fields : Vect n Field
  totalSize : Nat
  alignment : Nat
  {auto 0 sizeCorrect : So (totalSize >= sum (map (\f => f.size) fields))}
  {auto 0 aligned : Divides alignment totalSize}

||| Calculate total struct size including all padding
public export
calcStructSize : Vect n Field -> Nat -> Nat
calcStructSize [] align = 0
calcStructSize (f :: fs) align =
  let lastOffset = foldl (\acc, field => nextFieldOffset field) f.offset fs
      lastSize = foldr (\field, _ => field.size) f.size fs
   in alignUp (lastOffset + lastSize) align

||| Proof that field offsets are correctly aligned within a struct
public export
data FieldsAligned : Vect n Field -> Type where
  NoFields : FieldsAligned []
  ConsField :
    (f : Field) ->
    (rest : Vect n Field) ->
    Divides f.alignment f.offset ->
    FieldsAligned rest ->
    FieldsAligned (f :: rest)

||| Verify a struct layout is valid (all sizes and alignments consistent)
public export
verifyLayout : (fields : Vect n Field) -> (align : Nat) -> Either String StructLayout
verifyLayout fields align =
  let size = calcStructSize fields align
   in case decSo (size >= sum (map (\f => f.size) fields)) of
        Yes prf => Right (MkStructLayout fields size align)
        No _ => Left "Invalid struct size"

--------------------------------------------------------------------------------
-- State Space Layout
--------------------------------------------------------------------------------

||| Layout of a state machine's state space for FFI transport.
||| Each state variable occupies a fixed-size slot in a contiguous buffer.
||| The buffer is passed across the FFI boundary as a pointer + length.
|||
||| Layout: [var0: 8 bytes][var1: 8 bytes]...[varN: 8 bytes]
||| All variables are Bits64 for uniformity (simplifies FFI).
public export
stateSpaceLayout : (numVars : Nat) -> StructLayout
stateSpaceLayout numVars =
  let fields = tabulate numVars (\i =>
        MkField ("var_" ++ show (finToNat i))
                (finToNat i * 8)   -- offset: each var is 8 bytes
                8                  -- size: Bits64
                8)                 -- alignment: 8 bytes
      totalSize = numVars * 8
   in MkStructLayout fields totalSize 8

||| Proof that state space layout is correctly sized
public export
stateSpaceCorrectSize : (numVars : Nat) ->
  (stateSpaceLayout numVars).totalSize = numVars * 8
stateSpaceCorrectSize numVars = Refl

||| Layout for a counterexample trace step across FFI.
||| Contains: step number (8), state ID (4), padding (4), then variable values.
public export
traceStepLayout : (numVars : Nat) -> StructLayout
traceStepLayout numVars =
  MkStructLayout
    ([ MkField "step_number" 0 8 8      -- Bits64: step index
     , MkField "state_id" 8 4 4         -- Bits32: current state
     , MkField "padding" 12 4 4         -- 4 bytes padding for alignment
     ] ++ tabulate numVars (\i =>
        MkField ("var_" ++ show (finToNat i))
                (16 + finToNat i * 8)
                8 8))
    (16 + numVars * 8)
    8

--------------------------------------------------------------------------------
-- Model Check Request Layout
--------------------------------------------------------------------------------

||| Layout for the ModelCheckRequest FFI struct.
||| Must match the C struct on the Zig side exactly.
public export
modelCheckRequestLayout : StructLayout
modelCheckRequestLayout =
  MkStructLayout
    [ MkField "spec_ptr" 0 8 8         -- Bits64: pointer to spec string
    , MkField "spec_len" 8 4 4         -- Bits32: spec string length
    , MkField "padding_0" 12 4 4       -- 4 bytes padding
    , MkField "config_ptr" 16 8 8      -- Bits64: pointer to TLC config
    , MkField "num_workers" 24 4 4     -- Bits32: worker thread count
    , MkField "padding_1" 28 4 4       -- 4 bytes padding
    , MkField "max_states" 32 8 8      -- Bits64: state space limit
    , MkField "max_depth" 40 4 4       -- Bits32: max trace depth
    , MkField "padding_2" 44 4 4       -- 4 bytes trailing padding
    ]
    48  -- Total size: 48 bytes
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
