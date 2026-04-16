-- SPDX-License-Identifier: PMPL-1.0-or-later
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
