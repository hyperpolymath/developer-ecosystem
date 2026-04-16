// SPDX-License-Identifier: PMPL-1.0-or-later
// DroneTrainingGround  Archetype drone sandbox
//
// A dedicated training arena for the three drone archetypes from
// docs/design/drone-archetypes-spec.md:
//
//   Zone 1 (LEFT)  Helper Drone
//     Slow, tough, dumb. Attempts rescue of downed guard but gets
//     distracted by Moletaire. Demonstrates bad pathing, failed
//     pickups, hesitation. Hunter lidar guidance improves its focus.
//     Physically resilient  hard to hack, hard to destroy.
//
//   Zone 2 (MIDDLE)  Hunter Drone
//     Smart recon/command. 105 light cone, sonic circle, lidar beam,
//     flares, tuning forks. Coordinates guards and other drones.
//     Very fragile  easy to hack or physically break.
//
//   Zone 3 (RIGHT)  Killer Drone
//     Terrifyingly fast pursuit-and-kill. Narrow predator sight cone,
//     pulse sonar, environmental weapon improvisation, cloak,
//     snatch-and-drop (Moletaire). Diagonal movement. Agitation
//     escalation makes it reckless. Strong resilience.
//
// Each zone demonstrates the archetype's personality, strengths,
// weaknesses, and counterplay. The player can move between zones
// freely. Moletaire is present for distraction / snatch testing.
//
// See docs/design/drone-archetypes-spec.md for full design spec.

open Pixi

let absFloat = (x: float): float =>
  if x < 0.0 {
    -.x
  } else {
    x
  }

// ─────────────────────────────────────────────────────────
//  Archetype Tuning Constants
//  All gameplay-relevant numbers extracted here per spec.
//  "No magic numbers in logic  everything references Tuning."
// ─────────────────────────────────────────────────────────

module Tuning = {
  // Arena layout  three zones, one per archetype
  let arenaWidth = 2000.0
  let groundY = 500.0
  let droneAltitude = 350.0

  // Zone boundaries (x positions)
  let zone1Start = 50.0 // Helper zone
  let zone1End = 620.0
  let zone2Start = 680.0 // Hunter zone
  let zone2End = 1320.0
  let zone3Start = 1380.0 // Killer zone
  let zone3End = 1950.0

  // ── Helper Drone ──
  // "Strong but stupid"  slow, tough, bad at judgement
  let helperSpeed = 35.0 // Very slow (px/s)
  let helperDetectionRadius = 100.0
  let helperNoiseRadius = 80.0
  let helperBatteryDrain = 0.006
  let helperPhysicalHP = 5.0 // Toughest drone physically
  let helperHackResistance = 0.8 // Mostly immune to hacks (0-1, higher = harder)
  let helperMoletaireDistractionRange = 250.0 // Very distractible by Moletaire
  let helperRescueDuration = 8.0 // Seconds  very slow rescue
  let helperPathHesitationChance = 0.3 // 30% chance to hesitate each decision
  let helperRescueFailChance = 0.2 // 20% chance to botch a rescue attempt
  let helperLidarFocusBonus = 0.6 // When hunter lidar guides: hesitation reduced by this factor

  // ── Hunter Drone ──
  // "Smart but fragile"  good AI, broad sensors, breakable
  let hunterSpeed = 80.0
  let hunterDetectionRadius = 140.0
  let hunterNoiseRadius = 120.0
  let hunterBatteryDrain = 0.012
  let hunterPhysicalHP = 1.0 // Most fragile
  let hunterHackResistance = 0.2 // Very hackable
  let hunterLightConeAngle = 105.0 // Degrees  broad directional cone
  let hunterSonicRadius = 200.0 // Circular sound/vibration zone
  let hunterLidarRange = 400.0 // Precise ranging beam
  let hunterFlareRadius = 300.0 // Area illuminated by flare
  let hunterFlareDuration = 6.0 // Seconds
  let hunterTuningForkRadius = 150.0 // Sound confusion range
  let hunterTuningForkDuration = 8.0
  let hunterMemoryDuration = 30.0 // Seconds of short-term memory

  // ── Killer Drone ──
  // "Lethal, focused, predictable because obsessive"
  let killerSpeed = 160.0 // Very fast
  let killerPursuitSpeed = 220.0 // Even faster in pursuit
  let killerDetectionRadius = 60.0 // Narrow but long-range
  let killerNoiseRadius = 160.0
  let killerBatteryDrain = 0.018
  let killerPhysicalHP = 3.5 // Strong but not as tough as helper
  let killerHackResistance = 0.6 // Moderately resistant
  let killerPassiveConeAngle = 50.0 // Degrees  passive mode
  let killerPursuitConeAngle = 30.0 // Degrees  pursuit mode (very narrow)
  let killerPursuitRange = 3.0 // Multiplier of normal guard sight distance
  let killerSonarRadius = 300.0 // Active pulse sonar
  let killerCloakDuration = 4.0 // Seconds stationary cloak
  let killerAgitationDecay = 0.05 // Per second
  let killerAgitationThreshold = 0.6 // Above this  reckless behaviour
  let killerPatienceTimer = 10.0 // Seconds before forcing entry
  let killerSnatchRange = 40.0 // Range to grab Moletaire
  let killerDropHeight = 300.0 // Height for snatch-drop attack
}

// ─────────────────────────────────────────────────────────
//  Archetype-Specific State
//  Each archetype carries extra state beyond base Drone.t
// ─────────────────────────────────────────────────────────

type helperState = {
  mutable rescueAttempts: int,
  mutable rescueFails: int,
  mutable distractedByMole: bool,
  mutable hesitating: bool,
  mutable hesitateTimer: float,
  mutable lidarGuided: bool, // Hunter is actively guiding this helper
}

type hunterToolState =
  | ToolIdle
  | LidarLock(float) // Locked onto target at x position
  | FlareActive(float, float) // (x, remainingDuration)
  | TuningForkActive(float, float) // (x, remainingDuration)

type hunterState = {
  mutable currentTool: hunterToolState,
  mutable recentSearches: array<float>, // X positions recently checked
  mutable adaptationCount: int, // How many times fooled  reduces repeat mistakes
  mutable sonicDetections: int,
}

type killerBehaviourMode =
  | Passive // Patient, waiting
  | Pursuit // Active chase
  | Agitated // Reckless, collateral-tolerant
  | Cloaked // Invisible, stationary

type killerState = {
  mutable mode: killerBehaviourMode,
  mutable agitation: float, // 0.0 to 1.0
  mutable cloakTimer: float, // Remaining cloak duration
  mutable patienceTimer: float, // Countdown before forcing entry
  mutable snatchingMole: bool, // Currently carrying Moletaire
  mutable snatchHeight: float, // Current lift height
  mutable environmentWeaponCooldown: float,
  mutable lastKnownTargetPath: array<float>, // Recent target x positions
}

// ─────────────────────────────────────────────────────────
//  Training Ground State
// ─────────────────────────────────────────────────────────

type droneGroundState = {
  // Base drone entities (use existing Drone module)
  mutable helperDrone: option<Drone.t>,
  mutable hunterDrone: option<Drone.t>,
  mutable killerDrone: option<Drone.t>,
  // Archetype-specific state
  mutable helperExtra: helperState,
  mutable hunterExtra: hunterState,
  mutable killerExtra: killerState,
  // Moletaire for distraction / snatch testing
  mutable mole: option<Moletaire.t>,
  // Downed guard in helper zone (rescue target)
  mutable downedGuardX: float,
  mutable downedGuardRescued: bool,
  // Zone label graphics
  mutable zoneLabelGraphics: array<Text.t>,
  // Status display
  mutable statusText: option<Text.t>,
  // Agitation demo trigger
  mutable agitationTriggerTimer: float,
  // Flare visual
  mutable flareGraphic: option<Graphics.t>,
  // Lidar beam visual
  mutable lidarGraphic: option<Graphics.t>,
  // Killer cloak visual (alpha overlay)
  mutable killerCloakAlpha: float,
}

let makeGroundState = (): droneGroundState => {
  helperDrone: None,
  hunterDrone: None,
  killerDrone: None,
  helperExtra: {
    rescueAttempts: 0,
    rescueFails: 0,
    distractedByMole: false,
    hesitating: false,
    hesitateTimer: 0.0,
    lidarGuided: false,
  },
  hunterExtra: {
    currentTool: ToolIdle,
    recentSearches: [],
    adaptationCount: 0,
    sonicDetections: 0,
  },
  killerExtra: {
    mode: Passive,
    agitation: 0.0,
    cloakTimer: 0.0,
    patienceTimer: Tuning.killerPatienceTimer,
    snatchingMole: false,
    snatchHeight: 0.0,
    environmentWeaponCooldown: 0.0,
    lastKnownTargetPath: [],
  },
  mole: None,
  downedGuardX: 350.0,
  downedGuardRescued: false,
  zoneLabelGraphics: [],
  statusText: None,
  agitationTriggerTimer: 0.0,
  flareGraphic: None,
  lidarGraphic: None,
  killerCloakAlpha: 1.0,
}

// ─────────────────────────────────────────────────────────
//  Arena Decorations
// ─────────────────────────────────────────────────────────

let drawZoneDividers = (worldContainer: Container.t): unit => {
  let divider1 = Graphics.make()
  let _ =
    divider1
    ->Graphics.moveTo(Tuning.zone1End +. 30.0, 0.0)
    ->Graphics.lineTo(Tuning.zone1End +. 30.0, Tuning.groundY)
    ->Graphics.stroke({"color": 0x334455, "width": 2.0})
  let _ = Container.addChildGraphics(worldContainer, divider1)

  let divider2 = Graphics.make()
  let _ =
    divider2
    ->Graphics.moveTo(Tuning.zone2End +. 30.0, 0.0)
    ->Graphics.lineTo(Tuning.zone2End +. 30.0, Tuning.groundY)
    ->Graphics.stroke({"color": 0x334455, "width": 2.0})
  let _ = Container.addChildGraphics(worldContainer, divider2)
}

let drawZoneLabels = (worldContainer: Container.t): array<Text.t> => {
  let makeLabel = (~text: string, ~x: float, ~color: int) => {
    let label = Text.make({
      "text": text,
      "style": {
        "fontFamily": "monospace",
        "fontSize": 14,
        "fill": color,
        "fontWeight": "bold",
      },
    })
    ObservablePoint.set(Text.anchor(label), 0.5, ~y=0.0)
    Text.setX(label, x)
    Text.setY(label, Tuning.groundY +. 12.0)
    let _ = Container.addChildText(worldContainer, label)
    label
  }

  let helperLabel = makeLabel(
    ~text="HELPER ZONE  Strong but Stupid",
    ~x=(Tuning.zone1Start +. Tuning.zone1End) /. 2.0,
    ~color=0x44ffaa,
  )
  let hunterLabel = makeLabel(
    ~text="HUNTER ZONE  Smart but Fragile",
    ~x=(Tuning.zone2Start +. Tuning.zone2End) /. 2.0,
    ~color=0x44aaff,
  )
  let killerLabel = makeLabel(
    ~text="KILLER ZONE  Fast and Lethal",
    ~x=(Tuning.zone3Start +. Tuning.zone3End) /. 2.0,
    ~color=0xff4444,
  )

  [helperLabel, hunterLabel, killerLabel]
}

// Draw the downed guard that the helper drone tries to rescue
let drawDownedGuard = (worldContainer: Container.t, ~x: float): unit => {
  let gfx = Graphics.make()
  // Fallen guard silhouette (lying on ground)
  let _ =
    gfx
    ->Graphics.rect(x -. 15.0, Tuning.groundY -. 8.0, 30.0, 8.0)
    ->Graphics.fill({"color": 0x44aa44, "alpha": 0.6})
  // "!" indicator
  let _ =
    gfx
    ->Graphics.circle(x, Tuning.groundY -. 20.0, 8.0)
    ->Graphics.fill({"color": 0xff4444, "alpha": 0.7})
  let _ = Container.addChildGraphics(worldContainer, gfx)

  let label = Text.make({
    "text": "DOWNED GUARD",
    "style": {"fontSize": 10, "fill": 0xff8866, "fontStyle": "italic"},
  })
  ObservablePoint.set(Text.anchor(label), 0.5, ~y=1.0)
  Text.setX(label, x)
  Text.setY(label, Tuning.groundY -. 32.0)
  let _ = Container.addChildText(worldContainer, label)
}

// Draw archetype stat cards in each zone
let drawArchetypeCard = (
  worldContainer: Container.t,
  ~x: float,
  ~title: string,
  ~stats: array<string>,
  ~color: int,
): unit => {
  let cardBg = Graphics.make()
  let cardW = 200.0
  let cardH = 20.0 +. Int.toFloat(Array.length(stats)) *. 14.0
  let _ =
    cardBg
    ->Graphics.roundRect(x -. cardW /. 2.0, 20.0, cardW, cardH, 6.0)
    ->Graphics.fill({"color": 0x000000, "alpha": 0.5})
    ->Graphics.stroke({"width": 1, "color": color})
  let _ = Container.addChildGraphics(worldContainer, cardBg)

  let titleText = Text.make({
    "text": title,
    "style": {"fontFamily": "monospace", "fontSize": 12, "fill": color, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(titleText), 0.5, ~y=0.0)
  Text.setX(titleText, x)
  Text.setY(titleText, 24.0)
  let _ = Container.addChildText(worldContainer, titleText)

  Array.forEachWithIndex(stats, (stat, i) => {
    let statText = Text.make({
      "text": stat,
      "style": {"fontFamily": "monospace", "fontSize": 10, "fill": 0xaaaaaa},
    })
    ObservablePoint.set(Text.anchor(statText), 0.5, ~y=0.0)
    Text.setX(statText, x)
    Text.setY(statText, 38.0 +. Int.toFloat(i) *. 14.0)
    let _ = Container.addChildText(worldContainer, statText)
  })
}

// Draw a door obstacle in the killer zone (killer waits or smashes)
let drawDoor = (worldContainer: Container.t, ~x: float): unit => {
  let door = Graphics.make()
  let _ =
    door
    ->Graphics.rect(x -. 8.0, Tuning.groundY -. 50.0, 16.0, 50.0)
    ->Graphics.fill({"color": 0x664422})
    ->Graphics.stroke({"width": 2, "color": 0x886644})
  let _ = Container.addChildGraphics(worldContainer, door)

  let label = Text.make({
    "text": "DOOR",
    "style": {"fontSize": 9, "fill": 0x886644},
  })
  ObservablePoint.set(Text.anchor(label), 0.5, ~y=1.0)
  Text.setX(label, x)
  Text.setY(label, Tuning.groundY -. 54.0)
  let _ = Container.addChildText(worldContainer, label)
}

// ─────────────────────────────────────────────────────────
//  Helper Drone Archetype Behaviour
//  "Intentionally dumb. Stubborn, literal, rescue-capable."
// ─────────────────────────────────────────────────────────

let updateHelperArchetype = (
  ts: droneGroundState,
  drone: Drone.t,
  ~moleX: option<float>,
  ~dt: float,
): unit => {
  let extra = ts.helperExtra

  // Hesitation: randomly pause decision-making
  if extra.hesitating {
    extra.hesitateTimer = extra.hesitateTimer -. dt
    if extra.hesitateTimer <= 0.0 {
      extra.hesitating = false
    }
  } else {
    // Roll for hesitation each second
    let hesitateChance = if extra.lidarGuided {
      Tuning.helperPathHesitationChance *. (1.0 -. Tuning.helperLidarFocusBonus)
    } else {
      Tuning.helperPathHesitationChance
    }
    if Math.random() < hesitateChance *. dt {
      extra.hesitating = true
      extra.hesitateTimer = 1.0 +. Math.random() *. 2.0 // 1-3s hesitation
    }
  }

  // Moletaire distraction: if mole is visible and helper isn't deeply committed
  switch moleX {
  | Some(mx) =>
    if !extra.hesitating {
      let distToMole = absFloat(mx -. drone.x)
      if (
        distToMole < Tuning.helperMoletaireDistractionRange &&
        !Drone.isHelperBusy(drone) &&
        !extra.lidarGuided &&
        Math.random() < 0.4 *. dt // 40%/s chance to get distracted
      ) {
        extra.distractedByMole = true
        // Helper follows Moletaire instead of doing its job
        drone.lastKnownPlayerX = Some(mx)
        drone.state = Drone.Tracking
      }
    }
  | None => extra.distractedByMole = false
  }

  // Rescue attempt failure: when near downed guard, may botch the pickup
  if Drone.isHelperBusy(drone) && !extra.lidarGuided {
    if Math.random() < Tuning.helperRescueFailChance *. dt *. 0.5 {
      // Botched! Aborts rescue and flies away briefly
      extra.rescueFails = extra.rescueFails + 1
      drone.helperTaskTarget = None
      drone.state = Drone.Patrolling
    }
  }
}

// ─────────────────────────────────────────────────────────
//  Hunter Drone Archetype Behaviour
//  "Brains of coordination. Advanced AI, fragile hardware."
// ─────────────────────────────────────────────────────────

let updateHunterArchetype = (
  ts: droneGroundState,
  drone: Drone.t,
  ~playerX: float,
  ~dt: float,
): unit => {
  let extra = ts.hunterExtra

  // Cycle through tools on a timer to demonstrate capabilities
  switch extra.currentTool {
  | ToolIdle =>
    // Every few seconds, activate a random tool
    if Math.random() < 0.15 *. dt {
      let roll = Math.random()
      if roll < 0.4 {
        // Lidar lock on player's last known position
        extra.currentTool = LidarLock(playerX)
        // Guide the helper drone if it exists
        ts.helperExtra.lidarGuided = true
      } else if roll < 0.7 {
        // Deploy flare
        extra.currentTool = FlareActive(drone.x, Tuning.hunterFlareDuration)
      } else {
        // Deploy tuning fork
        extra.currentTool = TuningForkActive(drone.x, Tuning.hunterTuningForkDuration)
      }
    }

  | LidarLock(targetX) =>
    // Maintain lidar lock  track player position
    let _ = targetX // Used for beam rendering
    // Break lock after a while or if drone is jammed
    if drone.state == Drone.Jammed || drone.state == Drone.Disabled {
      extra.currentTool = ToolIdle
      ts.helperExtra.lidarGuided = false
    } else if Math.random() < 0.08 *. dt {
      extra.currentTool = ToolIdle
      ts.helperExtra.lidarGuided = false
    } else {
      // Update lock position
      extra.currentTool = LidarLock(playerX)
    }

  | FlareActive(x, remaining) =>
    let newRemaining = remaining -. dt
    if newRemaining <= 0.0 {
      extra.currentTool = ToolIdle
    } else {
      extra.currentTool = FlareActive(x, newRemaining)
    }

  | TuningForkActive(x, remaining) =>
    let newRemaining = remaining -. dt
    if newRemaining <= 0.0 {
      extra.currentTool = ToolIdle
    } else {
      extra.currentTool = TuningForkActive(x, newRemaining)
    }
  }

  // Sonic detection  circular hearing zone
  let playerDist = absFloat(playerX -. drone.x)
  if playerDist < Tuning.hunterSonicRadius {
    extra.sonicDetections = extra.sonicDetections + 1
  }

  // Adaptation  hunter remembers where it searched
  if Array.length(extra.recentSearches) > 10 {
    let _ = Array.shift(extra.recentSearches) // Drop oldest
  }
  if drone.state == Drone.Hovering || drone.state == Drone.Tracking {
    let _ = Array.push(extra.recentSearches, drone.x)
  }
}

// ─────────────────────────────────────────────────────────
//  Killer Drone Archetype Behaviour
//  "Terrifyingly fast. Narrow focus. Predictable obsession."
// ─────────────────────────────────────────────────────────

let updateKillerArchetype = (
  ts: droneGroundState,
  drone: Drone.t,
  ~playerX: float,
  ~playerY: float,
  ~moleX: option<float>,
  ~dt: float,
): unit => {
  let extra = ts.killerExtra

  // Agitation decay
  extra.agitation = Math.max(0.0, extra.agitation -. Tuning.killerAgitationDecay *. dt)

  // Agitation triggers
  // - player escapes pursuit repeatedly
  if drone.state == Drone.Tracking {
    let dist = absFloat(playerX -. drone.x)
    if dist > 300.0 {
      extra.agitation = Math.min(1.0, extra.agitation +. 0.1 *. dt) // Target escaping
    }
    // Track last known path
    if Array.length(extra.lastKnownTargetPath) > 20 {
      let _ = Array.shift(extra.lastKnownTargetPath)
    }
    let _ = Array.push(extra.lastKnownTargetPath, playerX)
  }

  // Demo: periodic agitation spikes (simulating allied damage)
  ts.agitationTriggerTimer = ts.agitationTriggerTimer +. dt
  if ts.agitationTriggerTimer > 15.0 {
    ts.agitationTriggerTimer = 0.0
    extra.agitation = Math.min(1.0, extra.agitation +. 0.3)
  }

  // Mode transitions based on agitation and state
  let prevMode = extra.mode
  if extra.cloakTimer > 0.0 {
    extra.mode = Cloaked
    extra.cloakTimer = extra.cloakTimer -. dt
    ts.killerCloakAlpha = 0.15 // Nearly invisible
    if extra.cloakTimer <= 0.0 {
      extra.mode = Passive
      ts.killerCloakAlpha = 1.0
    }
  } else if extra.agitation > Tuning.killerAgitationThreshold {
    extra.mode = Agitated
    ts.killerCloakAlpha = 1.0
    // Agitated: faster, more reckless
    // Override drone speed temporarily
    if drone.state == Drone.Tracking || drone.state == Drone.Spotlighting {
      // Move faster toward target
      let dx = playerX -. drone.x
      let dir = if dx > 0.0 { 1.0 } else { -1.0 }
      drone.x = drone.x +. dir *. (Tuning.killerPursuitSpeed -. Tuning.killerSpeed) *. dt
    }
  } else if drone.state == Drone.Tracking || drone.state == Drone.Spotlighting {
    extra.mode = Pursuit
    ts.killerCloakAlpha = 1.0
  } else {
    // Passive: may cloak if stationary long enough
    if (
      prevMode == Passive &&
      extra.patienceTimer > 0.0 &&
      drone.state == Drone.Hovering
    ) {
      extra.patienceTimer = extra.patienceTimer -. dt
      if extra.patienceTimer <= 0.0 && extra.cloakTimer <= 0.0 {
        // Cloak for ambush
        extra.cloakTimer = Tuning.killerCloakDuration
        extra.patienceTimer = Tuning.killerPatienceTimer
      }
    } else {
      extra.patienceTimer = Tuning.killerPatienceTimer
    }
    extra.mode = Passive
    ts.killerCloakAlpha = 1.0
  }

  // Environmental weapon cooldown
  if extra.environmentWeaponCooldown > 0.0 {
    extra.environmentWeaponCooldown = extra.environmentWeaponCooldown -. dt
  }

  // Snatch-and-drop Moletaire
  if extra.snatchingMole {
    extra.snatchHeight = extra.snatchHeight +. 120.0 *. dt
    if extra.snatchHeight >= Tuning.killerDropHeight {
      // Drop!
      extra.snatchingMole = false
      extra.snatchHeight = 0.0
    }
  } else {
    switch moleX {
    | Some(mx) =>
      if (
        extra.mode == Pursuit &&
        absFloat(mx -. drone.x) < Tuning.killerSnatchRange &&
        extra.environmentWeaponCooldown <= 0.0
      ) {
        extra.snatchingMole = true
        extra.snatchHeight = 0.0
        extra.environmentWeaponCooldown = 12.0
      }
    | None => ()
    }
  }

  // Apply cloak alpha to drone container
  switch ts.killerDrone {
  | Some(kd) => Container.setAlpha(kd.container, ts.killerCloakAlpha)
  | None => ()
  }

  ignore(playerY) // Used for future vertical pursuit
}

// ─────────────────────────────────────────────────────────
//  Status Display
// ─────────────────────────────────────────────────────────

let updateStatusDisplay = (ts: droneGroundState): unit => {
  switch ts.statusText {
  | Some(text) => {
      let helperStr = switch ts.helperDrone {
      | Some(h) =>
        let state = Drone.stateToString(h)
        let distracted = if ts.helperExtra.distractedByMole { " DISTRACTED!" } else { "" }
        let guided = if ts.helperExtra.lidarGuided { " [LIDAR GUIDED]" } else { "" }
        let hesitate = if ts.helperExtra.hesitating { " (hesitating...)" } else { "" }
        `Helper: ${state}${distracted}${guided}${hesitate} | Rescues failed: ${Int.toString(ts.helperExtra.rescueFails)}`
      | None => "Helper: --"
      }

      let hunterStr = switch ts.hunterDrone {
      | Some(h) =>
        let state = Drone.stateToString(h)
        let tool = switch ts.hunterExtra.currentTool {
        | ToolIdle => ""
        | LidarLock(_) => " [LIDAR LOCK]"
        | FlareActive(_, r) => ` [FLARE ${Float.toFixed(r, ~digits=1)}s]`
        | TuningForkActive(_, r) => ` [TUNING FORK ${Float.toFixed(r, ~digits=1)}s]`
        }
        `Hunter: ${state}${tool} | Sonic detections: ${Int.toString(ts.hunterExtra.sonicDetections)}`
      | None => "Hunter: --"
      }

      let killerStr = switch ts.killerDrone {
      | Some(k) =>
        let state = Drone.stateToString(k)
        let modeStr = switch ts.killerExtra.mode {
        | Passive => "PASSIVE"
        | Pursuit => "PURSUIT"
        | Agitated => "AGITATED!"
        | Cloaked => "CLOAKED"
        }
        let agitPct = Int.toString(Float.toInt(ts.killerExtra.agitation *. 100.0))
        let snatch = if ts.killerExtra.snatchingMole { " [SNATCHING MOLE!]" } else { "" }
        `Killer: ${state} Mode:${modeStr} Agitation:${agitPct}%${snatch}`
      | None => "Killer: --"
      }

      Text.setText(text, `${helperStr}\n${hunterStr}\n${killerStr}`)
    }
  | None => ()
  }
}

// ─────────────────────────────────────────────────────────
//  Render Overlays
//  Flare illumination, lidar beam, sonic circle, etc.
// ─────────────────────────────────────────────────────────

let renderOverlays = (ts: droneGroundState, worldContainer: Container.t): unit => {
  // Flare  bright circle on ground
  switch ts.flareGraphic {
  | Some(gfx) => {
      let _ = Graphics.clear(gfx)
      switch ts.hunterExtra.currentTool {
      | FlareActive(x, remaining) =>
        let alpha = Math.min(0.3, remaining /. Tuning.hunterFlareDuration *. 0.3)
        let _ =
          gfx
          ->Graphics.circle(x, Tuning.groundY -. 50.0, Tuning.hunterFlareRadius)
          ->Graphics.fill({"color": 0xffffaa, "alpha": alpha})
        // Flare source (small bright dot high up)
        let _ =
          gfx
          ->Graphics.circle(x, 100.0, 6.0)
          ->Graphics.fill({"color": 0xffff44})
      | _ => ()
      }
    }
  | None =>
    let gfx = Graphics.make()
    let _ = Container.addChildGraphics(worldContainer, gfx)
    ts.flareGraphic = Some(gfx)
  }

  // Lidar beam  thin green line from hunter to target
  switch ts.lidarGraphic {
  | Some(gfx) => {
      let _ = Graphics.clear(gfx)
      switch (ts.hunterDrone, ts.hunterExtra.currentTool) {
      | (Some(hunter), LidarLock(targetX)) =>
        let _ =
          gfx
          ->Graphics.moveTo(hunter.x, hunter.y)
          ->Graphics.lineTo(targetX, Tuning.groundY)
          ->Graphics.stroke({"color": 0x00ff44, "width": 1.5})
        // Target reticle
        let _ =
          gfx
          ->Graphics.circle(targetX, Tuning.groundY -. 5.0, 8.0)
          ->Graphics.stroke({"color": 0x00ff44, "width": 1.0})
      | _ => ()
      }
    }
  | None =>
    let gfx = Graphics.make()
    let _ = Container.addChildGraphics(worldContainer, gfx)
    ts.lidarGraphic = Some(gfx)
  }
}

// ─────────────────────────────────────────────────────────
//  Training Config
// ─────────────────────────────────────────────────────────

let config: TrainingBase.trainingConfig = {
  title: GameI18n.t("training.droneground.title"),
  instructions: [
    GameI18n.t("training.droneground.line1"),
    GameI18n.t("training.droneground.line2"),
    GameI18n.t("training.droneground.line3"),
    GameI18n.t("training.droneground.line4"),
  ],
  arenaWidth: Tuning.arenaWidth,
  groundY: Tuning.groundY,
}

let legendEntries: array<TrainingBase.legendEntry> = [
  {
    color: 0x44ffaa,
    name: "Helper",
    desc: "Slow, tough, dumb. Rescue/repair.",
  },
  {
    color: 0x44aaff,
    name: "Hunter",
    desc: "Smart, fragile. Lidar, flares, forks.",
  },
  {
    color: 0xff4444,
    name: "Killer",
    desc: "Fast, lethal. Cloak, snatch, smash.",
  },
]

// ─────────────────────────────────────────────────────────
//  Entity Setup
// ─────────────────────────────────────────────────────────

let stateRef: ref<option<droneGroundState>> = ref(None)

let setupEntities = (gameState: GameLoop.gameState, worldContainer: Container.t): unit => {
  let ts = makeGroundState()

  // Draw arena decorations
  drawZoneDividers(worldContainer)
  ts.zoneLabelGraphics = drawZoneLabels(worldContainer)

  // Archetype stat cards
  drawArchetypeCard(
    worldContainer,
    ~x=(Tuning.zone1Start +. Tuning.zone1End) /. 2.0,
    ~title="HELPER ARCHETYPE",
    ~stats=[
      "Speed: VERY SLOW (35px/s)",
      "Physical: VERY TOUGH (5 HP)",
      "Hack resist: HIGH (80%)",
      "AI quality: WEAK planner",
      "Distracted by: Moletaire",
      "Counterplay: Lure, confuse, waste time",
    ],
    ~color=0x44ffaa,
  )
  drawArchetypeCard(
    worldContainer,
    ~x=(Tuning.zone2Start +. Tuning.zone2End) /. 2.0,
    ~title="HUNTER ARCHETYPE",
    ~stats=[
      "Speed: MODERATE (80px/s)",
      "Physical: VERY FRAGILE (1 HP)",
      "Hack resist: LOW (20%)",
      "AI quality: STRONG planner",
      "Tools: Lidar, flares, tuning forks",
      "Counterplay: Scramble, break, bait",
    ],
    ~color=0x44aaff,
  )
  drawArchetypeCard(
    worldContainer,
    ~x=(Tuning.zone3Start +. Tuning.zone3End) /. 2.0,
    ~title="KILLER ARCHETYPE",
    ~stats=[
      "Speed: VERY FAST (160-220px/s)",
      "Physical: STRONG (3.5 HP)",
      "Hack resist: MODERATE (60%)",
      "AI quality: NARROW but strong",
      "Special: Cloak, snatch, env weapons",
      "Counterplay: Predict, bait agitation",
    ],
    ~color=0xff4444,
  )

  // Downed guard in helper zone (rescue target)
  drawDownedGuard(worldContainer, ~x=ts.downedGuardX)

  // Door in killer zone (patience test)
  drawDoor(worldContainer, ~x=1600.0)

  // ── Helper Drone (EMP_Drone variant, repurposed) ──
  let helperDrone = Drone.make(
    ~id="ground_helper",
    ~variant=EMP_Drone,
    ~x=300.0,
    ~y=Tuning.droneAltitude,
    ~groundY=Tuning.groundY,
    ~waypoints=[
      {x: Tuning.zone1Start +. 80.0, hoverDurationSec: 4.0},
      {x: Tuning.zone1End -. 80.0, hoverDurationSec: 4.0},
    ],
    ~chargingPadX=Tuning.zone1Start +. 50.0,
    (),
  )
  helperDrone.empPayloadAvailable = false
  let _ = Container.addChild(worldContainer, helperDrone.container)
  ts.helperDrone = Some(helperDrone)

  // ── Hunter Drone (Recon variant, upgraded behaviour) ──
  let hunterDrone = Drone.make(
    ~id="ground_hunter",
    ~variant=Recon,
    ~x=1000.0,
    ~y=Tuning.droneAltitude,
    ~groundY=Tuning.groundY,
    ~waypoints=[
      {x: Tuning.zone2Start +. 80.0, hoverDurationSec: 3.0},
      {x: Tuning.zone2End -. 80.0, hoverDurationSec: 3.0},
    ],
    ~chargingPadX=Tuning.zone2End -. 50.0,
    (),
  )
  let _ = Container.addChild(worldContainer, hunterDrone.container)
  ts.hunterDrone = Some(hunterDrone)

  // ── Killer Drone (Pursuit variant, upgraded behaviour) ──
  let killerDrone = Drone.make(
    ~id="ground_killer",
    ~variant=Pursuit,
    ~x=1650.0,
    ~y=Tuning.droneAltitude,
    ~groundY=Tuning.groundY,
    ~waypoints=[
      {x: Tuning.zone3Start +. 80.0, hoverDurationSec: 2.0},
      {x: Tuning.zone3End -. 80.0, hoverDurationSec: 1.5},
    ],
    ~chargingPadX=Tuning.zone3End -. 50.0,
    (),
  )
  let _ = Container.addChild(worldContainer, killerDrone.container)
  ts.killerDrone = Some(killerDrone)

  // ── Moletaire (for distraction / snatch testing) ──
  let moleEquip: Moletaire.equipmentLoadout = {head: None, body: NoBody}
  let mole = Moletaire.make(~id="ground_mole", ~x=200.0, ~y=Tuning.groundY, ~equipment=moleEquip)
  let _ = Container.addChild(worldContainer, mole.container)
  ts.mole = Some(mole)

  // ── Guard in hunter zone (for coordination demo) ──
  let guards = [
    GuardNPC.make(
      ~id="ground_guard1",
      ~rank=BasicGuard,
      ~x=900.0,
      ~y=Tuning.groundY,
      ~waypoints=[
        {x: Tuning.zone2Start +. 30.0, pauseDurationSec: 3.0},
        {x: Tuning.zone2End -. 30.0, pauseDurationSec: 3.0},
      ],
    ),
  ]
  gameState.guards = guards

  // Status text
  let statusText = Text.make({
    "text": "",
    "style": {"fontFamily": "monospace", "fontSize": 11, "fill": 0xaabbcc},
  })
  Text.setX(statusText, 20.0)
  Text.setY(statusText, Tuning.groundY +. 35.0)
  let _ = Container.addChildText(worldContainer, statusText)
  ts.statusText = Some(statusText)

  stateRef := Some(ts)
}

// ─────────────────────────────────────────────────────────
//  Per-Frame Update
// ─────────────────────────────────────────────────────────

let onUpdate = (
  player: Player.t,
  keyState: WorldBuilder.keyState,
  _hud: HUD.t,
  gameState: GameLoop.gameState,
  worldContainer: Container.t,
  dt: float,
): TrainingBase.trainingResult => {
  switch stateRef.contents {
  | None => Continue
  | Some(ts) => {
      let playerX = Player.getX(player)
      let playerY = Player.getY(player)
      let playerCrouching = keyState.crouch

      // Get mole position for distraction/snatch checks
      let moleX = switch ts.mole {
      | Some(m) => Some(m.x)
      | None => None
      }

      // ── Update Moletaire ──
      switch ts.mole {
      | Some(mole) => {
          // Simple mole control (J/K keys)
          if keyState.moleLeft {
            mole.x = Math.max(50.0, mole.x -. 150.0 *. dt)
            mole.facing = Moletaire.Left
          }
          if keyState.moleRight {
            mole.x = Math.min(Tuning.arenaWidth -. 50.0, mole.x +. 150.0 *. dt)
            mole.facing = Moletaire.Right
          }
          let _ = Moletaire.update(mole, ~dt)
        }
      | None => ()
      }

      // ── Update Helper Drone ──
      switch ts.helperDrone {
      | Some(helper) => {
          let _ = Drone.update(
            helper,
            ~dt,
            ~playerX,
            ~playerY,
            ~playerCrouching,
            ~alertLevel=0,
          )
          updateHelperArchetype(ts, helper, ~moleX, ~dt)

          // Auto-attempt rescue of downed guard when nearby
          if (
            !ts.downedGuardRescued &&
            !Drone.isHelperBusy(helper) &&
            !ts.helperExtra.distractedByMole &&
            !ts.helperExtra.hesitating &&
            absFloat(helper.x -. ts.downedGuardX) < 150.0
          ) {
            let ordered = Drone.orderRescue(
              helper,
              ~targetX=ts.downedGuardX,
              ~targetId="downed_guard",
            )
            if ordered {
              ts.helperExtra.rescueAttempts = ts.helperExtra.rescueAttempts + 1
            }
          }
        }
      | None => ()
      }

      // ── Update Hunter Drone ──
      switch ts.hunterDrone {
      | Some(hunter) => {
          let _ = Drone.update(
            hunter,
            ~dt,
            ~playerX,
            ~playerY,
            ~playerCrouching,
            ~alertLevel=2,
          )
          updateHunterArchetype(ts, hunter, ~playerX, ~dt)

          // Hunter alerts guards when it detects the player
          let detection = Drone.detectPlayer(hunter, ~playerX, ~playerY, ~playerCrouching)
          switch detection {
          | Drone.InDetectionZone(_) | Drone.SpotlightLock =>
            Array.forEach(gameState.guards, guard => {
              if guard.x >= Tuning.zone2Start && guard.x <= Tuning.zone2End {
                guard.lastKnownPlayerX = Some(playerX)
                if guard.suspicion < 0.8 {
                  guard.suspicion = guard.suspicion +. 0.3 *. dt
                }
              }
            })
          | Drone.NotDetected => ()
          }
        }
      | None => ()
      }

      // ── Update Killer Drone ──
      switch ts.killerDrone {
      | Some(killer) => {
          let _ = Drone.update(
            killer,
            ~dt,
            ~playerX,
            ~playerY,
            ~playerCrouching,
            ~alertLevel=3, // Always high alert
          )
          updateKillerArchetype(ts, killer, ~playerX, ~playerY, ~moleX, ~dt)
        }
      | None => ()
      }

      // ── Render overlays (flare, lidar, etc.) ──
      renderOverlays(ts, worldContainer)

      // ── Update status display ──
      updateStatusDisplay(ts)

      Continue
    }
  }
}

// ─────────────────────────────────────────────────────────
//  Screen Constructor
// ─────────────────────────────────────────────────────────

let constructorRef: ref<option<Navigation.appScreenConstructor>> = ref(None)

let make = (): Navigation.appScreen => {
  TrainingBase.makeTrainingScreen(
    config,
    ~setupEntities,
    ~onBack=TrainingBase.backToMenu,
    ~onReset=() => {
      stateRef := None
      switch (GetEngine.get(), constructorRef.contents) {
      | (Some(engine), Some(c)) => Navigation.showScreen(engine.navigation, c)->ignore
      | _ => ()
      }
    },
    ~onUpdate,
    ~selfConstructor=?constructorRef.contents,
    ~legendEntries,
  )
}

let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(["main"]),
}

let _ = constructorRef := Some(constructor)
