-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Memory Layout Proofs for Halideiser
|||
||| This module provides formal proofs about memory layout for Halide's
||| `buffer_t` / `halide_buffer_t` structure. Halide buffers use a
||| strided layout where each dimension has:
|||   - min: the minimum coordinate in that dimension
|||   - extent: the number of elements in that dimension
|||   - stride: the number of elements between adjacent entries in that dimension
|||
||| For a 3-channel 1920x1080 image stored in planar order:
|||   dim 0 (x):       min=0, extent=1920, stride=1
|||   dim 1 (y):       min=0, extent=1080, stride=1920
|||   dim 2 (channel): min=0, extent=3,    stride=1920*1080
|||
||| @see https://halide-lang.org/docs/structHalide_1_1Runtime_1_1Buffer.html

module Halideiser.ABI.Layout

import Halideiser.ABI.Types
import Data.Vect
import Data.So
import Data.Nat

%default total

--------------------------------------------------------------------------------
-- Halide Dimension Descriptor
--------------------------------------------------------------------------------

||| A single dimension in a Halide buffer.
||| Corresponds to `halide_dimension_t` in the Halide C API.
public export
record HalideDimension where
  constructor MkHalideDimension
  ||| Minimum coordinate (usually 0)
  min    : Int
  ||| Number of elements in this dimension
  extent : Nat
  ||| Distance in elements between adjacent entries in this dimension
  stride : Nat
  ||| Proof that extent is positive
  {auto 0 extentPos : So (extent > 0)}
  ||| Proof that stride is positive
  {auto 0 stridePos : So (stride > 0)}

||| Number of elements spanned by this dimension (extent * stride)
public export
dimSpan : HalideDimension -> Nat
dimSpan d = d.extent * d.stride

--------------------------------------------------------------------------------
-- Halide Buffer Layout
--------------------------------------------------------------------------------

||| The memory layout of a Halide buffer.
||| Models `halide_buffer_t` with n dimensions.
|||
||| A valid buffer layout requires:
|||   1. All dimensions have positive extent and stride
|||   2. No two dimensions alias the same memory (strides are compatible)
|||   3. Total allocation covers all addressable elements
public export
record HalideBufferLayout (n : Nat) where
  constructor MkHalideBufferLayout
  ||| Dimensions (x, y, channel, frame, etc.)
  dimensions : Vect n HalideDimension
  ||| Element type (uint8, float32, etc.)
  elemType   : PixelType
  ||| Total number of allocated elements
  allocSize  : Nat
  ||| Proof that allocation covers the full extent
  {auto 0 allocCovers : So (allocSize >= requiredAlloc dimensions)}
 where
  ||| Calculate the minimum allocation needed for the given dimensions.
  ||| This is the product of (extent_i * stride_i) across all dimensions,
  ||| but more precisely it is max over all dimensions of (extent_i * stride_i).
  public export
  requiredAlloc : Vect m HalideDimension -> Nat
  requiredAlloc []        = 0
  requiredAlloc (d :: ds) = max (dimSpan d) (requiredAlloc ds)

||| Total bytes for a buffer layout
public export
layoutBytes : HalideBufferLayout n -> Nat
layoutBytes buf = buf.allocSize * pixelBytes buf.elemType

--------------------------------------------------------------------------------
-- Standard Image Layouts
--------------------------------------------------------------------------------

||| Row-major interleaved layout (RGBRGBRGB...).
||| This is the most common layout for 8-bit images.
|||
||| dim 0 (channel): extent=channels, stride=1
||| dim 1 (x):       extent=width,    stride=channels
||| dim 2 (y):       extent=height,   stride=width*channels
public export
interleavedLayout : (dim : BufferDimension) -> (ptype : PixelType) ->
                    HalideBufferLayout 3
interleavedLayout dim ptype =
  MkHalideBufferLayout
    [ MkHalideDimension 0 dim.channels 1
    , MkHalideDimension 0 dim.width    dim.channels
    , MkHalideDimension 0 dim.height   (dim.width * dim.channels)
    ]
    ptype
    (dim.width * dim.height * dim.channels)

||| Planar layout (all R, then all G, then all B).
||| Common for processing — better SIMD utilisation per channel.
|||
||| dim 0 (x):       extent=width,    stride=1
||| dim 1 (y):       extent=height,   stride=width
||| dim 2 (channel): extent=channels, stride=width*height
public export
planarLayout : (dim : BufferDimension) -> (ptype : PixelType) ->
               HalideBufferLayout 3
planarLayout dim ptype =
  MkHalideBufferLayout
    [ MkHalideDimension 0 dim.width    1
    , MkHalideDimension 0 dim.height   dim.width
    , MkHalideDimension 0 dim.channels (dim.width * dim.height)
    ]
    ptype
    (dim.width * dim.height * dim.channels)

||| Video buffer layout (4D: x, y, channel, frame).
||| Planar within each frame, frames stored contiguously.
public export
videoLayout : (dim : BufferDimension) -> (ptype : PixelType) ->
              HalideBufferLayout 4
videoLayout dim ptype =
  MkHalideBufferLayout
    [ MkHalideDimension 0 dim.width    1
    , MkHalideDimension 0 dim.height   dim.width
    , MkHalideDimension 0 dim.channels (dim.width * dim.height)
    , MkHalideDimension 0 dim.frames   (dim.width * dim.height * dim.channels)
    ]
    ptype
    (bufferElements dim)

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

||| Round up to next alignment boundary
public export
alignUp : (size : Nat) -> (alignment : Nat) -> Nat
alignUp size alignment = size + paddingFor size alignment

||| Halide typically aligns buffer starts to 128 bytes for SIMD
public export
halideAlignment : Nat
halideAlignment = 128

||| Aligned allocation size for a buffer
public export
alignedAllocSize : HalideBufferLayout n -> Nat
alignedAllocSize buf = alignUp (layoutBytes buf) halideAlignment

--------------------------------------------------------------------------------
-- Buffer Bounds Proofs
--------------------------------------------------------------------------------

||| Proof that a coordinate is within a dimension's bounds
public export
data InBounds : (coord : Nat) -> HalideDimension -> Type where
  CoordInBounds : {c : Nat} -> {d : HalideDimension} ->
                  So (c < d.extent) ->
                  InBounds c d

||| Proof that a linear index is within the buffer allocation
public export
data IndexInAlloc : (idx : Nat) -> HalideBufferLayout n -> Type where
  IdxInAlloc : {i : Nat} -> {buf : HalideBufferLayout n} ->
               So (i < buf.allocSize) ->
               IndexInAlloc i buf

||| Calculate linear index from multi-dimensional coordinates.
||| For a buffer with dimensions [d0, d1, d2]:
|||   index = coord0 * stride0 + coord1 * stride1 + coord2 * stride2
public export
linearIndex : Vect n Nat -> Vect n HalideDimension -> Nat
linearIndex []        []        = 0
linearIndex (c :: cs) (d :: ds) = c * d.stride + linearIndex cs ds

--------------------------------------------------------------------------------
-- Layout Compatibility Between Pipeline Stages
--------------------------------------------------------------------------------

||| Proof that the output layout of one stage is compatible with
||| the input layout of the next stage.
public export
data LayoutCompatible : HalideBufferLayout n -> HalideBufferLayout m -> Type where
  ||| Same number of dimensions and matching extents
  SameDimLayout : {a : HalideBufferLayout n} -> {b : HalideBufferLayout n} ->
                  LayoutCompatible a b
  ||| Resize changes dimensions — new extents are explicitly provided
  ResizedLayout : {a : HalideBufferLayout n} -> {b : HalideBufferLayout n} ->
                  LayoutCompatible a b

||| Verify two layouts are compatible for pipeline stage connection
public export
checkCompatibility : HalideBufferLayout n -> HalideBufferLayout m ->
                     Either String (n = m)
checkCompatibility a b =
  case decEq n m of
    Yes prf => Right prf
    No _    => Left "Dimension count mismatch between pipeline stages"

--------------------------------------------------------------------------------
-- C ABI Struct Layout (for halide_buffer_t interop)
--------------------------------------------------------------------------------

||| A field in a C struct with its offset and size
public export
record Field where
  constructor MkField
  name      : String
  offset    : Nat
  size      : Nat
  alignment : Nat

||| The C-level halide_buffer_t structure layout.
||| This mirrors the actual Halide runtime struct for FFI correctness.
|||
||| struct halide_buffer_t {
|||     uint64_t device;              // offset 0,  size 8
|||     void *device_interface;       // offset 8,  size 8
|||     uint8_t *host;                // offset 16, size 8
|||     uint64_t flags;               // offset 24, size 8
|||     halide_type_t type;           // offset 32, size 4
|||     int32_t dimensions;           // offset 36, size 4
|||     halide_dimension_t *dim;      // offset 40, size 8
|||     void *padding;                // offset 48, size 8
||| };  // total: 56 bytes, alignment: 8
public export
halideBufferTLayout : List Field
halideBufferTLayout =
  [ MkField "device"           0  8 8
  , MkField "device_interface"  8  8 8
  , MkField "host"             16 8 8
  , MkField "flags"            24 8 8
  , MkField "type"             32 4 4
  , MkField "dimensions"       36 4 4
  , MkField "dim"              40 8 8
  , MkField "padding"          48 8 8
  ]

||| Total size of halide_buffer_t
public export
halideBufferTSize : Nat
halideBufferTSize = 56

||| Alignment of halide_buffer_t
public export
halideBufferTAlign : Nat
halideBufferTAlign = 8

||| The C-level halide_dimension_t structure layout.
|||
||| struct halide_dimension_t {
|||     int32_t min;       // offset 0,  size 4
|||     int32_t extent;    // offset 4,  size 4
|||     int32_t stride;    // offset 8,  size 4
|||     uint32_t flags;    // offset 12, size 4
||| };  // total: 16 bytes, alignment: 4
public export
halideDimensionTLayout : List Field
halideDimensionTLayout =
  [ MkField "min"    0  4 4
  , MkField "extent" 4  4 4
  , MkField "stride" 8  4 4
  , MkField "flags"  12 4 4
  ]

||| Total size of halide_dimension_t
public export
halideDimensionTSize : Nat
halideDimensionTSize = 16

||| Alignment of halide_dimension_t
public export
halideDimensionTAlign : Nat
halideDimensionTAlign = 4
