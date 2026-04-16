// SPDX-License-Identifier: PMPL-1.0-or-later
// Moletaire  Robotic mole companion entity (Molire joke)
//
// A controllable underground/above-ground companion with:
//   - Fast underground movement (~200px/s), very slow above-ground (~25px/s)
//   - Trap digging (4s under guard positions)
//   - Cable sabotage (3s chew)
//   - Item carrying (one small item, 5% eat chance on delivery)
//   - Wire distraction susceptibility (drawn to loose wires, 5s)
//   - Gliding (uncontrollable, height  distance)
//   - Permadeath (crushed by guard / caught by dog  Dead)
//
// State machine follows SecurityDog.res entity pattern exactly.
// Equipment system: head slot (Flash|BatteringRam|Camera|Miniglider)
//                   body slot (Skateboard|NoBody)

open Pixi

let absFloat = (x: float): float =>
  if x < 0.0 {
    -.x
  } else {
    x
  }

//  Tuning Constants 
//
// All gameplay constants extracted here for easy balancing.
// No magic numbers in logic  everything references Tuning.

module Tuning = {
  // Movement speeds (pixels per second)
  let undergroundSpeed = 200.0
  let aboveGroundSpeed = 25.0
  let skateboardSpeed = 55.0 // Above-ground with skateboard

  // Depth
  let maxDepth = 1.0 // 0.0 = surface, 1.0 = deepest
  let surfaceThreshold = 0.05 // Below this = effectively on surface
  let dogDetectionDepth = 0.3 // Dogs can detect mole at this depth or shallower

  // Actions
  let trapDigDurationSec = 4.0
  let cableSabotageDurationSec = 3.0
  let distractionDurationSec = 5.0
  let dodgeWindowSec = 0.5 // Time to dodge after trap triggers
  let flashStunDurationSec = 2.5

  // Item carrying
  let itemEatChance = 0.05 // 5% chance mole eats carried item on delivery
  let baseCarryCapacity = 1 // Default carry: 1 item
  let rucksackCarryCapacity = 3 // With rucksack: 3 items

  // Glider
  let gliderHeightMultiplier = 3.0 // Horizontal distance = height * this
  let gliderFallSpeed = 60.0

  // Visuals
  let bodyWidth = 20.0
  let bodyHeight = 14.0
  let noseRadius = 3.0

  // Underground indicator
  let dirtMoundWidth = 16.0
  let dirtMoundHeight = 6.0

  // Hunger system
  let hungerRate = 0.015 // Hunger units per second (takes ~67s to reach max)
  let hungerThreshold = 0.4 // Above this, mole starts resisting control
  let hungerStarvingThreshold = 0.8 // Above this, mole will eat ANYTHING including objectives
  let hungerFightInterval = 3.0 // Seconds between hunger-resistance episodes
  let hungerFightDuration = 1.5 // Seconds the mole fights the controller per episode
  let hungerEatSpeed = 120.0 // Speed when hunger-driven toward food
  let trainingHungerRate = 0.035 // Faster hunger for training visibility (reaches threshold in ~12s)
}

//  Equipment 

type headEquipment =
  | Flash // Stun nearby enemies temporarily
  | BatteringRam // Break window objects
  | Camera // Night vision + collect evidence
  | Miniglider // Glide from heights (uncontrollable)

type bodyEquipment =
  | Skateboard // Faster above-ground (55px/s instead of 25px/s)
  | Rucksack // Extra carry capacity (3 items instead of 1)
  | NoBody // No body equipment

type equipmentLoadout = {
  mutable head: option<headEquipment>,
  mutable body: bodyEquipment,
}

//  State Machine 

type moleState =
  | Idle // Stationary, awaiting orders
  | MovingUnderground // Fast tunnelling (~200px/s)
  | MovingAboveGround // Very slow surface movement (~25px/s)
  | DiggingTrap // 4s dig, then guard falls (dodge or be crushed)
  | SabotagingCable // 3s chew through cable
  | CarryingItem // Holding one small item  5% eat chance on delivery
  | Distracted // Drawn to loose wires, 5s duration
  | Gliding // Uncontrollable flight, height  distance
  | Crushed // Permadeath: guard fell into trap and mole didn't dodge
  | CaughtByDog // Permadeath: RoboDog dug down and caught mole
  | Dead // Terminal state (permadeath finalised)

type facing = Left | Right

//  Events 
//
// Returned from update() to signal game-level consequences.
// The caller (GameLoop / MoletaireTraining) acts on these.

type moleEvent =
  | TrapTriggered(float, float) // Guard fell at (x, y)  dodge window active
  | CableSabotaged(string) // Cable ID destroyed
  | ItemDelivered(string) // Item ID delivered to destination
  | ItemEaten(string) // Mole ate the item (5% chance)
  | FlashFired // Flash stun triggered
  | MoleDied(moleState) // Permadeath  Crushed or CaughtByDog
  | DistractionStarted // Mole was pulled toward loose wires
  | GlideComplete(float) // Landed at x position
  | ReachedDestination // MoveTo order completed
  | FoodEaten // Mole was fed
  | ItemPickedUp(string) // Item ID picked up by mole
  | ItemDropped(string) // Item ID dropped by mole
  | GlideStarted(float) // Glider launched at this height
  | HungerResistanceStarted // Mole began resisting control due to hunger
  | HungerResistanceEnded // Mole stopped resisting control
  | EnteredBuilding // Mole entered a building
  | ClimbedFloor(int) // Mole climbed to this floor number
  | JumpedFromBuilding // Mole jumped from a building
  | CaughtByJessica // Jessica caught the mole
  | MissedCatch // A catch attempt missed
  | DogDetectedMole // Dog detected the mole's position
  | DogCaughtMole // Dog successfully caught the mole

//  Entity 

type t = {
  id: string,
  mutable state: moleState,
  mutable x: float,
  mutable y: float, // Ground-level y (rendering anchor)
  mutable depth: float, // 0.0 = surface, 1.0 = deepest underground
  mutable facing: facing,
  mutable targetX: option<float>, // Where the mole is ordered to go
  mutable targetDepth: option<float>, // Target depth (0.0 to dig up, 1.0 to dig down)
  // Equipment
  equipment: equipmentLoadout,
  // Action timers
  mutable actionTimer: float, // Generic countdown for current action
  mutable dodgeTimer: float, // Countdown for trap dodge window
  // Carrying (capacity: 1 normally, 3 with Rucksack)
  mutable carriedItems: array<string>, // Item IDs being carried
  // Distraction
  mutable distractionTimer: float,
  mutable distractionX: option<float>,
  // Gliding
  mutable glideStartHeight: float,
  mutable glideDistance: float,
  mutable glideProgress: float, // 0.0 to 1.0
  // Status
  mutable alive: bool,
  // Hunger system — mole fights controller when hungry to eat components.
  // At max hunger, mole will even eat the main objective component.
  mutable hunger: float, // 0.0 (full) to 1.0 (starving)
  mutable hungerFightTimer: float, // When hungry, periodically ignores input
  mutable isResistingControl: bool, // True when hunger overrides player input
  mutable hungerTargetX: option<float>, // Where the mole is trying to eat
  // Pending events (supplementary channel, drained by caller each frame)
  mutable pendingEvents: array<moleEvent>,
  // Graphics
  container: Container.t,
  bodyGraphic: Graphics.t,
  indicatorGraphic: Graphics.t, // Surface dirt mound indicator
}

//  Construction 

let make = (~id: string, ~x: float, ~y: float, ~equipment: equipmentLoadout): t => {
  let container = Container.make()
  Container.setX(container, x)
  Container.setY(container, y)

  let bodyGraphic = Graphics.make()
  let indicatorGraphic = Graphics.make()
  let _ = Container.addChildGraphics(container, indicatorGraphic)
  let _ = Container.addChildGraphics(container, bodyGraphic)

  {
    id,
    state: Idle,
    x,
    y,
    depth: 0.0, // Start on surface (visible). Player dives underground with M key.
    facing: Right,
    targetX: None,
    targetDepth: None,
    equipment,
    actionTimer: 0.0,
    dodgeTimer: 0.0,
    carriedItems: [],
    distractionTimer: 0.0,
    distractionX: None,
    glideStartHeight: 0.0,
    glideDistance: 0.0,
    glideProgress: 0.0,
    alive: true,
    hunger: 0.0, // Start well-fed
    hungerFightTimer: 0.0,
    isResistingControl: false,
    hungerTargetX: None,
    pendingEvents: [],
    container,
    bodyGraphic,
    indicatorGraphic,
  }
}

// Push an event to the pending queue (drained by caller each frame)
let emitEvent = (mole: t, event: moleEvent): unit => {
  let _ = Array.push(mole.pendingEvents, event)
}

// Drain all pending events (caller processes then clears)
let drainEvents = (mole: t): array<moleEvent> => {
  let events = Array.copy(mole.pendingEvents)
  mole.pendingEvents = []
  events
}

//  Commands
//
// Player issues orders to Moletaire. The mole carries them out
// over time. Commands are fire-and-forget  the mole's state
// machine handles completion.

// Order the mole to move to a position (underground or above ground)
let orderMoveTo = (mole: t, ~targetX: float, ~underground: bool): unit => {
  if mole.alive && mole.state != Dead {
    mole.targetX = Some(targetX)
    if underground {
      mole.state = MovingUnderground

      // Dive underground if at surface
      if mole.depth < 0.3 {
        mole.targetDepth = Some(0.5)
      }
    } else {
      mole.state = MovingAboveGround

      // Surface if underground
      if mole.depth > Tuning.surfaceThreshold {
        mole.targetDepth = Some(0.0)
      }
    }
  }
}

// Order mole to dig a trap at current position
let orderDigTrap = (mole: t): unit => {
  if mole.alive && mole.state != Dead && mole.depth > 0.1 {
    mole.state = DiggingTrap
    mole.actionTimer = Tuning.trapDigDurationSec
  }
}

// Order mole to sabotage a cable at current position
let orderSabotageCable = (mole: t): unit => {
  if mole.alive && mole.state != Dead && mole.depth > 0.1 {
    mole.state = SabotagingCable
    mole.actionTimer = Tuning.cableSabotageDurationSec
  }
}

// Max carry capacity (1 normally, 3 with Rucksack)
let getCarryCapacity = (mole: t): int => {
  if mole.equipment.body == Rucksack {
    Tuning.rucksackCarryCapacity
  } else {
    Tuning.baseCarryCapacity
  }
}

// Give an item to the mole for carrying (respects capacity)
let giveItem = (mole: t, ~itemId: string): bool => {
  if mole.alive && Array.length(mole.carriedItems) < getCarryCapacity(mole) {
    let _ = Array.push(mole.carriedItems, itemId)
    mole.state = CarryingItem
    emitEvent(mole, ItemPickedUp(itemId))
    true
  } else {
    false
  }
}

// Drop a specific item (returns true if item was carried)
let dropItem = (mole: t, ~itemId: string): bool => {
  let idx = mole.carriedItems->Array.findIndex(id => id == itemId)
  if idx >= 0 {
    let _ = Array.splice(mole.carriedItems, ~start=idx, ~remove=1, ~insert=[])
    if Array.length(mole.carriedItems) == 0 {
      mole.state = Idle
    }
    emitEvent(mole, ItemDropped(itemId))
    true
  } else {
    false
  }
}

// Order mole to deliver carried items (move to delivery point then drop)
let orderDeliver = (mole: t, ~deliveryX: float): unit => {
  if mole.alive && Array.length(mole.carriedItems) > 0 {
    mole.targetX = Some(deliveryX)
    // Stay in CarryingItem state, will deliver on arrival
  }
}

// Equip head equipment at runtime (swap current)
let equipHead = (mole: t, ~head: headEquipment): unit => {
  mole.equipment.head = Some(head)
}

// Equip body equipment at runtime (swap current)
let equipBody = (mole: t, ~body: bodyEquipment): unit => {
  // If switching away from Rucksack, drop excess items
  if mole.equipment.body == Rucksack && body != Rucksack {
    while Array.length(mole.carriedItems) > Tuning.baseCarryCapacity {
      let _ = Array.pop(mole.carriedItems)
    }
  }
  mole.equipment.body = body
}

// Remove head equipment
let unequipHead = (mole: t): unit => {
  mole.equipment.head = None
}

// Use flash equipment (if equipped)
let useFlash = (mole: t): bool => {
  if mole.alive && mole.equipment.head == Some(Flash) {
    true
  } else {
    false
  }
}

// Launch glider (if equipped and above ground)
let launchGlider = (mole: t, ~launchHeight: float): bool => {
  if mole.alive && mole.equipment.head == Some(Miniglider) && mole.depth < Tuning.surfaceThreshold {
    mole.state = Gliding
    mole.glideStartHeight = launchHeight
    mole.glideDistance = launchHeight *. Tuning.gliderHeightMultiplier
    mole.glideProgress = 0.0
    emitEvent(mole, GlideStarted(launchHeight))
    true
  } else {
    false
  }
}

//  Movement Update 

let updateMovement = (mole: t, ~dt: float): option<moleEvent> => {
  // Move toward depth target
  switch mole.targetDepth {
  | Some(target) => {
      let depthDiff = target -. mole.depth
      let depthSpeed = 0.8 // depth units per second
      if absFloat(depthDiff) < 0.02 {
        mole.depth = target
        mole.targetDepth = None
      } else {
        let direction = if depthDiff > 0.0 {
          1.0
        } else {
          -1.0
        }
        mole.depth = mole.depth +. direction *. depthSpeed *. dt
      }
    }
  | None => ()
  }

  // Move toward x target
  switch mole.targetX {
  | Some(target) => {
      let dx = target -. mole.x
      let dist = absFloat(dx)
      let speed = switch mole.state {
      | MovingUnderground => Tuning.undergroundSpeed
      | MovingAboveGround =>
        if mole.equipment.body == Skateboard {
          Tuning.skateboardSpeed
        } else {
          Tuning.aboveGroundSpeed
        }
      | CarryingItem =>
        if mole.depth > Tuning.surfaceThreshold {
          Tuning.undergroundSpeed *. 0.7
        } else {
          Tuning.aboveGroundSpeed
        }
      | _ => 0.0
      }

      if dist < 5.0 {
        mole.x = target
        mole.targetX = None

        // Deliver items on arrival if carrying
        if mole.state == CarryingItem {
          if Array.length(mole.carriedItems) > 0 {
            // Deliver the first carried item
            switch mole.carriedItems[0] {
            | Some(itemId) => {
                // 5% chance mole eats the item
                let roll = Math.random()
                let _ = Array.splice(mole.carriedItems, ~start=0, ~remove=1, ~insert=[])
                if Array.length(mole.carriedItems) == 0 {
                  mole.state = Idle
                }
                if roll < Tuning.itemEatChance {
                  Some(ItemEaten(itemId))
                } else {
                  Some(ItemDelivered(itemId))
                }
              }
            | None => {
                mole.state = Idle
                Some(ReachedDestination)
              }
            }
          } else {
            mole.state = Idle
            Some(ReachedDestination)
          }
        } else {
          mole.state = Idle
          Some(ReachedDestination)
        }
      } else {
        let direction = if dx > 0.0 {
          1.0
        } else {
          -1.0
        }
        mole.x = mole.x +. direction *. speed *. dt
        mole.facing = if dx > 0.0 {
          Right
        } else {
          Left
        }
        None
      }
    }
  | None => None
  }
}

//  State Machine Update 

let updateState = (mole: t, ~dt: float): option<moleEvent> => {
  if !mole.alive {
    None
  } else {
    switch mole.state {
    | Idle => None

    | MovingUnderground | MovingAboveGround => updateMovement(mole, ~dt)

    | CarryingItem => updateMovement(mole, ~dt)

    | DiggingTrap => {
        mole.actionTimer = mole.actionTimer -. dt
        if mole.actionTimer <= 0.0 {
          mole.state = Idle
          // Trap is ready  caller checks for guard collision
          Some(TrapTriggered(mole.x, mole.y))
        } else {
          None
        }
      }

    | SabotagingCable => {
        mole.actionTimer = mole.actionTimer -. dt
        if mole.actionTimer <= 0.0 {
          mole.state = Idle
          Some(CableSabotaged("cable_" ++ Float.toString(mole.x)))
        } else {
          None
        }
      }

    | Distracted => {
        mole.distractionTimer = mole.distractionTimer -. dt
        // Move toward the distraction source
        switch mole.distractionX {
        | Some(dX) => {
            let dx = dX -. mole.x
            let direction = if dx > 0.0 {
              1.0
            } else {
              -1.0
            }
            mole.x = mole.x +. direction *. Tuning.aboveGroundSpeed *. dt
            mole.facing = if dx > 0.0 {
              Right
            } else {
              Left
            }
          }
        | None => ()
        }
        if mole.distractionTimer <= 0.0 {
          mole.state = Idle
          mole.distractionX = None
          None
        } else {
          None
        }
      }

    | Gliding => {
        // Move horizontally based on glide distance
        let glideSpeed =
          SafeFloat.divOr(mole.glideDistance, 2.0, ~default=50.0) *. Tuning.gliderFallSpeed /. 60.0
        let direction = switch mole.facing {
        | Right => 1.0
        | Left => -1.0
        }
        mole.x = mole.x +. direction *. glideSpeed *. dt
        mole.glideProgress = mole.glideProgress +. dt *. 0.5
        if mole.glideProgress >= 1.0 {
          mole.state = Idle
          mole.depth = 0.0
          Some(GlideComplete(mole.x))
        } else {
          None
        }
      }

    | Crushed | CaughtByDog => {
        mole.alive = false
        mole.state = Dead
        Some(MoleDied(mole.state))
      }

    | Dead => None
    }
  }
}

//  Distraction Response 

// Loose wires pull the mole toward them (involuntary)
let distractByWire = (mole: t, ~wireX: float): bool => {
  if (
    mole.alive && mole.state != Dead && mole.state != DiggingTrap && mole.state != SabotagingCable
  ) {
    let dist = absFloat(wireX -. mole.x)
    if dist < 200.0 {
      mole.state = Distracted
      mole.distractionTimer = Tuning.distractionDurationSec
      mole.distractionX = Some(wireX)
      true
    } else {
      false
    }
  } else {
    false
  }
}

//  Death 

// Guard fell into trap and mole didn't dodge in time
let crushMole = (mole: t): unit => {
  if mole.alive {
    mole.state = Crushed
    mole.alive = false
  }
}

// RoboDog dug down and caught the mole
let catchByDog = (mole: t): unit => {
  if mole.alive {
    mole.state = CaughtByDog
    mole.alive = false
  }
}

//  Graphics 
//
// Procedural rendering: small rounded brown body, pink nose,
// tiny eyes, optional equipment indicators.

// Console log mole pos for debug
// let _ = Js.log3("Mole pos:", mole.x, mole.depth)
let renderMole = (mole: t): unit => {
  let _ = Graphics.clear(mole.bodyGraphic)
  let _ = Graphics.clear(mole.indicatorGraphic)

  if !mole.alive || mole.state == Dead {
    // Dead mole  dim, flattened silhouette
    let _ =
      mole.bodyGraphic
      ->Graphics.rect(
        -.Tuning.bodyWidth /. 2.0,
        -.Tuning.bodyHeight /. 2.0,
        Tuning.bodyWidth,
        Tuning.bodyHeight *. 0.3,
      )
      ->Graphics.fill({"color": 0x4a3520, "alpha": 0.3})
    Container.setX(mole.container, mole.x)
    Container.setAlpha(mole.container, 0.4)
  } else {
    Container.setAlpha(mole.container, 1.0)

    // Body color varies by state
    let bodyColor = switch mole.state {
    | Idle => 0x6b4226 // Warm brown
    | MovingUnderground => 0x5a3518 // Darker (underground)
    | MovingAboveGround => 0x7a5230 // Lighter (surface)
    | DiggingTrap => 0x8b6914 // Yellowish (digging)
    | SabotagingCable => 0x884422 // Reddish-brown
    | CarryingItem => 0x6b4226
    | Distracted => 0xaa7744 // Lighter (confused)
    | Gliding => 0x6688aa // Blue tint (sky)
    | Crushed | CaughtByDog | Dead => 0x333333
    }

    // Underground offset  mole body shifts down when underground
    let depthOffset = 0.0

    // Main body  rounded rectangle
    let _ =
      mole.bodyGraphic
      ->Graphics.roundRect(
        -.Tuning.bodyWidth /. 2.0,
        -.Tuning.bodyHeight +. depthOffset,
        Tuning.bodyWidth,
        Tuning.bodyHeight,
        4.0,
      )
      ->Graphics.fill({"color": bodyColor})

    // Pink nose  circle at front
    let noseX = switch mole.facing {
    | Right => Tuning.bodyWidth /. 2.0 +. 1.0
    | Left => -.Tuning.bodyWidth /. 2.0 -. 1.0
    }
    let _ =
      mole.bodyGraphic
      ->Graphics.circle(noseX, -.Tuning.bodyHeight /. 2.0 +. depthOffset, Tuning.noseRadius)
      ->Graphics.fill({"color": 0xff9999})

    // Tiny eyes  2 small circles
    let eyeBaseX = switch mole.facing {
    | Right => Tuning.bodyWidth /. 2.0 -. 4.0
    | Left => -.Tuning.bodyWidth /. 2.0 +. 4.0
    }
    let _ =
      mole.bodyGraphic
      ->Graphics.circle(eyeBaseX, -.Tuning.bodyHeight +. 4.0 +. depthOffset, 1.5)
      ->Graphics.fill({"color": 0x111111})
    let _ =
      mole.bodyGraphic
      ->Graphics.circle(eyeBaseX, -.Tuning.bodyHeight +. 4.0 +. depthOffset -. 3.0, 1.5)
      ->Graphics.fill({"color": 0x111111})

    // Front paws (small rectangles at base)
    let pawColor = 0x8a6a3a
    let _ =
      mole.bodyGraphic
      ->Graphics.rect(-.Tuning.bodyWidth /. 2.0 +. 2.0, depthOffset, 4.0, 3.0)
      ->Graphics.fill({"color": pawColor})
    let _ =
      mole.bodyGraphic
      ->Graphics.rect(Tuning.bodyWidth /. 2.0 -. 6.0, depthOffset, 4.0, 3.0)
      ->Graphics.fill({"color": pawColor})

    // Equipment indicators
    switch mole.equipment.head {
    | Some(Flash) => {
        // Small yellow circle above head (flashlight)
        let _ =
          mole.bodyGraphic
          ->Graphics.circle(0.0, -.Tuning.bodyHeight -. 4.0 +. depthOffset, 3.0)
          ->Graphics.fill({"color": 0xffff00, "alpha": 0.7})
      }
    | Some(BatteringRam) => {
        // Small grey rectangle on head (helmet)
        let _ =
          mole.bodyGraphic
          ->Graphics.rect(
            -.Tuning.bodyWidth /. 2.0,
            -.Tuning.bodyHeight -. 3.0 +. depthOffset,
            Tuning.bodyWidth,
            3.0,
          )
          ->Graphics.fill({"color": 0x888888})
      }
    | Some(Camera) => {
        // Small green circle (camera lens)
        let lensX = switch mole.facing {
        | Right => Tuning.bodyWidth /. 2.0 +. 3.0
        | Left => -.Tuning.bodyWidth /. 2.0 -. 3.0
        }
        let _ =
          mole.bodyGraphic
          ->Graphics.circle(lensX, -.Tuning.bodyHeight +. 2.0 +. depthOffset, 2.5)
          ->Graphics.fill({"color": 0x00ff44})
      }
    | Some(Miniglider) => {
        // Small triangle wings
        let _ =
          mole.bodyGraphic
          ->Graphics.moveTo(
            -.Tuning.bodyWidth /. 2.0 -. 4.0,
            -.Tuning.bodyHeight /. 2.0 +. depthOffset,
          )
          ->Graphics.lineTo(
            Tuning.bodyWidth /. 2.0 +. 4.0,
            -.Tuning.bodyHeight /. 2.0 +. depthOffset,
          )
          ->Graphics.lineTo(0.0, -.Tuning.bodyHeight -. 6.0 +. depthOffset)
          ->Graphics.lineTo(
            -.Tuning.bodyWidth /. 2.0 -. 4.0,
            -.Tuning.bodyHeight /. 2.0 +. depthOffset,
          )
          ->Graphics.fill({"color": 0x4488cc, "alpha": 0.5})
      }
    | None => ()
    }

    // Skateboard indicator (small grey board under body)
    if mole.equipment.body == Skateboard && mole.depth < Tuning.surfaceThreshold {
      let _ =
        mole.bodyGraphic
        ->Graphics.rect(
          -.Tuning.bodyWidth /. 2.0 -. 2.0,
          depthOffset +. 3.0,
          Tuning.bodyWidth +. 4.0,
          2.0,
        )
        ->Graphics.fill({"color": 0x666666})
      // Wheels
      let _ =
        mole.bodyGraphic
        ->Graphics.circle(-.Tuning.bodyWidth /. 2.0 +. 2.0, depthOffset +. 6.0, 1.5)
        ->Graphics.fill({"color": 0x333333})
      let _ =
        mole.bodyGraphic
        ->Graphics.circle(Tuning.bodyWidth /. 2.0 -. 2.0, depthOffset +. 6.0, 1.5)
        ->Graphics.fill({"color": 0x333333})
    }

    // Carried item indicators (small blue rectangles stacked above mole)
    let itemCount = Array.length(mole.carriedItems)
    if itemCount > 0 {
      for i in 0 to itemCount - 1 {
        let itemY = -.Tuning.bodyHeight -. 8.0 -. Int.toFloat(i) *. 6.0 +. depthOffset
        let _ =
          mole.bodyGraphic
          ->Graphics.rect(-3.0, itemY, 6.0, 4.0)
          ->Graphics.fill({"color": 0x4488ff})
      }
    }

    // Rucksack indicator (small brown bag shape on body)
    if mole.equipment.body == Rucksack {
      let _ =
        mole.bodyGraphic
        ->Graphics.rect(
          -.Tuning.bodyWidth /. 2.0 +. 2.0,
          -.Tuning.bodyHeight +. 2.0 +. depthOffset,
          Tuning.bodyWidth -. 4.0,
          Tuning.bodyHeight -. 4.0,
        )
        ->Graphics.fill({"color": 0x664422, "alpha": 0.4})
        ->Graphics.stroke({"color": 0x886633, "width": 0.5})
    }

    // Surface dirt mound indicator  visible when underground
    // Made large and bright so the mole's underground position is obvious
    if mole.depth > Tuning.surfaceThreshold {
      // Large dirt mound triangle (surface marker)
      let moundW = Tuning.dirtMoundWidth *. 2.0
      let moundH = Tuning.dirtMoundHeight *. 2.5
      let _ =
        mole.indicatorGraphic
        ->Graphics.moveTo(-.moundW /. 2.0, 0.0)
        ->Graphics.lineTo(0.0, -.moundH)
        ->Graphics.lineTo(moundW /. 2.0, 0.0)
        ->Graphics.lineTo(-.moundW /. 2.0, 0.0)
        ->Graphics.fill({"color": 0xcc9933, "alpha": 0.85})
      // Bright outline ring at surface for easy spotting
      let _ =
        mole.indicatorGraphic
        ->Graphics.circle(0.0, -.moundH -. 4.0, 6.0)
        ->Graphics.fill({"color": 0xff9999, "alpha": 0.9})
      // "MOLE" label above the mound
      // (rendered via the body graphic since indicator is just Graphics)
      let _ =
        mole.indicatorGraphic
        ->Graphics.rect(-12.0, -.moundH -. 18.0, 24.0, 10.0)
        ->Graphics.fill({"color": 0x000000, "alpha": 0.5})
    }

    // Digging animation indicator
    if mole.state == DiggingTrap || mole.state == SabotagingCable {
      // Small dirt particles around the mole (3 rectangles offset)
      let _ =
        mole.bodyGraphic
        ->Graphics.rect(-8.0, -2.0 +. depthOffset, 3.0, 3.0)
        ->Graphics.fill({"color": 0xaa8833, "alpha": 0.6})
      let _ =
        mole.bodyGraphic
        ->Graphics.rect(6.0, -4.0 +. depthOffset, 3.0, 3.0)
        ->Graphics.fill({"color": 0xaa8833, "alpha": 0.5})
      let _ =
        mole.bodyGraphic
        ->Graphics.rect(0.0, -10.0 +. depthOffset, 2.0, 2.0)
        ->Graphics.fill({"color": 0xaa8833, "alpha": 0.4})
    }

    // Distraction indicator (spiral above head)
    if mole.state == Distracted {
      let _ =
        mole.bodyGraphic
        ->Graphics.circle(0.0, -.Tuning.bodyHeight -. 12.0 +. depthOffset, 4.0)
        ->Graphics.stroke({"color": 0xffaa00, "width": 1.5})
    }

    Container.setX(mole.container, mole.x)
    // Adjust visual y based on underground state
    let visualY = mole.y +. mole.depth *. 60.0
    Container.setY(mole.container, visualY)
  }
}

//  Per-Frame Update 
//
// Call once per frame with delta time. Returns optional game event
// for the caller to process (trap trigger, death, delivery, etc.)

let update = (mole: t, ~dt: float): option<moleEvent> => {
  let result = updateState(mole, ~dt)

  // Dodge timer countdown
  if mole.dodgeTimer > 0.0 {
    mole.dodgeTimer = mole.dodgeTimer -. dt
  }

  // Hunger increases over time
  if mole.alive {
    let wasResisting = mole.isResistingControl
    mole.hunger = Math.min(1.0, mole.hunger +. Tuning.hungerRate *. dt)

    // When hungry, periodically resist player control
    if mole.hunger > Tuning.hungerThreshold {
      mole.hungerFightTimer = mole.hungerFightTimer +. dt
      if mole.hungerFightTimer > Tuning.hungerFightInterval {
        mole.isResistingControl = true
        if mole.hungerFightTimer > Tuning.hungerFightInterval +. Tuning.hungerFightDuration {
          mole.hungerFightTimer = 0.0
          mole.isResistingControl = false
        }
      } else {
        mole.isResistingControl = false
      }

      // When starving and has a hunger target, move toward it autonomously
      switch mole.hungerTargetX {
      | Some(targetX) =>
        if mole.isResistingControl {
          let dx = targetX -. mole.x
          let dir = if dx > 0.0 { 1.0 } else { -1.0 }
          mole.x = mole.x +. dir *. Tuning.hungerEatSpeed *. dt
          mole.facing = if dx > 0.0 { Right } else { Left }
        }
      | None => ()
      }
    } else {
      mole.isResistingControl = false
    }

    // Emit hunger resistance transition events
    if !wasResisting && mole.isResistingControl {
      emitEvent(mole, HungerResistanceStarted)
    } else if wasResisting && !mole.isResistingControl {
      emitEvent(mole, HungerResistanceEnded)
    }
  }

  renderMole(mole)
  result
}

// Feed the mole — resets hunger to 0
let feed = (mole: t): unit => {
  mole.hunger = 0.0
  mole.hungerFightTimer = 0.0
  mole.isResistingControl = false
  mole.hungerTargetX = None
  emitEvent(mole, FoodEaten)
}

// Set a hunger target (component the mole wants to eat)
let setHungerTarget = (mole: t, ~targetX: float): unit => {
  mole.hungerTargetX = Some(targetX)
}

// Is the mole currently fighting the controller due to hunger?
let isResistingControl = (mole: t): bool => mole.isResistingControl

// Get hunger level (0.0 full, 1.0 starving)
let getHunger = (mole: t): float => mole.hunger

// Is the mole starving (will eat objectives)?
let isStarving = (mole: t): bool => mole.hunger > Tuning.hungerStarvingThreshold

//  Queries 

let isAlive = (mole: t): bool => mole.alive
let isDead = (mole: t): bool => !mole.alive
let isUnderground = (mole: t): bool => mole.depth > Tuning.surfaceThreshold
let isIdle = (mole: t): bool => mole.state == Idle
let isDigging = (mole: t): bool => mole.state == DiggingTrap || mole.state == SabotagingCable
let isDistracted = (mole: t): bool => mole.state == Distracted
let isCarrying = (mole: t): bool => Array.length(mole.carriedItems) > 0
let isGliding = (mole: t): bool => mole.state == Gliding

let getDepth = (mole: t): float => mole.depth

let stateToString = (mole: t): string => {
  switch mole.state {
  | Idle => "IDLE"
  | MovingUnderground => "TUNNELLING"
  | MovingAboveGround => "SURFACE"
  | DiggingTrap => "DIGGING TRAP"
  | SabotagingCable => "SABOTAGING"
  | CarryingItem => "CARRYING"
  | Distracted => "DISTRACTED"
  | Gliding => "GLIDING"
  | Crushed => "CRUSHED"
  | CaughtByDog => "CAUGHT"
  | Dead => "DEAD"
  }
}

let distanceTo = (mole: t, ~x: float): float => {
  absFloat(x -. mole.x)
}

//  Hitbox 
//
// Body rectangle for collision detection (guards, dogs, traps).

let getBodyRect = (mole: t): Hitbox.rect => {
  {
    x: mole.x -. Tuning.bodyWidth /. 2.0,
    y: mole.y -. Tuning.bodyHeight -. mole.depth *. 10.0,
    w: Tuning.bodyWidth,
    h: Tuning.bodyHeight,
  }
}
