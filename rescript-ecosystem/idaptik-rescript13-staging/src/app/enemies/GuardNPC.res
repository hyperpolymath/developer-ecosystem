// SPDX-License-Identifier: PMPL-1.0-or-later
// Guard NPC  full enemy hierarchy with distinct AI behaviours
//
// ADR-0004: Static patrols for basic guards, heat map AI for elites.
// ADR-0013: Anti-hacker specialists are the ONLY entities that can reverse
//           hacking. They are cowardly and panic-prone  they can flee
//           mid-reversal, abandoning the undo process.
//
// Guard hierarchy (weakest  strongest):
//   BasicGuard       Dumb, predictable patrol, easily avoided
//   SecurityGuard    Competent, radio comms, calls for backup
//   AntiHacker       Reverse-hack specialist. Cowardly, panics, flees
//   Sentinel         Stationary with wide detection cone
//   EliteGuard       Adaptive heat-map AI, fast, dangerous
//   SecurityChief    Boss. Commands others, tough, rare
//   RivalHacker      NPC competitor trying to beat you to the objective
//   Assassin         Mysterious killer. Appears from nowhere. Deadly.
//                     Not part of security. Spawns on harder levels when
//                     the "real threat" catches on to the player.

open Pixi

let absFloat = (x: float): float =>
  if x < 0.0 {
    -.x
  } else {
    x
  }

//  Guard Types 

type guardRank =
  | BasicGuard // Dumb patrol, slow, easily avoided
  | SecurityGuard // Competent, radio comms, calls for backup
  | AntiHacker // ONLY entity that can reverse hacking; cowardly
  | Sentinel // Stationary, wide detection cone
  | EliteGuard // Adaptive heat-map AI, fast, dangerous
  | SecurityChief // Boss  commands others, tough, rare
  | RivalHacker // Competitor  races to complete objectives
  | Assassin // Mysterious killer  appears from nowhere, deadly

type guardState =
  | Patrolling // Following waypoint route
  | Investigating // Heading to anomaly location
  | Alerted // Chasing player / calling backup
  | Returning // Going back to patrol route
  | Stationary // Standing guard (Sentinel)
  | ReverseHacking // AntiHacker actively undoing VM changes
  | Panicking // AntiHacker spooked  erratic movement
  | Fleeing // AntiHacker running away scared
  | CallingBackup // SecurityGuard/AntiHacker radioing for help
  | Commanding // SecurityChief directing other guards
  | Hacking // RivalHacker working on a device
  | Sabotaging // RivalHacker interfering with player's work
  | Racing // RivalHacker moving to next objective
  | Hiding // Assassin concealed  invisible to player
  | Ambushing // Assassin striking from concealment
  | Stalking // Assassin repositioning after failed ambush
  | SettingTrap // Assassin placing a trap device
  | KnockedDown // Knocked over by player stomp/charge

type facing = Left | Right

// Waypoint for patrol route
type waypoint = {
  x: float,
  pauseDurationSec: float, // How long to wait at this waypoint
}

// Vision cone parameters
type visionCone = {
  range: float, // Detection distance in pixels
  halfAngle: float, // Half-angle of cone in radians
  behindRange: float, // Short detection range behind guard (hearing)
}

//  Anti-Hacker Psychology 

// Anti-hackers are specialists but cowards. When threatened, they
// abandon whatever they're doing (even mid-reversal) and flee.

type panicTrigger =
  | PlayerTooClose // Player within 120px
  | AlertLevelHigh // Alert  DANGER (allies losing control)
  | BackupNotArriving // Called for backup but nobody came (8s)
  | DeviceExploded // KillSwitch or TimeBomb went off nearby
  | CaughtByPlayer // Player directly interacted with them

type antiHackerPsych = {
  mutable courage: float, // 0.0 (total coward) to 1.0 (brave). Starts low.
  mutable panicThreshold: float, // Courage below this  panic
  mutable panicTimer: float, // Seconds of erratic movement before fleeing
  mutable fleeSpeed: float, // How fast they run (faster than patrol!)
  mutable backupCallTimer: float, // Seconds since calling for backup
  mutable backupArrived: bool, // Has a guard come to protect them?
  mutable reverseTarget: option<string>, // Device ID being reverse-hacked
  mutable undosCompleted: int, // How many undos done on current target
  mutable undosRemaining: int, // How many left to do
  mutable undoCooldown: float, // Timer between undo operations
  mutable undoSpeed: float, // Seconds per undo operation
  mutable lastPanicTrigger: option<panicTrigger>,
}

let makeAntiHackerPsych = (): antiHackerPsych => {
  courage: 0.3, // Low baseline courage
  panicThreshold: 0.25,
  panicTimer: 0.0,
  fleeSpeed: 120.0, // Faster than patrol speed!
  backupCallTimer: 0.0,
  backupArrived: false,
  reverseTarget: None,
  undosCompleted: 0,
  undosRemaining: 0,
  undoCooldown: 0.0,
  undoSpeed: 2.5, // Slower than old SENTRY  they're careful
  lastPanicTrigger: None,
}

//  Rival Hacker AI 

// The rival hacker is not trying to catch you  they're trying to
// beat you to the objective. They sabotage your work to slow you
// down and race ahead.

type rivalObjective =
  | SeekDevice(string) // Moving to a specific device
  | HackDevice(string) // Working on a device
  | SabotageDevice(string) // Undoing player's work or locking device
  | Exfiltrate // Heading for exit (they think they've won)
  | Lurking // Waiting, watching for opportunity

type rivalHackerAI = {
  mutable currentObjective: rivalObjective,
  mutable objectivesCompleted: int, // Track rival's progress
  mutable totalObjectives: int, // How many they need
  mutable hackSpeed: float, // Seconds per hack operation
  mutable hackTimer: float,
  mutable sabotageChance: float, // 0.0-1.0 chance to sabotage vs. race
  mutable awareness: float, // How aware of player (0-1)
  mutable deviceQueue: array<string>, // Ordered list of target devices
  mutable devicesCompleted: array<string>,
}

let makeRivalHackerAI = (): rivalHackerAI => {
  currentObjective: Lurking,
  objectivesCompleted: 0,
  totalObjectives: 3,
  hackSpeed: 4.0, // Slower than player (fair)
  hackTimer: 0.0,
  sabotageChance: 0.3, // 30% chance to sabotage when detecting player work
  awareness: 0.0,
  deviceQueue: [],
  devicesCompleted: [],
}

//  SecurityChief Command 

type chiefCommand =
  | HoldPosition // Stay at your post
  | InvestigateArea(float) // Go check this X position
  | ProtectAntiHacker(string) // Guard this anti-hacker's ID
  | Converge(float) // Everyone converge on this position
  | Retreat // Fall back to safe positions

type chiefAI = {
  mutable commandCooldown: float, // Seconds between commands
  mutable lastCommand: option<chiefCommand>,
  mutable subordinateIds: array<string>, // Guards under command
  mutable commandRadius: float, // Range of command influence
}

let makeChiefAI = (): chiefAI => {
  commandCooldown: 0.0,
  lastCommand: None,
  subordinateIds: [],
  commandRadius: 400.0,
}

//  Assassin AI 

// The Assassin is a mysterious figure who is NOT part of building
// security. They appear on harder levels, spawning from hiding spots
// (under desks, behind plants, from elevators, ceiling vents). They
// are extremely dangerous in close range and nearly invisible when
// hiding. They don't interact with guards or the security system 
// they're an independent threat that signals someone powerful has
// noticed the player.
//
// Behaviour:
// - Spawn hidden at a random concealment point
// - Wait until player is nearby, then ambush
// - If ambush fails, stalk and reposition for another attempt
// - Can set traps (tripwires, locked doors, disabled lights)
// - Very fast, very lethal, but fragile if exposed
// - Does NOT raise alert level or interact with guards

type concealmentSpot =
  | UnderDesk
  | BehindPlant
  | InsideElevator
  | CeilingVent
  | ServerRack
  | MaintenanceCloset
  | BehindDoor

type trapType =
  | Tripwire // Alerts assassin to player's position; player trips and stumbles
  | Garrotte // Thin wire at neck height; instant kill if player runs through
  | DisabledLight // Creates dark zone for ambush advantage
  | LockedDoor // Forces player into a specific path
  | EMPDevice // Disrupts player's terminal for 3 seconds

type placedTrap = {
  trapType: trapType,
  x: float,
  mutable triggered: bool,
}

type assassinAI = {
  mutable concealment: concealmentSpot,
  mutable visibility: float, // 0.0 = invisible, 1.0 = fully visible
  mutable ambushRange: float, // Strike distance (very close)
  mutable ambushCooldown: float, // Seconds between ambush attempts
  mutable ambushTimer: float,
  mutable strikeSpeed: float, // How fast the attack animation plays
  mutable stalkSpeed: float, // Movement speed when repositioning
  mutable trapsPlaced: array<placedTrap>,
  mutable maxTraps: int,
  mutable hasBeenSeen: bool, // Player has spotted them (they relocate)
  mutable relocateTimer: float, // Seconds until next hiding attempt
  mutable killAttempts: int, // Lifetime counter
  mutable spawnLevel: int, // Minimum mission difficulty to appear (3 = Hard)
}

let makeAssassinAI = (): assassinAI => {
  concealment: BehindPlant,
  visibility: 0.0, // Starts invisible
  ambushRange: 60.0, // Very close  melee range
  ambushCooldown: 8.0, // 8 seconds between strike attempts
  ambushTimer: 0.0,
  strikeSpeed: 0.15, // Lightning fast
  stalkSpeed: 90.0, // Quick repositioning
  trapsPlaced: [],
  maxTraps: 3,
  hasBeenSeen: false,
  relocateTimer: 0.0,
  killAttempts: 0,
  spawnLevel: 3, // Hard difficulty and above
}

//  Guard Entity 

type t = {
  id: string,
  rank: guardRank,
  mutable state: guardState,
  mutable x: float,
  mutable y: float,
  mutable facing: facing,
  mutable speed: float,
  // Patrol
  waypoints: array<waypoint>,
  mutable currentWaypoint: int,
  mutable pauseTimer: float,
  // Vision
  vision: visionCone,
  mutable suspicion: float, // 0.0 to 1.0
  mutable lastKnownPlayerX: option<float>,
  // Radio comms
  mutable hasRadio: bool, // Can call for backup?
  mutable radioRange: float, // How far the call reaches
  // Rank-specific AI
  mutable anomalyLocations: array<float>, // Elite heat map
  mutable antiHacker: option<antiHackerPsych>,
  mutable rivalAI: option<rivalHackerAI>,
  mutable chiefAI: option<chiefAI>,
  mutable assassinAI: option<assassinAI>,
  // Combat
  mutable knockdownTimer: float,
  // Command following
  mutable receivedCommand: option<chiefCommand>,
  mutable commandingChiefId: option<string>,
  // Graphics
  container: Container.t,
  bodyGraphic: Graphics.t,
  coneGraphic: Graphics.t,
  mutable alertIcon: option<Graphics.t>,
}

//  Vision Defaults 

let basicVision: visionCone = {
  range: 150.0, // Short range  dumb
  halfAngle: 0.35, // ~20 each side  narrow
  behindRange: 25.0,
}

let securityVision: visionCone = {
  range: 220.0,
  halfAngle: 0.5, // ~28 each side
  behindRange: 50.0,
}

let antiHackerVision: visionCone = {
  range: 120.0, // Poor  they're nerds, not soldiers
  halfAngle: 0.3,
  behindRange: 20.0,
}

let sentinelVision: visionCone = {
  range: 300.0,
  halfAngle: 0.7, // ~40 each side  widest
  behindRange: 60.0,
}

let eliteVision: visionCone = {
  range: 250.0,
  halfAngle: 0.55,
  behindRange: 80.0, // Best hearing
}

let chiefVision: visionCone = {
  range: 200.0,
  halfAngle: 0.5,
  behindRange: 70.0,
}

let rivalVision: visionCone = {
  range: 180.0, // Decent awareness
  halfAngle: 0.45,
  behindRange: 40.0,
}

let assassinVision: visionCone = {
  range: 280.0, // Excellent  trained killer
  halfAngle: 0.6, // Wide awareness
  behindRange: 100.0, // Near-360 hearing  extremely perceptive
}

//  Construction 

let make = (
  ~id: string,
  ~rank: guardRank,
  ~x: float,
  ~y: float,
  ~waypoints: array<waypoint>,
): t => {
  let container = Container.make()
  Container.setX(container, x)
  Container.setY(container, y)

  let bodyGraphic = Graphics.make()
  let coneGraphic = Graphics.make()
  let _ = Container.addChildGraphics(container, coneGraphic)
  let _ = Container.addChildGraphics(container, bodyGraphic)

  let vision = switch rank {
  | BasicGuard => basicVision
  | SecurityGuard => securityVision
  | AntiHacker => antiHackerVision
  | Sentinel => sentinelVision
  | EliteGuard => eliteVision
  | SecurityChief => chiefVision
  | RivalHacker => rivalVision
  | Assassin => assassinVision
  }

  let speed = switch rank {
  | BasicGuard => 40.0 // Slow and dumb
  | SecurityGuard => 65.0 // Competent pace
  | AntiHacker => 45.0 // Nerdy, not athletic (but flees faster!)
  | Sentinel => 0.0 // Stationary
  | EliteGuard => 85.0 // Fast and dangerous
  | SecurityChief => 55.0 // Deliberate, not hasty
  | RivalHacker => 70.0 // Quick  they know the building
  | Assassin => 95.0 // Extremely fast  trained killer
  }

  let hasRadio = switch rank {
  | BasicGuard => false // Too low-rank for radio
  | SecurityGuard => true
  | AntiHacker => true // Can call for protection
  | Sentinel => true
  | EliteGuard => true
  | SecurityChief => true
  | RivalHacker => false // Not part of security
  | Assassin => false // Works alone  no radio, no allies
  }

  let initialState = switch rank {
  | Sentinel => Stationary
  | RivalHacker => Racing
  | Assassin => Hiding // Starts concealed
  | _ => Patrolling
  }

  {
    id,
    rank,
    state: initialState,
    x,
    y,
    facing: Right,
    speed,
    waypoints,
    currentWaypoint: 0,
    pauseTimer: 0.0,
    vision,
    suspicion: 0.0,
    lastKnownPlayerX: None,
    hasRadio,
    radioRange: 350.0,
    anomalyLocations: [],
    knockdownTimer: 0.0,
    antiHacker: if rank == AntiHacker {
      Some(makeAntiHackerPsych())
    } else {
      None
    },
    rivalAI: if rank == RivalHacker {
      Some(makeRivalHackerAI())
    } else {
      None
    },
    chiefAI: if rank == SecurityChief {
      Some(makeChiefAI())
    } else {
      None
    },
    assassinAI: if rank == Assassin {
      Some(makeAssassinAI())
    } else {
      None
    },
    receivedCommand: None,
    commandingChiefId: None,
    container,
    bodyGraphic,
    coneGraphic,
    alertIcon: None,
  }
}

//  Detection 

let isInVisionCone = (guard: t, ~targetX: float, ~targetY: float): bool => {
  let dx = targetX -. guard.x
  let dy = targetY -. guard.y
  let distance = Math.sqrt(dx *. dx +. dy *. dy)

  let facingRight = guard.facing == Right
  let isBehind = (facingRight && dx < 0.0) || (!facingRight && dx > 0.0)
  if isBehind && distance < guard.vision.behindRange {
    true
  } else if distance > guard.vision.range {
    false
  } else {
    let guardAngle = if facingRight {
      0.0
    } else {
      Math.Constants.pi
    }
    // SafeAngle.fromAtan2 guards against non-finite dy/dx inputs
    // (NaN/Infinity from degenerate positions would poison the entire
    // vision cone calculation and cause guards to never/always detect).
    let targetAngle = SafeAngle.fromAtan2(~y=dy, ~x=dx)
    let angleDiff = absFloat(targetAngle -. guardAngle)
    let normalised = if angleDiff > Math.Constants.pi {
      2.0 *. Math.Constants.pi -. angleDiff
    } else {
      angleDiff
    }
    normalised < guard.vision.halfAngle
  }
}

type detectionResult =
  | NotDetected
  | Peripheral(float) // In peripheral vision, suspicion amount (0-1)
  | FullDetection // Clearly spotted

let detectPlayer = (
  guard: t,
  ~playerX: float,
  ~playerY: float,
  ~playerCrouching: bool,
): detectionResult => {
  if !isInVisionCone(guard, ~targetX=playerX, ~targetY=playerY) {
    NotDetected
  } else {
    let dx = playerX -. guard.x
    let dy = playerY -. guard.y
    let distance = Math.sqrt(dx *. dx +. dy *. dy)

    let effectiveRange = if playerCrouching {
      guard.vision.range *. 0.6
    } else {
      guard.vision.range
    }

    if distance > effectiveRange {
      NotDetected
    } else {
      let proximityFactor = 1.0 -. distance /. effectiveRange
      if proximityFactor > 0.6 {
        FullDetection
      } else {
        Peripheral(proximityFactor)
      }
    }
  }
}

//  Distance helper 

let distanceTo = (guard: t, ~x: float): float => {
  absFloat(x -. guard.x)
}

//  Basic Patrol AI 

let updatePatrol = (guard: t, ~dt: float): unit => {
  switch guard.state {
  | Patrolling => if Array.length(guard.waypoints) == 0 {
      ()
    } else {
      switch guard.waypoints[guard.currentWaypoint] {
      | Some(wp) => {
          let dx = wp.x -. guard.x
          let dist = absFloat(dx)

          if dist < 5.0 {
            guard.pauseTimer = guard.pauseTimer +. dt
            if guard.pauseTimer >= wp.pauseDurationSec {
              guard.pauseTimer = 0.0
              guard.currentWaypoint = mod(guard.currentWaypoint + 1, Array.length(guard.waypoints))
            }
          } else {
            let direction = if dx > 0.0 {
              1.0
            } else {
              -1.0
            }
            // Suspicious guards move slower and more deliberately (0.4x speed).
            // Once fully suspicious, they transition to Investigating.
            let suspicionSlowdown = if guard.suspicion > 0.1 {
              0.4
            } else {
              1.0
            }
            guard.x = guard.x +. direction *. guard.speed *. suspicionSlowdown *. dt
            guard.facing = if dx > 0.0 {
              Right
            } else {
              Left
            }
          }
        }
      | None => ()
      }
    }
  | Investigating => switch guard.lastKnownPlayerX {
    | Some(targetX) => {
        let dx = targetX -. guard.x
        let dist = absFloat(dx)
        if dist < 10.0 {
          guard.pauseTimer = guard.pauseTimer +. dt
          if guard.pauseTimer >= 3.0 {
            guard.pauseTimer = 0.0
            guard.state = Returning
            guard.lastKnownPlayerX = None
          }
        } else {
          let speedMult = switch guard.rank {
          | BasicGuard => 1.2 // Barely faster
          | EliteGuard => 1.8 // Much faster investigating
          | _ => 1.5
          }
          let direction = if dx > 0.0 {
            1.0
          } else {
            -1.0
          }
          guard.x = guard.x +. direction *. guard.speed *. speedMult *. dt
          guard.facing = if dx > 0.0 {
            Right
          } else {
            Left
          }
        }
      }
    | None => guard.state = Returning
    }
  | Alerted => switch guard.lastKnownPlayerX {
    | Some(targetX) => {
        let dx = targetX -. guard.x
        let direction = if dx > 0.0 {
          1.0
        } else {
          -1.0
        }
        let speedMult = switch guard.rank {
        | BasicGuard => 1.5 // Slow even when alerted
        | SecurityGuard => 2.0
        | EliteGuard => 2.5 // Very fast pursuit
        | SecurityChief => 1.8
        | _ => 1.5
        }
        guard.x = guard.x +. direction *. guard.speed *. speedMult *. dt
        guard.facing = if dx > 0.0 {
          Right
        } else {
          Left
        }
      }
    | None => ()
    }
  | Returning => if Array.length(guard.waypoints) > 0 {
      switch guard.waypoints[guard.currentWaypoint] {
      | Some(wp) => {
          let dx = wp.x -. guard.x
          let dist = absFloat(dx)
          if dist < 5.0 {
            guard.state = if guard.rank == Sentinel {
              Stationary
            } else {
              Patrolling
            }
            guard.suspicion = 0.0
          } else {
            let direction = if dx > 0.0 {
              1.0
            } else {
              -1.0
            }
            guard.x = guard.x +. direction *. guard.speed *. dt
            guard.facing = if dx > 0.0 {
              Right
            } else {
              Left
            }
          }
        }
      | None =>
        guard.state = if guard.rank == Sentinel {
          Stationary
        } else {
          Patrolling
        }
      }
    } else {
      guard.state = Stationary
    }
  | Stationary
  | ReverseHacking
  | Panicking
  | Fleeing
  | CallingBackup
  | Commanding
  | Hacking
  | Sabotaging
  | Racing
  | Hiding
  | Ambushing
  | Stalking
  | SettingTrap
  | KnockedDown => ()
  }
}

//  Anti-Hacker Specialist AI 

// The anti-hacker is the game's most interesting enemy: a nerdy
// specialist who is the ONLY one that can reverse your hacking,
// but who is also cowardly. Threaten them and they panic, abandon
// their undo, and flee. Protecting an anti-hacker (via SecurityGuard
// escort) makes them much braver.

let updateAntiHacker = (guard: t, ~dt: float, ~playerX: float, ~alertLevel: int): unit => {
  switch guard.antiHacker {
  | None => ()
  | Some(psych) => {
      let playerDist = distanceTo(guard, ~x=playerX)

      // Courage modifiers
      let baseCourage = 0.3
      let backupBonus = if psych.backupArrived {
        0.4
      } else {
        0.0
      }
      let alertPenalty = if alertLevel >= 4 {
        -0.15
      } else {
        0.0
      }
      let proximityPenalty = if playerDist < 120.0 {
        -0.2
      } else {
        0.0
      }
      psych.courage = Math.max(
        0.0,
        Math.min(1.0, baseCourage +. backupBonus +. alertPenalty +. proximityPenalty),
      )

      switch guard.state {
      | ReverseHacking => {
          // Actively undoing VM changes on a device
          // Check for panic triggers
          if playerDist < 120.0 {
            psych.lastPanicTrigger = Some(PlayerTooClose)
            psych.courage = psych.courage -. 0.3
          }
          if alertLevel >= 4 {
            psych.lastPanicTrigger = Some(AlertLevelHigh)
            psych.courage = psych.courage -. 0.2
          }

          // PANIC CHECK  courage below threshold  abandon reversal!
          if psych.courage < psych.panicThreshold {
            // Drop everything and panic
            guard.state = Panicking
            psych.panicTimer = 0.0
            psych.reverseTarget = None
            psych.undosCompleted = 0
            psych.undosRemaining = 0
          } else {
            // Continue undo operations
            psych.undoCooldown = psych.undoCooldown +. dt
            if psych.undoCooldown >= psych.undoSpeed {
              psych.undoCooldown = 0.0

              // Perform one undo (SecurityAI will call the actual VMNetwork.undoOnDevice)
              psych.undosCompleted = psych.undosCompleted + 1
              psych.undosRemaining = psych.undosRemaining - 1
              if psych.undosRemaining <= 0 {
                // Finished! Return to patrol
                psych.reverseTarget = None
                guard.state = Returning
              }
            }
          }
        }

      | Panicking => {
          // Erratic movement for 1-3 seconds, then flee
          psych.panicTimer = psych.panicTimer +. dt
          // Jitter randomly
          let jitter = Math.random() *. 4.0 -. 2.0
          guard.x = guard.x +. jitter *. dt *. 100.0

          if psych.panicTimer >= 1.5 {
            guard.state = Fleeing

            // Face AWAY from player
            guard.facing = if playerX > guard.x {
              Left
            } else {
              Right
            }
          }
        }

      | Fleeing => {
          // Run away from player at high speed
          let fleeDir = if playerX > guard.x {
            -1.0
          } else {
            1.0
          }
          guard.x = guard.x +. fleeDir *. psych.fleeSpeed *. dt
          guard.facing = if fleeDir > 0.0 {
            Right
          } else {
            Left
          }

          // Stop fleeing if far enough away
          if playerDist > 500.0 {
            guard.state = Returning
            psych.courage = 0.3 // Reset courage
            psych.panicTimer = 0.0
          }
        }

      | CallingBackup => {
          // Waiting for backup to arrive
          psych.backupCallTimer = psych.backupCallTimer +. dt
          if psych.backupArrived {
            // Backup arrived  resume activity
            guard.state = Patrolling
            psych.backupCallTimer = 0.0
          } else if psych.backupCallTimer > 8.0 {
            // Nobody came! Panic!
            psych.lastPanicTrigger = Some(BackupNotArriving)
            psych.courage = psych.courage -. 0.3
            if psych.courage < psych.panicThreshold {
              guard.state = Panicking
              psych.panicTimer = 0.0
            } else {
              // Reluctantly go on alone
              guard.state = Patrolling
              psych.backupCallTimer = 0.0
            }
          }
        }

      | _ => // When patrolling/investigating: check for compromised devices
        // (SecurityAI.res will assign targets to us)
        ()
      }
    }
  }
}

//  SecurityChief Command AI 

// The boss guard coordinates other guards. Appears rarely but
// is a major escalation when present.

type commandEvent = {
  targetId: string,
  command: chiefCommand,
}

let updateChief = (guard: t, ~dt: float, ~playerX: float, ~_alertLevel: int): array<
  commandEvent,
> => {
  switch guard.chiefAI {
  | None => []
  | Some(chief) => {
      let commands = []
      chief.commandCooldown = chief.commandCooldown +. dt

      switch guard.state {
      | Commanding => if chief.commandCooldown >= 3.0 {
          chief.commandCooldown = 0.0

          // Issue commands to subordinates
          switch guard.lastKnownPlayerX {
          | Some(px) => {
              // Converge on last known player position
              chief.subordinateIds->Array.forEach(subId => {
                let _ = Array.push(
                  commands,
                  {
                    targetId: subId,
                    command: Converge(px),
                  },
                )
              })
              chief.lastCommand = Some(Converge(px))
            }
          | None => {
              // Spread out and investigate
              chief.subordinateIds->Array.forEachWithIndex((subId, i) => {
                let spreadX = guard.x +. Float.fromInt(i - 2) *. 100.0
                let _ = Array.push(
                  commands,
                  {
                    targetId: subId,
                    command: InvestigateArea(spreadX),
                  },
                )
              })
              chief.lastCommand = Some(InvestigateArea(playerX))
            }
          }
        }
      | Alerted => {
          // Transition to commanding when alerted
          guard.state = Commanding
          chief.commandCooldown = 0.0
        }
      | _ => ()
      }

      commands
    }
  }
}

//  Rival Hacker AI 

// The rival hacker doesn't try to catch you. Instead they:
// 1. Race to complete the same objectives you're working on
// 2. Sabotage your work (undo changes, lock devices)
// 3. If they complete enough objectives first, you lose the mission
//
// They move through the level on their own path, sometimes crossing
// yours. They're not hostile  just competitive.

let updateRival = (guard: t, ~dt: float, ~playerX: float): unit => {
  switch guard.rivalAI {
  | None => ()
  | Some(rival) => {
      // Track player awareness
      let playerDist = distanceTo(guard, ~x=playerX)
      if playerDist < 200.0 {
        rival.awareness = Math.min(1.0, rival.awareness +. dt *. 0.3)
      } else {
        rival.awareness = Math.max(0.0, rival.awareness -. dt *. 0.1)
      }

      switch guard.state {
      | Racing => // Move toward next device in queue
        switch rival.deviceQueue[0] {
        | Some(targetDevice) => // For now, use waypoints as device locations
          // (real implementation maps device IDs to positions)
          switch guard.waypoints[0] {
          | Some(wp) => {
              let dx = wp.x -. guard.x
              let dist = absFloat(dx)
              if dist < 15.0 {
                // Arrived at device  start hacking
                guard.state = Hacking
                rival.hackTimer = 0.0
                rival.currentObjective = HackDevice(targetDevice)
              } else {
                let direction = if dx > 0.0 {
                  1.0
                } else {
                  -1.0
                }
                guard.x = guard.x +. direction *. guard.speed *. dt
                guard.facing = if dx > 0.0 {
                  Right
                } else {
                  Left
                }
              }
            }
          | None => ()
          }
        | None => {
            // No more devices  try to exfiltrate
            rival.currentObjective = Exfiltrate
            guard.state = Racing
          }
        }

      | Hacking => {
          // Working on a device  timer-based completion
          rival.hackTimer = rival.hackTimer +. dt

          // Sabotage decision: if player is nearby and has worked on this device
          if rival.awareness > 0.5 && Math.random() < rival.sabotageChance *. dt {
            switch rival.currentObjective {
            | HackDevice(deviceId) => {
                rival.currentObjective = SabotageDevice(deviceId)
                guard.state = Sabotaging
              }
            | _ => ()
            }
          }

          if rival.hackTimer >= rival.hackSpeed {
            // Completed the hack
            rival.hackTimer = 0.0
            rival.objectivesCompleted = rival.objectivesCompleted + 1
            switch rival.deviceQueue[0] {
            | Some(deviceId) => {
                let _ = Array.push(rival.devicesCompleted, deviceId)

                // Remove from queue
                rival.deviceQueue = Array.sliceToEnd(rival.deviceQueue, ~start=1)
              }
            | None => ()
            }
            guard.state = Racing // Move to next device
          }
        }

      | Sabotaging => {
          // Undo or lock the player's work on a device
          rival.hackTimer = rival.hackTimer +. dt
          if rival.hackTimer >= 2.0 {
            // Sabotage complete  resume racing
            rival.hackTimer = 0.0
            guard.state = Hacking
            switch rival.currentObjective {
            | SabotageDevice(deviceId) => rival.currentObjective = HackDevice(deviceId)
            | _ => ()
            }
          }
        }

      | _ => ()
      }
    }
  }
}

//  Elite Heat Map AI 

let updateEliteHeatMap = (guard: t, ~anomalyX: float): unit => {
  if guard.rank == EliteGuard {
    let _ = Array.push(guard.anomalyLocations, anomalyX)
    if Array.length(guard.anomalyLocations) > 5 {
      guard.anomalyLocations = Array.sliceToEnd(guard.anomalyLocations, ~start=1)
    }
  }
}

//  Assassin AI 

// The assassin operates completely independently. They don't interact
// with the guard system, don't raise alerts, and don't respond to
// radio calls. They appear from concealment spots and attempt to
// kill the player directly.

let updateAssassin = (guard: t, ~dt: float, ~playerX: float): unit => {
  switch guard.assassinAI {
  | None => ()
  | Some(ai) => {
      let playerDist = distanceTo(guard, ~x=playerX)

      switch guard.state {
      | Hiding => {
          // Completely invisible. Wait for player to get close.
          ai.visibility = 0.0
          if playerDist < ai.ambushRange *. 1.5 {
            // Player is close  STRIKE!
            guard.state = Ambushing
            ai.killAttempts = ai.killAttempts + 1
            ai.visibility = 0.8 // Suddenly visible
          } else if playerDist < 200.0 {
            // Player getting closer  slight visibility increase (flicker)
            ai.visibility = Math.random() *. 0.1 // Brief flicker
          }
        }

      | Ambushing => {
          // Lunge toward player at extreme speed
          ai.visibility = 1.0
          let direction = if playerX > guard.x {
            1.0
          } else {
            -1.0
          }
          guard.x = guard.x +. direction *. guard.speed *. 2.5 *. dt // 2.5x speed lunge
          guard.facing = if direction > 0.0 {
            Right
          } else {
            Left
          }

          // If player moved away, switch to stalking
          if playerDist > ai.ambushRange *. 3.0 {
            guard.state = Stalking
            ai.ambushTimer = 0.0
          }
        }

      | Stalking => {
          // Repositioning after a failed ambush. Semi-visible.
          ai.visibility = 0.4
          ai.ambushTimer = ai.ambushTimer +. dt

          // Move toward a concealment spot (nearest waypoint)
          switch guard.waypoints[guard.currentWaypoint] {
          | Some(wp) => {
              let dx = wp.x -. guard.x
              let dist = absFloat(dx)
              if dist < 10.0 {
                // Reached concealment  hide again
                guard.state = Hiding
                ai.hasBeenSeen = false
                ai.ambushTimer = 0.0
                let wpLen = Array.length(guard.waypoints)
                if wpLen > 0 {
                  guard.currentWaypoint = mod(guard.currentWaypoint + 1, wpLen)
                }
              } else {
                let dir = if dx > 0.0 {
                  1.0
                } else {
                  -1.0
                }
                guard.x = guard.x +. dir *. ai.stalkSpeed *. dt
                guard.facing = if dx > 0.0 {
                  Right
                } else {
                  Left
                }
              }
            }
          | None => {
              // No waypoints  just fade and reposition randomly
              ai.visibility = Math.max(0.0, ai.visibility -. dt *. 0.3)
              if ai.visibility <= 0.05 {
                guard.state = Hiding
              }
            }
          }
        }

      | SettingTrap => {
          // Place a trap at current position
          ai.visibility = 0.2 // Nearly invisible while setting trap
          guard.pauseTimer = guard.pauseTimer +. dt
          if guard.pauseTimer >= 2.0 {
            // Trap placed
            if Array.length(ai.trapsPlaced) < ai.maxTraps {
              let trapKind = switch mod(Array.length(ai.trapsPlaced), 5) {
              | 0 => Tripwire
              | 1 => Garrotte
              | 2 => DisabledLight
              | 3 => LockedDoor
              | _ => EMPDevice
              }
              let _ = Array.push(ai.trapsPlaced, {trapType: trapKind, x: guard.x, triggered: false})
            }
            guard.pauseTimer = 0.0
            guard.state = Stalking // Move to next position
          }
        }

      | _ => ()
      }
    }
  }
}

//  Backup System 

// When an anti-hacker calls for backup, nearby SecurityGuards
// or EliteGuards can respond.

let canRespondToBackup = (guard: t): bool => {
  switch guard.rank {
  | SecurityGuard | EliteGuard | SecurityChief => guard.state == Patrolling ||
    guard.state == Stationary ||
    guard.state == Returning
  | _ => false
  }
}

let respondToBackup = (guard: t, ~callerX: float): unit => {
  guard.lastKnownPlayerX = Some(callerX)
  guard.state = Investigating
  guard.pauseTimer = 0.0
}

//  Graphics 

let rankColor = (rank: guardRank): int => {
  switch rank {
  | BasicGuard => 0x7777aa // Muted blue  unassuming
  | SecurityGuard => 0x8888cc // Blue-grey
  | AntiHacker => 0x44aa88 // Teal-green  techie
  | Sentinel => 0xcc8844 // Orange-brown
  | EliteGuard => 0xcc4444 // Red  danger
  | SecurityChief => 0xaa2222 // Dark red  boss
  | RivalHacker => 0x9944cc // Purple  rival
  | Assassin => 0x111111 // Near-black  shadow
  }
}

let rankSize = (rank: guardRank): (float, float) => {
  switch rank {
  | BasicGuard => (22.0, 32.0) // Smaller
  | SecurityGuard => (24.0, 36.0) // Standard
  | AntiHacker => (20.0, 34.0) // Thin, wiry
  | Sentinel => (26.0, 38.0) // Broader
  | EliteGuard => (24.0, 36.0) // Standard
  | SecurityChief => (28.0, 40.0) // Big boss
  | RivalHacker => (20.0, 34.0) // Similar to player
  | Assassin => (18.0, 38.0) // Tall, thin, menacing
  }
}

let renderGuard = (guard: t): unit => {
  let _ = Graphics.clear(guard.bodyGraphic)

  // Assassin visibility  controls overall alpha
  let bodyAlpha = switch guard.assassinAI {
  | Some(ai) => ai.visibility
  | None => 1.0
  }

  // Skip rendering entirely if assassin is invisible
  if guard.rank == Assassin && bodyAlpha < 0.02 {
    let _ = Graphics.clear(guard.coneGraphic)
    Container.setX(guard.container, guard.x)
  } else {
    Container.setAlpha(guard.container, bodyAlpha)

    let color = rankColor(guard.rank)
    let (w, h) = rankSize(guard.rank)
    let halfW = w /. 2.0

    // Body
    let _ =
      guard.bodyGraphic
      ->Graphics.rect(-.halfW, -.h -. 14.0, w, h)
      ->Graphics.fill({"color": color})

    // Head
    let headRadius = switch guard.rank {
    | SecurityChief => 12.0
    | AntiHacker | RivalHacker => 9.0
    | Assassin => 8.0 // Concealed face
    | _ => 10.0
    }
    // Assassin has no visible skin  masked face
    let headColor = if guard.rank == Assassin {
      0x222222
    } else {
      0xddbb99
    }
    let _ =
      guard.bodyGraphic
      ->Graphics.circle(0.0, -.h -. 14.0 -. headRadius +. 2.0, headRadius)
      ->Graphics.fill({"color": headColor})

    // Headgear varies by rank
    switch guard.rank {
    | BasicGuard => {
        // Simple cap
        let _ =
          guard.bodyGraphic
          ->Graphics.rect(-.halfW, -.h -. 14.0 -. headRadius *. 2.0, w, 6.0)
          ->Graphics.fill({"color": 0x444477})
      }
    | SecurityGuard | Sentinel => {
        // Helmet
        let _ =
          guard.bodyGraphic
          ->Graphics.rect(-.halfW -. 2.0, -.h -. 14.0 -. headRadius *. 2.0 -. 2.0, w +. 4.0, 8.0)
          ->Graphics.fill({"color": color})
      }
    | EliteGuard => {
        // Full helmet with visor
        let _ =
          guard.bodyGraphic
          ->Graphics.rect(-.halfW -. 2.0, -.h -. 14.0 -. headRadius *. 2.0 -. 2.0, w +. 4.0, 10.0)
          ->Graphics.fill({"color": 0x222222})
        let _ =
          guard.bodyGraphic
          ->Graphics.rect(-.halfW +. 2.0, -.h -. 14.0 -. headRadius *. 2.0 +. 4.0, w -. 4.0, 3.0)
          ->Graphics.fill({"color": 0xcc0000}) // Red visor
      }
    | SecurityChief => {
        // Officer's cap with insignia
        let _ =
          guard.bodyGraphic
          ->Graphics.rect(-.halfW -. 4.0, -.h -. 14.0 -. headRadius *. 2.0 -. 2.0, w +. 8.0, 10.0)
          ->Graphics.fill({"color": 0x880000})
        // Gold star insignia
        let _ =
          guard.bodyGraphic
          ->Graphics.circle(0.0, -.h -. 14.0 -. headRadius *. 2.0 +. 2.0, 3.0)
          ->Graphics.fill({"color": 0xffcc00})
      }
    | AntiHacker => {
        // Hoodie (just a rounded top)
        let _ =
          guard.bodyGraphic
          ->Graphics.rect(
            -.halfW -. 1.0,
            -.h -. 14.0 -. headRadius *. 2.0,
            w +. 2.0,
            headRadius *. 2.0 +. 4.0,
          )
          ->Graphics.fill({"color": 0x336655, "alpha": 0.5})
      }
    | RivalHacker => {
        // Beanie/headphones
        let _ =
          guard.bodyGraphic
          ->Graphics.rect(-.halfW, -.h -. 14.0 -. headRadius *. 2.0 -. 2.0, w, 6.0)
          ->Graphics.fill({"color": 0x663399})
      }
    | Assassin => {
        // Full face mask  featureless dark oval
        let _ =
          guard.bodyGraphic
          ->Graphics.circle(0.0, -.h -. 14.0 -. headRadius +. 2.0, headRadius +. 2.0)
          ->Graphics.fill({"color": 0x0a0a0a})
        // Thin red eye slits
        let _ =
          guard.bodyGraphic
          ->Graphics.rect(-5.0, -.h -. 14.0 -. headRadius +. 1.0, 3.0, 1.0)
          ->Graphics.fill({"color": 0xff0000})
        let _ =
          guard.bodyGraphic
          ->Graphics.rect(2.0, -.h -. 14.0 -. headRadius +. 1.0, 3.0, 1.0)
          ->Graphics.fill({"color": 0xff0000})
      }
    }

    // Legs
    let _ =
      guard.bodyGraphic
      ->Graphics.rect(-.halfW +. 2.0, -14.0, 8.0, 14.0)
      ->Graphics.fill({"color": 0x333333})
    let _ =
      guard.bodyGraphic
      ->Graphics.rect(halfW -. 10.0, -14.0, 8.0, 14.0)
      ->Graphics.fill({"color": 0x333333})

    // Vision cone (semi-transparent)  assassins have no visible cone
    let _ = Graphics.clear(guard.coneGraphic)
    let showCone = guard.rank != Assassin // Assassin has no visible cone
    let coneAlpha = switch guard.state {
    | Alerted | Commanding => 0.3
    | Investigating | ReverseHacking => 0.2
    | Panicking | Fleeing => 0.05
    | Ambushing => 0.4 // Visible during lunge
    | Hiding | SettingTrap => 0.0 // Invisible
    | Stalking => 0.02 // Barely perceptible
    | KnockedDown => 0.0 // No cone when knocked down
    | _ => 0.1
    }
    let coneColor = switch guard.state {
    | Alerted | Commanding => 0xff0000
    | Investigating => 0xffaa00
    | ReverseHacking => 0x00ffaa
    | Panicking | Fleeing => 0xff00ff
    | Hacking | Sabotaging => 0x9944cc
    | Ambushing => 0xff0000 // Red flash during strike
    | Stalking => 0x440000 // Dark red
    | _ => 0xffff00
    }

    if showCone {
      let baseAngle = if guard.facing == Right {
        0.0
      } else {
        Math.Constants.pi
      }
      let startAngle = baseAngle -. guard.vision.halfAngle
      let endAngle = baseAngle +. guard.vision.halfAngle

      let _ =
        guard.coneGraphic
        ->Graphics.moveTo(0.0, -.h /. 2.0 -. 14.0)
        ->Graphics.lineTo(
          Math.cos(startAngle) *. guard.vision.range,
          -.h /. 2.0 -. 14.0 +. Math.sin(startAngle) *. guard.vision.range,
        )
        ->Graphics.lineTo(
          Math.cos(endAngle) *. guard.vision.range,
          -.h /. 2.0 -. 14.0 +. Math.sin(endAngle) *. guard.vision.range,
        )
        ->Graphics.lineTo(0.0, -.h /. 2.0 -. 14.0)
        ->Graphics.fill({"color": coneColor, "alpha": coneAlpha})
    }

    // Status icons above head
    let iconY = -.h -. 14.0 -. headRadius *. 2.0 -. 20.0
    switch guard.alertIcon {
    | Some(icon) => {
        let _ = Container.removeChild(guard.container, Graphics.toContainer(icon))
        guard.alertIcon = None
      }
    | None => ()
    }

    // Show "?" icon when guard is suspicious but still patrolling (suspicion > 0.1)
    let isSuspicious = guard.suspicion > 0.1 && (
      guard.state == Patrolling || guard.state == Stationary || guard.state == Returning
    )

    let shouldShowIcon = isSuspicious || switch guard.state {
    | Investigating
    | Alerted
    | Commanding
    | ReverseHacking
    | Panicking
    | Fleeing
    | CallingBackup
    | Hacking
    | Sabotaging
    | Ambushing => true
    | Hiding | Stalking | SettingTrap => false // Assassin stays hidden
    | _ => false
    }

    if shouldShowIcon {
      let icon = Graphics.make()
      let iconColor = if isSuspicious {
        0xffdd44 // Yellow "?" for suspicious
      } else {
        switch guard.state {
        | Alerted | Commanding => 0xff0000
        | Investigating => 0xffaa00
        | ReverseHacking => 0x00ff88
        | Panicking | Fleeing => 0xff00ff
        | CallingBackup => 0x4488ff
        | Hacking | Sabotaging => 0x9944cc
        | Ambushing => 0xff0000 // Skull/danger  assassin striking
        | _ => 0xffffff
        }
      }

      if isSuspicious {
        // Render "?" shape: curved top + dot below
        // Curved arc (top of ?)
        let _ =
          icon
          ->Graphics.moveTo(-.4.0, iconY)
          ->Graphics.lineTo(4.0, iconY)
          ->Graphics.lineTo(4.0, iconY +. 6.0)
          ->Graphics.lineTo(1.0, iconY +. 9.0)
          ->Graphics.lineTo(1.0, iconY +. 12.0)
          ->Graphics.lineTo(-.1.0, iconY +. 12.0)
          ->Graphics.lineTo(-.1.0, iconY +. 9.0)
          ->Graphics.lineTo(-.4.0, iconY +. 6.0)
          ->Graphics.fill({"color": iconColor})
        // Dot below the ?
        let _ =
          icon
          ->Graphics.circle(0.0, iconY +. 16.0, 2.0)
          ->Graphics.fill({"color": iconColor})
      } else {
        // Exclamation mark "!" for alerted states
        let _ =
          icon
          ->Graphics.rect(-3.0, iconY, 6.0, 16.0)
          ->Graphics.fill({"color": iconColor})
        let _ =
          icon
          ->Graphics.circle(0.0, iconY +. 19.0, 3.0)
          ->Graphics.fill({"color": iconColor})
      }
      guard.alertIcon = Some(icon)
      let _ = Container.addChildGraphics(guard.container, icon)
    }

    Container.setX(guard.container, guard.x)
  } // end else (assassin visibility check)
}

//  Per-Frame Update 

let update = (
  guard: t,
  ~dt: float,
  ~playerX: float,
  ~playerY: float,
  ~playerCrouching: bool,
  ~alertLevel: int,
): option<detectionResult> => {
  // Update rank-specific AI
  switch guard.rank {
  | AntiHacker => updateAntiHacker(guard, ~dt, ~playerX, ~alertLevel)
  | RivalHacker => updateRival(guard, ~dt, ~playerX)
  | Assassin => updateAssassin(guard, ~dt, ~playerX)
  | _ => ()
  }

  // Handle knockdown timer
  if guard.state == KnockedDown {
    guard.knockdownTimer = guard.knockdownTimer -. dt
    if guard.knockdownTimer <= 0.0 {
      guard.knockdownTimer = 0.0
      guard.state = Investigating
      guard.suspicion = 0.5
    }
  }

  // Update base patrol movement (skipped for states handled by specialist AI)
  switch guard.state {
  | ReverseHacking
  | Panicking
  | Fleeing
  | CallingBackup
  | Hacking
  | Sabotaging
  | Racing
  | Hiding
  | Ambushing
  | Stalking
  | SettingTrap
  | KnockedDown => ()
  | _ => updatePatrol(guard, ~dt)
  }

  // RivalHacker and Assassin don't use the standard detection system.
  // RivalHacker doesn't care about the player. Assassin has its own
  // proximity-based ambush system handled in updateAssassin().
  if guard.rank == RivalHacker || guard.rank == Assassin {
    renderGuard(guard)
    Some(NotDetected)
  } else {
    // Check player detection
    let detection = detectPlayer(guard, ~playerX, ~playerY, ~playerCrouching)

    switch detection {
    | FullDetection => {
        guard.lastKnownPlayerX = Some(playerX)
        guard.suspicion = 1.0

        switch guard.rank {
        | AntiHacker => // Anti-hackers don't chase  they panic or call for backup
          switch guard.antiHacker {
          | Some(psych) => if psych.courage < psych.panicThreshold {
              guard.state = Panicking
              psych.panicTimer = 0.0
            } else if guard.hasRadio && !psych.backupArrived {
              guard.state = CallingBackup
              psych.backupCallTimer = 0.0
            }
          | None => ()
          }
        | BasicGuard => // Basic guards are slow to react
          if guard.state != Alerted && guard.state != Investigating {
            guard.state = Investigating // They investigate first, not pursue
            guard.pauseTimer = 0.0
          }
        | SecurityChief => // Chief goes into command mode
          guard.state = Commanding
        | _ => if guard.state != Alerted {
            guard.state = Alerted
          }
        }
      }
    | Peripheral(amount) => {
        guard.suspicion = Math.min(1.0, guard.suspicion +. amount *. dt *. 0.5)
        let threshold = switch guard.rank {
        | BasicGuard => 0.85 // Very slow to notice
        | SecurityGuard => 0.65
        | EliteGuard => 0.5 // Quick to notice
        | SecurityChief => 0.6
        | _ => 0.7
        }
        if guard.suspicion > threshold && guard.state == Patrolling {
          guard.lastKnownPlayerX = Some(playerX)
          guard.state = Investigating
          guard.pauseTimer = 0.0
        }
      }
    | NotDetected => {
        let decayRate = switch guard.rank {
        | BasicGuard => 0.3 // Quick to forget
        | EliteGuard => 0.1 // Slow to forget
        | _ => 0.2
        }
        guard.suspicion = Math.max(0.0, guard.suspicion -. dt *. decayRate)
      }
    }

    renderGuard(guard)
    Some(detection)
  }
}

//  State Queries 

let stateToString = (state: guardState): string => {
  switch state {
  | Patrolling => "PATROLLING"
  | Investigating => "INVESTIGATING"
  | Alerted => "ALERTED"
  | Returning => "RETURNING"
  | Stationary => "STATIONARY"
  | ReverseHacking => "REVERSE-HACKING"
  | Panicking => "PANICKING"
  | Fleeing => "FLEEING"
  | CallingBackup => "CALLING BACKUP"
  | Commanding => "COMMANDING"
  | Hacking => "HACKING"
  | Sabotaging => "SABOTAGING"
  | Racing => "RACING"
  | Hiding => "HIDING"
  | Ambushing => "AMBUSHING"
  | Stalking => "STALKING"
  | SettingTrap => "SETTING TRAP"
  | KnockedDown => "KNOCKED DOWN"
  }
}

let rankToString = (rank: guardRank): string => {
  switch rank {
  | BasicGuard => "Basic Guard"
  | SecurityGuard => "Security Guard"
  | AntiHacker => "Anti-Hacker Specialist"
  | Sentinel => "Sentinel"
  | EliteGuard => "Elite Guard"
  | SecurityChief => "Security Chief"
  | RivalHacker => "Rival Hacker"
  | Assassin => "???" // Mysterious  no known designation
  }
}

let isAntiHacker = (guard: t): bool => guard.rank == AntiHacker

let isRival = (guard: t): bool => guard.rank == RivalHacker

// Check if anti-hacker is currently reverse-hacking
let isReverseHacking = (guard: t): bool => {
  guard.rank == AntiHacker && guard.state == ReverseHacking
}

// Check if anti-hacker has fled (player successfully scared them off)
let hasFled = (guard: t): bool => {
  guard.rank == AntiHacker && (guard.state == Fleeing || guard.state == Panicking)
}

// Get anti-hacker's current reverse target (if any)
let getReverseTarget = (guard: t): option<string> => {
  switch guard.antiHacker {
  | Some(psych) => psych.reverseTarget
  | None => None
  }
}

// Assign a device for the anti-hacker to reverse-hack
let assignReverseTarget = (guard: t, ~deviceId: string, ~undoCount: int): bool => {
  switch guard.antiHacker {
  | Some(psych) =>
    if guard.state == Patrolling || guard.state == Returning || guard.state == Stationary {
      psych.reverseTarget = Some(deviceId)
      psych.undosRemaining = undoCount
      psych.undosCompleted = 0
      psych.undoCooldown = 0.0
      guard.state = ReverseHacking
      true
    } else {
      false // Busy, panicking, or fleeing
    }
  | None => false
  }
}

// Notify anti-hacker that backup arrived (boosts courage)
let notifyBackupArrived = (guard: t): unit => {
  switch guard.antiHacker {
  | Some(psych) => psych.backupArrived = true
  | None => ()
  }
}

// Check rival hacker progress (returns objectives completed / total)
let getRivalProgress = (guard: t): option<(int, int)> => {
  switch guard.rivalAI {
  | Some(rival) => Some((rival.objectivesCompleted, rival.totalObjectives))
  | None => None
  }
}

// Has the rival hacker won?
let hasRivalWon = (guard: t): bool => {
  switch guard.rivalAI {
  | Some(rival) => rival.objectivesCompleted >= rival.totalObjectives
  | None => false
  }
}

// Set rival hacker's device queue
let setRivalTargets = (guard: t, ~devices: array<string>, ~total: int): unit => {
  switch guard.rivalAI {
  | Some(rival) => {
      rival.deviceQueue = devices
      rival.totalObjectives = total
    }
  | None => ()
  }
}

//  Assassin Queries 

let isAssassin = (guard: t): bool => guard.rank == Assassin

// Is assassin currently visible to the player?
let isAssassinVisible = (guard: t): bool => {
  switch guard.assassinAI {
  | Some(ai) => ai.visibility > 0.15
  | None => false
  }
}

// Is assassin currently striking?
let isAssassinStriking = (guard: t): bool => {
  guard.rank == Assassin && guard.state == Ambushing
}

// Get traps placed by assassin
let getAssassinTraps = (guard: t): array<placedTrap> => {
  switch guard.assassinAI {
  | Some(ai) => ai.trapsPlaced
  | None => []
  }
}

// Set concealment spot for assassin spawn
let setConcealment = (guard: t, ~spot: concealmentSpot): unit => {
  switch guard.assassinAI {
  | Some(ai) => ai.concealment = spot
  | None => ()
  }
}

// Check if assassin should spawn on this difficulty level
let shouldSpawnAssassin = (missionDifficulty: int): bool => {
  missionDifficulty >= 3 // Hard and above
}

// Get kill attempt count (for stats/grading)
let getAssassinKillAttempts = (guard: t): int => {
  switch guard.assassinAI {
  | Some(ai) => ai.killAttempts
  | None => 0
  }
}

//  Combat Hitboxes 

// Body hitbox using rankSize dimensions (see renderGuard)
let getBodyRect = (guard: t): Hitbox.rect => {
  let (w, h) = rankSize(guard.rank)
  // Body rect from renderGuard: rect(-.halfW, -.h -. 14.0, w, h)
  {
    x: guard.x -. w /. 2.0,
    y: guard.y -. h -. 14.0,
    w,
    h,
  }
}

// Head hitbox  circle approximated as rect
let getHeadRect = (guard: t): Hitbox.rect => {
  let (_, h) = rankSize(guard.rank)
  let headRadius = switch guard.rank {
  | SecurityChief => 12.0
  | AntiHacker | RivalHacker => 9.0
  | Assassin => 8.0
  | _ => 10.0
  }
  // Head center from renderGuard: circle(0, -.h -. 14.0 -. headRadius +. 2.0, headRadius)
  let headCenterY = guard.y -. h -. 14.0 -. headRadius +. 2.0
  {
    x: guard.x -. headRadius,
    y: headCenterY -. headRadius,
    w: headRadius *. 2.0,
    h: headRadius *. 2.0,
  }
}

// Knock guard down for a duration. Drops detection.
let applyKnockdown = (guard: t, ~duration: float): unit => {
  guard.state = KnockedDown
  guard.knockdownTimer = duration
  guard.suspicion = 0.0
  guard.lastKnownPlayerX = None
}

// Check if guard is knocked down
let isKnockedDown = (guard: t): bool => guard.state == KnockedDown

//  Trap Trigger System
//
// Check if the player has walked into any assassin trap.
// Returns the trap type if triggered, None otherwise.
// Tripwire: stumble (brief stun), alerts assassin. Detection range 20px.
// Garrotte: lethal if running (sprinting). If walking, player spots it. Range 15px.
// DisabledLight: darkens area (visual effect). Range 30px.
// LockedDoor: not proximity-triggered (environmental).
// EMPDevice: disrupts electronics. Range 25px.

type trapEffect =
  | TrapTrip // Tripwire stumble — brief speed reduction
  | TrapLethal // Garrotte kill — instant death if sprinting
  | TrapSpotted // Garrotte spotted — player walking, can avoid
  | TrapDarkness // DisabledLight — visual darkness
  | TrapEMP // EMPDevice — terminal disruption
  | TrapNone // No trap triggered

let checkPlayerTrapCollision = (
  ~guard: t,
  ~playerX: float,
  ~playerSprinting: bool,
): trapEffect => {
  switch guard.assassinAI {
  | Some(ai) => {
      let result = ref(TrapNone)
      Array.forEach(ai.trapsPlaced, trap => {
        if !trap.triggered {
          let dist = absFloat(playerX -. trap.x)
          switch trap.trapType {
          | Tripwire =>
            if dist < 20.0 {
              trap.triggered = true
              result := TrapTrip
              // Alert the assassin to player's exact position
              guard.lastKnownPlayerX = Some(playerX)
            }
          | Garrotte =>
            if dist < 15.0 {
              if playerSprinting {
                trap.triggered = true
                result := TrapLethal // Lethal if running
              } else {
                // Walking player spots the wire — can step over
                result := TrapSpotted
              }
            }
          | DisabledLight =>
            if dist < 30.0 {
              trap.triggered = true
              result := TrapDarkness
            }
          | EMPDevice =>
            if dist < 25.0 {
              trap.triggered = true
              result := TrapEMP
            }
          | LockedDoor => () // Environmental, not proximity
          }
        }
      })
      result.contents
    }
  | None => TrapNone
  }
}
