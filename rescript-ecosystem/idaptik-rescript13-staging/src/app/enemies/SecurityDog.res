// SPDX-License-Identifier: PMPL-1.0-or-later
// SecurityDog  guard dogs and robodogs
//
// Two variants:
//   GuardDog    Biological K-9 unit. Scent detection ignores line-of-sight
//                and darkness. Distracted by food. Barks to raise alert.
//   RoboDog     Autonomous quadruped (Spot-style). Camera + IR sensor,
//                works in dark, hackable via terminal, EMP-vulnerable,
//                stuns on power outage.
//
// Dogs cannot open doors, hack devices, or use radios. They detect and
// bark/alarm  guards respond to the noise.

open Pixi

let absFloat = (x: float): float =>
  if x < 0.0 {
    -.x
  } else {
    x
  }

//  Dog Variant 

type dogVariant =
  | GuardDog // Biological  scent, food distraction, barks
  | RoboDog // Robotic  camera/IR, hackable, EMP-vulnerable

type dogState =
  | Patrolling // Following waypoint route
  | Tracking // Scent lock on player  following trail
  | Barking // Alerting guards (stationary, loud)
  | Distracted // Eating food / investigating thrown item
  | Investigating // Going to anomaly location
  | Returning // Heading back to patrol
  | Disabled // RoboDog: EMP'd, hacked, or power-downed
  | Stunned // Temporary incapacitation (both variants)

type facing = Left | Right

type waypoint = {
  x: float,
  pauseDurationSec: float,
}

//  Detection Model 

// GuardDog: scent-based detection (ignores walls, darkness, crouching)
// RoboDog: camera cone (similar to guards but with IR  works in dark)
type detectionModel = {
  scentRange: float, // GuardDog: scent detection radius (omnidirectional)
  cameraRange: float, // RoboDog: forward camera range
  cameraHalfAngle: float, // RoboDog: camera cone half-angle
  irRange: float, // RoboDog: infrared range (shorter, wider, works in dark)
  hearingRange: float, // Both: hearing (sprinting player is loud)
}

let guardDogDetection: detectionModel = {
  scentRange: 180.0, // Strong nose  wide radius
  cameraRange: 0.0, // No camera
  cameraHalfAngle: 0.0,
  irRange: 0.0,
  hearingRange: 200.0, // Good hearing
}

let roboDogDetection: detectionModel = {
  scentRange: 0.0, // No scent
  cameraRange: 200.0, // Forward camera
  cameraHalfAngle: 0.5, // ~28 degree half-angle
  irRange: 120.0, // IR shorter but omnidirectional
  hearingRange: 150.0, // Microphone array
}

//  Dog Entity 

type t = {
  id: string,
  variant: dogVariant,
  mutable state: dogState,
  mutable x: float,
  mutable y: float,
  mutable facing: facing,
  speed: float,
  // Patrol
  waypoints: array<waypoint>,
  mutable currentWaypoint: int,
  mutable pauseTimer: float,
  // Detection
  detection: detectionModel,
  mutable suspicion: float, // 0.0 to 1.0
  mutable lastScentX: option<float>,
  // GuardDog-specific
  mutable barkTimer: float, // Seconds spent barking
  mutable barkCooldown: float, // Cooldown between bark bursts
  mutable foodDistracted: bool, // Currently eating food?
  mutable distractionTimer: float, // Seconds left distracted
  // RoboDog-specific
  mutable hackProgress: float, // 0.0 to 1.0  hacking completion
  mutable hacked: bool, // Fully hacked  disabled or reprogrammed
  mutable empTimer: float, // Seconds of EMP stun remaining
  mutable batteryLevel: float, // 0.0 to 1.0  RoboDog power
  mutable chargingStationX: option<float>,
  // Handler (optional  GuardDog may follow a guard)
  mutable handlerId: option<string>,
  mutable handlerX: option<float>,
  // Graphics
  container: Container.t,
  bodyGraphic: Graphics.t,
  detectionGraphic: Graphics.t,
}

//  Construction 

let make = (
  ~id: string,
  ~variant: dogVariant,
  ~x: float,
  ~y: float,
  ~waypoints: array<waypoint>,
  ~handlerId: option<string>=?,
  ~chargingStationX: option<float>=?,
  (),
): t => {
  let container = Container.make()
  Container.setX(container, x)
  Container.setY(container, y)

  let bodyGraphic = Graphics.make()
  let detectionGraphic = Graphics.make()
  let _ = Container.addChildGraphics(container, detectionGraphic)
  let _ = Container.addChildGraphics(container, bodyGraphic)

  let speed = switch variant {
  | GuardDog => 75.0 // Fast  dogs are quick
  | RoboDog => 55.0 // Steady mechanical pace
  }

  {
    id,
    variant,
    state: Patrolling,
    x,
    y,
    facing: Right,
    speed,
    waypoints,
    currentWaypoint: 0,
    pauseTimer: 0.0,
    detection: switch variant {
    | GuardDog => guardDogDetection
    | RoboDog => roboDogDetection
    },
    suspicion: 0.0,
    lastScentX: None,
    barkTimer: 0.0,
    barkCooldown: 0.0,
    foodDistracted: false,
    distractionTimer: 0.0,
    hackProgress: 0.0,
    hacked: false,
    empTimer: 0.0,
    batteryLevel: 1.0,
    chargingStationX,
    handlerId,
    handlerX: None,
    container,
    bodyGraphic,
    detectionGraphic,
  }
}

//  Detection 

type detectionResult =
  | NotDetected
  | ScentDetected(float) // Scent strength 0-1 (GuardDog)
  | VisualDetected // Camera/IR lock (RoboDog)
  | HeardMovement // Both  sprinting player

let detectPlayer = (
  dog: t,
  ~playerX: float,
  ~playerY: float,
  ~playerCrouching: bool,
  ~playerSprinting: bool,
): detectionResult => {
  if dog.state == Disabled || dog.state == Stunned || dog.state == Distracted {
    NotDetected
  } else {
    let dx = playerX -. dog.x
    let dy = playerY -. dog.y
    let distance = Math.sqrt(dx *. dx +. dy *. dy)

    switch dog.variant {
    | GuardDog => // Scent detection  omnidirectional, ignores crouching/walls
      if distance < dog.detection.scentRange {
        let strength = 1.0 -. distance /. dog.detection.scentRange
        ScentDetected(strength)
      } else if playerSprinting && distance < dog.detection.hearingRange {
        HeardMovement
      } else {
        NotDetected
      }
    | RoboDog => {
        // Camera cone detection (like guards)
        let facingRight = dog.facing == Right
        let baseAngle = if facingRight {
          0.0
        } else {
          Math.Constants.pi
        }
        // SafeAngle.fromAtan2 guards against non-finite dy/dx inputs
        // (NaN/Infinity from degenerate positions would poison the entire
        // detection cone calculation).
        let targetAngle = SafeAngle.fromAtan2(~y=dy, ~x=dx)
        let angleDiff = absFloat(targetAngle -. baseAngle)
        let normalised = if angleDiff > Math.Constants.pi {
          2.0 *. Math.Constants.pi -. angleDiff
        } else {
          angleDiff
        }

        let effectiveRange = if playerCrouching {
          dog.detection.cameraRange *. 0.5
        } else {
          dog.detection.cameraRange
        }

        if normalised < dog.detection.cameraHalfAngle && distance < effectiveRange {
          VisualDetected
        } else if distance < dog.detection.irRange {
          // IR is omnidirectional but shorter range
          VisualDetected
        } else if playerSprinting && distance < dog.detection.hearingRange {
          HeardMovement
        } else {
          NotDetected
        }
      }
    }
  }
}

//  Patrol AI 

let updatePatrol = (dog: t, ~dt: float): unit => {
  // If handler is assigned, follow handler instead of waypoints
  switch dog.handlerX {
  | Some(hx) => {
      let dx = hx -. dog.x
      let dist = absFloat(dx)

      // Stay 30-50px behind handler
      if dist > 50.0 {
        let direction = if dx > 0.0 {
          1.0
        } else {
          -1.0
        }
        dog.x = dog.x +. direction *. dog.speed *. dt
        dog.facing = if dx > 0.0 {
          Right
        } else {
          Left
        }
      }
    }
  | None => // Standard waypoint patrol
    if Array.length(dog.waypoints) > 0 {
      switch dog.waypoints[dog.currentWaypoint] {
      | Some(wp) => {
          let dx = wp.x -. dog.x
          let dist = absFloat(dx)
          if dist < 5.0 {
            dog.pauseTimer = dog.pauseTimer +. dt
            if dog.pauseTimer >= wp.pauseDurationSec {
              dog.pauseTimer = 0.0
              dog.currentWaypoint = mod(dog.currentWaypoint + 1, Array.length(dog.waypoints))
            }
          } else {
            let direction = if dx > 0.0 {
              1.0
            } else {
              -1.0
            }
            dog.x = dog.x +. direction *. dog.speed *. dt
            dog.facing = if dx > 0.0 {
              Right
            } else {
              Left
            }
          }
        }
      | None => ()
      }
    }
  }
}

//  State Machine 

let updateState = (
  dog: t,
  ~dt: float,
  ~playerX: float,
  ~playerY: float,
  ~playerCrouching: bool,
  ~playerSprinting: bool,
): option<detectionResult> => {
  // RoboDog: handle EMP stun and battery (early exits)
  if dog.variant == RoboDog && dog.empTimer > 0.0 {
    dog.empTimer = dog.empTimer -. dt
    dog.state = Stunned
    if dog.empTimer <= 0.0 {
      dog.state = Returning
    }
    None
  } else if dog.variant == RoboDog && dog.hacked {
    dog.state = Disabled
    None
  } else if (
    dog.variant == RoboDog && {
        dog.batteryLevel = Math.max(0.0, dog.batteryLevel -. dt *. 0.002)
        dog.batteryLevel <= 0.0
      }
  ) {
    dog.state = Disabled
    None
  } else {
    switch dog.state {
    | Patrolling => {
        updatePatrol(dog, ~dt)
        let detection = detectPlayer(dog, ~playerX, ~playerY, ~playerCrouching, ~playerSprinting)
        switch detection {
        | ScentDetected(strength) if strength > 0.3 => {
            dog.lastScentX = Some(playerX)
            dog.state = Tracking
            dog.suspicion = strength
            Some(detection)
          }
        | VisualDetected => {
            dog.lastScentX = Some(playerX)
            dog.state = Barking
            dog.barkTimer = 0.0
            dog.suspicion = 1.0
            Some(detection)
          }
        | HeardMovement => {
            dog.lastScentX = Some(playerX)
            dog.state = Investigating
            dog.suspicion = 0.4
            Some(detection)
          }
        | _ => {
            dog.suspicion = Math.max(0.0, dog.suspicion -. dt *. 0.15)
            Some(NotDetected)
          }
        }
      }

    | Tracking => // Follow scent trail toward player
      switch dog.lastScentX {
      | Some(targetX) => {
          let dx = targetX -. dog.x
          let dist = absFloat(dx)
          if dist < 30.0 {
            // Close enough  start barking
            dog.state = Barking
            dog.barkTimer = 0.0
          } else {
            let direction = if dx > 0.0 {
              1.0
            } else {
              -1.0
            }
            dog.x = dog.x +. direction *. dog.speed *. 1.3 *. dt
            dog.facing = if dx > 0.0 {
              Right
            } else {
              Left
            }
          }
          // Update scent trail
          let detection = detectPlayer(dog, ~playerX, ~playerY, ~playerCrouching, ~playerSprinting)
          switch detection {
          | ScentDetected(_) | VisualDetected => dog.lastScentX = Some(playerX)
          | _ => ()
          }
          Some(detection)
        }
      | None => {
          dog.state = Returning
          Some(NotDetected)
        }
      }

    | Barking => {
        // Stay in place and bark  generates detection events each tick
        dog.barkTimer = dog.barkTimer +. dt
        let detection = detectPlayer(dog, ~playerX, ~playerY, ~playerCrouching, ~playerSprinting)
        // Update tracking position
        switch detection {
        | ScentDetected(_) | VisualDetected => dog.lastScentX = Some(playerX)
        | _ => ()
        }

        // After 4 seconds of barking, chase
        if dog.barkTimer >= 4.0 {
          dog.state = Tracking
          dog.barkCooldown = 6.0
        }
        Some(detection)
      }

    | Distracted => {
        // Eating food or investigating thrown item
        dog.distractionTimer = dog.distractionTimer -. dt
        if dog.distractionTimer <= 0.0 {
          dog.foodDistracted = false
          dog.state = Returning
        }
        Some(NotDetected)
      }

    | Investigating => switch dog.lastScentX {
      | Some(targetX) => {
          let dx = targetX -. dog.x
          let dist = absFloat(dx)
          if dist < 10.0 {
            dog.pauseTimer = dog.pauseTimer +. dt
            if dog.pauseTimer >= 2.5 {
              dog.pauseTimer = 0.0
              dog.state = Returning
              dog.lastScentX = None
            }
          } else {
            let direction = if dx > 0.0 {
              1.0
            } else {
              -1.0
            }
            dog.x = dog.x +. direction *. dog.speed *. dt
            dog.facing = if dx > 0.0 {
              Right
            } else {
              Left
            }
          }
          let detection = detectPlayer(dog, ~playerX, ~playerY, ~playerCrouching, ~playerSprinting)
          switch detection {
          | ScentDetected(s) if s > 0.4 => {
              dog.lastScentX = Some(playerX)
              dog.state = Tracking
            }
          | VisualDetected => {
              dog.lastScentX = Some(playerX)
              dog.state = Barking
              dog.barkTimer = 0.0
            }
          | _ => ()
          }
          Some(detection)
        }
      | None => {
          dog.state = Returning
          Some(NotDetected)
        }
      }

    | Returning => {
        if Array.length(dog.waypoints) > 0 {
          switch dog.waypoints[dog.currentWaypoint] {
          | Some(wp) => {
              let dx = wp.x -. dog.x
              let dist = absFloat(dx)
              if dist < 5.0 {
                dog.state = Patrolling
                dog.suspicion = 0.0
                dog.lastScentX = None
              } else {
                let direction = if dx > 0.0 {
                  1.0
                } else {
                  -1.0
                }
                dog.x = dog.x +. direction *. dog.speed *. dt
                dog.facing = if dx > 0.0 {
                  Right
                } else {
                  Left
                }
              }
            }
          | None => dog.state = Patrolling
          }
        } else {
          dog.state = Patrolling
        }
        Some(NotDetected)
      }

    | Disabled | Stunned => Some(NotDetected)
    }
  }
}

//  Distraction 

// Throw food to distract a guard dog. Returns true if successful.
let distractWithFood = (dog: t, ~foodX: float): bool => {
  if dog.variant == GuardDog && dog.state != Disabled && dog.state != Stunned {
    let dist = absFloat(foodX -. dog.x)
    if dist < dog.detection.scentRange {
      dog.state = Distracted
      dog.foodDistracted = true
      dog.distractionTimer = 15.0 // 15 seconds eating
      dog.lastScentX = Some(foodX)
      // Move toward food
      let direction = if foodX > dog.x {
        1.0
      } else {
        -1.0
      }
      dog.facing = if direction > 0.0 {
        Right
      } else {
        Left
      }
      true
    } else {
      false
    }
  } else {
    false
  }
}

// EMP a robodog
let applyEMP = (dog: t, ~duration: float): bool => {
  if dog.variant == RoboDog && dog.state != Disabled {
    dog.empTimer = duration
    dog.state = Stunned
    true
  } else {
    false
  }
}

// Start hacking a robodog (incremental  call each frame while hacking)
let hackTick = (dog: t, ~dt: float): bool => {
  if dog.variant == RoboDog && !dog.hacked {
    dog.hackProgress = dog.hackProgress +. dt *. 0.1 // ~10 seconds to hack
    if dog.hackProgress >= 1.0 {
      dog.hacked = true
      dog.state = Disabled
      true
    } else {
      false
    }
  } else {
    false
  }
}

//  Handler Sync 

// Call each frame to update handler position (if dog follows a guard)
let syncHandler = (dog: t, ~handlerX: float): unit => {
  dog.handlerX = Some(handlerX)
}

//  Distraction Response 

// Dogs can be pulled by distractions (PBX system sends these)
let respondToDistraction = (dog: t, ~distractionX: float, ~distractionRange: float): bool => {
  let dist = absFloat(distractionX -. dog.x)
  if dist < distractionRange && dog.state == Patrolling {
    dog.lastScentX = Some(distractionX)
    dog.state = Investigating
    true
  } else {
    false
  }
}

//  Graphics 

let renderDog = (dog: t): unit => {
  let _ = Graphics.clear(dog.bodyGraphic)
  let _ = Graphics.clear(dog.detectionGraphic)

  if dog.state == Disabled && dog.variant == RoboDog {
    // Disabled robodog  dark, powered down
    let _ =
      dog.bodyGraphic
      ->Graphics.rect(-15.0, -10.0, 30.0, 14.0)
      ->Graphics.fill({"color": 0x333333, "alpha": 0.4})
    Container.setX(dog.container, dog.x)
    Container.setAlpha(dog.container, 0.5)
  } else {
    Container.setAlpha(dog.container, 1.0)

    let bodyColor = switch (dog.variant, dog.state) {
    | (GuardDog, Barking) => 0xcc6633 // Agitated brown
    | (GuardDog, Tracking) => 0xaa5522
    | (GuardDog, Distracted) => 0x88aa44 // Happy green tint
    | (GuardDog, _) => 0x8b6914 // Brown
    | (RoboDog, Stunned) => 0x666666 // Grey  stunned
    | (RoboDog, Barking) => 0xff4444 // Red alert
    | (RoboDog, _) => 0x4488cc // Blue-steel
    }

    // Dog body  low rectangular shape
    let bodyW = switch dog.variant {
    | GuardDog => 28.0
    | RoboDog => 32.0
    }
    let bodyH = switch dog.variant {
    | GuardDog => 14.0
    | RoboDog => 16.0
    }
    let _ =
      dog.bodyGraphic
      ->Graphics.rect(-.bodyW /. 2.0, -.bodyH, bodyW, bodyH)
      ->Graphics.fill({"color": bodyColor})

    // Head
    let headX = if dog.facing == Right {
      bodyW /. 2.0 -. 2.0
    } else {
      -.bodyW /. 2.0 +. 2.0
    }
    let headSize = switch dog.variant {
    | GuardDog => 8.0
    | RoboDog => 10.0
    }
    let headColor = switch dog.variant {
    | GuardDog => 0x7a5a14
    | RoboDog => 0x3377aa
    }
    let _ =
      dog.bodyGraphic
      ->Graphics.rect(headX -. headSize /. 2.0, -.bodyH -. headSize +. 2.0, headSize, headSize)
      ->Graphics.fill({"color": headColor})

    // Eyes
    let eyeX = if dog.facing == Right {
      headX +. 2.0
    } else {
      headX -. 2.0
    }
    let eyeColor = switch (dog.variant, dog.state) {
    | (RoboDog, Stunned) => 0x444444
    | (RoboDog, _) => 0x00ff44 // Green LED
    | (GuardDog, Barking) => 0xff0000 // Red when barking
    | (GuardDog, _) => 0x332211
    }
    let _ =
      dog.bodyGraphic
      ->Graphics.circle(eyeX, -.bodyH -. headSize /. 2.0 +. 2.0, 2.0)
      ->Graphics.fill({"color": eyeColor})

    // Legs (4 short legs)
    let legColor = switch dog.variant {
    | GuardDog => 0x6a4a0a
    | RoboDog => 0x336699
    }
    let legW = 4.0
    let legH = 8.0
    let _ =
      dog.bodyGraphic
      ->Graphics.rect(-.bodyW /. 2.0 +. 2.0, 0.0, legW, legH)
      ->Graphics.fill({"color": legColor})
    let _ =
      dog.bodyGraphic
      ->Graphics.rect(-.bodyW /. 2.0 +. 10.0, 0.0, legW, legH)
      ->Graphics.fill({"color": legColor})
    let _ =
      dog.bodyGraphic
      ->Graphics.rect(bodyW /. 2.0 -. 14.0, 0.0, legW, legH)
      ->Graphics.fill({"color": legColor})
    let _ =
      dog.bodyGraphic
      ->Graphics.rect(bodyW /. 2.0 -. 6.0, 0.0, legW, legH)
      ->Graphics.fill({"color": legColor})

    // RoboDog antenna
    if dog.variant == RoboDog {
      let _ =
        dog.bodyGraphic
        ->Graphics.rect(-1.0, -.bodyH -. headSize -. 6.0, 2.0, 6.0)
        ->Graphics.fill({"color": 0x88aacc})
      // Antenna LED  blinks when tracking
      let ledColor = switch dog.state {
      | Tracking | Barking => 0xff0000
      | Stunned => 0x444444
      | _ => 0x00ff00
      }
      let _ =
        dog.bodyGraphic
        ->Graphics.circle(0.0, -.bodyH -. headSize -. 8.0, 2.0)
        ->Graphics.fill({"color": ledColor})
    }

    // Tail (GuardDog only  wagging when distracted)
    if dog.variant == GuardDog {
      let tailBaseX = if dog.facing == Right {
        -.bodyW /. 2.0
      } else {
        bodyW /. 2.0
      }
      let tailDir = if dog.facing == Right {
        -1.0
      } else {
        1.0
      }
      let _ =
        dog.bodyGraphic
        ->Graphics.moveTo(tailBaseX, -.bodyH +. 2.0)
        ->Graphics.lineTo(tailBaseX +. tailDir *. 10.0, -.bodyH -. 6.0)
        ->Graphics.stroke({"color": 0x7a5a14, "width": 2.0})
    }

    // Detection radius (scent = circle, camera = cone)
    let showDetection =
      dog.state == Patrolling || dog.state == Tracking || dog.state == Investigating
    if showDetection {
      switch dog.variant {
      | GuardDog => {
          // Scent radius  subtle circle
          let scentAlpha = switch dog.state {
          | Tracking => 0.08
          | _ => 0.04
          }
          let _ =
            dog.detectionGraphic
            ->Graphics.circle(0.0, -.bodyH /. 2.0, dog.detection.scentRange)
            ->Graphics.fill({"color": 0xffaa00, "alpha": scentAlpha})
        }
      | RoboDog => {
          // Camera cone
          let baseAngle = if dog.facing == Right {
            0.0
          } else {
            Math.Constants.pi
          }
          let startAngle = baseAngle -. dog.detection.cameraHalfAngle
          let endAngle = baseAngle +. dog.detection.cameraHalfAngle
          let coneColor = switch dog.state {
          | Tracking | Barking => 0xff0000
          | _ => 0x4488ff
          }
          let _ =
            dog.detectionGraphic
            ->Graphics.moveTo(0.0, -.bodyH /. 2.0)
            ->Graphics.lineTo(
              Math.cos(startAngle) *. dog.detection.cameraRange,
              -.bodyH /. 2.0 +. Math.sin(startAngle) *. dog.detection.cameraRange,
            )
            ->Graphics.lineTo(
              Math.cos(endAngle) *. dog.detection.cameraRange,
              -.bodyH /. 2.0 +. Math.sin(endAngle) *. dog.detection.cameraRange,
            )
            ->Graphics.lineTo(0.0, -.bodyH /. 2.0)
            ->Graphics.fill({"color": coneColor, "alpha": 0.08})
        }
      }
    }

    // Bark indicator (exclamation marks)
    if dog.state == Barking {
      let _ =
        dog.bodyGraphic
        ->Graphics.rect(-2.0, -.bodyH -. 30.0, 4.0, 12.0)
        ->Graphics.fill({"color": 0xff4444})
      let _ =
        dog.bodyGraphic
        ->Graphics.circle(0.0, -.bodyH -. 15.0, 2.5)
        ->Graphics.fill({"color": 0xff4444})
    }

    Container.setX(dog.container, dog.x)
  }
}

//  Per-Frame Update 

let update = (
  dog: t,
  ~dt: float,
  ~playerX: float,
  ~playerY: float,
  ~playerCrouching: bool,
  ~playerSprinting: bool,
): option<detectionResult> => {
  let result = updateState(dog, ~dt, ~playerX, ~playerY, ~playerCrouching, ~playerSprinting)

  // Bark cooldown
  if dog.barkCooldown > 0.0 {
    dog.barkCooldown = dog.barkCooldown -. dt
  }
  renderDog(dog)
  result
}

//  Queries 

let isBarking = (dog: t): bool => dog.state == Barking
let isDisabled = (dog: t): bool => dog.state == Disabled
let isDistracted = (dog: t): bool => dog.state == Distracted
let isTracking = (dog: t): bool => dog.state == Tracking

let stateToString = (dog: t): string => {
  switch dog.state {
  | Patrolling => "PATROLLING"
  | Tracking => "TRACKING"
  | Barking => "BARKING"
  | Distracted => "DISTRACTED"
  | Investigating => "INVESTIGATING"
  | Returning => "RETURNING"
  | Disabled => "DISABLED"
  | Stunned => "STUNNED"
  }
}

let variantToString = (variant: dogVariant): string => {
  switch variant {
  | GuardDog => "Guard Dog"
  | RoboDog => "RoboDog"
  }
}

let distanceTo = (dog: t, ~x: float): float => {
  absFloat(x -. dog.x)
}

//  Combat Hitboxes 

// Body hitbox using render dimensions (see renderDog)
let getBodyRect = (dog: t): Hitbox.rect => {
  let (bodyW, bodyH) = switch dog.variant {
  | GuardDog => (28.0, 14.0)
  | RoboDog => (32.0, 16.0)
  }
  // Body goes from (-.bodyW/2, -.bodyH) to (bodyW/2, 0) relative to dog position
  {
    x: dog.x -. bodyW /. 2.0,
    y: dog.y -. bodyH,
    w: bodyW,
    h: bodyH,
  }
}

// Head hitbox  front-facing rectangle approximating the head circle
let getHeadRect = (dog: t): Hitbox.rect => {
  let bodyW = switch dog.variant {
  | GuardDog => 28.0
  | RoboDog => 32.0
  }
  let bodyH = switch dog.variant {
  | GuardDog => 14.0
  | RoboDog => 16.0
  }
  let headSize = switch dog.variant {
  | GuardDog => 8.0
  | RoboDog => 10.0
  }
  let headX = if dog.facing == Right {
    bodyW /. 2.0 -. 2.0
  } else {
    -.bodyW /. 2.0 +. 2.0
  }
  {
    x: dog.x +. headX -. headSize /. 2.0,
    y: dog.y -. bodyH -. headSize +. 2.0,
    w: headSize,
    h: headSize,
  }
}

// Stomp on head  KO, flip to Disabled, hack-ready (RoboDog) or long stun (GuardDog)
let applyHeadStomp = (dog: t): unit => {
  dog.state = Disabled
  dog.suspicion = 0.0
}

// Stomp on body  stun for 3 seconds
let applyBodyStomp = (dog: t): unit => {
  dog.state = Stunned
  dog.empTimer = 3.0 // Reuse empTimer for stun duration
}

// Is this dog aggressively touching the player? (alert + not incapacitated)
let isAggressiveContact = (dog: t): bool => {
  switch dog.state {
  | Tracking | Barking => true
  | _ => false
  }
}
