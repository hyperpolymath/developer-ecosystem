-- SPDX-License-Identifier: MPL-2.0
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
