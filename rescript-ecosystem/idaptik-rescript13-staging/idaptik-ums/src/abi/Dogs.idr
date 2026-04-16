-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Dogs.idr — Security dog placement
module Dogs

import Primitives
import Types

%default total

||| A security dog placed in the game world.
public export
record DogPlacement where
  constructor MkDogPlacement
  worldX       : WorldX
  breed        : DogBreed
  patrolRadius : Double
