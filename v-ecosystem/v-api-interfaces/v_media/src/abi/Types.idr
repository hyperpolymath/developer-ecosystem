-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-media protocol.
-- Media types: codecs, stream types, transcoding profiles.

module Types

||| Media codec.
public export
data Codec : Type where
  H264 : Codec
  H265 : Codec
  VP9  : Codec
  AV1  : Codec
  Opus : Codec
  AAC  : Codec

||| Stream type.
public export
data StreamType : Type where
  Live      : StreamType
  VOD       : StreamType
  AudioOnly : StreamType

||| Media stream.
public export
record MediaStream where
  constructor MkMediaStream
  streamId    : String
  name        : String
  codec       : Codec
  streamType  : StreamType
  bitrateKbps : Nat
