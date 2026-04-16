-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Mission.idr — Mission objectives and structure
module Mission

%default total

||| A single mission objective.
public export
record MissionObjective where
  constructor MkMissionObjective
  id          : String
  description : String
  required    : Bool

||| Top-level mission configuration for a level.
public export
record MissionConfig where
  constructor MkMissionConfig
  missionId  : String
  locationId : String
  objectives : List MissionObjective
  timeLimit  : Maybe Nat
