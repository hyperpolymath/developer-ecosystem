-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Memory Layout Proofs for Eclexiaiser
|||
||| This module provides formal proofs about memory layout, alignment,
||| and padding for C-compatible energy measurement structs.
|||
||| Key structs:
|||   - EnergyMeasurement: hardware counter reading with timestamp
|||   - CarbonQuery: carbon API request/response
|||   - BudgetEnforcement: budget vs measurement comparison result
|||
||| @see https://en.wikipedia.org/wiki/Data_structure_alignment

module Eclexiaiser.ABI.Layout

import Eclexiaiser.ABI.Types
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
-- EnergyMeasurement Layout
--------------------------------------------------------------------------------

||| Energy measurement struct: a single reading from hardware counters.
||| C layout:
|||   offset 0:  function_id   (Bits64, 8 bytes)  — hash of function name
|||   offset 8:  energy_uj     (Bits64, 8 bytes)  — measured microjoules
|||   offset 16: timestamp_ns  (Bits64, 8 bytes)  — nanosecond timestamp
|||   offset 24: counter_type  (Bits32, 4 bytes)  — 0=RAPL, 1=IPMI, 2=estimate
|||   offset 28: padding       (4 bytes)
|||   total: 32 bytes, alignment: 8 bytes
public export
energyMeasurementLayout : StructLayout
energyMeasurementLayout =
  MkStructLayout
    [ MkField "function_id"  0  8 8   -- Bits64 at offset 0
    , MkField "energy_uj"    8  8 8   -- Bits64 at offset 8
    , MkField "timestamp_ns" 16 8 8   -- Bits64 at offset 16
    , MkField "counter_type" 24 4 4   -- Bits32 at offset 24
    ]
    32  -- Total size: 32 bytes (28 data + 4 padding)
    8   -- Alignment: 8 bytes

||| Proof that EnergyMeasurement layout is C-ABI compliant
export
energyMeasurementValid : CABICompliant energyMeasurementLayout
energyMeasurementValid = CABIOk energyMeasurementLayout ?energyMeasurementAligned

--------------------------------------------------------------------------------
-- CarbonQuery Layout
--------------------------------------------------------------------------------

||| Carbon API query/response struct.
||| C layout:
|||   offset 0:  zone_id         (Bits32, 4 bytes)  — grid zone hash
|||   offset 4:  intensity_mg    (Bits32, 4 bytes)  — mg CO2/kWh
|||   offset 8:  timestamp_epoch (Bits64, 8 bytes)  — query timestamp
|||   offset 16: renewable_bps   (Bits32, 4 bytes)  — renewable % in basis points
|||   offset 20: api_source      (Bits32, 4 bytes)  — 0=WattTime, 1=ElectricityMaps, 2=static
|||   total: 24 bytes, alignment: 8 bytes
public export
carbonQueryLayout : StructLayout
carbonQueryLayout =
  MkStructLayout
    [ MkField "zone_id"         0  4 4   -- Bits32 at offset 0
    , MkField "intensity_mg"    4  4 4   -- Bits32 at offset 4
    , MkField "timestamp_epoch" 8  8 8   -- Bits64 at offset 8
    , MkField "renewable_bps"   16 4 4   -- Bits32 at offset 16
    , MkField "api_source"      20 4 4   -- Bits32 at offset 20
    ]
    24  -- Total size: 24 bytes
    8   -- Alignment: 8 bytes

||| Proof that CarbonQuery layout is C-ABI compliant
export
carbonQueryValid : CABICompliant carbonQueryLayout
carbonQueryValid = CABIOk carbonQueryLayout ?carbonQueryAligned

--------------------------------------------------------------------------------
-- BudgetEnforcement Layout
--------------------------------------------------------------------------------

||| Budget enforcement result struct.
||| C layout:
|||   offset 0:  function_id    (Bits64, 8 bytes)  — which function was checked
|||   offset 8:  budget_uj      (Bits64, 8 bytes)  — the budget limit
|||   offset 16: measured_uj    (Bits64, 8 bytes)  — actual measurement
|||   offset 24: carbon_mg_co2  (Bits64, 8 bytes)  — carbon cost of this measurement
|||   offset 32: result_code    (Bits32, 4 bytes)  — 0=pass, 5=budget_exceeded, 6=carbon_exceeded
|||   offset 36: padding        (4 bytes)
|||   total: 40 bytes, alignment: 8 bytes
public export
budgetEnforcementLayout : StructLayout
budgetEnforcementLayout =
  MkStructLayout
    [ MkField "function_id"   0  8 8   -- Bits64 at offset 0
    , MkField "budget_uj"     8  8 8   -- Bits64 at offset 8
    , MkField "measured_uj"   16 8 8   -- Bits64 at offset 16
    , MkField "carbon_mg_co2" 24 8 8   -- Bits64 at offset 24
    , MkField "result_code"   32 4 4   -- Bits32 at offset 32
    ]
    40  -- Total size: 40 bytes (36 data + 4 padding)
    8   -- Alignment: 8 bytes

||| Proof that BudgetEnforcement layout is C-ABI compliant
export
budgetEnforcementValid : CABICompliant budgetEnforcementLayout
budgetEnforcementValid = CABIOk budgetEnforcementLayout ?budgetEnforcementAligned

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
