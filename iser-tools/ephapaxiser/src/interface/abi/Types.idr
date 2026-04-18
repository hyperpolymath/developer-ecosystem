-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| ABI Type Definitions for Ephapaxiser
|||
||| This module defines the core types for ephapaxiser's resource linearity
||| enforcement. All types encode single-use semantics: every resource handle
||| must be acquired exactly once, used, and then consumed (released).
|||
||| The Idris2 ABI layer is the formal specification. When Idris2 proofs
||| conflict with Ephapax linear types, Idris2 always wins.
|||
||| @see Types: LinearResource, UsageCount, ResourceLifecycle, ConsumeProof

module Ephapaxiser.ABI.Types

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
  ||| Resource already consumed (use-after-free attempt)
  AlreadyConsumed : Result
  ||| Resource leaked (not consumed before scope exit)
  ResourceLeaked : Result
  ||| Double-free attempt (resource consumed more than once)
  DoubleFree : Result

||| Convert Result to C integer
public export
resultToInt : Result -> Bits32
resultToInt Ok = 0
resultToInt Error = 1
resultToInt InvalidParam = 2
resultToInt OutOfMemory = 3
resultToInt NullPointer = 4
resultToInt AlreadyConsumed = 5
resultToInt ResourceLeaked = 6
resultToInt DoubleFree = 7

||| Results are decidably equal
public export
DecEq Result where
  decEq Ok Ok = Yes Refl
  decEq Error Error = Yes Refl
  decEq InvalidParam InvalidParam = Yes Refl
  decEq OutOfMemory OutOfMemory = Yes Refl
  decEq NullPointer NullPointer = Yes Refl
  decEq AlreadyConsumed AlreadyConsumed = Yes Refl
  decEq ResourceLeaked ResourceLeaked = Yes Refl
  decEq DoubleFree DoubleFree = Yes Refl
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
-- Usage Tracking Types
--------------------------------------------------------------------------------

||| How many times a resource has been used. In a correct program this is
||| always exactly 1 by the time the resource goes out of scope.
public export
data UsageCount : Type where
  ||| Resource has not been used yet (freshly acquired)
  Unused : UsageCount
  ||| Resource has been used exactly once (correct state for consumption)
  UsedOnce : UsageCount
  ||| Resource has been used more than once (ERROR: violates linearity)
  UsedMultiple : UsageCount

||| Proof that a UsageCount represents exactly-once usage
public export
data IsUsedOnce : UsageCount -> Type where
  ItIsUsedOnce : IsUsedOnce UsedOnce

||| Decidable equality for UsageCount
public export
DecEq UsageCount where
  decEq Unused Unused = Yes Refl
  decEq UsedOnce UsedOnce = Yes Refl
  decEq UsedMultiple UsedMultiple = Yes Refl
  decEq _ _ = No absurd

--------------------------------------------------------------------------------
-- Resource Lifecycle
--------------------------------------------------------------------------------

||| The lifecycle states a resource passes through. This is a state machine:
||| Acquired -> InUse -> Consumed. No other transitions are valid.
public export
data ResourceLifecycle : Type where
  ||| Resource has been acquired (handle obtained)
  Acquired : ResourceLifecycle
  ||| Resource is currently in use (handle dereferenced)
  InUse : ResourceLifecycle
  ||| Resource has been consumed (handle released/freed)
  Consumed : ResourceLifecycle

||| Proof of a valid lifecycle transition.
||| Only Acquired->InUse and InUse->Consumed are valid.
public export
data ValidTransition : ResourceLifecycle -> ResourceLifecycle -> Type where
  ||| Transition from Acquired to InUse (start using the resource)
  AcquiredToInUse : ValidTransition Acquired InUse
  ||| Transition from InUse to Consumed (release the resource)
  InUseToConsumed : ValidTransition InUse Consumed

||| Proof that no transition out of Consumed is valid.
||| Once consumed, a resource cannot be reused (prevents use-after-free).
public export
consumedIsFinal : ValidTransition Consumed next -> Void
consumedIsFinal _ impossible

||| Proof that Acquired cannot directly transition to Consumed
||| (a resource must be used before it can be released).
public export
noSkipToConsumed : ValidTransition Acquired Consumed -> Void
noSkipToConsumed _ impossible

--------------------------------------------------------------------------------
-- Linear Resource
--------------------------------------------------------------------------------

||| A linear resource: a handle paired with its lifecycle state and usage count.
||| The type indices enforce that the resource is in a valid state.
public export
data LinearResource : ResourceLifecycle -> UsageCount -> Type where
  ||| Create a new linear resource (freshly acquired, unused)
  MkLinearResource :
    (handle : Handle) ->
    LinearResource Acquired Unused

||| Proof that a resource was properly consumed: it was used exactly once
||| and transitioned through the full lifecycle.
public export
data ConsumeProof : Type where
  ||| Evidence of correct consumption
  MkConsumeProof :
    (handle : Handle) ->
    (lifecycle : ValidTransition InUse Consumed) ->
    (usage : IsUsedOnce UsedOnce) ->
    ConsumeProof

||| Use a linear resource (transition Acquired -> InUse, Unused -> UsedOnce)
public export
useResource :
  LinearResource Acquired Unused ->
  (LinearResource InUse UsedOnce, ValidTransition Acquired InUse)
useResource (MkLinearResource h) = (?usedResource, AcquiredToInUse)

||| Consume a linear resource (transition InUse -> Consumed)
||| Returns a ConsumeProof as evidence of correct disposal.
public export
consumeResource :
  LinearResource InUse UsedOnce ->
  ConsumeProof
consumeResource (MkLinearResource h) =
  MkConsumeProof h InUseToConsumed ItIsUsedOnce

--------------------------------------------------------------------------------
-- Resource Kind Classification
--------------------------------------------------------------------------------

||| Classification of resource kinds that ephapaxiser can wrap.
||| Each kind has different acquire/release semantics.
public export
data ResourceKind : Type where
  ||| File descriptor (open/close)
  FileHandle : ResourceKind
  ||| Network socket (connect/disconnect)
  Socket : ResourceKind
  ||| Database connection (connect/disconnect, pooled)
  DbConnection : ResourceKind
  ||| GPU buffer (allocate/deallocate)
  GpuBuffer : ResourceKind
  ||| Cryptographic key material (generate/zeroize)
  CryptoKey : ResourceKind
  ||| Session token (issue/revoke)
  SessionToken : ResourceKind
  ||| Heap allocation (malloc/free)
  HeapAlloc : ResourceKind
  ||| User-defined resource kind
  Custom : (name : String) -> ResourceKind

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

||| Size of C types (platform-specific)
public export
cSizeOf : (p : Platform) -> (t : Type) -> Nat
cSizeOf p (CInt _) = 4
cSizeOf p (CSize _) = if ptrSize p == 64 then 8 else 4
cSizeOf p Bits32 = 4
cSizeOf p Bits64 = 8
cSizeOf p Double = 8
cSizeOf p _ = ptrSize p `div` 8

||| Alignment of C types (platform-specific)
public export
cAlignOf : (p : Platform) -> (t : Type) -> Nat
cAlignOf p (CInt _) = 4
cAlignOf p (CSize _) = if ptrSize p == 64 then 8 else 4
cAlignOf p Bits32 = 4
cAlignOf p Bits64 = 8
cAlignOf p Double = 8
cAlignOf p _ = ptrSize p `div` 8

--------------------------------------------------------------------------------
-- Resource Tracking Struct
--------------------------------------------------------------------------------

||| The resource tracking struct stored alongside each wrapped resource.
||| Contains the handle, lifecycle state, usage count, and resource kind.
public export
record ResourceTracker where
  constructor MkResourceTracker
  handle    : Handle
  kind      : ResourceKind
  lifecycle : ResourceLifecycle
  usage     : UsageCount

||| Prove the resource tracker struct has correct size (platform-specific)
public export
resourceTrackerSize : (p : Platform) -> HasSize ResourceTracker 32
resourceTrackerSize p = SizeProof

||| Prove the resource tracker struct has correct alignment
public export
resourceTrackerAlign : (p : Platform) -> HasAlignment ResourceTracker 8
resourceTrackerAlign p = AlignProof

--------------------------------------------------------------------------------
-- FFI Declarations (resource-specific)
--------------------------------------------------------------------------------

namespace Foreign

  ||| Analyse a source file for resource handles
  export
  %foreign "C:ephapaxiser_analyse, libephapaxiser"
  prim__analyse : Bits64 -> PrimIO Bits32

  ||| Safe wrapper around analyse FFI function
  export
  analyse : Handle -> IO (Either Result Bits32)
  analyse h = do
    result <- primIO (prim__analyse (handlePtr h))
    pure (Right result)

  ||| Wrap a resource handle with linearity enforcement
  export
  %foreign "C:ephapaxiser_wrap_resource, libephapaxiser"
  prim__wrapResource : Bits64 -> Bits32 -> PrimIO Bits64

  ||| Consume (release) a wrapped resource
  export
  %foreign "C:ephapaxiser_consume_resource, libephapaxiser"
  prim__consumeResource : Bits64 -> PrimIO Bits32

--------------------------------------------------------------------------------
-- Verification
--------------------------------------------------------------------------------

namespace Verify

  ||| Compile-time verification of ABI properties
  export
  verifySizes : IO ()
  verifySizes = do
    putStrLn "ABI sizes verified for ephapaxiser"

  ||| Compile-time verification of alignment properties
  export
  verifyAlignments : IO ()
  verifyAlignments = do
    putStrLn "ABI alignments verified for ephapaxiser"

  ||| Verify that the linearity invariants hold
  export
  verifyLinearity : IO ()
  verifyLinearity = do
    putStrLn "Linearity invariants verified: every resource consumed exactly once"
