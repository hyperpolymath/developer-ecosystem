// SPDX-License-Identifier: PMPL-1.0-or-later
// GameLoop  coordinator that wires all game systems together
//
// Per-frame update that connects:
// - Player physics and input
// - Guard AI (8 ranks) and patrol movement
// - SecurityAI (SENTRY) and anti-hacker dispatch
// - DetectionSystem (alert scoring)
// - HUD overlay (alert, inventory, zone, objective)
// - Inventory system
// - Mission objectives
//
// This module is called once per frame by the active location screen.

//  Game State 

type gameState = {
  // Systems
  mutable detection: DetectionSystem.t,
  mutable securityAI: SecurityAI.t,
  mutable guards: array<GuardNPC.t>,
  mutable dogs: array<SecurityDog.t>,
  mutable inventory: Inventory.t,
  // Companion
  mutable moletaire: option<Moletaire.t>,
  // PBX distraction system
  mutable pbx: option<Distraction.pbxState>,
  // Level items
  mutable worldItems: array<LevelConfig.worldItem>,
  // Per-device defence flags for the active level (ADR-0013).
  // Loaded from LevelConfig.deviceDefences by startMission.
  // Queried by kernel handlers to enforce canary, timeBomb, etc. at runtime.
  mutable currentLevelDefences: array<LevelConfig.deviceDefenceConfig>,
  // Mission
  mutable currentMission: option<MissionBriefing.mission>,
  mutable missionTimeSec: float,
  // Game time
  mutable gameTime: float,
  mutable paused: bool,
  // Player last known position (for AI)
  mutable playerX: float,
  mutable playerY: float,
  mutable playerCrouching: bool,
  // Current zone
  mutable currentZone: string,
  // Stats for grading
  mutable commandsExecuted: int,
  mutable devicesHacked: int,
  mutable covertLinksDiscovered: int,
  mutable maxAlertReached: int,
  mutable distractionsCalled: int,
  // Rival hacker tracking
  mutable rivalActive: bool,
  mutable rivalWon: bool,
  // Assassin tracking
  mutable assassinActive: bool,
  mutable assassinKillAttempts: int,
  // Startup grace period  suppress detection for the first few seconds
  // so the player has time to react after entering a location.
  mutable gracePeriodSec: float,
}

let make = (~tier: Inventory.difficultyTier): gameState => {
  let inv = Inventory.make(~tier)
  Inventory.applyLoadout(inv)

  {
    detection: DetectionSystem.make(),
    securityAI: SecurityAI.make(),
    guards: [],
    dogs: [],
    inventory: inv,
    moletaire: None,
    pbx: None,
    worldItems: [],
    currentMission: None,
    missionTimeSec: 0.0,
    gameTime: 0.0,
    paused: false,
    playerX: 0.0,
    playerY: 0.0,
    playerCrouching: false,
    currentZone: "unknown",
    commandsExecuted: 0,
    devicesHacked: 0,
    covertLinksDiscovered: 0,
    maxAlertReached: 0,
    distractionsCalled: 0,
    rivalActive: false,
    rivalWon: false,
    assassinActive: false,
    assassinKillAttempts: 0,
    gracePeriodSec: 3.0,
    currentLevelDefences: [],
  }
}

//  Guard Spawning

// Map a LevelConfig rank string to the GuardNPC.guardRank variant.
// "Enforcer" maps to SecurityGuard (competent patrol guard with radio).
// Unrecognised strings fall back to BasicGuard (safe default).
let rankFromString = (s: string): GuardNPC.guardRank =>
  switch s {
  | "Enforcer" => GuardNPC.SecurityGuard // Competent patrol, calls for backup
  | "AntiHacker" => GuardNPC.AntiHacker // Reverse-hack specialist (ADR-0013)
  | "Sentinel" => GuardNPC.Sentinel // Stationary, wide detection cone
  | "EliteGuard" => GuardNPC.EliteGuard // Adaptive heat-map AI
  | "SecurityChief" => GuardNPC.SecurityChief // Commands subordinates
  | "RivalHacker" => GuardNPC.RivalHacker // Competing NPC hacker
  | "Assassin" => GuardNPC.Assassin // Mysterious, deadly
  | _ => GuardNPC.BasicGuard // Fallback: slow, predictable
  }

// Build a GuardNPC from a LevelConfig.guardPlacement.
// Sentinels are stationary (empty waypoints); all others patrol ±patrolRadius.
let spawnFromPlacement = (placement: LevelConfig.guardPlacement, idx: int): GuardNPC.t => {
  let rank = rankFromString(placement.rank)
  let id = `guard_loc_${Int.toString(idx + 1)}`
  let r = placement.patrolRadius
  let waypoints: array<GuardNPC.waypoint> = switch rank {
  | GuardNPC.Sentinel => [] // Sentinel stands still
  | _ => [
      {x: placement.x -. r, pauseDurationSec: 2.5},
      {x: placement.x +. r, pauseDurationSec: 2.5},
    ]
  }
  GuardNPC.make(~id, ~rank, ~x=placement.x, ~y=500.0, ~waypoints)
}

// Spawn guards for a mission based on difficulty and location.
// If LevelConfig.guardPlacements is non-empty for the location, those are used
// directly (giving level designers control over guard composition and positions).
// Otherwise, falls back to difficulty-based generic spawning.
let spawnGuards = (state: gameState, ~locationId: string): unit => {
  let difficulty = switch state.currentMission {
  | Some(mission) => mission.difficulty
  | None => MissionBriefing.Tutorial
  }

  // Use location-specific guard placements when the level config defines them.
  // Falls back to the difficulty-based generic roster if none are configured.
  // This gives level designers explicit control over guard composition and positions
  // (ADR-0013 Phase 1: guard placement data wired from LevelConfig.res).
  let locationGuards: option<array<GuardNPC.t>> = switch LevelConfig.getConfig(locationId) {
  | Some(cfg) when Array.length(cfg.guardPlacements) > 0 =>
    Some(
      cfg.guardPlacements->Array.mapWithIndex((placement, idx) =>
        spawnFromPlacement(placement, idx)
      ),
    )
  | _ => None
  }

  // Guard roster: use location-config placements if available, otherwise scale by difficulty.
  let guards = switch locationGuards {
  | Some(g) => g
  | None =>
    switch difficulty {
  | MissionBriefing.Tutorial => [
      // Tutorial: just 1 basic guard with slow, obvious patrol
      GuardNPC.make(
        ~id="guard_1",
        ~rank=BasicGuard,
        ~x=600.0,
        ~y=500.0,
        ~waypoints=[{x: 400.0, pauseDurationSec: 3.0}, {x: 800.0, pauseDurationSec: 3.0}],
      ),
    ]
  | MissionBriefing.Easy => [
      GuardNPC.make(
        ~id="guard_1",
        ~rank=BasicGuard,
        ~x=500.0,
        ~y=500.0,
        ~waypoints=[{x: 300.0, pauseDurationSec: 2.0}, {x: 700.0, pauseDurationSec: 2.0}],
      ),
      GuardNPC.make(
        ~id="guard_2",
        ~rank=SecurityGuard,
        ~x=1200.0,
        ~y=500.0,
        ~waypoints=[{x: 1000.0, pauseDurationSec: 2.5}, {x: 1400.0, pauseDurationSec: 2.5}],
      ),
      GuardNPC.make(~id="sentinel_1", ~rank=Sentinel, ~x=800.0, ~y=500.0, ~waypoints=[]),
    ]
  | MissionBriefing.Normal => [
      GuardNPC.make(
        ~id="guard_1",
        ~rank=BasicGuard,
        ~x=400.0,
        ~y=500.0,
        ~waypoints=[{x: 200.0, pauseDurationSec: 2.0}, {x: 600.0, pauseDurationSec: 2.0}],
      ),
      GuardNPC.make(
        ~id="guard_2",
        ~rank=SecurityGuard,
        ~x=1000.0,
        ~y=500.0,
        ~waypoints=[{x: 800.0, pauseDurationSec: 2.0}, {x: 1200.0, pauseDurationSec: 2.0}],
      ),
      GuardNPC.make(
        ~id="guard_3",
        ~rank=SecurityGuard,
        ~x=1800.0,
        ~y=500.0,
        ~waypoints=[{x: 1600.0, pauseDurationSec: 2.5}, {x: 2000.0, pauseDurationSec: 2.5}],
      ),
      GuardNPC.make(~id="sentinel_1", ~rank=Sentinel, ~x=1400.0, ~y=500.0, ~waypoints=[]),
      GuardNPC.make(
        ~id="antihack_1",
        ~rank=AntiHacker,
        ~x=700.0,
        ~y=500.0,
        ~waypoints=[{x: 500.0, pauseDurationSec: 4.0}, {x: 900.0, pauseDurationSec: 4.0}],
      ),
    ]
  | MissionBriefing.Hard => [
      GuardNPC.make(
        ~id="guard_1",
        ~rank=BasicGuard,
        ~x=300.0,
        ~y=500.0,
        ~waypoints=[{x: 100.0, pauseDurationSec: 1.5}, {x: 500.0, pauseDurationSec: 1.5}],
      ),
      GuardNPC.make(
        ~id="guard_2",
        ~rank=SecurityGuard,
        ~x=800.0,
        ~y=500.0,
        ~waypoints=[{x: 600.0, pauseDurationSec: 2.0}, {x: 1000.0, pauseDurationSec: 2.0}],
      ),
      GuardNPC.make(
        ~id="guard_3",
        ~rank=SecurityGuard,
        ~x=1500.0,
        ~y=500.0,
        ~waypoints=[{x: 1300.0, pauseDurationSec: 2.0}, {x: 1700.0, pauseDurationSec: 2.0}],
      ),
      GuardNPC.make(
        ~id="elite_1",
        ~rank=EliteGuard,
        ~x=2000.0,
        ~y=500.0,
        ~waypoints=[{x: 1800.0, pauseDurationSec: 1.0}, {x: 2200.0, pauseDurationSec: 1.0}],
      ),
      GuardNPC.make(~id="sentinel_1", ~rank=Sentinel, ~x=1200.0, ~y=500.0, ~waypoints=[]),
      GuardNPC.make(
        ~id="antihack_1",
        ~rank=AntiHacker,
        ~x=600.0,
        ~y=500.0,
        ~waypoints=[{x: 400.0, pauseDurationSec: 3.0}, {x: 800.0, pauseDurationSec: 3.0}],
      ),
      GuardNPC.make(
        ~id="antihack_2",
        ~rank=AntiHacker,
        ~x=1800.0,
        ~y=500.0,
        ~waypoints=[{x: 1600.0, pauseDurationSec: 3.0}, {x: 2000.0, pauseDurationSec: 3.0}],
      ),
      // Assassin appears on Hard
      GuardNPC.make(
        ~id="assassin_1",
        ~rank=Assassin,
        ~x=1400.0,
        ~y=500.0,
        ~waypoints=[{x: 1000.0, pauseDurationSec: 0.0}, {x: 1800.0, pauseDurationSec: 0.0}],
      ),
    ]
  | MissionBriefing.Expert => [
      GuardNPC.make(
        ~id="guard_1",
        ~rank=BasicGuard,
        ~x=200.0,
        ~y=500.0,
        ~waypoints=[{x: 100.0, pauseDurationSec: 1.0}, {x: 400.0, pauseDurationSec: 1.0}],
      ),
      GuardNPC.make(
        ~id="guard_2",
        ~rank=SecurityGuard,
        ~x=700.0,
        ~y=500.0,
        ~waypoints=[{x: 500.0, pauseDurationSec: 1.5}, {x: 900.0, pauseDurationSec: 1.5}],
      ),
      GuardNPC.make(
        ~id="guard_3",
        ~rank=SecurityGuard,
        ~x=1300.0,
        ~y=500.0,
        ~waypoints=[{x: 1100.0, pauseDurationSec: 1.5}, {x: 1500.0, pauseDurationSec: 1.5}],
      ),
      GuardNPC.make(
        ~id="elite_1",
        ~rank=EliteGuard,
        ~x=1800.0,
        ~y=500.0,
        ~waypoints=[{x: 1600.0, pauseDurationSec: 1.0}, {x: 2000.0, pauseDurationSec: 1.0}],
      ),
      GuardNPC.make(
        ~id="elite_2",
        ~rank=EliteGuard,
        ~x=2400.0,
        ~y=500.0,
        ~waypoints=[{x: 2200.0, pauseDurationSec: 1.0}, {x: 2600.0, pauseDurationSec: 1.0}],
      ),
      GuardNPC.make(~id="sentinel_1", ~rank=Sentinel, ~x=1000.0, ~y=500.0, ~waypoints=[]),
      GuardNPC.make(~id="sentinel_2", ~rank=Sentinel, ~x=2000.0, ~y=500.0, ~waypoints=[]),
      GuardNPC.make(
        ~id="chief_1",
        ~rank=SecurityChief,
        ~x=1500.0,
        ~y=500.0,
        ~waypoints=[{x: 1200.0, pauseDurationSec: 2.0}, {x: 1800.0, pauseDurationSec: 2.0}],
      ),
      GuardNPC.make(
        ~id="antihack_1",
        ~rank=AntiHacker,
        ~x=500.0,
        ~y=500.0,
        ~waypoints=[{x: 300.0, pauseDurationSec: 3.0}, {x: 700.0, pauseDurationSec: 3.0}],
      ),
      GuardNPC.make(
        ~id="antihack_2",
        ~rank=AntiHacker,
        ~x=1600.0,
        ~y=500.0,
        ~waypoints=[{x: 1400.0, pauseDurationSec: 3.0}, {x: 1800.0, pauseDurationSec: 3.0}],
      ),
      GuardNPC.make(
        ~id="antihack_3",
        ~rank=AntiHacker,
        ~x=2200.0,
        ~y=500.0,
        ~waypoints=[{x: 2000.0, pauseDurationSec: 3.0}, {x: 2400.0, pauseDurationSec: 3.0}],
      ),
      // Rival hacker on Expert
      GuardNPC.make(
        ~id="rival_1",
        ~rank=RivalHacker,
        ~x=100.0,
        ~y=500.0,
        ~waypoints=[
          {x: 500.0, pauseDurationSec: 0.0},
          {x: 1500.0, pauseDurationSec: 0.0},
          {x: 2500.0, pauseDurationSec: 0.0},
        ],
      ),
      // Assassin
      GuardNPC.make(
        ~id="assassin_1",
        ~rank=Assassin,
        ~x=1200.0,
        ~y=500.0,
        ~waypoints=[
          {x: 800.0, pauseDurationSec: 0.0},
          {x: 1600.0, pauseDurationSec: 0.0},
          {x: 2200.0, pauseDurationSec: 0.0},
        ],
      ),
    ]
    }
  }

  // Set up chief subordinates
  guards->Array.forEach(g => {
    if g.rank == GuardNPC.SecurityChief {
      switch g.chiefAI {
      | Some(chief) => chief.subordinateIds =
          guards
          ->Array.filter(sub =>
            sub.rank == GuardNPC.SecurityGuard ||
            sub.rank == GuardNPC.EliteGuard ||
            sub.rank == GuardNPC.BasicGuard
          )
          ->Array.map(sub => sub.id)
      | None => ()
      }
    }
  })

  // Set up rival hacker targets
  guards->Array.forEach(g => {
    if g.rank == GuardNPC.RivalHacker {
      GuardNPC.setRivalTargets(g, ~devices=["router", "firewall", "database"], ~total=3)
    }
  })

  // Track assassin/rival presence
  state.assassinActive = guards->Array.some(g => g.rank == GuardNPC.Assassin)
  state.rivalActive = guards->Array.some(g => g.rank == GuardNPC.RivalHacker)

  state.guards = guards

  // Spawn dogs scaled by difficulty
  let dogs = switch difficulty {
  | MissionBriefing.Tutorial => []
  | MissionBriefing.Easy => [
      SecurityDog.make(
        ~id="robodog_1",
        ~variant=RoboDog,
        ~x=900.0,
        ~y=500.0,
        ~waypoints=[{x: 700.0, pauseDurationSec: 2.0}, {x: 1100.0, pauseDurationSec: 2.0}],
        (),
      ),
    ]
  | MissionBriefing.Normal => [
      SecurityDog.make(
        ~id="robodog_1",
        ~variant=RoboDog,
        ~x=700.0,
        ~y=500.0,
        ~waypoints=[{x: 500.0, pauseDurationSec: 2.0}, {x: 900.0, pauseDurationSec: 2.0}],
        (),
      ),
      SecurityDog.make(
        ~id="guarddog_1",
        ~variant=GuardDog,
        ~x=1500.0,
        ~y=500.0,
        ~waypoints=[{x: 1300.0, pauseDurationSec: 1.5}, {x: 1700.0, pauseDurationSec: 1.5}],
        (),
      ),
    ]
  | MissionBriefing.Hard => [
      SecurityDog.make(
        ~id="robodog_1",
        ~variant=RoboDog,
        ~x=600.0,
        ~y=500.0,
        ~waypoints=[{x: 400.0, pauseDurationSec: 1.5}, {x: 800.0, pauseDurationSec: 1.5}],
        (),
      ),
      SecurityDog.make(
        ~id="robodog_2",
        ~variant=RoboDog,
        ~x=1600.0,
        ~y=500.0,
        ~waypoints=[{x: 1400.0, pauseDurationSec: 1.5}, {x: 1800.0, pauseDurationSec: 1.5}],
        (),
      ),
      SecurityDog.make(
        ~id="guarddog_1",
        ~variant=GuardDog,
        ~x=1100.0,
        ~y=500.0,
        ~waypoints=[{x: 900.0, pauseDurationSec: 1.0}, {x: 1300.0, pauseDurationSec: 1.0}],
        (),
      ),
    ]
  | MissionBriefing.Expert => [
      SecurityDog.make(
        ~id="robodog_1",
        ~variant=RoboDog,
        ~x=500.0,
        ~y=500.0,
        ~waypoints=[{x: 300.0, pauseDurationSec: 1.0}, {x: 700.0, pauseDurationSec: 1.0}],
        (),
      ),
      SecurityDog.make(
        ~id="robodog_2",
        ~variant=RoboDog,
        ~x=1400.0,
        ~y=500.0,
        ~waypoints=[{x: 1200.0, pauseDurationSec: 1.0}, {x: 1600.0, pauseDurationSec: 1.0}],
        (),
      ),
      SecurityDog.make(
        ~id="robodog_3",
        ~variant=RoboDog,
        ~x=2200.0,
        ~y=500.0,
        ~waypoints=[{x: 2000.0, pauseDurationSec: 1.0}, {x: 2400.0, pauseDurationSec: 1.0}],
        (),
      ),
      SecurityDog.make(
        ~id="guarddog_1",
        ~variant=GuardDog,
        ~x=800.0,
        ~y=500.0,
        ~waypoints=[{x: 600.0, pauseDurationSec: 1.0}, {x: 1000.0, pauseDurationSec: 1.0}],
        (),
      ),
      SecurityDog.make(
        ~id="guarddog_2",
        ~variant=GuardDog,
        ~x=1800.0,
        ~y=500.0,
        ~waypoints=[{x: 1600.0, pauseDurationSec: 1.0}, {x: 2000.0, pauseDurationSec: 1.0}],
        (),
      ),
    ]
  }
  state.dogs = dogs
}

//  Anti-Hacker Dispatch 

// Find an available anti-hacker specialist for SENTRY dispatch
let findAvailableAntiHacker = (state: gameState): option<GuardNPC.t> => {
  state.guards->Array.find(g => {
    GuardNPC.isAntiHacker(g) &&
    !GuardNPC.isReverseHacking(g) &&
    !GuardNPC.hasFled(g) &&
    (g.state == GuardNPC.Patrolling ||
    g.state == GuardNPC.Returning ||
    g.state == GuardNPC.Stationary)
  })
}

// Process SENTRY dispatch requests  assign anti-hackers to compromised devices
let processDispatches = (
  state: gameState,
  ~dispatches: array<SecurityAI.dispatchRequest>,
): unit => {
  dispatches->Array.forEach(dispatch => {
    switch findAvailableAntiHacker(state) {
    | Some(antiHacker) => {
        let assigned = GuardNPC.assignReverseTarget(
          antiHacker,
          ~deviceId=dispatch.deviceId,
          ~undoCount=dispatch.undosNeeded,
        )
        if assigned {
          SecurityAI.assignSpecialist(
            state.securityAI,
            ~deviceId=dispatch.deviceId,
            ~specialistId=antiHacker.id,
          )
        } else {
          SecurityAI.recordDispatchFailure(state.securityAI, ~deviceId=dispatch.deviceId)
        }
      }
    | None => SecurityAI.recordDispatchFailure(state.securityAI, ~deviceId=dispatch.deviceId)
    }
  })
}

//  Backup Response 

// Check if any anti-hackers are calling for backup and dispatch guards
let processBackupCalls = (state: gameState): unit => {
  state.guards->Array.forEach(g => {
    if g.state == GuardNPC.CallingBackup && GuardNPC.isAntiHacker(g) {
      // Find nearest guard that can respond
      let responder = state.guards->Array.find(other => {
        GuardNPC.canRespondToBackup(other) && GuardNPC.distanceTo(other, ~x=g.x) < other.radioRange
      })
      switch responder {
      | Some(guard) => {
          GuardNPC.respondToBackup(guard, ~callerX=g.x)
          GuardNPC.notifyBackupArrived(g)
        }
      | None => () // Nobody close enough
      }
    }
  })
}

//  Chief Commands 

// Process chief guard commands and relay to subordinates
let processChiefCommands = (state: gameState, ~dt: float): unit => {
  let alertLevel = DetectionSystem.getAlertInt(state.detection)
  state.guards->Array.forEach(g => {
    if g.rank == GuardNPC.SecurityChief {
      let commands = GuardNPC.updateChief(g, ~dt, ~playerX=state.playerX, ~_alertLevel=alertLevel)
      commands->Array.forEach(cmd => {
        // Find the target subordinate
        let target = state.guards->Array.find(sub => sub.id == cmd.targetId)
        switch target {
        | Some(sub) => {
            sub.receivedCommand = Some(cmd.command)
            sub.commandingChiefId = Some(g.id)
            // Execute the command
            switch cmd.command {
            | GuardNPC.Converge(x) | GuardNPC.InvestigateArea(x) => {
                sub.lastKnownPlayerX = Some(x)
                sub.state = Investigating
              }
            | GuardNPC.ProtectAntiHacker(ahId) => {
                // Find the anti-hacker and go to their position
                let ah = state.guards->Array.find(a => a.id == ahId)
                switch ah {
                | Some(antiHacker) => {
                    sub.lastKnownPlayerX = Some(antiHacker.x)
                    sub.state = Investigating
                  }
                | None => ()
                }
              }
            | GuardNPC.HoldPosition => sub.state = Stationary
            | GuardNPC.Retreat => sub.state = Returning
            }
          }
        | None => ()
        }
      })
    }
  })
}

//  Anti-Hacker Reversion Execution 

// When an anti-hacker completes an undo cycle, execute the actual VMNetwork undo
let processReversions = (state: gameState): unit => {
  state.guards->Array.forEach(g => {
    if GuardNPC.isAntiHacker(g) {
      switch g.antiHacker {
      | Some(psych) => {
          // Check if they just completed an undo tick
          if (
            g.state == GuardNPC.ReverseHacking &&
            psych.undoCooldown < 0.01 &&
            psych.undosCompleted > 0
          ) {
            switch psych.reverseTarget {
            | Some(deviceId) => {
                let _result = VMNetwork.undoOnDevice(~deviceId, ~playerId=g.id)

                // If they finished all undos, report completion
                if psych.undosRemaining <= 0 {
                  SecurityAI.recordReversion(state.securityAI, ~deviceId)
                }
              }
            | None => ()
            }
          }

          // If anti-hacker fled, report it
          if GuardNPC.hasFled(g) {
            switch psych.reverseTarget {
            | Some(deviceId) => {
                SecurityAI.recordSpecialistFled(state.securityAI, ~deviceId)
                psych.reverseTarget = None
              }
            | None => ()
            }
          }
        }
      | None => ()
      }
    }
  })
}

//  Per-Frame Update 

type frameResult = {
  alertLevel: HUD.alertLevel,
  missionComplete: bool,
  gameOver: bool,
  gameOverReason: option<GameOverScreen.failureReason>,
  rivalWon: bool,
  assassinStrike: bool,
}

let update = (
  state: gameState,
  ~dt: float,
  ~playerX: float,
  ~playerY: float,
  ~playerCrouching: bool,
  ~playerSprinting: bool=false,
): frameResult => {
  // Apply game speed multiplier (accessibility: allows slower gameplay)
  let dt = dt *. AccessibilitySettings.getGameSpeed()

  // Update timing
  state.gameTime = state.gameTime +. dt
  state.missionTimeSec = state.missionTimeSec +. dt
  state.playerX = playerX
  state.playerY = playerY
  state.playerCrouching = playerCrouching

  // Countdown the startup grace period
  let inGracePeriod = state.gracePeriodSec > 0.0
  if inGracePeriod {
    state.gracePeriodSec = Math.max(0.0, state.gracePeriodSec -. dt)
  }

  let alertLevel = DetectionSystem.getAlertInt(state.detection)

  // 0. Update Moletaire companion (if active)
  switch state.moletaire {
  | Some(mole) if Moletaire.isAlive(mole) => {
      let _moleEvent = Moletaire.update(mole, ~dt)
    }
  | _ => ()
  }

  // 0b. Update all dogs (detection suppressed during grace period)
  state.dogs->Array.forEach(dog => {
    let detection = SecurityDog.update(
      dog,
      ~dt,
      ~playerX,
      ~playerY,
      ~playerCrouching,
      ~playerSprinting,
    )
    if !inGracePeriod {
      switch detection {
      | Some(SecurityDog.VisualDetected) | Some(SecurityDog.ScentDetected(_)) =>
        DetectionSystem.reportDetection(
          state.detection,
          ~source=DogDetection(dog.id),
          ~gameTime=state.gameTime,
        )
      | Some(SecurityDog.HeardMovement) =>
        DetectionSystem.reportDetection(
          state.detection,
          ~source=DogHearing(dog.id),
          ~gameTime=state.gameTime,
        )
      | _ => ()
      }
    }
  })

  // 1. Update all guards
  let assassinStrike = ref(false)
  state.guards->Array.forEach(guard => {
    let detection = GuardNPC.update(guard, ~dt, ~playerX, ~playerY, ~playerCrouching, ~alertLevel)

    // Report detections to the detection system (suppressed during startup grace period)
    if !inGracePeriod {
      switch detection {
      | Some(GuardNPC.FullDetection) => {
          let source = switch guard.rank {
          | GuardNPC.Assassin => {
              // Assassin strike  immediate danger
              if guard.state == GuardNPC.Ambushing {
                assassinStrike := true
              }

              // Assassins don't report to detection system
              None
            }
          | GuardNPC.RivalHacker => None // Rivals don't report
          | _ => Some(DetectionSystem.GuardSight(guard.id))
          }
          switch source {
          | Some(s) =>
            DetectionSystem.reportDetection(state.detection, ~source=s, ~gameTime=state.gameTime)
          | None => ()
          }
        }
      | Some(GuardNPC.Peripheral(_)) => if (
          guard.rank != GuardNPC.Assassin && guard.rank != GuardNPC.RivalHacker
        ) {
          DetectionSystem.reportDetection(
            state.detection,
            ~source=GuardHearing(guard.id),
            ~gameTime=state.gameTime,
          )
        }
      | _ => ()
      }
    }

    // Track elite heat map
    if guard.rank == GuardNPC.EliteGuard {
      switch detection {
      | Some(GuardNPC.FullDetection) | Some(GuardNPC.Peripheral(_)) =>
        GuardNPC.updateEliteHeatMap(guard, ~anomalyX=playerX)
      | _ => ()
      }
    }
  })

  // 1b. Update PBX distraction system
  switch state.pbx {
  | Some(pbx) => {
      let events = Distraction.update(pbx, ~dt)
      events->Array.forEach(evt => {
        switch evt {
        | Distraction.DistractionExpired(d) =>
          // When a distraction expires, guards realise it was fake  add suspicion
          let kindName = Distraction.kindToString(d.spec.kind)
          DetectionSystem.reportDetection(
            state.detection,
            ~source=DistractionExpired(kindName),
            ~gameTime=state.gameTime,
          )

          // DistractionExpired has weight 0  apply the per-type suspicion directly
          state.detection.alertScore = Math.min(
            120.0,
            state.detection.alertScore +. d.spec.suspicionOnExpiry,
          )
        | Distraction.DistractionStarted(_) => ()
        }
      })
      state.distractionsCalled = pbx.totalCalls

      // 1c. Direct guards to active distractions
      state.guards->Array.forEach(guard => {
        // Only redirect guards that are patrolling or returning (not already chasing player)
        if guard.state == GuardNPC.Patrolling || guard.state == GuardNPC.Returning {
          // Skip assassins, rivals, and chiefs  they have their own priorities
          if (
            guard.rank != GuardNPC.Assassin &&
            guard.rank != GuardNPC.RivalHacker &&
            guard.rank != GuardNPC.SecurityChief
          ) {
            switch Distraction.getDistractionForGuard(pbx, ~guardX=guard.x) {
            | Some(order) =>
              // Redirect guard to investigate the distraction
              guard.lastKnownPlayerX = Some(order.targetX)
              guard.state = GuardNPC.Investigating
              Distraction.registerResponder(pbx, ~distractionId=order.distractionId)
            | None => ()
            }
          }
        }
      })
    }
  | None => ()
  }

  // 2. Update detection system (natural decay)
  DetectionSystem.update(state.detection, ~dt)
  let currentAlert = DetectionSystem.getAlertLevel(state.detection)
  let currentAlertInt = HUD.alertToInt(currentAlert)
  if currentAlertInt > state.maxAlertReached {
    state.maxAlertReached = currentAlertInt
  }

  // 2b. Update VM Network mesh (Tier 5)
  if FeaturePacks.isInvertibleProgrammingEnabled() {
    VMNetwork.update(dt)
  }

  // 3. Update SENTRY  get dispatch requests
  let dispatches = SecurityAI.update(state.securityAI, ~dt, ~alertLevel=currentAlertInt)

  // 4. Process SENTRY dispatches  assign anti-hackers
  processDispatches(state, ~dispatches)

  // 5. Process backup calls
  processBackupCalls(state)

  // 6. Process chief commands
  processChiefCommands(state, ~dt)

  // 7. Execute anti-hacker reversions
  if FeaturePacks.isInvertibleProgrammingEnabled() {
    processReversions(state)
  }

  // 8. Check rival hacker progress
  state.guards->Array.forEach(g => {
    if GuardNPC.isRival(g) && GuardNPC.hasRivalWon(g) {
      state.rivalWon = true
    }
  })

  // 9. Track assassin stats
  state.guards->Array.forEach(g => {
    if GuardNPC.isAssassin(g) {
      state.assassinKillAttempts = GuardNPC.getAssassinKillAttempts(g)
    }
  })

  // 10. Check mission completion
  let missionComplete = switch state.currentMission {
  | Some(mission) => MissionBriefing.isComplete(mission)
  | None => false
  }

  // 11. Check game over conditions
  let gameOver = ref(false)
  let gameOverReason = ref(None)

  if DetectionSystem.isLockdown(state.detection) {
    gameOver := true
    gameOverReason := Some(GameOverScreen.SecurityDetected)
  }

  if state.rivalWon {
    gameOver := true
    // Rival winning is treated as a mission failure
    gameOverReason := Some(GameOverScreen.SecurityDetected)
  }

  {
    alertLevel: currentAlert,
    missionComplete,
    gameOver: gameOver.contents,
    gameOverReason: gameOverReason.contents,
    rivalWon: state.rivalWon,
    assassinStrike: assassinStrike.contents,
  }
}

//  Mission Management 

let startMission = (state: gameState, ~locationId: string): unit => {
  let mission = MissionBriefing.getMission(locationId)
  state.currentMission = mission
  state.missionTimeSec = 0.0
  state.gameTime = 0.0
  state.commandsExecuted = 0
  state.devicesHacked = 0
  state.covertLinksDiscovered = 0
  state.maxAlertReached = 0
  state.distractionsCalled = 0
  state.rivalWon = false
  state.assassinKillAttempts = 0
  state.gracePeriodSec = 3.0 // 3 seconds of immunity on mission start

  // Load level config — world items, device defence flags, and guard placements
  // are all sourced from LevelConfig.  Guard placements are consumed by spawnGuards
  // below; defence flags are stored on state for the Kernel to query at runtime.
  let levelCfg = LevelConfig.getConfig(locationId)
  state.worldItems = switch levelCfg {
  | Some(cfg) => cfg.worldItems
  | None => []
  }
  state.currentLevelDefences = switch levelCfg {
  | Some(cfg) => cfg.deviceDefences
  | None => []
  }
  // Push the defence flags into DeviceRegistry so that any module can query
  // them by IP without needing a gameState reference (ADR-0013).
  Array.forEach(state.currentLevelDefences, dc => {
    DeviceRegistry.setDefenceFlags(dc.ipAddress, dc.flags)
  })

  // Reset systems
  DetectionSystem.reset(state.detection)
  SecurityAI.reset(state.securityAI)

  // Initialise VM Network mesh (Tier 5)
  if FeaturePacks.isInvertibleProgrammingEnabled() {
    VMNetwork.initializeDefaultLevel()
  }

  // Set up PBX for levels that have one (security+ levels)
  let hasPBX = switch locationId {
  | "security" | "scada" | "backbone" => true
  | _ => false
  }
  if hasPBX {
    let pbxIp = switch locationId {
    | "security" => "10.0.3.10"
    | "scada" => "10.10.1.1"
    | "backbone" => "10.0.3.20"
    | _ => "10.0.3.10"
    }
    let pbx = Distraction.make(~ipAddress=pbxIp)
    // Set layout anchors per level
    switch locationId {
    | "security" => {
        pbx.entranceX = 100.0
        pbx.exitX = 50.0
        pbx.lobbyX = 400.0
        pbx.dockX = 1800.0
      }
    | "scada" => {
        pbx.entranceX = 150.0
        pbx.exitX = 50.0
        pbx.lobbyX = 300.0
        pbx.dockX = 2200.0
      }
    | "backbone" => {
        pbx.entranceX = 100.0
        pbx.exitX = 50.0
        pbx.lobbyX = 500.0
        pbx.dockX = 2500.0
      }
    | _ => ()
    }
    // Apply difficulty scaling
    let difficultyInt = switch state.currentMission {
    | Some(m) =>
      switch m.difficulty {
      | MissionBriefing.Tutorial => 0
      | MissionBriefing.Easy => 1
      | MissionBriefing.Normal => 2
      | MissionBriefing.Hard => 3
      | MissionBriefing.Expert => 4
      }
    | None => 0
    }
    Distraction.applyDifficultyScaling(pbx, ~difficulty=difficultyInt)
    state.pbx = Some(pbx)
    // Register with Terminal so `pbx` commands work from any terminal
    Terminal.registerPBX(pbx)
  } else {
    state.pbx = None
    Terminal.unregisterPBX()
  }

  // Spawn guards
  spawnGuards(state, ~locationId)
}

//  Item Interaction 

// Attempt to pick up an item near the player
let attemptItemPickup = (state: gameState, ~playerX: float, ~interactionDistance: float): bool => {
  let found = ref(false)
  
  state.worldItems->Array.forEach(wi => {
    if !found.contents && !wi.collected {
      let dist = Math.abs(playerX -. wi.x)
      if dist <= interactionDistance {
        // Try adding to inventory
        let added = Inventory.addItem(state.inventory, ~item=wi.item)
        if added {
          wi.collected = true
          found := true
          Announcer.alert(`Picked up ${wi.item.name}`)
        } else {
          Announcer.alert("Inventory full! Cannot pick up item.")
        }
      }
    }
  })
  
  found.contents
}

//  Stats for Grading 

let getRunStats = (state: gameState): GameOverScreen.runStats => {
  {
    devicesHacked: state.devicesHacked,
    commandsExecuted: state.commandsExecuted,
    timeElapsedSec: state.missionTimeSec,
    alertLevelReached: state.maxAlertReached,
  }
}

let getVictoryStats = (state: gameState): VictoryScreen.victoryStats => {
  {
    devicesHacked: state.devicesHacked,
    commandsExecuted: state.commandsExecuted,
    timeElapsedSec: state.missionTimeSec,
    alertLevelReached: state.maxAlertReached,
    undosUsed: state.securityAI.totalReversions,
    covertLinksDiscovered: state.covertLinksDiscovered,
  }
}

//  HUD Sync 

// Sync game state to HUD display
let syncHUD = (state: gameState, ~hud: HUD.t): unit => {
  let alertLevel = DetectionSystem.getAlertLevel(state.detection)
  HUD.setAlert(hud, ~level=alertLevel)
  HUD.setZone(hud, ~name=state.currentZone)

  // Sync objective
  switch state.currentMission {
  | Some(mission) => switch MissionBriefing.getCurrentObjective(mission) {
    | Some(obj) => HUD.setObjective(hud, ~text=obj)
    | None => HUD.setObjective(hud, ~text="")
    }
  | None => ()
  }

  // Sync inventory quickbar
  let quickbar = InventoryUI.formatQuickbar(state.inventory)
  quickbar->Array.forEachWithIndex((slot, i) => {
    HUD.setInventorySlot(hud, ~index=i, ~slot)
  })

  HUD.render(hud)
}

//  Queries 

let getGuardCount = (state: gameState): int => Array.length(state.guards)

let getActiveAntiHackers = (state: gameState): int => {
  state.guards
  ->Array.filter(g => GuardNPC.isAntiHacker(g) && !GuardNPC.hasFled(g))
  ->Array.length
}

let getFledAntiHackers = (state: gameState): int => {
  state.guards
  ->Array.filter(g => GuardNPC.isAntiHacker(g) && GuardNPC.hasFled(g))
  ->Array.length
}

let isRivalActive = (state: gameState): bool => state.rivalActive

let getRivalProgress = (state: gameState): option<(int, int)> => {
  let rival = state.guards->Array.find(g => GuardNPC.isRival(g))
  switch rival {
  | Some(g) => GuardNPC.getRivalProgress(g)
  | None => None
  }
}

//  Device Defence Flags (ADR-0013)

// Look up the ADR-0013 defence flags for a device by its IP address.
// Returns the flags configured in the level's LevelConfig.deviceDefences array, or
// the zero-flags record (all false) if no override exists for this device.
// Used by the Kernel (CoprocessorManager) and SecurityAI to check whether a device
// has time-bombs, undo immunity, canaries, etc. active for the current mission.
let getDeviceDefenceFlags = (
  state: gameState,
  ~ipAddress: string,
): DeviceType.defenceFlags => {
  let found = state.currentLevelDefences->Array.find(d => d.ipAddress == ipAddress)
  switch found {
  | Some(d) => d.flags
  | None => DeviceType.defaultDefenceFlags // No override — all defences inactive
  }
}
