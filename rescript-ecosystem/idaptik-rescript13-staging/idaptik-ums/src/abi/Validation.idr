-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Validation.idr — Cross-domain validation proofs for level integrity
module Validation

import Primitives
import Types
import Devices
import Zones
import Guards
import Level

%default total

------------------------------------------------------------------------
-- Proof: a device IP exists in the device registry
------------------------------------------------------------------------

||| Witness that a given IP address appears in a list of devices.
public export
data InRegistry : (device : IpAddress) -> (devs : List DeviceSpec) -> Type where
  ||| The device is at the head of the list.
  Here  : (prf : ip d = addr) -> InRegistry addr (d :: ds)
  ||| The device is somewhere in the tail.
  There : InRegistry addr ds -> InRegistry addr (d :: ds)

------------------------------------------------------------------------
-- Proof: all guards reference valid zones
------------------------------------------------------------------------

||| Witness that a zone name appears in the zone list.
public export
data ZoneExists : (zoneName : String) -> (zs : List Zone) -> Type where
  ZoneHere  : (prf : name z = n) -> ZoneExists n (z :: zs)
  ZoneThere : ZoneExists n zs -> ZoneExists n (z :: zs)

||| Witness that every guard's zone field names a valid zone.
public export
data GuardsInZones : (gs : List GuardPlacement) -> (zs : List Zone) -> Type where
  ||| No guards — trivially valid.
  NoGuards  : GuardsInZones [] zs
  ||| Head guard is in a valid zone, and the rest are too.
  GuardOk   : ZoneExists (zone g) zs
           -> GuardsInZones gs2 zs
           -> GuardsInZones (g :: gs2) zs

------------------------------------------------------------------------
-- Proof: defence failover/cascade/mirror targets reference real devices
------------------------------------------------------------------------

||| Helper: if a Maybe IpAddress is Just, that IP is in the registry.
public export
data MaybeInRegistry : (target : Maybe IpAddress) -> (devs : List DeviceSpec) -> Type where
  ||| Target is Nothing — no constraint.
  TargetNone : MaybeInRegistry Nothing devs
  ||| Target is Just addr — addr must be in registry.
  TargetSome : InRegistry addr devs -> MaybeInRegistry (Just addr) devs

||| Witness that all defence config targets reference real devices.
public export
data DefenceTargetsValid : (defs : List DeviceDefenceConfig) -> (devs : List DeviceSpec) -> Type where
  ||| No defences — trivially valid.
  NoDefences  : DefenceTargetsValid [] devs
  ||| Head defence has valid targets, and the rest do too.
  DefenceOk   : InRegistry (ip d) devs
             -> MaybeInRegistry (failoverTarget (flags d)) devs
             -> MaybeInRegistry (cascadeTrap (flags d)) devs
             -> MaybeInRegistry (mirrorTarget (flags d)) devs
             -> DefenceTargetsValid ds devs
             -> DefenceTargetsValid (d :: ds) devs

------------------------------------------------------------------------
-- Proof: zone transitions are monotonically increasing in X
------------------------------------------------------------------------

||| Witness that zone transitions are ordered by world X position.
public export
data ZonesOrdered : (transitions : List ZoneTransition) -> Type where
  ||| Empty list is ordered.
  ZonesNil  : ZonesOrdered []
  ||| Single transition is ordered.
  ZonesOne  : ZonesOrdered [t]
  ||| Consecutive transitions: first X <= second X, and the tail is ordered.
  ZonesCons : (lte : position (worldX t1) <= position (worldX t2) = True)
           -> ZonesOrdered (t2 :: ts)
           -> ZonesOrdered (t1 :: t2 :: ts)

------------------------------------------------------------------------
-- Proof: PBX consistency
------------------------------------------------------------------------

||| When hasPBX is True, the pbxAddr must exist in the device registry.
||| When hasPBX is False, no constraint is imposed.
public export
data PBXConsistent : (enabled : Bool) -> (pbxAddr : IpAddress) -> (devs : List DeviceSpec) -> Type where
  ||| PBX is disabled — no constraint.
  PBXOff : PBXConsistent False pbxAddr devs
  ||| PBX is enabled — its IP must be in the registry.
  PBXOn  : InRegistry pbxAddr devs -> PBXConsistent True pbxAddr devs

------------------------------------------------------------------------
-- Validated level: level data + all proofs, erased at runtime
------------------------------------------------------------------------

||| A level that has been validated against all cross-domain invariants.
||| Proof fields are erased (0-quantity) so they have zero runtime cost.
public export
record ValidatedLevel where
  constructor MkValidatedLevel
  levelData          : LevelData
  0 devicesExist     : DefenceTargetsValid (deviceDefences levelData) (devices levelData)
  0 guardsValid      : GuardsInZones (guards levelData) (zones levelData)
  0 zonesMonotonic   : ZonesOrdered (zoneTransitions levelData)
  0 pbxOk            : PBXConsistent (hasPBX levelData) (pbxIp levelData) (devices levelData)
