-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Drones.idr — Drone placement
module Drones

import Primitives
import Types

%default total

||| A drone placed in the game world.
public export
record DronePlacement where
  constructor MkDronePlacement
  worldX    : WorldX
  archetype : DroneArchetype
  altitude  : Double
