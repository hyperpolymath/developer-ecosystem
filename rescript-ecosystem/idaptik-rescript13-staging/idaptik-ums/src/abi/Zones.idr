-- SPDX-License-Identifier: MPL-2.0
-- Zones.idr — Security zone system for level layouts
module Zones

import Primitives

%default total

||| A named security zone with a tier indicating clearance required.
public export
record Zone where
  constructor MkZone
  name         : String
  securityTier : Nat

||| A transition point between two zones at a world X coordinate.
public export
record ZoneTransition where
  constructor MkZoneTransition
  worldX   : WorldX
  fromZone : String
  toZone   : String
