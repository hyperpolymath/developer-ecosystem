-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Physical.idr — Physical world configuration
module Physical

%default total

||| Physical properties of the game world.
public export
record PhysicalConfig where
  constructor MkPhysicalConfig
  groundY             : Double
  worldWidth          : Double
  interactionDistance  : Double
  hasPowerSystem      : Bool
  hasSecurityCameras  : Bool
  numberOfCovertLinks : Nat
