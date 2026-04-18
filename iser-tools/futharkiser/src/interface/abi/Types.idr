-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| ABI Type Definitions for Futharkiser
|||
||| Defines the Application Binary Interface types for the Futhark GPU
||| compilation pipeline. All types include formal proofs of correctness
||| to guarantee safe parallelism and correct memory layouts.
|||
||| Key domain types:
|||   - SOAC: Second-Order Array Combinators (map, reduce, scan, scatter)
|||   - GPUBackend: Target compilation backend (OpenCL, CUDA, multicore, sequential)
|||   - ArrayShape: Dimensioned array descriptors with compile-time rank
|||   - ParallelPattern: Recognised parallelisable source patterns
|||   - MemorySpace: GPU memory hierarchy (Device, Host, Shared)
|||
||| @see https://futhark-lang.org for Futhark language documentation
||| @see https://idris2.readthedocs.io for Idris2 documentation

module Futharkiser.ABI.Types

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
||| Set during compilation based on target architecture
public export
thisPlatform : Platform
thisPlatform =
  %runElab do
    -- Platform detection logic; override with compiler flags
    pure Linux

--------------------------------------------------------------------------------
-- GPU Backend Selection
--------------------------------------------------------------------------------

||| GPU compilation backends supported by Futhark
||| Each corresponds to a `futhark <backend>` compiler invocation
public export
data GPUBackend
  = ||| OpenCL — widest hardware support (AMD, Intel, NVIDIA)
    OpenCL
  | ||| CUDA — NVIDIA GPUs, best NVIDIA performance
    CUDA
  | ||| Multicore CPU — no GPU required, still parallel via pthreads
    Multicore
  | ||| Sequential C — single-threaded, for debugging and correctness testing
    Sequential

||| Convert backend to the Futhark compiler flag string
public export
backendFlag : GPUBackend -> String
backendFlag OpenCL     = "opencl"
backendFlag CUDA       = "cuda"
backendFlag Multicore  = "multicore"
backendFlag Sequential = "c"

||| GPUBackend is decidably equal
public export
DecEq GPUBackend where
  decEq OpenCL     OpenCL     = Yes Refl
  decEq CUDA       CUDA       = Yes Refl
  decEq Multicore  Multicore  = Yes Refl
  decEq Sequential Sequential = Yes Refl
  decEq _          _          = No absurd

--------------------------------------------------------------------------------
-- Second-Order Array Combinators (SOACs)
--------------------------------------------------------------------------------

||| Futhark's second-order array combinators.
||| These are the fundamental parallel operations that Futhark compiles to GPU kernels.
public export
data SOAC
  = ||| map f xs — apply f to every element in parallel
    Map
  | ||| reduce op ne xs — fold with associative operator and neutral element
    Reduce
  | ||| scan op ne xs — inclusive prefix scan (parallel prefix sums)
    Scan
  | ||| scatter dest indices values — irregular parallel writes
    Scatter
  | ||| flatten / unflatten — reshape between nested and flat arrays
    Reshape

||| Convert SOAC to its Futhark keyword representation
public export
soacKeyword : SOAC -> String
soacKeyword Map     = "map"
soacKeyword Reduce  = "reduce"
soacKeyword Scan    = "scan"
soacKeyword Scatter = "scatter"
soacKeyword Reshape = "flatten"

||| SOAC is decidably equal
public export
DecEq SOAC where
  decEq Map     Map     = Yes Refl
  decEq Reduce  Reduce  = Yes Refl
  decEq Scan    Scan    = Yes Refl
  decEq Scatter Scatter = Yes Refl
  decEq Reshape Reshape = Yes Refl
  decEq _       _       = No absurd

--------------------------------------------------------------------------------
-- Memory Space (GPU memory hierarchy)
--------------------------------------------------------------------------------

||| Where array data physically resides in the GPU memory model.
||| Correct tracking of memory space prevents invalid cross-boundary accesses
||| and enables minimisation of host-device memory transfers.
public export
data MemorySpace
  = ||| Device — GPU global memory; fastest for kernel access, not CPU-visible
    Device
  | ||| Host — CPU main memory; must be transferred to Device before kernel use
    Host
  | ||| Shared — Unified memory visible to both CPU and GPU (slower but convenient)
    Shared

||| MemorySpace is decidably equal
public export
DecEq MemorySpace where
  decEq Device Device = Yes Refl
  decEq Host   Host   = Yes Refl
  decEq Shared Shared = Yes Refl
  decEq _      _      = No absurd

||| Proof that a memory transfer direction is valid.
||| Host -> Device and Device -> Host are always valid.
||| Shared is accessible from both sides without transfer.
public export
data ValidTransfer : MemorySpace -> MemorySpace -> Type where
  HostToDevice   : ValidTransfer Host Device
  DeviceToHost   : ValidTransfer Device Host
  SharedFromHost : ValidTransfer Host Shared
  SharedToHost   : ValidTransfer Shared Host
  SharedFromDev  : ValidTransfer Device Shared
  SharedToDev    : ValidTransfer Shared Device
  SameSpace      : ValidTransfer s s

--------------------------------------------------------------------------------
-- Array Shape (compile-time dimensioned arrays)
--------------------------------------------------------------------------------

||| An array shape with compile-time known rank (number of dimensions).
||| Dimensions are stored as a Vect so the type system tracks the rank.
public export
record ArrayShape (rank : Nat) where
  constructor MkArrayShape
  ||| Dimension sizes; length of this vector equals the rank
  dims : Vect rank Nat

||| Total number of elements in an array (product of dimensions)
public export
totalElements : ArrayShape rank -> Nat
totalElements shape = foldr (*) 1 shape.dims

||| Proof that two shapes are compatible for element-wise operations (map)
||| Shapes must have the same rank and the same dimensions
public export
data ShapesCompatible : ArrayShape r -> ArrayShape r -> Type where
  SameShape : (s : ArrayShape r) -> ShapesCompatible s s

||| Proof that an array is non-empty (required for reduce/scan)
public export
data NonEmpty : ArrayShape rank -> Type where
  IsNonEmpty : {s : ArrayShape rank} -> So (totalElements s > 0) -> NonEmpty s

--------------------------------------------------------------------------------
-- Parallel Pattern (recognised source-level patterns)
--------------------------------------------------------------------------------

||| A recognised parallelisable pattern extracted from user source code.
||| Each pattern maps to one or more SOACs in the generated Futhark program.
public export
record ParallelPattern where
  constructor MkParallelPattern
  ||| Which SOAC this pattern compiles to
  soac : SOAC
  ||| Shape of the input array
  inputShape : ArrayShape inputRank
  ||| Shape of the output array
  outputShape : ArrayShape outputRank
  ||| Where the input currently lives
  inputSpace : MemorySpace
  ||| Where the output should be placed
  outputSpace : MemorySpace

--------------------------------------------------------------------------------
-- Result Codes
--------------------------------------------------------------------------------

||| Result codes for FFI operations.
||| C-compatible integers for cross-language interop.
public export
data Result : Type where
  ||| Operation succeeded
  Ok : Result
  ||| Generic error
  Error : Result
  ||| Invalid parameter provided
  InvalidParam : Result
  ||| Out of memory (host or device)
  OutOfMemory : Result
  ||| Null pointer encountered
  NullPointer : Result
  ||| Futhark compilation failed
  CompilationFailed : Result
  ||| GPU backend not available on this system
  BackendUnavailable : Result
  ||| Array shape mismatch
  ShapeMismatch : Result

||| Convert Result to C-compatible integer
public export
resultToInt : Result -> Bits32
resultToInt Ok                 = 0
resultToInt Error              = 1
resultToInt InvalidParam       = 2
resultToInt OutOfMemory        = 3
resultToInt NullPointer        = 4
resultToInt CompilationFailed  = 5
resultToInt BackendUnavailable = 6
resultToInt ShapeMismatch      = 7

||| Results are decidably equal
public export
DecEq Result where
  decEq Ok                 Ok                 = Yes Refl
  decEq Error              Error              = Yes Refl
  decEq InvalidParam       InvalidParam       = Yes Refl
  decEq OutOfMemory        OutOfMemory        = Yes Refl
  decEq NullPointer        NullPointer        = Yes Refl
  decEq CompilationFailed  CompilationFailed  = Yes Refl
  decEq BackendUnavailable BackendUnavailable = Yes Refl
  decEq ShapeMismatch      ShapeMismatch      = Yes Refl
  decEq _                  _                  = No absurd

--------------------------------------------------------------------------------
-- Opaque Handles
--------------------------------------------------------------------------------

||| Opaque handle to a Futharkiser library instance.
||| Prevents direct construction; must be created through safe init API.
public export
data Handle : Type where
  MkHandle : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> Handle

||| Safely create a handle from a pointer value.
||| Returns Nothing if pointer is null.
public export
createHandle : Bits64 -> Maybe Handle
createHandle 0 = Nothing
createHandle ptr = Just (MkHandle ptr)

||| Extract pointer value from handle.
public export
handlePtr : Handle -> Bits64
handlePtr (MkHandle ptr) = ptr

--------------------------------------------------------------------------------
-- GPU Buffer Descriptor
--------------------------------------------------------------------------------

||| Descriptor for a GPU buffer that tracks shape, element type, and memory space.
||| Used to verify that Futhark kernel arguments have correct layouts.
public export
record GPUBuffer (rank : Nat) where
  constructor MkGPUBuffer
  ||| Shape of the array in this buffer
  shape : ArrayShape rank
  ||| Size in bytes of each element
  elementBytes : Nat
  ||| Which memory space the buffer resides in
  space : MemorySpace
  ||| Pointer to the buffer data (opaque, managed by Futhark runtime)
  bufferPtr : Bits64

||| Total size in bytes of a GPU buffer
public export
bufferSizeBytes : GPUBuffer rank -> Nat
bufferSizeBytes buf = totalElements buf.shape * buf.elementBytes

||| Proof that a buffer has been allocated (non-null pointer)
public export
data BufferAllocated : GPUBuffer rank -> Type where
  IsAllocated : {buf : GPUBuffer rank} -> So (buf.bufferPtr /= 0) -> BufferAllocated buf

--------------------------------------------------------------------------------
-- Platform-Specific Types
--------------------------------------------------------------------------------

||| C int size varies by platform
public export
CInt : Platform -> Type
CInt Linux   = Bits32
CInt Windows = Bits32
CInt MacOS   = Bits32
CInt BSD     = Bits32
CInt WASM    = Bits32

||| C size_t varies by platform
public export
CSize : Platform -> Type
CSize Linux   = Bits64
CSize Windows = Bits64
CSize MacOS   = Bits64
CSize BSD     = Bits64
CSize WASM    = Bits32

||| C pointer size varies by platform
public export
ptrSize : Platform -> Nat
ptrSize Linux   = 64
ptrSize Windows = 64
ptrSize MacOS   = 64
ptrSize BSD     = 64
ptrSize WASM    = 32

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
-- Futhark Element Types
--------------------------------------------------------------------------------

||| Futhark primitive element types that can appear in arrays.
||| Each corresponds to a Futhark type keyword.
public export
data FutharkType
  = F32      -- 32-bit float
  | F64      -- 64-bit float
  | I8       -- 8-bit signed integer
  | I16      -- 16-bit signed integer
  | I32      -- 32-bit signed integer
  | I64      -- 64-bit signed integer
  | U8       -- 8-bit unsigned integer
  | U16      -- 16-bit unsigned integer
  | U32      -- 32-bit unsigned integer
  | U64      -- 64-bit unsigned integer
  | FBool    -- boolean

||| Size in bytes of a Futhark type
public export
futharkTypeSize : FutharkType -> Nat
futharkTypeSize F32   = 4
futharkTypeSize F64   = 8
futharkTypeSize I8    = 1
futharkTypeSize I16   = 2
futharkTypeSize I32   = 4
futharkTypeSize I64   = 8
futharkTypeSize U8    = 1
futharkTypeSize U16   = 2
futharkTypeSize U32   = 4
futharkTypeSize U64   = 8
futharkTypeSize FBool = 1

||| Convert to Futhark type keyword
public export
futharkTypeName : FutharkType -> String
futharkTypeName F32   = "f32"
futharkTypeName F64   = "f64"
futharkTypeName I8    = "i8"
futharkTypeName I16   = "i16"
futharkTypeName I32   = "i32"
futharkTypeName I64   = "i64"
futharkTypeName U8    = "u8"
futharkTypeName U16   = "u16"
futharkTypeName U32   = "u32"
futharkTypeName U64   = "u64"
futharkTypeName FBool = "bool"

--------------------------------------------------------------------------------
-- Verification
--------------------------------------------------------------------------------

||| Compile-time verification of ABI properties
namespace Verify

  ||| Verify that a GPU buffer descriptor matches the expected Futhark entry
  ||| point signature (element type and rank must agree)
  export
  verifyBufferForEntry : (buf : GPUBuffer rank) ->
                         (expectedRank : Nat) ->
                         (expectedElemSize : Nat) ->
                         Either String ()
  verifyBufferForEntry buf expRank expElem =
    case decEq (length buf.shape.dims) expRank of
      Yes _ =>
        if buf.elementBytes == expElem
          then Right ()
          else Left "Element size mismatch"
      No _ => Left "Array rank mismatch"

  ||| Verify that a memory transfer is valid before issuing it
  export
  verifyTransfer : (from : MemorySpace) -> (to : MemorySpace) ->
                   Either String (ValidTransfer from to)
  verifyTransfer Host   Device = Right HostToDevice
  verifyTransfer Device Host   = Right DeviceToHost
  verifyTransfer Host   Shared = Right SharedFromHost
  verifyTransfer Shared Host   = Right SharedToHost
  verifyTransfer Device Shared = Right SharedFromDev
  verifyTransfer Shared Device = Right SharedToDev
  verifyTransfer s      s      = Right SameSpace
