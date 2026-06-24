-- SPDX-License-Identifier: MPL-2.0
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
