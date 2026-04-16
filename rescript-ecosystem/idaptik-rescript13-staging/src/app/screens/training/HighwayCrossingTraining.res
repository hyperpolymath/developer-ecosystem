// SPDX-License-Identifier: PMPL-1.0-or-later
// HighwayCrossingTraining  Frogger-style Moletaire road crossing minigame
//
// An optional interlude for missions where Moletaire is deployed:
// the mole must cross a multi-lane highway to reach the mission area.
// The mole gets car-sick from near-misses, which slows him down.
//
// Controls:
//   J / K  Move mole left / right (dodge within lane)
//   Y      Hop forward (toward finish / up on screen)
//   H      Hop backward (toward start / down on screen)
//   M      Dig underground (safe from traffic but very slow)
//
// Mechanics:
//   - 5 traffic lanes with vehicles moving at different speeds/directions
//   - Each near-miss increases car-sickness (nausea meter)
//   - High nausea  mole slows down and controls become sluggish
//   - Getting hit resets mole to starting side
//   - Underground travel is 100% safe but takes 3x longer
//   - Objective: reach the far side of the road
//
// This is a "second column" training — lighter, skill-based fun
// rather than combat practice. Available when Moletaire is enabled.

open Pixi

// ─────────────────────────────────────────────────────────
//  Tuning Constants
// ─────────────────────────────────────────────────────────

module Tuning = {
  // Arena dimensions
  let arenaWidth = 800.0
  let groundY = 500.0

  // Road layout
  let roadTopY = 150.0 // Top of the road
  let roadBottomY = 450.0 // Bottom of the road
  let laneCount = 5
  let laneHeight = 60.0 // Height of each lane
  let roadLeftX = 100.0
  let roadRightX = 700.0

  // Start and finish zones
  let startZoneWidth = 90.0 // Safe zone at the bottom
  let finishZoneWidth = 90.0 // Safe zone at the top

  // Mole movement
  let hopDistance = 60.0 // One hop = one lane
  let hopDuration = 0.3 // Seconds per hop animation
  let dodgeSpeed = 120.0 // Horizontal dodge speed (px/s) within lanes
  let moleWidth = 16.0
  let moleHeight = 12.0

  // Car-sickness mechanic
  let nearMissDistance = 25.0 // px: how close a vehicle must pass to trigger nausea
  let nauseaPerNearMiss = 0.15 // 0-1 scale
  let nauseaDecayRate = 0.02 // Per second decay when safe
  let nauseaSlowdown = 0.4 // At max nausea, mole moves at 40% speed
  let nauseaSluggishness = 0.5 // At max nausea, input delay multiplier

  // Underground travel
  let undergroundSpeed = 20.0 // px/s  very slow but safe
  let surfaceSpeed = 0.0 // Mole doesn't move horizontally, only hops between lanes

  // Vehicle speeds (px/s)
  let vehicleMinSpeed = 80.0
  let vehicleMaxSpeed = 200.0
  let vehicleWidth = 40.0
  let vehicleHeight = 20.0

  // Vehicle spawn rate (seconds between spawns per lane)
  let spawnIntervalMin = 1.0
  let spawnIntervalMax = 3.0

  // Hit penalty
  let hitStunDuration = 1.0 // Seconds of stun after being hit
  let maxHits = 3 // Hits before game over
}

// ─────────────────────────────────────────────────────────
//  Vehicle
// ─────────────────────────────────────────────────────────

type vehicleType = Car | Truck | Motorbike

type vehicle = {
  mutable x: float,
  y: float, // Fixed to lane centre
  speed: float, // Positive = moving right, negative = moving left
  width: float,
  height: float,
  vehicleType: vehicleType,
  color: int,
  graphic: Graphics.t,
}

// ─────────────────────────────────────────────────────────
//  Mole State
// ─────────────────────────────────────────────────────────

type moleState =
  | OnSurface // Normal, can hop between lanes
  | Hopping(float, float) // (startY, targetY) — mid-hop animation
  | Underground // Digging across  safe from traffic
  | Stunned(float) // Hit by vehicle, timer counting down
  | Arrived // Reached the finish zone

type moleData = {
  mutable x: float,
  mutable y: float,
  mutable state: moleState,
  mutable hopTimer: float,
  mutable nausea: float, // 0.0 (fresh) to 1.0 (violently ill)
  mutable hits: int,
  mutable undergroundProgress: float, // 0.0 to 1.0 (fraction of road crossed)
  mutable facing: int, // -1 left, 1 right
  graphic: Graphics.t,
  nauseaIndicator: Graphics.t,
}

// ─────────────────────────────────────────────────────────
//  Training State
// ─────────────────────────────────────────────────────────

type highwayState = {
  mutable mole: moleData,
  mutable vehicles: array<vehicle>,
  mutable spawnTimers: array<float>, // Per-lane countdown to next vehicle spawn
  mutable laneDirections: array<float>, // Per-lane: 1.0 = right, -1.0 = left
  mutable laneSpeeds: array<float>, // Per-lane base speed
  mutable nearMissCount: int,
  mutable totalHops: int,
  mutable gameOver: bool,
  mutable victory: bool,
  // Graphics
  mutable roadGraphic: option<Graphics.t>,
  mutable hudText: option<Text.t>,
}

let stateRef: ref<option<highwayState>> = ref(None)

// ─────────────────────────────────────────────────────────
//  Vehicle Rendering
// ─────────────────────────────────────────────────────────

let drawVehicle = (v: vehicle): unit => {
  let _ = Graphics.clear(v.graphic)
  // Body
  let _ =
    v.graphic
    ->Graphics.rect(v.x, v.y -. v.height /. 2.0, v.width, v.height)
    ->Graphics.fill({"color": v.color})
    ->Graphics.stroke({"width": 1, "color": 0x222222})

  // Headlights (small yellow dots on the front)
  let frontX = if v.speed > 0.0 {
    v.x +. v.width // Moving right: front is right edge
  } else {
    v.x // Moving left: front is left edge
  }
  let _ =
    v.graphic
    ->Graphics.circle(frontX, v.y -. 4.0, 2.0)
    ->Graphics.fill({"color": 0xffff44})
  let _ =
    v.graphic
    ->Graphics.circle(frontX, v.y +. 4.0, 2.0)
    ->Graphics.fill({"color": 0xffff44})
}

// ─────────────────────────────────────────────────────────
//  Mole Rendering
// ─────────────────────────────────────────────────────────

let drawMole = (mole: moleData): unit => {
  let _ = Graphics.clear(mole.graphic)
  let _ = Graphics.clear(mole.nauseaIndicator)

  switch mole.state {
  | Arrived => {
      // Happy mole (green)
      let _ =
        mole.graphic
        ->Graphics.circle(mole.x, mole.y, 10.0)
        ->Graphics.fill({"color": 0x44ff44})
      // Star burst around mole
      for i in 0 to 5 {
        let angle = Int.toFloat(i) *. 1.047 // 60 degrees apart
        let sx = mole.x +. Math.cos(angle) *. 18.0
        let sy = mole.y +. Math.sin(angle) *. 18.0
        let _ =
          mole.graphic
          ->Graphics.circle(sx, sy, 3.0)
          ->Graphics.fill({"color": 0xffff00, "alpha": 0.7})
      }
    }
  | Underground => {
      // Underground: dirt mound indicator (darker, with tunnel symbol)
      let _ =
        mole.graphic
        ->Graphics.circle(mole.x, mole.y, 8.0)
        ->Graphics.fill({"color": 0x664422, "alpha": 0.6})
      let _ =
        mole.graphic
        ->Graphics.circle(mole.x, mole.y, 4.0)
        ->Graphics.fill({"color": 0xcc8833, "alpha": 0.8})
    }
  | Stunned(_) => {
      // Stunned: red flash, spinning stars
      let _ =
        mole.graphic
        ->Graphics.circle(mole.x, mole.y, 10.0)
        ->Graphics.fill({"color": 0xff2222, "alpha": 0.7})
      // Stars spinning around head
      let _ =
        mole.graphic
        ->Graphics.circle(mole.x -. 12.0, mole.y -. 12.0, 3.0)
        ->Graphics.fill({"color": 0xffff00})
      let _ =
        mole.graphic
        ->Graphics.circle(mole.x +. 12.0, mole.y -. 10.0, 3.0)
        ->Graphics.fill({"color": 0xffff00})
    }
  | _ => {
      // Normal/hopping mole (brown body, pink nose)
      let alpha = if mole.nausea > 0.5 { 0.7 } else { 1.0 }
      // Body (rounded rectangle approximating an ellipse)
      let _ =
        mole.graphic
        ->Graphics.roundRect(
          mole.x -. Tuning.moleWidth /. 2.0,
          mole.y -. Tuning.moleHeight /. 2.0,
          Tuning.moleWidth,
          Tuning.moleHeight,
          Tuning.moleHeight /. 2.0, // Fully rounded ends
        )
        ->Graphics.fill({"color": 0x8B6914, "alpha": alpha})
      // Snout
      let snoutX = mole.x +. Int.toFloat(mole.facing) *. 6.0
      let _ =
        mole.graphic
        ->Graphics.circle(snoutX, mole.y, 3.0)
        ->Graphics.fill({"color": 0xffaaaa})
    }
  }

  // Nausea indicator (green tint gets stronger as nausea increases)
  if mole.nausea > 0.1 {
    let nauseaAlpha = mole.nausea *. 0.4
    let _ =
      mole.nauseaIndicator
      ->Graphics.circle(mole.x, mole.y -. 16.0, 6.0 *. mole.nausea)
      ->Graphics.fill({"color": 0x44ff44, "alpha": nauseaAlpha})
    // "Dizzy" spirals at high nausea
    if mole.nausea > 0.5 {
      let _ =
        mole.nauseaIndicator
        ->Graphics.circle(mole.x -. 8.0, mole.y -. 14.0, 2.0)
        ->Graphics.fill({"color": 0x88ff88, "alpha": 0.5})
      let _ =
        mole.nauseaIndicator
        ->Graphics.circle(mole.x +. 8.0, mole.y -. 18.0, 2.0)
        ->Graphics.fill({"color": 0x88ff88, "alpha": 0.5})
    }
  }
}

// ─────────────────────────────────────────────────────────
//  Road Drawing
// ─────────────────────────────────────────────────────────

let drawRoad = (worldContainer: Container.t): Graphics.t => {
  let roadGfx = Graphics.make()

  // Road surface (dark grey)
  let _ =
    roadGfx
    ->Graphics.rect(
      Tuning.roadLeftX,
      Tuning.roadTopY,
      Tuning.roadRightX -. Tuning.roadLeftX,
      Tuning.roadBottomY -. Tuning.roadTopY,
    )
    ->Graphics.fill({"color": 0x333333})

  // Lane dividers (dashed white lines)
  for i in 1 to Tuning.laneCount - 1 {
    let laneY = Tuning.roadTopY +. Int.toFloat(i) *. Tuning.laneHeight
    // Dashed line: 20px segments with 15px gaps
    let dashCount = 18
    for d in 0 to dashCount - 1 {
      let dashX = Tuning.roadLeftX +. Int.toFloat(d) *. 35.0
      let _ =
        roadGfx
        ->Graphics.rect(dashX, laneY -. 1.0, 20.0, 2.0)
        ->Graphics.fill({"color": 0xaaaaaa, "alpha": 0.6})
    }
  }

  // Start zone (bottom, green "SAFE" area)
  let _ =
    roadGfx
    ->Graphics.rect(
      Tuning.roadLeftX,
      Tuning.roadBottomY,
      Tuning.roadRightX -. Tuning.roadLeftX,
      Tuning.startZoneWidth,
    )
    ->Graphics.fill({"color": 0x224422})
  // "START" label
  let startLabel = Text.make({
    "text": "START  SAFE ZONE",
    "style": {"fontFamily": "monospace", "fontSize": 12, "fill": 0x44aa44, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(startLabel), 0.5, ~y=0.5)
  Text.setX(startLabel, (Tuning.roadLeftX +. Tuning.roadRightX) /. 2.0)
  Text.setY(startLabel, Tuning.roadBottomY +. Tuning.startZoneWidth /. 2.0)
  let _ = Container.addChildText(worldContainer, startLabel)

  // Finish zone (top, gold "FINISH" area)
  let _ =
    roadGfx
    ->Graphics.rect(
      Tuning.roadLeftX,
      Tuning.roadTopY -. Tuning.finishZoneWidth,
      Tuning.roadRightX -. Tuning.roadLeftX,
      Tuning.finishZoneWidth,
    )
    ->Graphics.fill({"color": 0x443322})
  // "FINISH" label
  let finishLabel = Text.make({
    "text": "FINISH  MISSION AREA",
    "style": {"fontFamily": "monospace", "fontSize": 12, "fill": 0xffaa44, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(finishLabel), 0.5, ~y=0.5)
  Text.setX(finishLabel, (Tuning.roadLeftX +. Tuning.roadRightX) /. 2.0)
  Text.setY(finishLabel, Tuning.roadTopY -. Tuning.finishZoneWidth /. 2.0)
  let _ = Container.addChildText(worldContainer, finishLabel)

  // Lane direction arrows (small arrows on each lane showing traffic direction)
  for i in 0 to Tuning.laneCount - 1 {
    let laneY = Tuning.roadTopY +. (Int.toFloat(i) +. 0.5) *. Tuning.laneHeight
    let direction = if mod(i, 2) == 0 { ">>>" } else { "<<<" }
    let dirLabel = Text.make({
      "text": direction,
      "style": {"fontFamily": "monospace", "fontSize": 10, "fill": 0x555555, "fontWeight": "bold"},
    })
    ObservablePoint.set(Text.anchor(dirLabel), 0.5, ~y=0.5)
    Text.setX(dirLabel, Tuning.roadLeftX -. 30.0)
    Text.setY(dirLabel, laneY)
    let _ = Container.addChildText(worldContainer, dirLabel)
  }

  let _ = Container.addChildGraphics(worldContainer, roadGfx)
  roadGfx
}

// ─────────────────────────────────────────────────────────
//  Vehicle Spawning
// ─────────────────────────────────────────────────────────

let spawnVehicle = (
  worldContainer: Container.t,
  ~laneIndex: int,
  ~direction: float,
  ~baseSpeed: float,
): vehicle => {
  let laneY = Tuning.roadTopY +. (Int.toFloat(laneIndex) +. 0.5) *. Tuning.laneHeight

  // Random speed variation (+/- 30%)
  let speedVariation = 0.7 +. Math.random() *. 0.6
  let speed = baseSpeed *. speedVariation *. direction

  // Random vehicle type
  let roll = Math.random()
  let (vType, vWidth, vHeight, vColor) = if roll < 0.3 {
    // Truck (big, slow-ish, red/orange)
    (Truck, 55.0, 24.0, 0xcc4422)
  } else if roll < 0.7 {
    // Car (medium, normal speed, varied colors)
    let colors = [0x4488cc, 0xcc8844, 0x888888, 0x44cc44, 0xcc44cc]
    let colorIdx = mod(Float.toInt(Math.random() *. 5.0), 5)
    let color = switch colors[colorIdx] {
    | Some(c) => c
    | None => 0x888888
    }
    (Car, 40.0, 18.0, color)
  } else {
    // Motorbike (small, fast, yellow)
    (Motorbike, 22.0, 12.0, 0xdddd44)
  }

  // Start position: off-screen on the side the vehicle enters from
  let startX = if direction > 0.0 {
    Tuning.roadLeftX -. vWidth -. 20.0 // Enter from left
  } else {
    Tuning.roadRightX +. 20.0 // Enter from right
  }

  let graphic = Graphics.make()
  let _ = Container.addChildGraphics(worldContainer, graphic)

  {
    x: startX,
    y: laneY,
    speed,
    width: vWidth,
    height: vHeight,
    vehicleType: vType,
    color: vColor,
    graphic,
  }
}

// ─────────────────────────────────────────────────────────
//  Collision Check
// ─────────────────────────────────────────────────────────

// Check if mole overlaps a vehicle (swept AABB to prevent tunneling).
// For fast/narrow vehicles, extend the collision box in the direction of travel
// by the distance moved this frame. This prevents motorbikes and cars from
// passing through the mole between frames.
let moleHitsVehicle = (mole: moleData, v: vehicle, ~dt: float): bool => {
  let moleLeft = mole.x -. Tuning.moleWidth /. 2.0
  let moleRight = mole.x +. Tuning.moleWidth /. 2.0
  let moleTop = mole.y -. Tuning.moleHeight /. 2.0
  let moleBottom = mole.y +. Tuning.moleHeight /. 2.0
  // Sweep: extend vehicle bounds by how far it moved this frame
  let frameDist = Math.abs(v.speed *. dt)
  let vLeft = if v.speed > 0.0 { v.x -. frameDist } else { v.x }
  let vRight = if v.speed > 0.0 { v.x +. v.width } else { v.x +. v.width +. frameDist }
  let vTop = v.y -. v.height /. 2.0
  let vBottom = v.y +. v.height /. 2.0

  moleRight > vLeft && moleLeft < vRight && moleBottom > vTop && moleTop < vBottom
}

// Check near-miss (vehicle passes very close but doesn't hit)
let isNearMiss = (mole: moleData, v: vehicle): bool => {
  let moleCenterY = mole.y
  let vCenterY = v.y
  let yDist = Math.abs(moleCenterY -. vCenterY)

  // Must be in the same lane (close vertically) but narrowly missed horizontally
  if yDist < Tuning.laneHeight /. 2.0 {
    let moleRight = mole.x +. Tuning.moleWidth /. 2.0
    let moleLeft = mole.x -. Tuning.moleWidth /. 2.0
    let vRight = v.x +. v.width
    let vLeft = v.x

    // Check if vehicle edge is within near-miss distance of mole edge
    let gapRight = Math.abs(vLeft -. moleRight)
    let gapLeft = Math.abs(moleLeft -. vRight)
    let minGap = Math.min(gapRight, gapLeft)

    minGap < Tuning.nearMissDistance && minGap > 0.0
  } else {
    false
  }
}

// ─────────────────────────────────────────────────────────
//  HUD
// ─────────────────────────────────────────────────────────

let drawHUD = (worldContainer: Container.t, ~state: highwayState): Text.t => {
  let hudText = Text.make({
    "text": "",
    "style": {
      "fontFamily": "monospace",
      "fontSize": 13,
      "fill": 0xcccccc,
      "wordWrap": true,
      "wordWrapWidth": 200,
    },
  })
  Text.setX(hudText, 10.0)
  Text.setY(hudText, 10.0)
  let _ = Container.addChildText(worldContainer, hudText)
  state.hudText = Some(hudText)
  hudText
}

let updateHUD = (state: highwayState): unit => {
  switch state.hudText {
  | Some(text) => {
      let nauseaPct = Int.toString(Float.toInt(state.mole.nausea *. 100.0))
      let hitsLeft = Int.toString(Tuning.maxHits - state.mole.hits)
      let moleStatus = switch state.mole.state {
      | Underground => " [UNDERGROUND]"
      | Stunned(_) => " [STUNNED!]"
      | Arrived => " [ARRIVED!]"
      | Hopping(_, _) => " [HOPPING]"
      | OnSurface => ""
      }
      Text.setText(
        text,
        `Nausea: ${nauseaPct}%${moleStatus}\nHits remaining: ${hitsLeft}\nNear misses: ${Int.toString(state.nearMissCount)}\nHops: ${Int.toString(state.totalHops)}`,
      )
    }
  | None => ()
  }
}

// ─────────────────────────────────────────────────────────
//  Training Config
// ─────────────────────────────────────────────────────────

let config: TrainingBase.trainingConfig = {
  title: GameI18n.t("training.highway.title"),
  instructions: [
    GameI18n.t("training.highway.line1"),
    GameI18n.t("training.highway.line2"),
    GameI18n.t("training.highway.line3"),
    GameI18n.t("training.highway.line4"),
  ],
  arenaWidth: Tuning.arenaWidth,
  groundY: Tuning.groundY,
}

let highwayLegendEntries: array<TrainingBase.legendEntry> = [
  {color: 0x4488cc, name: "Car", desc: "Medium speed, varied"},
  {color: 0xcc4422, name: "Truck", desc: "Slow, wide body"},
  {color: 0xdddd44, name: "Motorbike", desc: "Fast, narrow"},
]

// ─────────────────────────────────────────────────────────
//  Entity Setup
// ─────────────────────────────────────────────────────────

let setupEntities = (_gameState: GameLoop.gameState, worldContainer: Container.t): unit => {
  // Draw road
  let roadGfx = drawRoad(worldContainer)

  // Create mole at bottom (start zone)
  let moleGraphic = Graphics.make()
  let nauseaGfx = Graphics.make()
  let _ = Container.addChildGraphics(worldContainer, moleGraphic)
  let _ = Container.addChildGraphics(worldContainer, nauseaGfx)

  let startX = (Tuning.roadLeftX +. Tuning.roadRightX) /. 2.0
  let startY = Tuning.roadBottomY +. Tuning.startZoneWidth /. 2.0

  let mole: moleData = {
    x: startX,
    y: startY,
    state: OnSurface,
    hopTimer: 0.0,
    nausea: 0.0,
    hits: 0,
    undergroundProgress: 0.0,
    facing: 1,
    graphic: moleGraphic,
    nauseaIndicator: nauseaGfx,
  }

  // Lane directions and speeds (alternating left/right)
  let laneDirections = Array.make(~length=Tuning.laneCount, 1.0)
  let laneSpeeds = Array.make(~length=Tuning.laneCount, Tuning.vehicleMinSpeed)
  let spawnTimers = Array.make(~length=Tuning.laneCount, 0.0)

  for i in 0 to Tuning.laneCount - 1 {
    let dir = if mod(i, 2) == 0 { 1.0 } else { -1.0 }
    // Speed increases with lane (inner lanes faster)
    let speedFactor = 0.6 +. Int.toFloat(i) *. 0.15
    let speed =
      Tuning.vehicleMinSpeed +.
      (Tuning.vehicleMaxSpeed -. Tuning.vehicleMinSpeed) *. speedFactor
    switch laneDirections[i] {
    | Some(_) => {
        laneDirections[i] = dir
        laneSpeeds[i] = speed
        spawnTimers[i] = Math.random() *. Tuning.spawnIntervalMax
      }
    | None => ()
    }
  }

  let state: highwayState = {
    mole,
    vehicles: [],
    spawnTimers,
    laneDirections,
    laneSpeeds,
    nearMissCount: 0,
    totalHops: 0,
    gameOver: false,
    victory: false,
    roadGraphic: Some(roadGfx),
    hudText: None,
  }

  let _ = drawHUD(worldContainer, ~state)

  stateRef := Some(state)
}

// ─────────────────────────────────────────────────────────
//  Per-Frame Update
// ─────────────────────────────────────────────────────────

let onUpdate = (
  _player: Player.t,
  keyState: WorldBuilder.keyState,
  _hud: HUD.t,
  _gameState: GameLoop.gameState,
  worldContainer: Container.t,
  dt: float,
): TrainingBase.trainingResult => {
  switch stateRef.contents {
  | None => Continue
  | Some(state) => {
      if state.gameOver {
        Defeat("Car-sick mole couldn't make it!")
      } else if state.victory {
        Victory
      } else {
        let mole = state.mole

        // ── Input handling (Y/H hop forward/back, J/K dodge left/right, M underground) ──
        // Apply nausea-based input delay: at high nausea, inputs are sluggish.
        // The hop cooldown is extended by nausea.
        let effectiveHopDuration =
          Tuning.hopDuration *. (1.0 +. mole.nausea *. Tuning.nauseaSluggishness)

        switch mole.state {
        | OnSurface => {
            // Y = hop forward (toward finish, upward on screen = decreasing Y)
            if keyState.moleForward && mole.hopTimer <= 0.0 {
              let targetY = mole.y -. Tuning.hopDistance
              // Clamp to finish zone
              let clampedTarget = Math.max(
                Tuning.roadTopY -. Tuning.finishZoneWidth /. 2.0,
                targetY,
              )
              mole.state = Hopping(mole.y, clampedTarget)
              mole.hopTimer = effectiveHopDuration
              state.totalHops = state.totalHops + 1
            }

            // H = hop backward (toward start, downward = increasing Y)
            if keyState.moleBackward && mole.hopTimer <= 0.0 {
              let targetY = mole.y +. Tuning.hopDistance
              let clampedTarget = Math.min(
                Tuning.roadBottomY +. Tuning.startZoneWidth /. 2.0,
                targetY,
              )
              mole.state = Hopping(mole.y, clampedTarget)
              mole.hopTimer = effectiveHopDuration
              state.totalHops = state.totalHops + 1
            }

            // J/K = dodge left/right within lane
            let nauseaSpeedMult = 1.0 -. mole.nausea *. Tuning.nauseaSlowdown
            let dodgeSpd = Tuning.dodgeSpeed *. nauseaSpeedMult
            if keyState.moleLeft {
              mole.x = Math.max(Tuning.roadLeftX +. 10.0, mole.x -. dodgeSpd *. dt)
              mole.facing = -1
            }
            if keyState.moleRight {
              mole.x = Math.min(Tuning.roadRightX -. 10.0, mole.x +. dodgeSpd *. dt)
              mole.facing = 1
            }

            // M = dig underground
            if keyState.moleToggle {
              mole.state = Underground
              mole.undergroundProgress = 0.0
            }
          }

        | Hopping(startY, targetY) => {
            // Animate hop (linear interpolation)
            mole.hopTimer = mole.hopTimer -. dt
            if mole.hopTimer <= 0.0 {
              mole.y = targetY
              mole.hopTimer = 0.0
              mole.state = OnSurface
            } else {
              let progress = 1.0 -. mole.hopTimer /. effectiveHopDuration
              mole.y = startY +. (targetY -. startY) *. progress
            }
          }

        | Underground => {
            // Move upward slowly (underground crossing)
            let speed =
              Tuning.undergroundSpeed *. (1.0 -. mole.nausea *. 0.3) // Nausea slows underground too
            mole.y = mole.y -. speed *. dt

            // Surface when M is pressed again OR when reaching finish
            if keyState.moleToggle && mole.hopTimer <= 0.0 {
              mole.state = OnSurface
              mole.hopTimer = 0.3 // Brief cooldown to prevent toggle spam
            }

            // Check if reached finish zone underground
            if mole.y <= Tuning.roadTopY -. Tuning.finishZoneWidth /. 2.0 {
              mole.y = Tuning.roadTopY -. Tuning.finishZoneWidth /. 2.0
              mole.state = Arrived
              state.victory = true
            }
          }

        | Stunned(timer) => {
            let remaining = timer -. dt
            if remaining <= 0.0 {
              // Reset mole to start after stun
              mole.y = Tuning.roadBottomY +. Tuning.startZoneWidth /. 2.0
              mole.state = OnSurface
              mole.hopTimer = 0.5 // Brief cooldown after respawn
            } else {
              mole.state = Stunned(remaining)
            }
          }

        | Arrived => ()
        }

        // Decay hop timer
        if mole.hopTimer > 0.0 && mole.state == OnSurface {
          mole.hopTimer = mole.hopTimer -. dt
        }

        // ── Check finish zone ──
        if mole.state == OnSurface && mole.y <= Tuning.roadTopY {
          mole.state = Arrived
          state.victory = true
        }

        // ── Spawn vehicles ──
        for i in 0 to Tuning.laneCount - 1 {
          switch state.spawnTimers[i] {
          | Some(timer) => {
              let newTimer = timer -. dt
              if newTimer <= 0.0 {
                // Spawn a vehicle in this lane
                let dir = switch state.laneDirections[i] {
                | Some(d) => d
                | None => 1.0
                }
                let speed = switch state.laneSpeeds[i] {
                | Some(s) => s
                | None => Tuning.vehicleMinSpeed
                }
                let v = spawnVehicle(worldContainer, ~laneIndex=i, ~direction=dir, ~baseSpeed=speed)
                state.vehicles = Array.concat(state.vehicles, [v])

                // Reset spawn timer with random interval
                state.spawnTimers[i] =
                  Tuning.spawnIntervalMin +.
                  Math.random() *. (Tuning.spawnIntervalMax -. Tuning.spawnIntervalMin)
              } else {
                state.spawnTimers[i] = newTimer
              }
            }
          | None => ()
          }
        }

        // ── Update vehicles ──
        // Move vehicles and check for off-screen removal
        let activeVehicles = []
        Array.forEach(state.vehicles, v => {
          v.x = v.x +. v.speed *. dt

          // Remove if off-screen
          let offScreen = if v.speed > 0.0 {
            v.x > Tuning.roadRightX +. 50.0
          } else {
            v.x +. v.width < Tuning.roadLeftX -. 50.0
          }

          if offScreen {
            // Hide off-screen vehicle (Graphics.t has setAlpha, not setVisible)
            Graphics.setAlpha(v.graphic, 0.0)
          } else {
            // Keep vehicle
            let _ = Array.push(activeVehicles, v)

            // Check collision with mole (only on surface or hopping)
            switch mole.state {
            | OnSurface | Hopping(_, _) => {
                if moleHitsVehicle(mole, v, ~dt) {
                  // Hit! Stun the mole
                  mole.hits = mole.hits + 1
                  mole.nausea = Math.min(1.0, mole.nausea +. 0.3) // Big nausea spike
                  mole.state = Stunned(Tuning.hitStunDuration)

                  if mole.hits >= Tuning.maxHits {
                    state.gameOver = true
                  }
                } else if isNearMiss(mole, v) {
                  // Near miss! Increase nausea
                  mole.nausea = Math.min(1.0, mole.nausea +. Tuning.nauseaPerNearMiss)
                  state.nearMissCount = state.nearMissCount + 1
                }
              }
            | _ => () // Underground or stunned — safe from traffic
            }
          }

          // Render vehicle
          drawVehicle(v)
        })
        state.vehicles = activeVehicles

        // ── Nausea decay ──
        // Nausea slowly decreases when mole is in a safe zone or underground
        let inSafeZone =
          mole.y > Tuning.roadBottomY || mole.y < Tuning.roadTopY || mole.state == Underground
        if inSafeZone {
          mole.nausea = Math.max(0.0, mole.nausea -. Tuning.nauseaDecayRate *. dt *. 3.0)
        } else {
          // Slow decay even on road
          mole.nausea = Math.max(0.0, mole.nausea -. Tuning.nauseaDecayRate *. dt)
        }

        // ── Render mole ──
        drawMole(mole)

        // ── Update HUD ──
        updateHUD(state)

        Continue
      }
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
    ~legendEntries=highwayLegendEntries,
  )
}

let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(["main"]),
}

let _ = constructorRef := Some(constructor)
