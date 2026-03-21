-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-federation protocol.
-- Federation protocol types: actors, activities, HTTP signatures,
-- inbox/outbox routing, and WebFinger descriptors.

module Types

import Data.List

||| ActivityPub activity type.
public export
data ActivityType : Type where
  Create   : ActivityType
  Update   : ActivityType
  Delete   : ActivityType
  Follow   : ActivityType
  Accept   : ActivityType
  Reject   : ActivityType
  Announce : ActivityType
  Like     : ActivityType
  Undo     : ActivityType

||| Federated actor identity.
public export
record Actor where
  constructor MkActor
  actorId   : String
  kind      : String
  name      : String
  inbox     : String
  outbox    : String
  publicKey : String

||| ActivityPub activity.
public export
record Activity where
  constructor MkActivity
  activityId : String
  kind       : ActivityType
  actor      : String
  object     : String
