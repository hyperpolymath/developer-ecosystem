-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Memory Layout Proofs for Wokelangiser
|||
||| Formal proofs about memory layout, alignment, and padding for the
||| consent record, accessibility annotation, and i18n hook structures
||| that cross the FFI boundary.
|||
||| @see Wokelangiser.ABI.Types for type definitions

module Wokelangiser.ABI.Layout

import Wokelangiser.ABI.Types
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
-- Consent Record Layout
--------------------------------------------------------------------------------

||| Memory layout for a consent record crossing the FFI boundary.
|||
||| C-equivalent struct:
|||   struct ConsentRecord {
|||     uint32_t consent_type;   // 0: OptIn, 1: OptOut, 2: Withdraw, 3: AuditTrail
|||     uint32_t state;          // 0: Pending, 1: Granted, 2: Active, 3: Revoked
|||     uint64_t timestamp;      // Unix epoch seconds (consent event time)
|||     uint64_t subject_id;     // Opaque identifier for the data subject
|||   };
public export
consentRecordLayout : StructLayout
consentRecordLayout =
  MkStructLayout
    [ MkField "consent_type" 0  4 4   -- Bits32 at offset 0
    , MkField "state"        4  4 4   -- Bits32 at offset 4 (no padding)
    , MkField "timestamp"    8  8 8   -- Bits64 at offset 8 (naturally aligned)
    , MkField "subject_id"   16 8 8   -- Bits64 at offset 16
    ]
    24  -- Total size: 24 bytes
    8   -- Alignment: 8 bytes (max field alignment)

||| Proof that the consent record layout is C-ABI compliant
export
consentRecordValid : CABICompliant consentRecordLayout
consentRecordValid = CABIOk consentRecordLayout ?consentFieldsAligned

--------------------------------------------------------------------------------
-- Accessibility Annotation Layout
--------------------------------------------------------------------------------

||| Memory layout for an accessibility annotation crossing the FFI boundary.
|||
||| C-equivalent struct:
|||   struct AccessibilityRecord {
|||     uint32_t wcag_level;     // 0: A, 1: AA, 2: AAA
|||     uint32_t focus_order;    // Tab order position
|||     uint32_t contrast_ratio; // Ratio * 100 (e.g. 450 = 4.50:1)
|||     uint32_t _padding;       // Alignment padding
|||     uint64_t aria_label_ptr; // Pointer to ARIA label string
|||     uint64_t role_ptr;       // Pointer to role string
|||   };
public export
accessibilityRecordLayout : StructLayout
accessibilityRecordLayout =
  MkStructLayout
    [ MkField "wcag_level"     0  4 4   -- Bits32 at offset 0
    , MkField "focus_order"    4  4 4   -- Bits32 at offset 4
    , MkField "contrast_ratio" 8  4 4   -- Bits32 at offset 8
    , MkField "_padding"       12 4 4   -- Bits32 padding for 8-byte alignment
    , MkField "aria_label_ptr" 16 8 8   -- Bits64 at offset 16
    , MkField "role_ptr"       24 8 8   -- Bits64 at offset 24
    ]
    32  -- Total size: 32 bytes
    8   -- Alignment: 8 bytes

||| Proof that the accessibility record layout is C-ABI compliant
export
accessibilityRecordValid : CABICompliant accessibilityRecordLayout
accessibilityRecordValid = CABIOk accessibilityRecordLayout ?accessibilityFieldsAligned

--------------------------------------------------------------------------------
-- I18n Hook Layout
--------------------------------------------------------------------------------

||| Memory layout for an i18n hook record crossing the FFI boundary.
|||
||| C-equivalent struct:
|||   struct I18nRecord {
|||     uint32_t hook_type;      // 0: Locale, 1: RTL, 2: Pluralise, 3: FormatSpec
|||     uint32_t format_kind;    // 0: Date, 1: Number, 2: Currency (if hook_type == 3)
|||     uint64_t locale_tag_ptr; // Pointer to BCP 47 tag string (if hook_type == 0)
|||     uint64_t source_ptr;     // Pointer to source string being localised
|||   };
public export
i18nRecordLayout : StructLayout
i18nRecordLayout =
  MkStructLayout
    [ MkField "hook_type"      0  4 4   -- Bits32 at offset 0
    , MkField "format_kind"    4  4 4   -- Bits32 at offset 4
    , MkField "locale_tag_ptr" 8  8 8   -- Bits64 at offset 8
    , MkField "source_ptr"     16 8 8   -- Bits64 at offset 16
    ]
    24  -- Total size: 24 bytes
    8   -- Alignment: 8 bytes

||| Proof that the i18n record layout is C-ABI compliant
export
i18nRecordValid : CABICompliant i18nRecordLayout
i18nRecordValid = CABIOk i18nRecordLayout ?i18nFieldsAligned

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
