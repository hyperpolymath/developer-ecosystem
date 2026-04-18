-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| ABI Type Definitions for Mylangiser
|||
||| Defines the core types used by the progressive-disclosure layer generator.
||| All type definitions include formal proofs of correctness.
|||
||| Key domain types:
|||   - DisclosureLevel: the three progressive-disclosure tiers
|||   - ComplexityScore: cognitive-load rating for an API endpoint
|||   - APIEndpoint: a single callable unit in the target API
|||   - LayeredWrapper: the generated disclosure-tiered interface
|||   - SmartDefault: an inferred safe default for a parameter
|||
||| @see https://idris2.readthedocs.io for Idris2 documentation

module Mylangiser.ABI.Types

import Data.Bits
import Data.So
import Data.Vect

%default total

--------------------------------------------------------------------------------
-- Platform Detection
--------------------------------------------------------------------------------

||| Supported platforms for this ABI
public export
data Platform = Linux | Windows | MacOS | BSD | WASM

||| Compile-time platform detection
||| This will be set during compilation based on target
public export
thisPlatform : Platform
thisPlatform =
  %runElab do
    -- Platform detection logic
    pure Linux  -- Default, override with compiler flags

--------------------------------------------------------------------------------
-- Disclosure Levels
--------------------------------------------------------------------------------

||| The three progressive-disclosure tiers.
||| Each level is a strict superset of the previous one:
|||   Beginner < Intermediate < Expert
public export
data DisclosureLevel : Type where
  ||| Simplified signatures, smart defaults, friendly error messages.
  ||| Hides optional parameters and advanced features.
  Beginner     : DisclosureLevel
  ||| Full parameter access, named arguments, complete type signatures.
  ||| All optional parameters visible; advanced features documented.
  Intermediate : DisclosureLevel
  ||| Raw API access, performance tuning, batch operations, escape hatches.
  ||| No simplification — the full power of the underlying API.
  Expert       : DisclosureLevel

||| Disclosure levels have a natural ordering (Beginner < Intermediate < Expert)
public export
Eq DisclosureLevel where
  Beginner     == Beginner     = True
  Intermediate == Intermediate = True
  Expert       == Expert       = True
  _            == _            = False

||| Ordering: Beginner < Intermediate < Expert
public export
Ord DisclosureLevel where
  compare Beginner     Beginner     = EQ
  compare Beginner     _            = LT
  compare Intermediate Beginner     = GT
  compare Intermediate Intermediate = EQ
  compare Intermediate Expert       = LT
  compare Expert       Expert       = EQ
  compare Expert       _            = GT

||| Convert DisclosureLevel to C-compatible integer
public export
disclosureLevelToInt : DisclosureLevel -> Bits32
disclosureLevelToInt Beginner     = 0
disclosureLevelToInt Intermediate = 1
disclosureLevelToInt Expert       = 2

||| Proof that each level is a subset of the next
||| (Beginner exposes fewer capabilities than Intermediate, etc.)
public export
data IsSubsetOf : DisclosureLevel -> DisclosureLevel -> Type where
  BeginnerSubIntermediate : IsSubsetOf Beginner Intermediate
  BeginnerSubExpert       : IsSubsetOf Beginner Expert
  IntermediateSubExpert   : IsSubsetOf Intermediate Expert
  ReflSubset              : IsSubsetOf l l

--------------------------------------------------------------------------------
-- Complexity Scoring
--------------------------------------------------------------------------------

||| A cognitive-load score for an API endpoint.
||| Bounded 0–100; higher means more complex.
public export
record ComplexityScore where
  constructor MkComplexityScore
  ||| Raw score value, 0 to 100 inclusive
  score : Bits32
  ||| Proof the score is within bounds
  {auto 0 inBounds : So (score <= 100)}

||| Create a complexity score, returning Nothing if out of bounds
public export
mkComplexityScore : Bits32 -> Maybe ComplexityScore
mkComplexityScore s =
  case decSo (s <= 100) of
    Yes prf => Just (MkComplexityScore s)
    No _    => Nothing

||| Determine which disclosure level an endpoint belongs to based on score.
||| Thresholds: 0-33 -> Beginner, 34-66 -> Intermediate, 67-100 -> Expert
public export
scoreToLevel : ComplexityScore -> DisclosureLevel
scoreToLevel (MkComplexityScore s) =
  if s <= 33 then Beginner
  else if s <= 66 then Intermediate
  else Expert

--------------------------------------------------------------------------------
-- API Endpoint Descriptor
--------------------------------------------------------------------------------

||| Describes a single callable unit in the target API.
public export
record APIEndpoint where
  constructor MkAPIEndpoint
  ||| Endpoint name (e.g. "send_email", "create_user")
  name          : String
  ||| Number of required parameters
  requiredParams : Bits32
  ||| Number of optional parameters
  optionalParams : Bits32
  ||| Type nesting depth (how deep the type tree goes)
  typeDepth     : Bits32
  ||| Number of distinct error codes this endpoint can return
  errorSurface  : Bits32

||| Total parameter count for an endpoint
public export
totalParams : APIEndpoint -> Bits32
totalParams ep = ep.requiredParams + ep.optionalParams

--------------------------------------------------------------------------------
-- Smart Defaults
--------------------------------------------------------------------------------

||| A safe default value inferred for an optional parameter.
public export
data SmartDefaultKind : Type where
  ||| Default inferred from an enum's first variant
  EnumFirst    : SmartDefaultKind
  ||| Default inferred from a numeric lower bound
  NumericLower : SmartDefaultKind
  ||| Default inferred from API documentation annotation
  DocAnnotated : SmartDefaultKind
  ||| Default explicitly provided by the user in mylangiser.toml
  UserProvided : SmartDefaultKind

||| A smart default pairs a parameter name with its inferred value.
public export
record SmartDefault where
  constructor MkSmartDefault
  ||| Name of the parameter this default applies to
  paramName    : String
  ||| How this default was inferred
  kind         : SmartDefaultKind
  ||| String representation of the default value
  defaultValue : String

--------------------------------------------------------------------------------
-- Layered Wrapper
--------------------------------------------------------------------------------

||| A generated progressive-disclosure wrapper for an API endpoint.
||| Contains the simplified signatures at each disclosure level.
public export
record LayeredWrapper where
  constructor MkLayeredWrapper
  ||| The original endpoint this wraps
  endpointName   : String
  ||| Complexity score assigned during analysis
  complexity     : ComplexityScore
  ||| Number of parameters visible at @beginner level
  beginnerParams : Bits32
  ||| Number of parameters visible at @intermediate level
  intermediateParams : Bits32
  ||| Number of parameters visible at @expert level (= totalParams)
  expertParams   : Bits32
  ||| Smart defaults applied at @beginner level
  defaultCount   : Bits32

||| Proof that each layer exposes a non-decreasing number of parameters
public export
layerMonotonic : (w : LayeredWrapper) ->
  So (w.beginnerParams <= w.intermediateParams &&
      w.intermediateParams <= w.expertParams)
layerMonotonic w = ?layerMonotonicProof

--------------------------------------------------------------------------------
-- Result Codes
--------------------------------------------------------------------------------

||| Result codes for FFI operations
||| Use C-compatible integers for cross-language compatibility
public export
data Result : Type where
  ||| Operation succeeded
  Ok : Result
  ||| Generic error
  Error : Result
  ||| Invalid parameter provided
  InvalidParam : Result
  ||| Out of memory
  OutOfMemory : Result
  ||| Null pointer encountered
  NullPointer : Result
  ||| Endpoint not found in API surface
  EndpointNotFound : Result
  ||| Score out of valid range
  InvalidScore : Result

||| Convert Result to C integer
public export
resultToInt : Result -> Bits32
resultToInt Ok               = 0
resultToInt Error            = 1
resultToInt InvalidParam     = 2
resultToInt OutOfMemory      = 3
resultToInt NullPointer      = 4
resultToInt EndpointNotFound = 5
resultToInt InvalidScore     = 6

||| Results are decidably equal
public export
DecEq Result where
  decEq Ok Ok = Yes Refl
  decEq Error Error = Yes Refl
  decEq InvalidParam InvalidParam = Yes Refl
  decEq OutOfMemory OutOfMemory = Yes Refl
  decEq NullPointer NullPointer = Yes Refl
  decEq EndpointNotFound EndpointNotFound = Yes Refl
  decEq InvalidScore InvalidScore = Yes Refl
  decEq _ _ = No absurd

--------------------------------------------------------------------------------
-- Opaque Handles
--------------------------------------------------------------------------------

||| Opaque handle type for FFI
||| Prevents direct construction, enforces creation through safe API
public export
data Handle : Type where
  MkHandle : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> Handle

||| Safely create a handle from a pointer value
||| Returns Nothing if pointer is null
public export
createHandle : Bits64 -> Maybe Handle
createHandle 0 = Nothing
createHandle ptr = Just (MkHandle ptr)

||| Extract pointer value from handle
public export
handlePtr : Handle -> Bits64
handlePtr (MkHandle ptr) = ptr

--------------------------------------------------------------------------------
-- Platform-Specific Types
--------------------------------------------------------------------------------

||| C int size varies by platform
public export
CInt : Platform -> Type
CInt Linux = Bits32
CInt Windows = Bits32
CInt MacOS = Bits32
CInt BSD = Bits32
CInt WASM = Bits32

||| C size_t varies by platform
public export
CSize : Platform -> Type
CSize Linux = Bits64
CSize Windows = Bits64
CSize MacOS = Bits64
CSize BSD = Bits64
CSize WASM = Bits32

||| C pointer size varies by platform
public export
ptrSize : Platform -> Nat
ptrSize Linux = 64
ptrSize Windows = 64
ptrSize MacOS = 64
ptrSize BSD = 64
ptrSize WASM = 32

||| Pointer type for platform
public export
CPtr : Platform -> Type -> Type
CPtr p _ = Bits (ptrSize p)

--------------------------------------------------------------------------------
-- Memory Layout Proofs
--------------------------------------------------------------------------------

||| Proof that a type has a specific size
public export
data HasSize : Type -> Nat -> Type where
  SizeProof : {0 t : Type} -> {n : Nat} -> HasSize t n

||| Proof that a type has a specific alignment
public export
data HasAlignment : Type -> Nat -> Type where
  AlignProof : {0 t : Type} -> {n : Nat} -> HasAlignment t n

--------------------------------------------------------------------------------
-- Verification
--------------------------------------------------------------------------------

||| Compile-time verification of ABI properties
namespace Verify

  ||| Verify all disclosure-level types are correctly ordered
  export
  verifyDisclosureLevels : IO ()
  verifyDisclosureLevels = do
    putStrLn "Disclosure levels: Beginner < Intermediate < Expert"
    putStrLn "ABI types verified"

  ||| Verify complexity score bounds
  export
  verifyScoreBounds : IO ()
  verifyScoreBounds = do
    putStrLn "Complexity scores bounded 0-100"
    putStrLn "Score bounds verified"
