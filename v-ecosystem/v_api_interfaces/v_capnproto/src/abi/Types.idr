-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-capnproto protocol.
-- Segment, message, field, and schema types for zero-copy serialisation.

module Types

import Data.List
import Data.Nat

||| Word size in bytes (Cap'n Proto uses 8-byte alignment).
public export
WordSize : Nat
WordSize = 8

||| Contiguous byte buffer for zero-copy struct/list storage.
||| The position is proven to never exceed capacity.
public export
record Segment where
  constructor MkSegment
  capacity : Nat
  position : Nat
  bounded  : LTE position capacity

||| Wire type tag for a field within a struct's data section.
public export
data FieldType : Type where
  FVoid    : FieldType
  FBool    : FieldType
  FUInt8   : FieldType
  FUInt16  : FieldType
  FUInt32  : FieldType
  FUInt64  : FieldType
  FFloat32 : FieldType
  FFloat64 : FieldType
  FText    : FieldType  -- Length-prefixed UTF-8
  FData    : FieldType  -- Length-prefixed raw bytes
  FStruct  : FieldType  -- Pointer to nested struct
  FList    : (elemType : FieldType) -> FieldType

||| Descriptor for a single field within a struct schema.
public export
record FieldDescriptor where
  constructor MkFieldDescriptor
  name      : String
  fieldType : FieldType
  offset    : Nat  -- Byte offset in data section
  ordinal   : Nat  -- Unique within struct, 0-based

||| Schema defining a struct's layout and fields.
public export
record StructSchema where
  constructor MkStructSchema
  name         : String
  dataSize     : Nat   -- Data section bytes (word-aligned)
  pointerCount : Nat
  fields       : List FieldDescriptor

||| A complete message with root segment and optional extras.
public export
record Message where
  constructor MkMessage
  rootSegment   : Segment
  extraSegments : List Segment

||| RPC wire header prepended to each request or response.
public export
record RpcHeader where
  constructor MkRpcHeader
  methodId   : Nat
  payloadLen : Nat
