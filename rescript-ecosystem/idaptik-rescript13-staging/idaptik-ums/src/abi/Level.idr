-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Level.idr — Composite level bundle importing all sub-records
module Level

import Primitives
import Types
import Devices
import Zones
import Inventory
import Guards
import Dogs
import Drones
import Assassin
import Mission
import Wiring
import Physical

%default total

||| Complete level data composed from all sub-domain records.
public export
record LevelData where
  constructor MkLevelData
  devices         : List DeviceSpec
  zones           : List Zone
  guards          : List GuardPlacement
  dogs            : List DogPlacement
  drones          : List DronePlacement
  assassins       : List AssassinConfig
  items           : List WorldItem
  wiring          : List WiringChallenge
  mission         : MissionConfig
  physical        : PhysicalConfig
  zoneTransitions : List ZoneTransition
  deviceDefences  : List DeviceDefenceConfig
  hasPBX          : Bool
  pbxIp           : IpAddress
  pbxWorldX       : WorldX
