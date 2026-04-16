// SPDX-License-Identifier: PMPL-1.0-or-later
// DroneTraining  Drone encounter practice scenarios
//
// Three hover-drone types for the player to learn avoidance and tactics:
//
//   Surveillance Drone (Recon variant)
//     A flying vertical torch beam that sweeps downward, across, or up
//     depending on where it suspects intruders are hiding. Detection zone
//     projects onto the ground as a circular searchlight. The player must
//     stay out of the lit zone or crouch to reduce their detection profile.
//
//   Combat Drone (Pursuit variant)
//     Short-range but lethal — locks on with a targeting spotlight and
//     deals damage when in range. Fast, noisy, aggressive. The player
//     must use cover or sprint out of range before it locks on.
//
//   Helper Drone (EMP_Drone variant, repurposed)
//     Aids the security forces. Moves very slowly (35px/s). Abilities:
//       1. Alert guards — draws guards to Jessica's location ("!" indicator)
//       2. Building lift — slow-elevator platform up building side
//       3. Rescue — lifts guards/dogs from Moletaire pitfall traps (8s, very slow)
//       4. Repair — fixes disabled electronic devices (drones, robodogs) (6s)
//       5. Revive — revives knocked-out regular guards and dogs (4s)
//       6. Open doors — unlocks external doors for guards (3s)
//
// The demos are kept separate — each drone patrols its own zone in
// the arena so the player can study one behaviour at a time.

open Pixi

// ─────────────────────────────────────────────────────────
//  Tuning Constants
// ─────────────────────────────────────────────────────────

module Tuning = {
  // Arena layout — three zones, one per drone type
  let arenaWidth = 1600.0
  let groundY = 500.0
  let droneAltitude = 350.0 // Y position for drones (above ground)

  // Zone boundaries (x positions)
  let zone1Start = 50.0 // Surveillance zone
  let zone1End = 500.0
  let zone2Start = 550.0 // Combat zone
  let zone2End = 1000.0
  let zone3Start = 1050.0 // Helper zone
  let zone3End = 1550.0

  // Building for helper drone demo (in zone 3)
  let buildingX = 1250.0
  let buildingWidth = 80.0
  let buildingFloors = 3
  let buildingFloorHeight = 50.0

  // Helper drone vertical lift speed (px/s)
  let helperLiftSpeed = 30.0
  let helperLiftTopY = 320.0 // How high the lift goes
  let helperLiftBottomY = 490.0 // Ground-level lift start

  // Combat drone damage radius
  let combatDamageRadius = 60.0
  let combatDamageRate = 0.8 // Damage per second when in range

  // Surveillance drone searchlight sweep
  let searchlightSweepSpeed = 0.4 // Radians per second
  let searchlightMaxAngle = 0.6 // Max tilt from vertical (radians)
}

// ─────────────────────────────────────────────────────────
//  Helper Drone Lift State
//   Tracks the helper drone's vertical lift mechanic.
//   The drone ferries a "platform" up and down the building.
// ─────────────────────────────────────────────────────────

type liftDirection = GoingUp | GoingDown | Idle

type helperLiftState = {
  mutable liftY: float, // Current Y of the lift platform
  mutable direction: liftDirection,
  mutable playerOnLift: bool, // Player standing on lift platform
}

// ─────────────────────────────────────────────────────────
//  Training State
//   Per-instance state for the drone training scenario.
// ─────────────────────────────────────────────────────────

type droneTrainingState = {
  // The three drones (managed locally, not in GameLoop)
  mutable surveillanceDrone: option<Drone.t>,
  mutable combatDrone: option<Drone.t>,
  mutable helperDrone: option<Drone.t>,
  // Helper lift
  mutable lift: helperLiftState,
  // Searchlight sweep angle (for surveillance)
  mutable searchlightAngle: float,
  mutable searchlightDirection: float, // 1.0 or -1.0
  // Combat drone damage accumulator
  mutable combatDamageTimer: float,
  // Guard alert demo (for helper drone)
  mutable guardAlertTimer: float,
  mutable guardAlerted: bool,
  // Building graphic ref
  mutable buildingContainer: option<Container.t>,
  // Lift platform graphic
  mutable liftGraphic: option<Graphics.t>,
  // Zone label graphics (for resize)
  mutable zoneLabelGraphics: array<Text.t>,
}

let makeTrainingState = (): droneTrainingState => {
  surveillanceDrone: None,
  combatDrone: None,
  helperDrone: None,
  lift: {
    liftY: Tuning.helperLiftBottomY,
    direction: Idle,
    playerOnLift: false,
  },
  searchlightAngle: 0.0,
  searchlightDirection: 1.0,
  combatDamageTimer: 0.0,
  guardAlertTimer: 0.0,
  guardAlerted: false,
  buildingContainer: None,
  liftGraphic: None,
  zoneLabelGraphics: [],
}

// ─────────────────────────────────────────────────────────
//  Arena Decorations
// ─────────────────────────────────────────────────────────

// Draw zone divider lines on the arena floor
let drawZoneDividers = (worldContainer: Container.t): unit => {
  let divider1 = Graphics.make()
  let _ =
    divider1
    ->Graphics.moveTo(Tuning.zone1End +. 25.0, 0.0)
    ->Graphics.lineTo(Tuning.zone1End +. 25.0, Tuning.groundY)
    ->Graphics.stroke({"color": 0x334455, "width": 2.0})
  let _ = Container.addChildGraphics(worldContainer, divider1)

  let divider2 = Graphics.make()
  let _ =
    divider2
    ->Graphics.moveTo(Tuning.zone2End +. 25.0, 0.0)
    ->Graphics.lineTo(Tuning.zone2End +. 25.0, Tuning.groundY)
    ->Graphics.stroke({"color": 0x334455, "width": 2.0})
  let _ = Container.addChildGraphics(worldContainer, divider2)
}

// Draw zone labels ("SURVEILLANCE", "COMBAT", "HELPER")
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

  let survLabel = makeLabel(
    ~text="SURVEILLANCE ZONE",
    ~x=(Tuning.zone1Start +. Tuning.zone1End) /. 2.0,
    ~color=0x44aaff,
  )
  let combatLabel = makeLabel(
    ~text="COMBAT ZONE",
    ~x=(Tuning.zone2Start +. Tuning.zone2End) /. 2.0,
    ~color=0xff4444,
  )
  let helperLabel = makeLabel(
    ~text="HELPER ZONE",
    ~x=(Tuning.zone3Start +. Tuning.zone3End) /. 2.0,
    ~color=0x44ff88,
  )

  [survLabel, combatLabel, helperLabel]
}

// Draw the building in the helper zone for lift demonstration.
// 3-floor building with floor lines, labels, and a door.
let drawBuilding = (worldContainer: Container.t): Container.t => {
  let bldgContainer = Container.make()

  let totalHeight = Int.toFloat(Tuning.buildingFloors) *. Tuning.buildingFloorHeight
  let bldgTop = Tuning.groundY -. totalHeight

  // Building body (dark grey)
  let body = Graphics.make()
  let _ =
    body
    ->Graphics.rect(
      Tuning.buildingX,
      bldgTop,
      Tuning.buildingWidth,
      totalHeight,
    )
    ->Graphics.fill({"color": 0x2a2a3a})
    ->Graphics.stroke({"width": 2, "color": 0x444466})
  let _ = Container.addChildGraphics(bldgContainer, body)

  // Floor lines and labels
  for i in 1 to Tuning.buildingFloors - 1 {
    let floorY = Tuning.groundY -. Int.toFloat(i) *. Tuning.buildingFloorHeight
    let floorLine = Graphics.make()
    let _ =
      floorLine
      ->Graphics.moveTo(Tuning.buildingX, floorY)
      ->Graphics.lineTo(Tuning.buildingX +. Tuning.buildingWidth, floorY)
      ->Graphics.stroke({"color": 0x555577, "width": 1.0})
    let _ = Container.addChildGraphics(bldgContainer, floorLine)
  }

  // Floor labels (F1, F2, F3 from bottom)
  for i in 0 to Tuning.buildingFloors - 1 {
    let floorY =
      Tuning.groundY -. Int.toFloat(i) *. Tuning.buildingFloorHeight -. Tuning.buildingFloorHeight /. 2.0
    let label = Text.make({
      "text": `F${Int.toString(i + 1)}`,
      "style": {"fontFamily": "monospace", "fontSize": 10, "fill": 0x888899},
    })
    ObservablePoint.set(Text.anchor(label), 0.5, ~y=0.5)
    Text.setX(label, Tuning.buildingX +. Tuning.buildingWidth /. 2.0)
    Text.setY(label, floorY)
    let _ = Container.addChildText(bldgContainer, label)
  }

  // Door at ground level
  let door = Graphics.make()
  let doorW = 18.0
  let doorH = 30.0
  let _ =
    door
    ->Graphics.rect(
      Tuning.buildingX +. Tuning.buildingWidth /. 2.0 -. doorW /. 2.0,
      Tuning.groundY -. doorH,
      doorW,
      doorH,
    )
    ->Graphics.fill({"color": 0x665533})
    ->Graphics.stroke({"width": 1, "color": 0x886644})
  let _ = Container.addChildGraphics(bldgContainer, door)

  // Title above building
  let titleText = Text.make({
    "text": "LIFT DEMO",
    "style": {
      "fontFamily": "monospace",
      "fontSize": 11,
      "fill": 0x44ff88,
      "fontWeight": "bold",
    },
  })
  ObservablePoint.set(Text.anchor(titleText), 0.5, ~y=1.0)
  Text.setX(titleText, Tuning.buildingX +. Tuning.buildingWidth /. 2.0)
  Text.setY(titleText, bldgTop -. 5.0)
  let _ = Container.addChildText(bldgContainer, titleText)

  // "Also rescues guards from mole traps (very slow!)" annotation
  let rescueNote = Text.make({
    "text": "Rescue | Repair | Revive\nOpen doors (all very slow!)",
    "style": {
      "fontFamily": "monospace",
      "fontSize": 9,
      "fill": 0x66aa77,
      "fontStyle": "italic",
      "wordWrap": true,
      "wordWrapWidth": 160,
    },
  })
  ObservablePoint.set(Text.anchor(rescueNote), 0.0, ~y=0.0)
  Text.setX(rescueNote, Tuning.buildingX +. Tuning.buildingWidth +. 10.0)
  Text.setY(rescueNote, bldgTop +. 20.0)
  let _ = Container.addChildText(bldgContainer, rescueNote)

  let _ = Container.addChild(worldContainer, bldgContainer)
  bldgContainer
}

// Draw the lift platform (a small glowing platform on the building side)
let drawLiftPlatform = (worldContainer: Container.t, ~liftY: float): Graphics.t => {
  let liftGfx = Graphics.make()
  let platW = 30.0
  let platH = 6.0
  let platX = Tuning.buildingX -. platW -. 4.0 // Left side of building
  let _ =
    liftGfx
    ->Graphics.rect(platX, liftY -. platH /. 2.0, platW, platH)
    ->Graphics.fill({"color": 0x44ff88, "alpha": 0.7})
    ->Graphics.stroke({"width": 1, "color": 0x88ffbb})
  // Small "LIFT" label
  let _ =
    liftGfx
    ->Graphics.rect(platX +. 2.0, liftY -. platH /. 2.0 -. 10.0, 26.0, 10.0)
    ->Graphics.fill({"color": 0x000000, "alpha": 0.5})
  let _ = Container.addChildGraphics(worldContainer, liftGfx)
  liftGfx
}

// Draw a guard in the helper zone (static, for alert demo)
let drawDemoGuard = (worldContainer: Container.t, ~x: float, ~y: float): Graphics.t => {
  let guardGfx = Graphics.make()
  // Simple guard rectangle
  let _ =
    guardGfx
    ->Graphics.rect(x -. 10.0, y -. 35.0, 20.0, 35.0)
    ->Graphics.fill({"color": 0x44aa44})
    ->Graphics.stroke({"width": 1, "color": 0x66cc66})
  // Head
  let _ =
    guardGfx
    ->Graphics.circle(x, y -. 42.0, 8.0)
    ->Graphics.fill({"color": 0xddbb88})
  let _ = Container.addChildGraphics(worldContainer, guardGfx)
  guardGfx
}

// ─────────────────────────────────────────────────────────
//  Training Config
// ─────────────────────────────────────────────────────────

let config: TrainingBase.trainingConfig = {
  title: GameI18n.t("training.drone.title"),
  instructions: [
    GameI18n.t("training.drone.line1"),
    GameI18n.t("training.drone.line2"),
    GameI18n.t("training.drone.line3"),
    GameI18n.t("training.drone.line4"),
  ],
  arenaWidth: Tuning.arenaWidth,
  groundY: Tuning.groundY,
}

// Legend entries for the three drone types
let droneLegendEntries: array<TrainingBase.legendEntry> = [
  {
    color: 0x44aaff,
    name: "Surveillance",
    desc: "Searchlight beam, wide FOV",
  },
  {
    color: 0xff4444,
    name: "Combat",
    desc: "Short range, has firepower",
  },
  {
    color: 0x44ff88,
    name: "Helper",
    desc: "Very slow. Rescue, repair, revive, doors",
  },
]

// ─────────────────────────────────────────────────────────
//  Entity Setup
//   Spawns the 3 drones and arena decorations.
//   Drones are NOT added to GameLoop (no drones field).
//   Instead they are managed locally via the training state.
// ─────────────────────────────────────────────────────────

// Module-level training state ref so onUpdate can access it
let stateRef: ref<option<droneTrainingState>> = ref(None)

let setupEntities = (gameState: GameLoop.gameState, worldContainer: Container.t): unit => {
  let ts = makeTrainingState()

  // Draw arena decorations
  drawZoneDividers(worldContainer)
  ts.zoneLabelGraphics = drawZoneLabels(worldContainer)

  // ── Surveillance Drone (Recon variant) ──
  // Patrols the left zone with a wide searchlight beam.
  let survDrone = Drone.make(
    ~id="train_surv",
    ~variant=Recon,
    ~x=250.0,
    ~y=Tuning.droneAltitude,
    ~groundY=Tuning.groundY,
    ~waypoints=[
      {x: Tuning.zone1Start +. 50.0, hoverDurationSec: 3.0},
      {x: Tuning.zone1End -. 50.0, hoverDurationSec: 3.0},
    ],
    ~chargingPadX=Tuning.zone1Start +. 50.0,
    (),
  )
  let _ = Container.addChild(worldContainer, survDrone.container)
  ts.surveillanceDrone = Some(survDrone)

  // ── Combat Drone (Pursuit variant) ──
  // Patrols the middle zone. Locks on with spotlight, deals damage.
  let combatDrone = Drone.make(
    ~id="train_combat",
    ~variant=Pursuit,
    ~x=750.0,
    ~y=Tuning.droneAltitude,
    ~groundY=Tuning.groundY,
    ~waypoints=[
      {x: Tuning.zone2Start +. 50.0, hoverDurationSec: 2.0},
      {x: Tuning.zone2End -. 50.0, hoverDurationSec: 2.0},
    ],
    ~chargingPadX=Tuning.zone2End -. 50.0,
    (),
  )
  let _ = Container.addChild(worldContainer, combatDrone.container)
  ts.combatDrone = Some(combatDrone)

  // ── Helper Drone (EMP_Drone variant, repurposed) ──
  // Patrols the right zone near the building. Demonstrates lift mechanic.
  let helperDrone = Drone.make(
    ~id="train_helper",
    ~variant=EMP_Drone,
    ~x=1300.0,
    ~y=Tuning.droneAltitude,
    ~groundY=Tuning.groundY,
    ~waypoints=[
      {x: Tuning.zone3Start +. 50.0, hoverDurationSec: 2.0},
      {x: Tuning.zone3End -. 100.0, hoverDurationSec: 4.0}, // Longer hover near building
    ],
    ~chargingPadX=Tuning.zone3End -. 50.0,
    (),
  )
  // Disable EMP payload — helper doesn't use it
  helperDrone.empPayloadAvailable = false
  let _ = Container.addChild(worldContainer, helperDrone.container)
  ts.helperDrone = Some(helperDrone)

  // ── Building for lift demo ──
  let bldg = drawBuilding(worldContainer)
  ts.buildingContainer = Some(bldg)

  // ── Lift platform ──
  let liftGfx = drawLiftPlatform(worldContainer, ~liftY=ts.lift.liftY)
  ts.liftGraphic = Some(liftGfx)

  // ── Demo guard in helper zone (for alert mechanic demo) ──
  let _ = drawDemoGuard(worldContainer, ~x=1150.0, ~y=Tuning.groundY)

  // Spawn one guard in the helper zone so the helper drone's alert
  // mechanic has a target to demonstrate with
  let guards = [
    GuardNPC.make(
      ~id="train_drone_guard",
      ~rank=BasicGuard,
      ~x=1150.0,
      ~y=Tuning.groundY,
      ~waypoints=[
        {x: Tuning.zone3Start +. 30.0, pauseDurationSec: 3.0},
        {x: Tuning.zone3End -. 80.0, pauseDurationSec: 3.0},
      ],
    ),
  ]
  gameState.guards = guards

  stateRef := Some(ts)
}

// ─────────────────────────────────────────────────────────
//  Per-Frame Update
//   Updates all three drones and their demo-specific logic.
// ─────────────────────────────────────────────────────────

let onUpdate = (
  player: Player.t,
  _keyState: WorldBuilder.keyState,
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
      let playerCrouching = _keyState.crouch

      // ── Update Surveillance Drone ──
      // Sweeps a searchlight beam back and forth. Detection zone is the
      // lit area on the ground. The beam tilts left/right to simulate
      // "looking" for intruders.
      switch ts.surveillanceDrone {
      | Some(surv) => {
          // Searchlight sweep animation
          ts.searchlightAngle =
            ts.searchlightAngle +. ts.searchlightDirection *. Tuning.searchlightSweepSpeed *. dt
          if ts.searchlightAngle > Tuning.searchlightMaxAngle {
            ts.searchlightDirection = -1.0
            ts.searchlightAngle = Tuning.searchlightMaxAngle
          } else if ts.searchlightAngle < -.Tuning.searchlightMaxAngle {
            ts.searchlightDirection = 1.0
            ts.searchlightAngle = -.Tuning.searchlightMaxAngle
          }

          // Move detection centre based on sweep angle (simulates searchlight tilt)
          // The drone's detection is already circular via Drone.update;
          // we just shift the drone's x slightly to simulate the beam sweeping
          let sweepOffset = ts.searchlightAngle *. 80.0 // px offset from drone centre
          let effectivePlayerX = playerX -. sweepOffset

          let _ = Drone.update(
            surv,
            ~dt,
            ~playerX=effectivePlayerX,
            ~playerY,
            ~playerCrouching,
            ~alertLevel=1,
          )
        }
      | None => ()
      }

      // ── Update Combat Drone ──
      // Tracks player aggressively. When spotlight-locked, deals contact
      // damage at short range (simulating "firepower").
      switch ts.combatDrone {
      | Some(combat) => {
          let detection = Drone.update(
            combat,
            ~dt,
            ~playerX,
            ~playerY,
            ~playerCrouching,
            ~alertLevel=3, // Always high alert for combat training
          )

          // Damage when spotlight-locked and player is close
          switch detection {
          | Some(Drone.SpotlightLock) => {
              let dist = Math.abs(playerX -. combat.x)
              if dist < Tuning.combatDamageRadius {
                ts.combatDamageTimer = ts.combatDamageTimer +. dt
                if ts.combatDamageTimer >= 1.0 /. Tuning.combatDamageRate {
                  ts.combatDamageTimer = 0.0
                  let hp = Player.getHP(player)
                  PlayerHP.takeDamage(
                    hp,
                    ~amount=PlayerHP.Damage.guardMelee,
                    ~fromX=combat.x,
                    ~playerX,
                  )
                }
              }
            }
          | _ => ts.combatDamageTimer = 0.0
          }
        }
      | None => ()
      }

      // ── Update Helper Drone ──
      // Patrols near the building. When the helper drone is near the
      // building (hovering at its waypoint), the lift platform moves
      // up and down. The drone also periodically "alerts" the guard.
      switch ts.helperDrone {
      | Some(helper) => {
          let _ = Drone.update(
            helper,
            ~dt,
            ~playerX,
            ~playerY,
            ~playerCrouching,
            ~alertLevel=0, // Helper doesn't track player directly
          )

          // Lift mechanic: if helper is near the building, operate the lift
          let helperNearBuilding =
            Math.abs(helper.x -. Tuning.buildingX) < 120.0
          if helperNearBuilding {
            switch ts.lift.direction {
            | Idle => ts.lift.direction = GoingUp
            | GoingUp => {
                ts.lift.liftY = ts.lift.liftY -. Tuning.helperLiftSpeed *. dt
                if ts.lift.liftY <= Tuning.helperLiftTopY {
                  ts.lift.liftY = Tuning.helperLiftTopY
                  ts.lift.direction = GoingDown
                }
              }
            | GoingDown => {
                ts.lift.liftY = ts.lift.liftY +. Tuning.helperLiftSpeed *. dt
                if ts.lift.liftY >= Tuning.helperLiftBottomY {
                  ts.lift.liftY = Tuning.helperLiftBottomY
                  ts.lift.direction = GoingUp
                }
              }
            }

            // Check if player is standing on the lift platform
            let platX = Tuning.buildingX -. 34.0 // Left side of building
            let platW = 30.0
            let platY = ts.lift.liftY
            if (
              playerX >= platX &&
              playerX <= platX +. platW &&
              playerY >= platY -. 10.0 &&
              playerY <= platY +. 5.0
            ) {
              ts.lift.playerOnLift = true
              // Move player with the lift — set Y directly via player state
              player.state.y = ts.lift.liftY
              player.state.velY = 0.0
            } else {
              ts.lift.playerOnLift = false
            }
          } else {
            ts.lift.direction = Idle
          }

          // Guard alert mechanic: helper periodically triggers alert
          // on nearby guards when it detects the player
          let helperDetection = Drone.detectPlayer(
            helper,
            ~playerX,
            ~playerY,
            ~playerCrouching,
          )
          switch helperDetection {
          | Drone.InDetectionZone(_) | Drone.SpotlightLock => {
              ts.guardAlertTimer = ts.guardAlertTimer +. dt
              if ts.guardAlertTimer >= 5.0 && !ts.guardAlerted {
                ts.guardAlerted = true
                ts.guardAlertTimer = 0.0
                // Alert all guards in the helper zone
                Array.forEach(gameState.guards, guard => {
                  if guard.x >= Tuning.zone3Start && guard.x <= Tuning.zone3End {
                    guard.state = GuardNPC.Alerted
                    guard.suspicion = 1.0
                    guard.lastKnownPlayerX = Some(playerX)
                  }
                })
              }
            }
          | Drone.NotDetected => {
              ts.guardAlertTimer = 0.0
              if ts.guardAlerted {
                // Reset guard alert after player escapes detection
                ts.guardAlerted = false
                Array.forEach(gameState.guards, guard => {
                  if guard.x >= Tuning.zone3Start && guard.x <= Tuning.zone3End {
                    guard.state = GuardNPC.Patrolling
                    guard.suspicion = 0.0
                  }
                })
              }
            }
          }
        }
      | None => ()
      }

      // ── Redraw lift platform ──
      switch ts.liftGraphic {
      | Some(gfx) => {
          let _ = Graphics.clear(gfx)
          let platW = 30.0
          let platH = 6.0
          let platX = Tuning.buildingX -. platW -. 4.0
          let liftColor = if ts.lift.playerOnLift {
            0x88ffcc // Brighter when player is on it
          } else {
            0x44ff88
          }
          let _ =
            gfx
            ->Graphics.rect(platX, ts.lift.liftY -. platH /. 2.0, platW, platH)
            ->Graphics.fill({"color": liftColor, "alpha": 0.7})
            ->Graphics.stroke({"width": 1, "color": 0x88ffbb})
          // Direction arrow
          let arrowY = ts.lift.liftY
          switch ts.lift.direction {
          | GoingUp => {
              let _ =
                gfx
                ->Graphics.moveTo(platX +. platW /. 2.0, arrowY -. 12.0)
                ->Graphics.lineTo(platX +. platW /. 2.0 -. 5.0, arrowY -. 6.0)
                ->Graphics.lineTo(platX +. platW /. 2.0 +. 5.0, arrowY -. 6.0)
                ->Graphics.lineTo(platX +. platW /. 2.0, arrowY -. 12.0)
                ->Graphics.fill({"color": 0x44ff88, "alpha": 0.8})
            }
          | GoingDown => {
              let _ =
                gfx
                ->Graphics.moveTo(platX +. platW /. 2.0, arrowY +. 12.0)
                ->Graphics.lineTo(platX +. platW /. 2.0 -. 5.0, arrowY +. 6.0)
                ->Graphics.lineTo(platX +. platW /. 2.0 +. 5.0, arrowY +. 6.0)
                ->Graphics.lineTo(platX +. platW /. 2.0, arrowY +. 12.0)
                ->Graphics.fill({"color": 0x44ff88, "alpha": 0.8})
            }
          | Idle => ()
          }
        }
      | None => {
          // First frame — create the lift graphic
          let liftGfx = drawLiftPlatform(worldContainer, ~liftY=ts.lift.liftY)
          ts.liftGraphic = Some(liftGfx)
        }
      }

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
    ~legendEntries=droneLegendEntries,
  )
}

let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(["main"]),
}

let _ = constructorRef := Some(constructor)
