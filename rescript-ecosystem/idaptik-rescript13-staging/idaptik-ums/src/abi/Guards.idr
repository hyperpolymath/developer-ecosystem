-- SPDX-License-Identifier: MPL-2.0
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
