-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Types.idr — Core enum types for IDApTIK Level Architect ABI
module Types

%default total

||| Hardware device categories in the game world.
public export
data DeviceKind
  = Laptop
  | Desktop
  | Server
  | Router
  | Switch
  | Firewall
  | Camera
  | AccessPoint
  | PatchPanel
  | PowerSupply
  | PhoneSystem
  | FibreHub

public export
Eq DeviceKind where
  Laptop      == Laptop      = True
  Desktop     == Desktop     = True
  Server      == Server      = True
  Router      == Router      = True
  Switch      == Switch      = True
  Firewall    == Firewall    = True
  Camera      == Camera      = True
  AccessPoint == AccessPoint = True
  PatchPanel  == PatchPanel  = True
  PowerSupply == PowerSupply = True
  PhoneSystem == PhoneSystem = True
  FibreHub    == FibreHub    = True
  _           == _           = False

||| Guard ranks from weakest to most dangerous.
public export
data GuardRank
  = BasicGuard
  | Enforcer
  | AntiHacker
  | Sentinel
  | Assassin
  | EliteGuard
  | SecurityChief
  | RivalHacker

public export
Eq GuardRank where
  BasicGuard    == BasicGuard    = True
  Enforcer      == Enforcer      = True
  AntiHacker    == AntiHacker    = True
  Sentinel      == Sentinel      = True
  Assassin      == Assassin      = True
  EliteGuard    == EliteGuard    = True
  SecurityChief == SecurityChief = True
  RivalHacker   == RivalHacker   = True
  _             == _             = False

||| Security dog breeds.
public export
data DogBreed = Patrol | Bloodhound | RoboDog

public export
Eq DogBreed where
  Patrol     == Patrol     = True
  Bloodhound == Bloodhound = True
  RoboDog    == RoboDog    = True
  _          == _          = False

||| Drone behaviour archetypes.
public export
data DroneArchetype = Helper | Hunter | Killer

public export
Eq DroneArchetype where
  Helper == Helper = True
  Hunter == Hunter = True
  Killer == Killer = True
  _      == _      = False

||| Facility-wide alert levels.
public export
data AlertLevel = Green | Yellow | Orange | Red

public export
Eq AlertLevel where
  Green  == Green  = True
  Yellow == Yellow = True
  Orange == Orange = True
  Red    == Red    = True
  _      == _      = False

||| Physical condition of inventory items.
public export
data ItemCondition = Pristine | Good | Worn | Damaged | Broken

public export
Eq ItemCondition where
  Pristine == Pristine = True
  Good     == Good     = True
  Worn     == Worn     = True
  Damaged  == Damaged  = True
  Broken   == Broken   = True
  _        == _        = False
