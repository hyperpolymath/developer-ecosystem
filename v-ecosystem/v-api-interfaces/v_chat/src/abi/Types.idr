-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-chat protocol.
-- Chat protocol types: message formats, room descriptors,
-- presence state, and encryption key bundles.

module Types

import Data.List

||| Chat backend protocol.
public export
data ChatBackend : Type where
  IRC     : ChatBackend
  Matrix  : ChatBackend
  Webhook : ChatBackend

||| User presence state.
public export
data PresenceState : Type where
  Online  : PresenceState
  Away    : PresenceState
  Busy    : PresenceState
  Offline : PresenceState

||| Chat message.
public export
record Message where
  constructor MkMessage
  msgId     : String
  roomId    : String
  sender    : String
  body      : String
  timestamp : Bits64
  encrypted : Bool

||| Chat room descriptor.
public export
record Room where
  constructor MkRoom
  roomId      : String
  name        : String
  isEncrypted : Bool
