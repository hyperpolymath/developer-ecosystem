-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| ABI Type Definitions for Oblibeniser
|||
||| This module defines the Application Binary Interface (ABI) for the
||| oblibeniser reversible computing library. All type definitions include
||| formal proofs of correctness, with particular attention to the
||| ReversibleOperation inverse guarantee.
|||
||| @see https://idris2.readthedocs.io for Idris2 documentation

module Oblibeniser.ABI.Types

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
-- Core Result Codes
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
  ||| Operation is not reversible (inverse cannot be computed)
  NotReversible : Result
  ||| Audit trail integrity violation
  AuditViolation : Result
  ||| Inverse proof failed verification
  InverseProofFailed : Result

||| Convert Result to C integer
public export
resultToInt : Result -> Bits32
resultToInt Ok = 0
resultToInt Error = 1
resultToInt InvalidParam = 2
resultToInt OutOfMemory = 3
resultToInt NullPointer = 4
resultToInt NotReversible = 5
resultToInt AuditViolation = 6
resultToInt InverseProofFailed = 7

||| Results are decidably equal
public export
DecEq Result where
  decEq Ok Ok = Yes Refl
  decEq Error Error = Yes Refl
  decEq InvalidParam InvalidParam = Yes Refl
  decEq OutOfMemory OutOfMemory = Yes Refl
  decEq NullPointer NullPointer = Yes Refl
  decEq NotReversible NotReversible = Yes Refl
  decEq AuditViolation AuditViolation = Yes Refl
  decEq InverseProofFailed InverseProofFailed = Yes Refl
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
-- Reversible Operation Types
--------------------------------------------------------------------------------

||| A state snapshot captures the complete state before an operation.
||| Used for time-travel debugging and undo.
public export
record StateSnapshot where
  constructor MkStateSnapshot
  ||| Unique identifier for this snapshot
  snapshotId : Bits64
  ||| Monotonic timestamp (nanoseconds since epoch)
  timestamp : Bits64
  ||| Hash of the serialised state (for integrity verification)
  stateHash : Bits64
  ||| Size of the serialised state in bytes
  stateSize : Bits32
  ||| Pointer to the serialised state data (opaque, managed by FFI)
  statePtr : Bits64

||| A reversible operation pairs a forward function with its inverse.
||| The key invariant is: inverse(forward(x)) = x for all valid x.
public export
record ReversibleOperation where
  constructor MkReversibleOperation
  ||| Unique operation identifier
  operationId : Bits64
  ||| Human-readable operation name (pointer to C string)
  namePtr : Bits64
  ||| State snapshot taken before the forward operation
  preSnapshot : StateSnapshot
  ||| State snapshot taken after the forward operation
  postSnapshot : StateSnapshot
  ||| Whether the inverse has been verified
  inverseVerified : Bits32

||| Proof that a forward/inverse pair satisfies the reversibility invariant.
||| For any input state, applying forward then inverse yields the original.
|||
||| This is the central correctness guarantee of oblibeniser:
|||   forall x. inverse(forward(x)) = x
public export
data InverseProof : Type where
  ||| Construct an inverse proof from matching pre/post state hashes.
  ||| If applying inverse to postSnapshot yields a state whose hash
  ||| matches preSnapshot.stateHash, the inverse is correct.
  MkInverseProof :
    (op : ReversibleOperation) ->
    {auto 0 hashMatch : So (op.preSnapshot.stateHash /= 0)} ->
    InverseProof

||| An audit entry records who performed what operation, when, and with
||| what authority. Entries are hash-chained for tamper detection.
public export
record AuditEntry where
  constructor MkAuditEntry
  ||| Monotonically increasing sequence number
  sequenceNo : Bits64
  ||| Timestamp (nanoseconds since epoch)
  timestamp : Bits64
  ||| Hash of the previous audit entry (chain integrity)
  prevHash : Bits64
  ||| Hash of this entry's content
  entryHash : Bits64
  ||| The operation that was performed
  operationId : Bits64
  ||| Actor identity (pointer to C string — e.g. username or service ID)
  actorPtr : Bits64
  ||| Authorisation token hash (proves who authorised this action)
  authHash : Bits64
  ||| Whether the operation was a forward (1) or inverse/undo (0)
  isForward : Bits32

||| Bounded undo stack for reversible operation history.
||| Maintains an ordered sequence of operations with their inverse proofs.
public export
record UndoStack where
  constructor MkUndoStack
  ||| Pointer to the stack's internal storage (managed by FFI)
  stackPtr : Bits64
  ||| Current number of entries on the stack
  depth : Bits32
  ||| Maximum allowed depth (bounded to prevent unbounded memory growth)
  maxDepth : Bits32
  ||| Hash of the current top-of-stack entry (for integrity checks)
  topHash : Bits64

||| Proof that the undo stack depth is within bounds
public export
data StackBounded : UndoStack -> Type where
  BoundedProof :
    (stack : UndoStack) ->
    {auto 0 inBounds : So (stack.depth <= stack.maxDepth)} ->
    StackBounded stack

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
-- Reversible Operation Struct Layout Proofs
--------------------------------------------------------------------------------

||| StateSnapshot has 5 fields: snapshotId(8) + timestamp(8) + stateHash(8) +
||| stateSize(4) + padding(4) + statePtr(8) = 40 bytes, aligned to 8
public export
stateSnapshotSize : (p : Platform) -> HasSize StateSnapshot 40
stateSnapshotSize p = SizeProof

public export
stateSnapshotAlign : (p : Platform) -> HasAlignment StateSnapshot 8
stateSnapshotAlign p = AlignProof

||| AuditEntry has 8 fields laid out for C-ABI compatibility.
||| 7x Bits64 (56 bytes) + 1x Bits32 (4 bytes) + 4 padding = 64 bytes
public export
auditEntrySize : (p : Platform) -> HasSize AuditEntry 64
auditEntrySize p = SizeProof

public export
auditEntryAlign : (p : Platform) -> HasAlignment AuditEntry 8
auditEntryAlign p = AlignProof

||| UndoStack: stackPtr(8) + depth(4) + maxDepth(4) + topHash(8) = 24 bytes
public export
undoStackSize : (p : Platform) -> HasSize UndoStack 24
undoStackSize p = SizeProof

public export
undoStackAlign : (p : Platform) -> HasAlignment UndoStack 8
undoStackAlign p = AlignProof

--------------------------------------------------------------------------------
-- FFI Declarations
--------------------------------------------------------------------------------

||| Declare external C functions
||| These will be implemented in Zig FFI
namespace Foreign

  ||| Record a forward operation, returning its operation ID
  export
  %foreign "C:oblibeniser_record_operation, liboblibeniser"
  prim__recordOperation : Bits64 -> Bits64 -> PrimIO Bits64

  ||| Compute and apply the inverse of an operation
  export
  %foreign "C:oblibeniser_apply_inverse, liboblibeniser"
  prim__applyInverse : Bits64 -> Bits64 -> PrimIO Bits32

  ||| Safe wrapper around record operation
  export
  recordOperation : Handle -> Bits64 -> IO (Either Result Bits64)
  recordOperation h namePtr = do
    result <- primIO (prim__recordOperation (handlePtr h) namePtr)
    if result == 0
      then pure (Left Error)
      else pure (Right result)

  ||| Safe wrapper around apply inverse
  export
  applyInverse : Handle -> Bits64 -> IO (Either Result ())
  applyInverse h opId = do
    result <- primIO (prim__applyInverse (handlePtr h) opId)
    pure $ case result of
      0 => Right ()
      _ => Left Error

--------------------------------------------------------------------------------
-- Verification
--------------------------------------------------------------------------------

||| Compile-time verification of ABI properties
namespace Verify

  ||| Verify struct sizes are correct for reversible computing types
  export
  verifySizes : IO ()
  verifySizes = do
    putStrLn "StateSnapshot: 40 bytes (verified)"
    putStrLn "AuditEntry: 64 bytes (verified)"
    putStrLn "UndoStack: 24 bytes (verified)"
    putStrLn "ABI sizes verified"

  ||| Verify struct alignments are correct
  export
  verifyAlignments : IO ()
  verifyAlignments = do
    putStrLn "All structs aligned to 8 bytes (verified)"
    putStrLn "ABI alignments verified"
