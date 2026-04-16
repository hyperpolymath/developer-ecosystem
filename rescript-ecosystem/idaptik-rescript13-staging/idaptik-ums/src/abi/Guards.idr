-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Guards.idr — Guard placement in level layouts
module Guards

import Primitives
import Types

%default total

||| A guard placed in the game world.
public export
record GuardPlacement where
  constructor MkGuardPlacement
  worldX       : WorldX
  zone         : String
  rank         : GuardRank
  patrolRadius : Double
