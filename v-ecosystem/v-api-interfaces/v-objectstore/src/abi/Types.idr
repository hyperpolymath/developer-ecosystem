-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-objectstore protocol.
-- S3-compatible object storage types: buckets, objects, multipart
-- uploads, and presigned URL structures.

module Types

import Data.List

||| URL addressing style for S3-compatible endpoints.
public export
data AddressingStyle : Type where
  PathStyle          : AddressingStyle  -- https://endpoint/bucket/key
  VirtualHostedStyle : AddressingStyle  -- https://bucket.endpoint/key

||| Lifecycle state of a multipart upload session.
public export
data UploadState : Type where
  Initiated : UploadState  -- Upload ID assigned, no parts sent
  Uploading : UploadState  -- One or more parts uploaded
  Completed : UploadState  -- All parts submitted and finalised
  Aborted   : UploadState  -- Upload cancelled, parts discarded

||| An object storage bucket (container).
public export
record Bucket where
  constructor MkBucket
  name         : String
  creationDate : String
  region       : String

||| Metadata for a stored object (without body content).
public export
record ObjectInfo where
  constructor MkObjectInfo
  key          : String
  size         : Nat
  lastModified : String
  etag         : String
  contentType  : String

||| A single part in a multipart upload with its server-assigned ETag.
public export
record UploadPart where
  constructor MkUploadPart
  partNumber : Nat
  etag       : String
  size       : Nat

||| An in-progress multipart upload session.
public export
record MultipartUpload where
  constructor MkMultipartUpload
  bucket   : String
  key      : String
  uploadId : String
  parts    : List UploadPart
  state    : UploadState

||| A time-limited presigned URL for temporary object access.
public export
record PresignedUrl where
  constructor MkPresignedUrl
  url       : String
  expiresAt : String
  method    : String
