// SPDX-License-Identifier: PMPL-1.0-or-later
// Drone  aerial surveillance and pursuit drones
//
// Drones patrol at a higher Y position (above ground level). They have:
//   - Wide top-down camera FOV (circular detection zone below)
//   - Limited battery (must return to charging pad)
//   - Audible  player can hear them approaching
//   - Hackable, jammable, EMP-vulnerable
//   - Spotlight mode on high alert (visible beam, tight tracking)
//
// Types:
//   Recon        Standard patrol drone. Camera only, quiet.
//   Pursuit      Faster, louder, spotlight, follows player.
//   EMP_Drone    Carries single-use EMP payload. Disables player terminal.

open Pixi

let absFloat = (x: float): float =>
  if x < 0.0 {
    -.x
  } else {
    x
  }

//  Drone Variant 

type droneVariant =
  | Recon // Standard patrol  quiet, wide FOV, passive
  | Pursuit // Fast, spotlight, tracks player, noisy
  | EMP_Drone // Carries EMP payload  disables player electronics

type droneState =
  | Patrolling // Standard patrol route
  | Hovering // Stationary observation (over anomaly)
  | Tracking // Actively following player
  | Spotlighting // Pursuit: locked on, bright spotlight
  | Returning // Going to charging pad
  | Charging // On pad, recharging battery
  | Jammed // Signal jammed  erratic movement
  | Disabled // EMP'd, hacked, or crashed
  | Delivering // EMP_Drone: diving to deliver payload
  // Helper drone states
  | Rescuing // Hovering over trap, lifting guard/dog out (very slow)
  | Repairing // Hovering over disabled device, restoring function
  | Reviving // Hovering over knocked-out guard/dog, reviving
  | OpeningDoor // Hovering at external door, unlocking mechanism

type facing = Left | Right

type waypoint = {
  x: float,
  hoverDurationSec: float,
}

//  Drone Entity 

type t = {
  id: string,
  variant: droneVariant,
  mutable state: droneState,
  mutable x: float,
  mutable y: float, // Drones fly above ground  typically y = 350-400
  groundY: float, // Reference ground level (for detection zone calc)
  mutable facing: facing,
  speed: float,
  // Patrol
  waypoints: array<waypoint>,
  mutable currentWaypoint: int,
  mutable hoverTimer: float,
  // Detection  top-down cone projected onto ground
  detectionRadius: float, // Radius of detection circle on ground
  mutable suspicion: float,
  mutable lastKnownPlayerX: option<float>,
  // Battery
  mutable battery: float, // 0.0 to 1.0
  mutable batteryDrainRate: float, // Per second
  mutable chargeRate: float, // Per second while charging
  chargingPadX: float,
  lowBatteryThreshold: float,
  // Spotlight (Pursuit only)
  mutable spotlightActive: bool,
  mutable spotlightIntensity: float, // 0.0 to 1.0
  // EMP payload (EMP_Drone only)
  mutable empPayloadAvailable: bool,
  mutable empDeliveryTimer: float,
  // Hackable
  mutable hackProgress: float,
  mutable hacked: bool,
  mutable jamTimer: float,
  // Helper drone task progress (shared timer for rescue/repair/revive/door)
  mutable helperTaskTimer: float, // Countdown for current helper action
  mutable helperTaskTarget: option<string>, // ID of entity being helped
  // Noise
  noiseRadius: float, // How far player can "hear" the drone
  // Graphics
  container: Container.t,
  bodyGraphic: Graphics.t,
  detectionGraphic: Graphics.t,
  spotlightGraphic: Graphics.t,
}

//  Construction 

let make = (
  ~id: string,
  ~variant: droneVariant,
  ~x: float,
  ~y: float,
  ~groundY: float,
  ~waypoints: array<waypoint>,
  ~chargingPadX: float,
  (),
): t => {
  let container = Container.make()
  Container.setX(container, x)
  Container.setY(container, y)

  let bodyGraphic = Graphics.make()
  let detectionGraphic = Graphics.make()
  let spotlightGraphic = Graphics.make()
  let _ = Container.addChildGraphics(container, detectionGraphic)
  let _ = Container.addChildGraphics(container, spotlightGraphic)
  let _ = Container.addChildGraphics(container, bodyGraphic)

  let (speed, detRadius, noise, drain) = switch variant {
  | Recon => (60.0, 120.0, 100.0, 0.008) // Slow, wide FOV, quiet
  | Pursuit => (100.0, 80.0, 180.0, 0.015) // Fast, narrow, loud
  | EMP_Drone => (35.0, 100.0, 80.0, 0.012) // Helper: very slow, quiet, medium FOV
  }

  {
    id,
    variant,
    state: Patrolling,
    x,
    y,
    groundY,
    facing: Right,
    speed,
    waypoints,
    currentWaypoint: 0,
    hoverTimer: 0.0,
    detectionRadius: detRadius,
    suspicion: 0.0,
    lastKnownPlayerX: None,
    battery: 1.0,
    batteryDrainRate: drain,
    chargeRate: 0.05,
    chargingPadX,
    lowBatteryThreshold: 0.15,
    spotlightActive: false,
    spotlightIntensity: 0.0,
    empPayloadAvailable: variant == EMP_Drone,
    empDeliveryTimer: 0.0,
    hackProgress: 0.0,
    hacked: false,
    jamTimer: 0.0,
    helperTaskTimer: 0.0,
    helperTaskTarget: None,
    noiseRadius: noise,
    container,
    bodyGraphic,
    detectionGraphic,
    spotlightGraphic,
  }
}

//  Detection 

type detectionResult =
  | NotDetected
  | InDetectionZone(float) // Player in camera zone, proximity 0-1
  | SpotlightLock // Pursuit drone has spotlight on player

let detectPlayer = (
  drone: t,
  ~playerX: float,
  ~playerY: float,
  ~playerCrouching: bool,
): detectionResult => {
  if drone.state == Disabled || drone.state == Charging || drone.state == Jammed {
    NotDetected
  } else {
    // Detection is projected onto ground  circular zone below drone
    let dx = playerX -. drone.x
    // Y difference between drone altitude and player on ground
    let dy = playerY -. drone.groundY
    let groundDist = Math.sqrt(dx *. dx +. dy *. dy)

    let effectiveRadius = if playerCrouching {
      drone.detectionRadius *. 0.6 // Harder to spot crouching from above
    } else {
      drone.detectionRadius
    }

    if groundDist < effectiveRadius {
      let proximity = 1.0 -. groundDist /. effectiveRadius
      if drone.spotlightActive && proximity > 0.3 {
        SpotlightLock
      } else {
        InDetectionZone(proximity)
      }
    } else {
      NotDetected
    }
  }
}

//  Movement 

let moveToward = (drone: t, ~targetX: float, ~dt: float, ~speedMult: float): bool => {
  let dx = targetX -. drone.x
  let dist = absFloat(dx)
  if dist < 5.0 {
    true // Arrived
  } else {
    let direction = if dx > 0.0 {
      1.0
    } else {
      -1.0
    }
    drone.x = drone.x +. direction *. drone.speed *. speedMult *. dt
    drone.facing = if dx > 0.0 {
      Right
    } else {
      Left
    }
    false
  }
}

//  State Machine 

let updateState = (
  drone: t,
  ~dt: float,
  ~playerX: float,
  ~playerY: float,
  ~playerCrouching: bool,
  ~alertLevel: int,
): option<detectionResult> => {
  // Handle disabled/hacked (early exits)
  if drone.hacked {
    drone.state = Disabled
    None
  } else if drone.jamTimer > 0.0 {
    // Handle jam
    drone.jamTimer = drone.jamTimer -. dt
    drone.state = Jammed

    // Erratic jitter
    drone.x = drone.x +. (Math.random() *. 4.0 -. 2.0) *. dt *. 50.0
    if drone.jamTimer <= 0.0 {
      drone.state = Returning
    }
    Some(NotDetected)
  } else if (
    drone.state != Charging &&
    drone.state != Disabled && {
      drone.battery = Math.max(0.0, drone.battery -. drone.batteryDrainRate *. dt)
      drone.battery <= 0.0
    }
  ) {
    // Battery dead
    drone.state = Disabled
    None
  } else {
    // Battery low  trigger return
    if (
      drone.state != Charging &&
      drone.state != Disabled &&
      drone.battery <= drone.lowBatteryThreshold &&
      drone.state != Returning
    ) {
      drone.state = Returning
    }

    switch drone.state {
    | Patrolling => {
        if Array.length(drone.waypoints) > 0 {
          switch drone.waypoints[drone.currentWaypoint] {
          | Some(wp) => {
              let arrived = moveToward(drone, ~targetX=wp.x, ~dt, ~speedMult=1.0)
              if arrived {
                drone.hoverTimer = drone.hoverTimer +. dt
                if drone.hoverTimer >= wp.hoverDurationSec {
                  drone.hoverTimer = 0.0
                  drone.currentWaypoint = mod(
                    drone.currentWaypoint + 1,
                    Array.length(drone.waypoints),
                  )
                }
              }
            }
          | None => ()
          }
        }

        let detection = detectPlayer(drone, ~playerX, ~playerY, ~playerCrouching)
        switch detection {
        | InDetectionZone(proximity) if proximity > 0.4 => {
            drone.lastKnownPlayerX = Some(playerX)
            drone.suspicion = proximity

            // On high alert, immediately switch to tracking
            if alertLevel >= 3 || drone.variant == Pursuit {
              drone.state = Tracking
            } else {
              drone.state = Hovering
              drone.hoverTimer = 0.0
            }
          }
        | _ => drone.suspicion = Math.max(0.0, drone.suspicion -. dt *. 0.1)
        }
        Some(detection)
      }

    | Hovering => {
        // Stay in place, observe
        drone.hoverTimer = drone.hoverTimer +. dt
        let detection = detectPlayer(drone, ~playerX, ~playerY, ~playerCrouching)
        switch detection {
        | InDetectionZone(proximity) if proximity > 0.3 => {
            drone.lastKnownPlayerX = Some(playerX)
            drone.suspicion = Math.min(1.0, drone.suspicion +. dt *. 0.3)
            if drone.suspicion > 0.7 {
              drone.state = Tracking
            }
          }
        | SpotlightLock => {
            drone.lastKnownPlayerX = Some(playerX)
            drone.state = Tracking
          }
        | _ => if drone.hoverTimer >= 5.0 {
            drone.state = Patrolling
            drone.hoverTimer = 0.0
            drone.suspicion = 0.0
          }
        }
        Some(detection)
      }

    | Tracking => // Follow player
      switch drone.lastKnownPlayerX {
      | Some(targetX) => {
          let _ = moveToward(drone, ~targetX, ~dt, ~speedMult=1.5)
          let detection = detectPlayer(drone, ~playerX, ~playerY, ~playerCrouching)
          switch detection {
          | InDetectionZone(_) | SpotlightLock => {
              drone.lastKnownPlayerX = Some(playerX)

              // Pursuit drones activate spotlight
              if drone.variant == Pursuit && alertLevel >= 2 {
                drone.spotlightActive = true
                drone.spotlightIntensity = Math.min(1.0, drone.spotlightIntensity +. dt *. 0.5)
                drone.state = Spotlighting
              }

              // EMP drone delivers payload
              if drone.variant == EMP_Drone && drone.empPayloadAvailable {
                let dist = absFloat(playerX -. drone.x)
                if dist < 40.0 {
                  drone.state = Delivering
                  drone.empDeliveryTimer = 0.0
                }
              }
            }
          | NotDetected => {
              // Lost visual  hover and search
              drone.hoverTimer = drone.hoverTimer +. dt
              if drone.hoverTimer >= 8.0 {
                drone.state = Patrolling
                drone.hoverTimer = 0.0
                drone.lastKnownPlayerX = None
                drone.spotlightActive = false
                drone.spotlightIntensity = 0.0
              }
            }
          }
          Some(detection)
        }
      | None => {
          drone.state = Patrolling
          Some(NotDetected)
        }
      }

    | Spotlighting => // Pursuit drone  locked on with spotlight
      switch drone.lastKnownPlayerX {
      | Some(targetX) => {
          let _ = moveToward(drone, ~targetX, ~dt, ~speedMult=1.8)
          let detection = detectPlayer(drone, ~playerX, ~playerY, ~playerCrouching)
          switch detection {
          | InDetectionZone(_) | SpotlightLock => {
              drone.lastKnownPlayerX = Some(playerX)
              drone.spotlightIntensity = 1.0
            }
          | NotDetected => {
              drone.spotlightIntensity = Math.max(0.0, drone.spotlightIntensity -. dt *. 0.3)
              if drone.spotlightIntensity <= 0.0 {
                drone.spotlightActive = false
                drone.state = Tracking
              }
            }
          }
          Some(detection)
        }
      | None => {
          drone.spotlightActive = false
          drone.spotlightIntensity = 0.0
          drone.state = Patrolling
          Some(NotDetected)
        }
      }

    | Delivering => {
        // EMP_Drone diving to deploy EMP
        drone.empDeliveryTimer = drone.empDeliveryTimer +. dt

        // Dive animation (Y decreases toward ground)
        drone.y = drone.y +. dt *. 80.0 // Move toward ground
        if drone.empDeliveryTimer >= 1.5 {
          // EMP delivered
          drone.empPayloadAvailable = false
          drone.y = drone.groundY -. 150.0 // Return to flight altitude
          drone.state = Returning
        }
        Some(InDetectionZone(1.0))
      }

    | Returning => {
        let arrived = moveToward(drone, ~targetX=drone.chargingPadX, ~dt, ~speedMult=1.2)
        if arrived {
          drone.state = Charging
          drone.spotlightActive = false
          drone.spotlightIntensity = 0.0
        }
        Some(NotDetected)
      }

    | Charging => {
        drone.battery = Math.min(1.0, drone.battery +. drone.chargeRate *. dt)
        if drone.battery >= 0.95 {
          drone.state = Patrolling
        }
        Some(NotDetected)
      }

    // ── Helper drone task states ──
    // All follow the same pattern: fly to target, then work for duration.
    // Helper drones move very slowly (35px/s base speed).
    | Rescuing | Repairing | Reviving | OpeningDoor => {
        switch drone.lastKnownPlayerX {
        | Some(targetX) => {
            let arrived = moveToward(drone, ~targetX, ~dt, ~speedMult=0.8) // Extra slow for precision
            if arrived {
              // Count down the task timer
              drone.helperTaskTimer = drone.helperTaskTimer -. dt
              if drone.helperTaskTimer <= 0.0 {
                // Task complete — return to patrol
                drone.helperTaskTarget = None
                drone.state = Patrolling
              }
            }
          }
        | None => {
            // No target — abort and resume patrol
            drone.helperTaskTarget = None
            drone.state = Patrolling
          }
        }
        Some(NotDetected)
      }

    | Jammed | Disabled => Some(NotDetected)
    }
  }
}

//  Interactions 

let applyEMP = (drone: t, ~duration: float): bool => {
  if drone.state != Disabled {
    drone.jamTimer = duration
    drone.state = Jammed
    true
  } else {
    false
  }
}

let hackTick = (drone: t, ~dt: float): bool => {
  if !drone.hacked {
    drone.hackProgress = drone.hackProgress +. dt *. 0.08 // ~12.5 seconds
    if drone.hackProgress >= 1.0 {
      drone.hacked = true
      drone.state = Disabled
      true
    } else {
      false
    }
  } else {
    false
  }
}

let jam = (drone: t, ~duration: float): unit => {
  drone.jamTimer = duration
  drone.state = Jammed
}

// Check if player can hear this drone
let isAudibleTo = (drone: t, ~playerX: float): bool => {
  if drone.state == Disabled || drone.state == Charging {
    false
  } else {
    absFloat(playerX -. drone.x) < drone.noiseRadius
  }
}

// ── Helper Drone Actions ──
// These are called by the game loop when the helper drone detects something
// it can assist with. Helper drones move very slowly (35px/s).

// Duration constants for helper actions (seconds)
let rescueDuration = 8.0 // Lifting guard/dog from pitfall trap (very slow, awkward hover)
let repairDuration = 6.0 // Repairing disabled drone or robodog
let reviveDuration = 4.0 // Reviving knocked-out guard or dog
let doorOpenDuration = 3.0 // Unlocking an external door mechanism

// Order helper to rescue a trapped entity (guard/dog in pitfall)
let orderRescue = (drone: t, ~targetX: float, ~targetId: string): bool => {
  if drone.variant == EMP_Drone && drone.state == Patrolling || drone.state == Hovering {
    drone.lastKnownPlayerX = Some(targetX)
    drone.helperTaskTarget = Some(targetId)
    drone.helperTaskTimer = rescueDuration
    drone.state = Rescuing
    true
  } else {
    false
  }
}

// Order helper to repair a disabled electronic device
let orderRepair = (drone: t, ~targetX: float, ~targetId: string): bool => {
  if drone.variant == EMP_Drone && drone.state == Patrolling || drone.state == Hovering {
    drone.lastKnownPlayerX = Some(targetX)
    drone.helperTaskTarget = Some(targetId)
    drone.helperTaskTimer = repairDuration
    drone.state = Repairing
    true
  } else {
    false
  }
}

// Order helper to revive a knocked-out guard or dog
let orderRevive = (drone: t, ~targetX: float, ~targetId: string): bool => {
  if drone.variant == EMP_Drone && drone.state == Patrolling || drone.state == Hovering {
    drone.lastKnownPlayerX = Some(targetX)
    drone.helperTaskTarget = Some(targetId)
    drone.helperTaskTimer = reviveDuration
    drone.state = Reviving
    true
  } else {
    false
  }
}

// Order helper to open an external door
let orderOpenDoor = (drone: t, ~targetX: float, ~doorId: string): bool => {
  if drone.variant == EMP_Drone && drone.state == Patrolling || drone.state == Hovering {
    drone.lastKnownPlayerX = Some(targetX)
    drone.helperTaskTarget = Some(doorId)
    drone.helperTaskTimer = doorOpenDuration
    drone.state = OpeningDoor
    true
  } else {
    false
  }
}

// Check if helper drone is busy with a task
let isHelperBusy = (drone: t): bool => {
  drone.state == Rescuing ||
  drone.state == Repairing ||
  drone.state == Reviving ||
  drone.state == OpeningDoor
}

// Distractions pull drones to investigate
let respondToDistraction = (drone: t, ~distractionX: float, ~distractionRange: float): bool => {
  let dist = absFloat(distractionX -. drone.x)
  if dist < distractionRange && (drone.state == Patrolling || drone.state == Hovering) {
    drone.lastKnownPlayerX = Some(distractionX)
    drone.state = Tracking
    true
  } else {
    false
  }
}

//  Graphics 

let renderDrone = (drone: t): unit => {
  let _ = Graphics.clear(drone.bodyGraphic)
  let _ = Graphics.clear(drone.detectionGraphic)
  let _ = Graphics.clear(drone.spotlightGraphic)

  if drone.state == Disabled {
    let _ =
      drone.bodyGraphic
      ->Graphics.rect(-10.0, -6.0, 20.0, 12.0)
      ->Graphics.fill({"color": 0x444444, "alpha": 0.3})
    Container.setX(drone.container, drone.x)
    Container.setY(drone.container, drone.y)
    Container.setAlpha(drone.container, 0.4)
  } else {
    Container.setAlpha(drone.container, 1.0)

    let bodyColor = switch (drone.variant, drone.state) {
    | (Recon, Tracking) => 0xffaa00
    | (Recon, _) => 0x66aa88
    | (Pursuit, Spotlighting) => 0xff2222
    | (Pursuit, Tracking) => 0xff6644
    | (Pursuit, _) => 0xcc4444
    | (EMP_Drone, Delivering) => 0xff00ff
    | (EMP_Drone, Rescuing) => 0x44ffaa // Green glow when rescuing
    | (EMP_Drone, Repairing) => 0x44aaff // Blue glow when repairing
    | (EMP_Drone, Reviving) => 0xffff44 // Yellow glow when reviving
    | (EMP_Drone, OpeningDoor) => 0xff8844 // Orange glow when opening door
    | (EMP_Drone, _) => 0x8844cc
    }

    // Central body  compact diamond/hexagonal shape
    let hw = switch drone.variant {
    | Recon => 10.0
    | Pursuit => 12.0
    | EMP_Drone => 11.0
    }
    let _ =
      drone.bodyGraphic
      ->Graphics.moveTo(0.0, -.hw)
      ->Graphics.lineTo(hw, 0.0)
      ->Graphics.lineTo(0.0, hw *. 0.6)
      ->Graphics.lineTo(-.hw, 0.0)
      ->Graphics.lineTo(0.0, -.hw)
      ->Graphics.fill({"color": bodyColor})

    // Rotor arms (4 arms extending from center)
    let armLen = hw +. 8.0
    let rotorColor = switch drone.state {
    | Jammed => 0xff0000
    | Charging => 0x00ff00
    | _ => 0x888888
    }
    // Top-left, top-right, bottom-left, bottom-right
    let arms = [(-1.0, -1.0), (1.0, -1.0), (-1.0, 0.6), (1.0, 0.6)]
    arms->Array.forEach(((dirX, dirY)) => {
      let endX = dirX *. armLen
      let endY = dirY *. armLen *. 0.5
      let _ =
        drone.bodyGraphic
        ->Graphics.moveTo(0.0, 0.0)
        ->Graphics.lineTo(endX, endY)
        ->Graphics.stroke({"color": 0x666666, "width": 1.5})
      // Rotor disc
      let _ =
        drone.bodyGraphic
        ->Graphics.circle(endX, endY, 5.0)
        ->Graphics.fill({"color": rotorColor, "alpha": 0.4})
    })

    // Camera eye (center bottom)
    let cameraColor = switch drone.state {
    | Tracking | Spotlighting => 0xff0000
    | Hovering => 0xffaa00
    | Jammed => 0xff00ff
    | _ => 0x00ccff
    }
    let _ =
      drone.bodyGraphic
      ->Graphics.circle(0.0, hw *. 0.3, 3.0)
      ->Graphics.fill({"color": cameraColor})

    // EMP payload indicator
    if drone.variant == EMP_Drone && drone.empPayloadAvailable {
      let _ =
        drone.bodyGraphic
        ->Graphics.circle(0.0, hw *. 0.6 +. 4.0, 4.0)
        ->Graphics.fill({"color": 0xff00ff, "alpha": 0.7})
    }

    // Battery indicator (small bar above drone)
    let barW = 16.0
    let barH = 2.0
    let _ =
      drone.bodyGraphic
      ->Graphics.rect(-.barW /. 2.0, -.hw -. 6.0, barW, barH)
      ->Graphics.fill({"color": 0x333333})
    let batColor = if drone.battery > 0.5 {
      0x00ff00
    } else if drone.battery > 0.2 {
      0xffaa00
    } else {
      0xff0000
    }
    let _ =
      drone.bodyGraphic
      ->Graphics.rect(-.barW /. 2.0, -.hw -. 6.0, barW *. drone.battery, barH)
      ->Graphics.fill({"color": batColor})

    // Detection zone on ground (projected circle)
    let showZone =
      drone.state == Patrolling ||
      drone.state == Hovering ||
      drone.state == Tracking ||
      drone.state == Spotlighting
    if showZone {
      // The detection zone is below the drone, on the ground
      let zoneY = drone.groundY -. drone.y // Offset from drone to ground
      let zoneAlpha = switch drone.state {
      | Tracking | Spotlighting => 0.12
      | Hovering => 0.08
      | _ => 0.04
      }
      let zoneColor = switch drone.state {
      | Tracking | Spotlighting => 0xff4444
      | Hovering => 0xffaa00
      | _ => 0x44aaff
      }
      let _ =
        drone.detectionGraphic
        ->Graphics.circle(0.0, zoneY, drone.detectionRadius)
        ->Graphics.fill({"color": zoneColor, "alpha": zoneAlpha})
    }

    // Spotlight beam (Pursuit only)
    if drone.spotlightActive && drone.spotlightIntensity > 0.0 {
      let beamY = drone.groundY -. drone.y
      let beamW = 15.0 *. drone.spotlightIntensity
      let _ =
        drone.spotlightGraphic
        ->Graphics.moveTo(0.0, 0.0)
        ->Graphics.lineTo(-.beamW, beamY)
        ->Graphics.lineTo(beamW, beamY)
        ->Graphics.lineTo(0.0, 0.0)
        ->Graphics.fill({"color": 0xffffcc, "alpha": 0.15 *. drone.spotlightIntensity})
      // Ground circle
      let _ =
        drone.spotlightGraphic
        ->Graphics.circle(0.0, beamY, beamW *. 1.5)
        ->Graphics.fill({"color": 0xffffcc, "alpha": 0.2 *. drone.spotlightIntensity})
    }

    Container.setX(drone.container, drone.x)
    Container.setY(drone.container, drone.y)
  }
}

//  Per-Frame Update 

let update = (
  drone: t,
  ~dt: float,
  ~playerX: float,
  ~playerY: float,
  ~playerCrouching: bool,
  ~alertLevel: int,
): option<detectionResult> => {
  let result = updateState(drone, ~dt, ~playerX, ~playerY, ~playerCrouching, ~alertLevel)
  renderDrone(drone)
  result
}

//  Queries 

let isActive = (drone: t): bool =>
  drone.state != Disabled && drone.state != Charging

let isSpotlighting = (drone: t): bool => drone.spotlightActive

let hasEMPPayload = (drone: t): bool => drone.variant == EMP_Drone && drone.empPayloadAvailable

let stateToString = (drone: t): string => {
  switch drone.state {
  | Patrolling => "PATROLLING"
  | Hovering => "HOVERING"
  | Tracking => "TRACKING"
  | Spotlighting => "SPOTLIGHT"
  | Returning => "RTB"
  | Charging => "CHARGING"
  | Jammed => "JAMMED"
  | Disabled => "DISABLED"
  | Delivering => "EMP DELIVERY"
  | Rescuing => "RESCUING"
  | Repairing => "REPAIRING"
  | Reviving => "REVIVING"
  | OpeningDoor => "OPENING DOOR"
  }
}

let variantToString = (variant: droneVariant): string => {
  switch variant {
  | Recon => "Recon Drone"
  | Pursuit => "Pursuit Drone"
  | EMP_Drone => "EMP Drone"
  }
}

let distanceTo = (drone: t, ~x: float): float => {
  absFloat(x -. drone.x)
}
