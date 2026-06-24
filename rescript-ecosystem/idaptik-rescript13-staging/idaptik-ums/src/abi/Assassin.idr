-- SPDX-License-Identifier: MPL-2.0
-- Assassin.idr — Assassin encounter configuration
module Assassin

import Primitives

%default total

||| Configuration for assassin encounters in a level.
public export
record AssassinConfig where
  constructor MkAssassinConfig
  spawnX           : WorldX
  ambushCount      : Nat
  retreatThreshold : Nat
