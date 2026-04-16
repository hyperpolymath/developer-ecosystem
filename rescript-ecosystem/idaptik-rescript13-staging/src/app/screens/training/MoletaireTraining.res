// SPDX-License-Identifier: PMPL-1.0-or-later
// MoletaireTraining  Training ground for the Moletaire robotic mole companion
//
// Arena with:
//   - Tunnelling zones (drawn as brown earth below ground line)
//   - 2 guards to practise trap-digging on
//   - Loose wire distractions (mole is involuntarily drawn to them)
//   - A USB pickup to practise item carrying
//   - A RoboDog that prioritises Moletaire over the player:
//       * Digs for mole if close to surface (depth < dogDetectionDepth)
//       * Gets confused when mole pops up on different sides repeatedly
//       * Confusion resets if mole stays on one side too long
//   - A multi-floor building that mole can enter, climb to top, and jump from
//       * Jessica (player) must position below to catch the falling mole
//   - Hunger bar: mole gets hungry over time, starts fighting the controller
//       * At high hunger, mole moves autonomously toward nearest component
//       * At max hunger, mole will even eat the main objective (USB)
//
// Permadeath is DISABLED in training (mole resets on death).
// Victory condition: dig a trap under a guard + deliver USB to dropoff.
//
// Synthesised chiptune loop (MoletaireMusic) plays during underground
// movement in this arena only.
//
// Uses TrainingBase.makeTrainingScreen() with custom onUpdate callback
// returning trainingResult.

open Pixi

let absFloat = (x: float): float =>
  if x < 0.0 { -.x } else { x }

//  Arena Configuration

let arenaWidth = 1400.0
let groundY = 500.0
let undergroundBottom = 620.0 // Visual bottom of earth zone

//  Building Configuration

// 3-floor building for mole climbing + jump-and-catch mechanic
module Building = {
  let x = 1100.0 // Building left edge x
  let width = 80.0
  let floorHeight = 60.0
  let floors = 3
  let totalHeight = Int.toFloat(floors) *. floorHeight
  let topY = groundY -. totalHeight // Top floor Y
  let catchRadius = 50.0 // Jessica must be within this distance to catch falling mole
  let doorHitboxHalfWidth = 25.0 // Wider than visual door for reliable entry
}

//  Dog Confusion AI

// The RoboDog prioritises Moletaire. When the mole pops up on different sides
// of the dog repeatedly, the dog gets confused (spinning, barking randomly).
// Confusion decays over time. If mole stays on one side too long, dog locks on.
module DogMoleAI = {
  let hearingRange = 250.0 // How far dog can hear mole (circular range, regardless of facing)
  let maxDigReach = 2.0 // Dog can dig to this multiplier of their own depth (shallow only)
                         // e.g. if maxDigReach=2.0, dog at surface can reach mole at depth 0.15
                         // effectively: dog can catch mole if mole.depth < dogDigDepth
  let dogDigDepth = 0.15 // Absolute max depth the dog can paw down to
  let digSpeed = 30.0 // Dog paws at ground — slow, gives mole time to escape
  let confusionThreshold = 3 // Pop-ups needed to confuse the dog
  let confusionDuration = 4.0 // Seconds the dog stays confused
  let sideSwitchCooldown = 2.0 // Min time between side-switches to count as "different side"
}

//  Training State

type rec trainingState = {
  mutable mole: Moletaire.t,
  mutable trapTriggered: bool,
  mutable usbDelivered: bool,
  mutable usbPickedUp: bool,
  // Arena objects
  usbX: float,
  usbY: float,
  dropoffX: float,
  wireX: float,
  mutable wireActive: bool,
  mutable wireTimer: float,
  // Music state
  mutable musicStarted: bool,
  mutable prevToggle: bool,
  mutable prevTrap: bool,
  mutable prevItem: bool,
  // Dog confusion tracking
  mutable dogLastMoleSide: int, // -1 left, 0 unknown, 1 right (relative to dog)
  mutable dogSideSwitchCount: int, // How many times mole popped up on different sides
  mutable dogSideSwitchTimer: float, // Cooldown since last side switch
  mutable dogConfusionTimer: float, // Remaining confusion duration (0 = not confused)
  mutable dogDigging: bool, // Dog is pawing at ground trying to get mole
  // Building state
  mutable moleInBuilding: bool, // Mole is inside the building
  mutable moleFloor: int, // 0 = ground, 1-3 = floors
  mutable moleJumping: bool, // Mole jumped from top floor
  mutable moleJumpY: float, // Current Y during jump/fall
  mutable moleCaught: bool, // Jessica caught the mole
  // Hunger display
  mutable hungerBarGraphic: option<Graphics.t>,
  // Food pellet positions (mole can eat these to reduce hunger)
  foodX: float,
  mutable foodAvailable: bool,
  mutable foodRespawnTimer: float,
  // USB-eaten failure tracking
  mutable usbEatenByMole: bool,
  // Visual feedback graphics
  mutable catchZoneGraphic: option<Graphics.t>,
  mutable dogHearingGraphic: option<Graphics.t>,
  // Equipment pickup stations (walk over + press B to equip)
  equipStations: array<equipmentStation>,
}

and equipmentStation = {
  x: float,
  equipType: equipStationType,
  mutable collected: bool,
}

and equipStationType =
  | HeadStation(Moletaire.headEquipment)
  | BodyStation(Moletaire.bodyEquipment)

//  Setup

let config: TrainingBase.trainingConfig = {
  title: GameI18n.t("training.moletaire.title"),
  instructions: [
    GameI18n.t("training.moletaire.line1"),
    GameI18n.t("training.moletaire.line2"),
    GameI18n.t("training.moletaire.line3"),
    GameI18n.t("training.moletaire.line4"),
  ],
  arenaWidth,
  groundY,
}

// Training state singleton (reset each time the screen loads)
let trainingStateRef: ref<option<trainingState>> = ref(None)

// Opaque type for event handler references (avoids value restriction)
type eventHandler

// Mole keyboard handler ref (for cleanup)
let moleKeyHandlerDown: ref<option<eventHandler>> = ref(None)
let moleKeyHandlerUp: ref<option<eventHandler>> = ref(None)

//  Draw Underground Layer

let drawUnderground = (worldContainer: Container.t): unit => {
  let earth = Graphics.make()
  // Brown earth fill below ground line
  let _ =
    earth
    ->Graphics.rect(0.0, groundY +. 4.0, arenaWidth, undergroundBottom -. groundY -. 4.0)
    ->Graphics.fill({"color": 0x4a3520, "alpha": 0.6})
  // Darker soil layers
  let _ =
    earth
    ->Graphics.rect(0.0, groundY +. 40.0, arenaWidth, 2.0)
    ->Graphics.fill({"color": 0x3a2510, "alpha": 0.4})
  let _ =
    earth
    ->Graphics.rect(0.0, groundY +. 80.0, arenaWidth, 2.0)
    ->Graphics.fill({"color": 0x3a2510, "alpha": 0.3})
  let _ = Container.addChildGraphics(worldContainer, earth)

  // "TUNNEL ZONE" label
  let tunnelLabel = Text.make({
    "text": "TUNNEL ZONE",
    "style": {"fontSize": 14, "fill": 0x6a5530, "fontWeight": "bold"},
  })
  Text.setX(tunnelLabel, 60.0)
  Text.setY(tunnelLabel, groundY +. 12.0)
  let _ = Container.addChildText(worldContainer, tunnelLabel)
}

//  Draw Arena Objects

let drawUSB = (worldContainer: Container.t, ~x: float, ~y: float): Graphics.t => {
  let usb = Graphics.make()
  let _ =
    usb
    ->Graphics.rect(x -. 6.0, y -. 10.0, 12.0, 8.0)
    ->Graphics.fill({"color": 0x2266cc})
  let _ =
    usb
    ->Graphics.rect(x -. 3.0, y -. 14.0, 6.0, 4.0)
    ->Graphics.fill({"color": 0xcccccc})
  let _ = Container.addChildGraphics(worldContainer, usb)
  usb
}

let drawDropoff = (worldContainer: Container.t, ~x: float): unit => {
  let dropoff = Graphics.make()
  let _ =
    dropoff
    ->Graphics.moveTo(x, groundY -. 30.0)
    ->Graphics.lineTo(x -. 12.0, groundY -. 50.0)
    ->Graphics.lineTo(x +. 12.0, groundY -. 50.0)
    ->Graphics.lineTo(x, groundY -. 30.0)
    ->Graphics.fill({"color": 0x00ff88, "alpha": 0.7})
  let _ = Container.addChildGraphics(worldContainer, dropoff)

  let label = Text.make({
    "text": "DROPOFF",
    "style": {"fontSize": 11, "fill": 0x00ff88},
  })
  Text.setX(label, x -. 22.0)
  Text.setY(label, groundY -. 65.0)
  let _ = Container.addChildText(worldContainer, label)
}

let drawWire = (worldContainer: Container.t, ~x: float): Graphics.t => {
  let wire = Graphics.make()
  let _ =
    wire
    ->Graphics.moveTo(x, groundY -. 5.0)
    ->Graphics.lineTo(x +. 5.0, groundY -. 15.0)
    ->Graphics.lineTo(x -. 5.0, groundY -. 25.0)
    ->Graphics.lineTo(x +. 5.0, groundY -. 35.0)
    ->Graphics.stroke({"color": 0xffaa00, "width": 2.0})
  let _ = Container.addChildGraphics(worldContainer, wire)

  let label = Text.make({
    "text": "WIRE",
    "style": {"fontSize": 10, "fill": 0xffaa00},
  })
  Text.setX(label, x -. 12.0)
  Text.setY(label, groundY -. 50.0)
  let _ = Container.addChildText(worldContainer, label)

  wire
}

//  Draw Building

let drawBuilding = (worldContainer: Container.t): unit => {
  let building = Graphics.make()
  let bx = Building.x
  let bw = Building.width

  // Building exterior — dark grey rectangle
  let _ =
    building
    ->Graphics.rect(bx, Building.topY, bw, Building.totalHeight)
    ->Graphics.fill({"color": 0x334455})
    ->Graphics.stroke({"color": 0x556677, "width": 2.0})
  let _ = Container.addChildGraphics(worldContainer, building)

  // Floor lines and labels
  for i in 1 to Building.floors {
    let floorY = groundY -. Int.toFloat(i) *. Building.floorHeight
    let floorLine = Graphics.make()
    let _ =
      floorLine
      ->Graphics.moveTo(bx, floorY)
      ->Graphics.lineTo(bx +. bw, floorY)
      ->Graphics.stroke({"color": 0x667788, "width": 1.0})
    let _ = Container.addChildGraphics(worldContainer, floorLine)

    // Floor number
    let floorLabel = Text.make({
      "text": `F${Int.toString(i)}`,
      "style": {"fontSize": 10, "fill": 0x8899aa},
    })
    Text.setX(floorLabel, bx +. 4.0)
    Text.setY(floorLabel, floorY +. 2.0)
    let _ = Container.addChildText(worldContainer, floorLabel)
  }

  // Door at ground level
  let doorGraphic = Graphics.make()
  let _ =
    doorGraphic
    ->Graphics.rect(bx +. bw /. 2.0 -. 10.0, groundY -. 30.0, 20.0, 30.0)
    ->Graphics.fill({"color": 0x664422})
  let _ = Container.addChildGraphics(worldContainer, doorGraphic)

  // "BUILDING" label
  let buildingLabel = Text.make({
    "text": "MOLE TOWER",
    "style": {"fontSize": 11, "fill": 0x8899aa, "fontWeight": "bold"},
  })
  Text.setX(buildingLabel, bx +. 6.0)
  Text.setY(buildingLabel, Building.topY -. 16.0)
  let _ = Container.addChildText(worldContainer, buildingLabel)

  // "CATCH ZONE" on ground below building
  let catchLabel = Text.make({
    "text": "CATCH ZONE",
    "style": {"fontSize": 10, "fill": 0xff8866},
  })
  Text.setX(catchLabel, bx +. 10.0)
  Text.setY(catchLabel, groundY +. 8.0)
  let _ = Container.addChildText(worldContainer, catchLabel)
}

//  Draw Food Pellet

let drawFood = (worldContainer: Container.t, ~x: float): Graphics.t => {
  let food = Graphics.make()
  // Small green pellet
  let _ =
    food
    ->Graphics.circle(x, groundY -. 6.0, 5.0)
    ->Graphics.fill({"color": 0x44cc44})
  // Label
  let _ =
    food
    ->Graphics.rect(x -. 10.0, groundY -. 20.0, 20.0, 10.0)
    ->Graphics.fill({"color": 0x000000, "alpha": 0.4})
  let _ = Container.addChildGraphics(worldContainer, food)

  let label = Text.make({
    "text": "FOOD",
    "style": {"fontSize": 9, "fill": 0x44cc44},
  })
  Text.setX(label, x -. 10.0)
  Text.setY(label, groundY -. 19.0)
  let _ = Container.addChildText(worldContainer, label)

  food
}

//  Draw Equipment Station
//
// Small coloured crate with label showing what equipment it contains.
// Mole walks up and presses B to equip.

let equipStationLabel = (stationType: equipStationType): (string, int) => {
  switch stationType {
  | HeadStation(Flash) => ("FLASH", 0xffff00)
  | HeadStation(BatteringRam) => ("RAM", 0x888888)
  | HeadStation(Camera) => ("CAMERA", 0x00ff44)
  | HeadStation(Miniglider) => ("GLIDER", 0x4488cc)
  | BodyStation(Skateboard) => ("SKATE", 0x666666)
  | BodyStation(Rucksack) => ("RUCKSACK", 0x664422)
  | BodyStation(NoBody) => ("NONE", 0x444444)
  }
}

let drawEquipStation = (
  worldContainer: Container.t,
  ~x: float,
  ~groundY: float,
  ~stationType: equipStationType,
): unit => {
  let (label, color) = equipStationLabel(stationType)

  // Crate body (small box on ground)
  let crate = Graphics.make()
  let _ =
    crate
    ->Graphics.rect(x -. 12.0, groundY -. 20.0, 24.0, 20.0)
    ->Graphics.fill({"color": color, "alpha": 0.3})
    ->Graphics.stroke({"width": 1, "color": color})
  let _ = Container.addChildGraphics(worldContainer, crate)

  // Equipment icon on crate (small symbol)
  let icon = Graphics.make()
  switch stationType {
  | HeadStation(Flash) => {
      // Yellow flash bolt
      let _ =
        icon
        ->Graphics.moveTo(x -. 3.0, groundY -. 18.0)
        ->Graphics.lineTo(x +. 2.0, groundY -. 12.0)
        ->Graphics.lineTo(x -. 1.0, groundY -. 12.0)
        ->Graphics.lineTo(x +. 3.0, groundY -. 4.0)
        ->Graphics.stroke({"color": 0xffff00, "width": 2.0})
    }
  | HeadStation(BatteringRam) => {
      // Grey helmet shape
      let _ =
        icon
        ->Graphics.rect(x -. 6.0, groundY -. 16.0, 12.0, 6.0)
        ->Graphics.fill({"color": 0x888888})
    }
  | HeadStation(Camera) => {
      // Green lens circle
      let _ =
        icon
        ->Graphics.circle(x, groundY -. 12.0, 5.0)
        ->Graphics.fill({"color": 0x00ff44, "alpha": 0.6})
    }
  | HeadStation(Miniglider) => {
      // Blue wing triangle
      let _ =
        icon
        ->Graphics.moveTo(x -. 8.0, groundY -. 8.0)
        ->Graphics.lineTo(x +. 8.0, groundY -. 8.0)
        ->Graphics.lineTo(x, groundY -. 16.0)
        ->Graphics.lineTo(x -. 8.0, groundY -. 8.0)
        ->Graphics.fill({"color": 0x4488cc, "alpha": 0.5})
    }
  | BodyStation(Skateboard) => {
      // Grey board shape
      let _ =
        icon
        ->Graphics.rect(x -. 8.0, groundY -. 6.0, 16.0, 3.0)
        ->Graphics.fill({"color": 0x666666})
      let _ =
        icon
        ->Graphics.circle(x -. 5.0, groundY -. 2.0, 2.0)
        ->Graphics.fill({"color": 0x333333})
      let _ =
        icon
        ->Graphics.circle(x +. 5.0, groundY -. 2.0, 2.0)
        ->Graphics.fill({"color": 0x333333})
    }
  | BodyStation(Rucksack) => {
      // Brown bag shape
      let _ =
        icon
        ->Graphics.rect(x -. 5.0, groundY -. 16.0, 10.0, 12.0)
        ->Graphics.fill({"color": 0x664422})
        ->Graphics.stroke({"color": 0x886633, "width": 1.0})
    }
  | BodyStation(NoBody) => ()
  }
  let _ = Container.addChildGraphics(worldContainer, icon)

  // Label above crate
  let labelText = Text.make({
    "text": label,
    "style": {"fontSize": 9, "fill": color, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(labelText), 0.5, ~y=1.0)
  Text.setX(labelText, x)
  Text.setY(labelText, groundY -. 23.0)
  let _ = Container.addChildText(worldContainer, labelText)

  // "B" prompt
  let promptText = Text.make({
    "text": "[B]",
    "style": {"fontSize": 8, "fill": 0x999999},
  })
  ObservablePoint.set(Text.anchor(promptText), 0.5, ~y=0.0)
  Text.setX(promptText, x)
  Text.setY(promptText, groundY +. 4.0)
  let _ = Container.addChildText(worldContainer, promptText)
}

//  Setup Entities

let setupEntities = (gameState: GameLoop.gameState, worldContainer: Container.t): unit => {
  // Draw underground earth zone
  drawUnderground(worldContainer)

  // Draw building
  drawBuilding(worldContainer)

  // Catch zone visual indicator (semi-transparent rectangle on ground)
  let catchZoneGfx = Graphics.make()
  let czLeft = Building.x +. Building.width /. 2.0 -. Building.catchRadius
  let czRight = Building.x +. Building.width /. 2.0 +. Building.catchRadius
  let _ =
    catchZoneGfx
    ->Graphics.rect(czLeft, groundY -. 4.0, czRight -. czLeft, 8.0)
    ->Graphics.fill({"color": 0xff8866, "alpha": 0.2})
    ->Graphics.stroke({"width": 1, "color": 0xff8866})
  let _ = Container.addChildGraphics(worldContainer, catchZoneGfx)

  // Dog hearing range visual (updated each frame)
  let dogHearingGfx = Graphics.make()
  let _ = Container.addChildGraphics(worldContainer, dogHearingGfx)

  // Spawn 2 guards for trap practice
  let guards = [
    GuardNPC.make(
      ~id="train_mole_guard1",
      ~rank=BasicGuard,
      ~x=500.0,
      ~y=groundY,
      ~waypoints=[{x: 400.0, pauseDurationSec: 3.0}, {x: 700.0, pauseDurationSec: 3.0}],
    ),
    GuardNPC.make(
      ~id="train_mole_guard2",
      ~rank=SecurityGuard,
      ~x=1000.0,
      ~y=groundY,
      ~waypoints=[{x: 850.0, pauseDurationSec: 2.0}, {x: 1150.0, pauseDurationSec: 2.0}],
    ),
  ]
  gameState.guards = guards

  // Spawn RoboDog that prioritises Moletaire
  let dog = SecurityDog.make(
    ~id="train_mole_dog",
    ~variant=RoboDog,
    ~x=650.0,
    ~y=groundY,
    ~waypoints=[{x: 400.0, pauseDurationSec: 1.0}, {x: 900.0, pauseDurationSec: 1.0}],
    (),
  )
  gameState.dogs = [dog]

  // Arena object positions
  let usbX = 300.0
  let dropoffX = 1200.0
  let wireX = 750.0
  let foodX = 150.0

  // Draw arena objects
  let _usbGraphic = drawUSB(worldContainer, ~x=usbX, ~y=groundY)
  drawDropoff(worldContainer, ~x=dropoffX)
  let _wireGraphic = drawWire(worldContainer, ~x=wireX)
  let _foodGraphic = drawFood(worldContainer, ~x=foodX)

  // Equipment pickup stations — one for each equipment type
  let equipStations: array<equipmentStation> = [
    {x: 60.0, equipType: HeadStation(Flash), collected: false},
    {x: 120.0, equipType: HeadStation(BatteringRam), collected: false},
    {x: 180.0, equipType: HeadStation(Camera), collected: false},
    {x: 240.0, equipType: HeadStation(Miniglider), collected: false},
    {x: 1280.0, equipType: BodyStation(Skateboard), collected: false},
    {x: 1340.0, equipType: BodyStation(Rucksack), collected: false},
  ]
  Array.forEach(equipStations, station => {
    drawEquipStation(worldContainer, ~x=station.x, ~groundY, ~stationType=station.equipType)
  })

  // Create mole entity (starts on surface, visible)
  let equipment: Moletaire.equipmentLoadout = {
    head: None,
    body: NoBody,
  }
  let mole = Moletaire.make(~id="training_mole", ~x=200.0, ~y=groundY, ~equipment)
  let _ = Container.addChild(worldContainer, mole.container)

  // Initialize training state
  trainingStateRef :=
    Some({
      mole,
      trapTriggered: false,
      usbDelivered: false,
      usbPickedUp: false,
      usbX,
      usbY: groundY,
      dropoffX,
      wireX,
      wireActive: false,
      wireTimer: 0.0,
      musicStarted: false,
      prevToggle: false,
      prevTrap: false,
      prevItem: false,
      // Dog confusion
      dogLastMoleSide: 0,
      dogSideSwitchCount: 0,
      dogSideSwitchTimer: 0.0,
      dogConfusionTimer: 0.0,
      dogDigging: false,
      // Building
      moleInBuilding: false,
      moleFloor: 0,
      moleJumping: false,
      moleJumpY: 0.0,
      moleCaught: false,
      // Hunger
      hungerBarGraphic: None,
      foodX,
      foodAvailable: true,
      foodRespawnTimer: 0.0,
      // USB-eaten failure
      usbEatenByMole: false,
      // Visual feedback
      catchZoneGraphic: Some(catchZoneGfx),
      dogHearingGraphic: Some(dogHearingGfx),
      equipStations,
    })
}

//  Mole Controls HUD

let drawMoleControlsHUD = (container: Container.t): unit => {
  let controlsBg = Graphics.make()
  let _ =
    controlsBg
    ->Graphics.roundRect(0.0, 0.0, 340.0, 90.0, 6.0)
    ->Graphics.fill({"color": 0x000000, "alpha": 0.6})
    ->Graphics.stroke({"width": 1, "color": 0x6b4226})
  let _ = Container.addChildGraphics(container, controlsBg)

  let controlsTitle = Text.make({
    "text": "MOLE CONTROLS",
    "style": {"fontSize": 13, "fill": 0xff9999, "fontWeight": "bold"},
  })
  Text.setX(controlsTitle, 8.0)
  Text.setY(controlsTitle, 4.0)
  let _ = Container.addChildText(container, controlsTitle)

  let controlsText = Text.make({
    "text": "J/K move mole | M toggle underground\nN dig trap | B pick up / deliver / eat / equip\nMole gets hungry! Walk to crates to equip gear",
    "style": {"fontSize": 11, "fill": 0xaaaaaa},
  })
  Text.setX(controlsText, 8.0)
  Text.setY(controlsText, 22.0)
  let _ = Container.addChildText(container, controlsText)

  // Position bottom-right
  Graphics.setX(controlsBg, -350.0)
  Graphics.setY(controlsBg, -100.0)
  Text.setX(controlsTitle, -342.0)
  Text.setY(controlsTitle, -96.0)
  Text.setX(controlsText, -342.0)
  Text.setY(controlsText, -78.0)
}

//  Status Display

let moleStatusText: ref<option<Text.t>> = ref(None)

let drawMoleStatus = (container: Container.t): unit => {
  let statusText = Text.make({
    "text": "",
    "style": {"fontSize": 12, "fill": 0x6b4226},
  })
  let _ = Container.addChildText(container, statusText)
  moleStatusText := Some(statusText)
}

let updateMoleStatus = (ts: trainingState): unit => {
  switch moleStatusText.contents {
  | Some(text) => {
      let mole = ts.mole
      let stateStr = Moletaire.stateToString(mole)
      let depthStr = Float.toFixed(mole.depth, ~digits=1)
      let hungerPct = Int.toString(Float.toInt(Moletaire.getHunger(mole) *. 100.0))
      let carryStr = if Array.length(mole.carriedItems) > 0 {
        ` [${Int.toString(Array.length(mole.carriedItems))} items]`
      } else {
        ""
      }
      let trapStr = if ts.trapTriggered { " [TRAP OK]" } else { "" }
      let usbStr = if ts.usbDelivered { " [USB OK]" } else { "" }
      let hungerStr = if Moletaire.isResistingControl(mole) {
        " HUNGRY!"
      } else if Moletaire.getHunger(mole) > 0.4 {
        ` Hunger:${hungerPct}%`
      } else {
        ""
      }
      let dogStr = if ts.dogConfusionTimer > 0.0 {
        " [DOG CONFUSED]"
      } else if ts.dogDigging {
        " [DOG DIGGING]"
      } else {
        ""
      }
      let headStr = switch mole.equipment.head {
      | Some(Flash) => " Head:Flash"
      | Some(BatteringRam) => " Head:Ram"
      | Some(Camera) => " Head:Camera"
      | Some(Miniglider) => " Head:Glider"
      | None => ""
      }
      let bodyStr = switch mole.equipment.body {
      | Skateboard => " Body:Skate"
      | Rucksack => ` Body:Ruck(${Int.toString(Array.length(mole.carriedItems))}/${Int.toString(Moletaire.getCarryCapacity(mole))})`
      | NoBody => ""
      }
      let usbEatenStr = if ts.usbEatenByMole {
        " | MOLE ATE THE USB! Press Reset (R)"
      } else {
        ""
      }
      Text.setText(
        text,
        `Mole: ${stateStr} | Depth: ${depthStr}${carryStr}${headStr}${bodyStr}${trapStr}${usbStr}${hungerStr}${dogStr}${usbEatenStr}`,
      )
    }
  | None => ()
  }
}

//  Hunger Bar Rendering

let hungerBarRef: ref<option<Graphics.t>> = ref(None)

let drawHungerBar = (container: Container.t): unit => {
  let bar = Graphics.make()
  let _ = Container.addChildGraphics(container, bar)
  hungerBarRef := Some(bar)
}

let updateHungerBar = (mole: Moletaire.t): unit => {
  switch hungerBarRef.contents {
  | Some(bar) => {
      let _ = Graphics.clear(bar)
      let hunger = Moletaire.getHunger(mole)

      // Background (dark)
      let _ =
        bar
        ->Graphics.rect(0.0, 0.0, 100.0, 10.0)
        ->Graphics.fill({"color": 0x333333})

      // Fill (green → yellow → red based on hunger)
      let fillColor = if hunger < 0.4 {
        0x44cc44 // Green — well fed
      } else if hunger < 0.7 {
        0xcccc44 // Yellow — getting hungry
      } else {
        0xcc4444 // Red — starving
      }
      let fillWidth = hunger *. 100.0
      let _ =
        bar
        ->Graphics.rect(0.0, 0.0, fillWidth, 10.0)
        ->Graphics.fill({"color": fillColor})

      // Border
      let _ =
        bar
        ->Graphics.rect(0.0, 0.0, 100.0, 10.0)
        ->Graphics.stroke({"color": 0x666666, "width": 1.0})

      // "HUNGER" resistingControl flash
      if Moletaire.isResistingControl(mole) {
        let _ =
          bar
          ->Graphics.rect(-2.0, -2.0, 104.0, 14.0)
          ->Graphics.stroke({"color": 0xff0000, "width": 2.0})
      }
    }
  | None => ()
  }
}

//  Dog-Mole AI Update

// Updates the dog's behaviour toward Moletaire.
// Returns true if the dog is currently distracted/confused by the mole.
let updateDogMoleAI = (ts: trainingState, dog: SecurityDog.t, dt: float): unit => {
  let mole = ts.mole
  let moleX = mole.x
  let dogX = dog.x
  let dist = absFloat(moleX -. dogX)

  // Decrement confusion timer
  if ts.dogConfusionTimer > 0.0 {
    ts.dogConfusionTimer = ts.dogConfusionTimer -. dt
    // Dog spins in place when confused (oscillate facing)
    if mod(Float.toInt(ts.dogConfusionTimer *. 4.0), 2) == 0 {
      dog.facing = SecurityDog.Left
    } else {
      dog.facing = SecurityDog.Right
    }
    ts.dogDigging = false
  } else if dist < DogMoleAI.hearingRange {
    // Dog can hear mole within circular hearing range (regardless of facing).
    // Detection is sound-based: mole digging/moving underground makes noise.

    // Check if mole is underground but within the dog's shallow dig reach
    if Moletaire.isUnderground(mole) && mole.depth < DogMoleAI.dogDigDepth {
      // Mole is close enough to the surface — dog can paw down to catch it.
      // This is the danger zone when mole is setting traps or distracting guards.
      ts.dogDigging = true
      // Move dog toward mole position
      let dir = if moleX > dogX { 1.0 } else { -1.0 }
      dog.x = dog.x +. dir *. DogMoleAI.digSpeed *. dt
      dog.facing = if dir > 0.0 { SecurityDog.Right } else { SecurityDog.Left }
    } else if Moletaire.isUnderground(mole) && mole.depth < DogMoleAI.dogDigDepth *. DogMoleAI.maxDigReach {
      // Mole is slightly deeper — dog can hear it but struggles to dig.
      // Dog paces above the mole's position, pawing occasionally but can't reach.
      ts.dogDigging = false
      let dir = if moleX > dogX { 1.0 } else { -1.0 }
      dog.x = dog.x +. dir *. DogMoleAI.digSpeed *. 0.5 *. dt
      dog.facing = if dir > 0.0 { SecurityDog.Right } else { SecurityDog.Left }
    } else if !Moletaire.isUnderground(mole) {
      ts.dogDigging = false
      // Mole is on surface — track side switches for confusion mechanic
      let currentSide = if moleX > dogX { 1 } else { -1 }

      ts.dogSideSwitchTimer = ts.dogSideSwitchTimer +. dt

      if currentSide != ts.dogLastMoleSide && ts.dogLastMoleSide != 0 {
        // Mole switched sides
        if ts.dogSideSwitchTimer < DogMoleAI.sideSwitchCooldown {
          // Quick switch — counts toward confusion
          ts.dogSideSwitchCount = ts.dogSideSwitchCount + 1
          if ts.dogSideSwitchCount >= DogMoleAI.confusionThreshold {
            // Dog is confused!
            ts.dogConfusionTimer = DogMoleAI.confusionDuration
            ts.dogSideSwitchCount = 0
          }
        } else {
          // Slow switch — doesn't count, reset
          ts.dogSideSwitchCount = 0
        }
        ts.dogSideSwitchTimer = 0.0
      }
      ts.dogLastMoleSide = currentSide

      // Chase the mole on the surface
      let chaseDir = if moleX > dogX { 1.0 } else { -1.0 }
      dog.x = dog.x +. chaseDir *. dog.speed *. 1.5 *. dt
      dog.facing = if chaseDir > 0.0 { SecurityDog.Right } else { SecurityDog.Left }
    } else {
      // Mole is deep underground — dog can hear faintly but can't reach, resume patrol
      ts.dogDigging = false
    }
  } else {
    ts.dogDigging = false
  }
}

//  Building Interaction

// Check if mole is at the building entrance (ground level, near door)
let isMoleAtBuildingDoor = (mole: Moletaire.t): bool => {
  let moleX = mole.x
  let doorCenterX = Building.x +. Building.width /. 2.0
  absFloat(moleX -. doorCenterX) <= Building.doorHitboxHalfWidth && !Moletaire.isUnderground(mole)
}

//  Per-Frame Update

let onUpdate = (
  player: Player.t,
  keyState: WorldBuilder.keyState,
  _hud: HUD.t,
  gameState: GameLoop.gameState,
  _worldContainer: Container.t,
  dt: float,
): TrainingBase.trainingResult => {
  switch trainingStateRef.contents {
  | None => Continue
  | Some(ts) => {
      let mole = ts.mole

      //  Process mole input (only if not resisting control from hunger)
      let canControl = !Moletaire.isResistingControl(mole) && !ts.moleJumping

      if canControl {
        // Move left/right (direct speed injection for responsiveness)
        let moveSpeed = if Moletaire.isUnderground(mole) { 200.0 } else { 180.0 }
        if keyState.moleLeft && !keyState.moleRight {
          mole.x = Math.max(50.0, mole.x -. moveSpeed *. dt)
          mole.facing = Moletaire.Left
          mole.targetX = None
        } else if keyState.moleRight && !keyState.moleLeft {
          mole.x = Math.min(arenaWidth -. 50.0, mole.x +. moveSpeed *. dt)
          mole.facing = Moletaire.Right
          mole.targetX = None
        }

        // Toggle underground (on press, not hold)
        if keyState.moleToggle && !ts.prevToggle {
          if ts.moleInBuilding {
            // In building: M moves up a floor
            if ts.moleFloor < Building.floors {
              ts.moleFloor = ts.moleFloor + 1
              // Move mole visual to that floor
              let floorY = groundY -. Int.toFloat(ts.moleFloor) *. Building.floorHeight
              mole.y = floorY
              Container.setY(mole.container, floorY)
            } else {
              // At top floor — jump!
              ts.moleJumping = true
              ts.moleJumpY = Building.topY
              ts.moleInBuilding = false
              ts.moleFloor = 0
            }
          } else if Moletaire.isUnderground(mole) {
            mole.targetDepth = Some(0.0)
            mole.state = MovingAboveGround
          } else {
            mole.targetDepth = Some(0.5)
            mole.state = MovingUnderground
          }
        }

        // Dig trap (on press)
        if keyState.moleTrap && !ts.prevTrap {
          Moletaire.orderDigTrap(mole)
        }

        // Pick up / deliver / eat food / enter building / equip (on press)
        if keyState.moleItem && !ts.prevItem {
          // Priority 1: Check equipment stations (equip on contact)
          let equipped = ref(false)
          if !Moletaire.isUnderground(mole) {
            Array.forEach(ts.equipStations, station => {
              if (
                !station.collected &&
                !equipped.contents &&
                Moletaire.distanceTo(mole, ~x=station.x) < 30.0
              ) {
                switch station.equipType {
                | HeadStation(head) => Moletaire.equipHead(mole, ~head)
                | BodyStation(body) => Moletaire.equipBody(mole, ~body)
                }
                station.collected = true
                equipped := true
              }
            })
          }

          if !equipped.contents {
            // Priority 2: Deliver if carrying items
            if Moletaire.isCarrying(mole) {
              Moletaire.orderDeliver(mole, ~deliveryX=ts.dropoffX)
            } else if isMoleAtBuildingDoor(mole) && !ts.moleInBuilding {
              // Priority 3: Enter building
              ts.moleInBuilding = true
              ts.moleFloor = 1
              mole.x = Building.x +. Building.width /. 2.0
              let floorY = groundY -. Building.floorHeight
              mole.y = floorY
              Container.setY(mole.container, floorY)
            } else if ts.foodAvailable && Moletaire.distanceTo(mole, ~x=ts.foodX) < 30.0 {
              // Priority 4: Eat food pellet — reduces hunger
              ts.foodAvailable = false
              Moletaire.feed(mole)
            } else if !ts.usbPickedUp {
              // Priority 5: Pick up USB
              let usbDist = Moletaire.distanceTo(mole, ~x=ts.usbX)
              if usbDist < 40.0 {
                let picked = Moletaire.giveItem(mole, ~itemId="training_usb")
                if picked {
                  ts.usbPickedUp = true
                }
              }
            }
          }
        }
      }

      // Save previous input for edge detection
      ts.prevToggle = keyState.moleToggle
      ts.prevTrap = keyState.moleTrap
      ts.prevItem = keyState.moleItem

      //  Mole falling from building (jump)
      if ts.moleJumping {
        let fallSpeed = 180.0 // Pixels per second
        ts.moleJumpY = ts.moleJumpY +. fallSpeed *. dt
        mole.x = Building.x +. Building.width /. 2.0 // Stay centered on building

        // Dynamic catch zone feedback: green if Jessica is in range, red if not
        switch ts.catchZoneGraphic {
        | Some(gfx) => {
            let _ = Graphics.clear(gfx)
            let czLeft = Building.x +. Building.width /. 2.0 -. Building.catchRadius
            let czWidth = Building.catchRadius *. 2.0
            let pX = Player.getX(player)
            let catchDist = absFloat(pX -. (Building.x +. Building.width /. 2.0))
            let (czColor, czAlpha) = if catchDist < Building.catchRadius {
              (0x44ff44, 0.35) // Green  Jessica is in position!
            } else {
              (0xff4444, 0.35) // Red  Jessica needs to move!
            }
            let _ =
              gfx
              ->Graphics.rect(czLeft, groundY -. 4.0, czWidth, 8.0)
              ->Graphics.fill({"color": czColor, "alpha": czAlpha})
              ->Graphics.stroke({"width": 1, "color": czColor})
          }
        | None => ()
        }

        // Update visual position
        Container.setY(mole.container, ts.moleJumpY)

        // Check if Jessica (player) is positioned below to catch
        if ts.moleJumpY >= groundY -. 20.0 {
          let playerX = Player.getX(player)
          let catchDist = absFloat(playerX -. mole.x)
          if catchDist < Building.catchRadius {
            // Caught! Jessica saves the mole
            ts.moleCaught = true
            ts.moleJumping = false
            mole.y = groundY
            Container.setY(mole.container, groundY)
          } else {
            // Splat — mole dies (training: respawn)
            ts.moleJumping = false
            mole.y = groundY
            Container.setY(mole.container, groundY)
            // Reset mole
            let newMole = Moletaire.make(
              ~id="training_mole",
              ~x=200.0,
              ~y=groundY,
              ~equipment={head: None, body: Moletaire.NoBody},
            )
            let _ = Container.addChild(_worldContainer, newMole.container)
            ts.mole = newMole
          }
        }
      }

      //  Wire distraction cycle
      ts.wireTimer = ts.wireTimer +. dt
      if ts.wireTimer > 8.0 {
        ts.wireTimer = 0.0
        ts.wireActive = !ts.wireActive
        if ts.wireActive {
          let _ = Moletaire.distractByWire(mole, ~wireX=ts.wireX)
        }
      }

      // Food respawn: pellet reappears after 12 seconds (training concession per spec)
      if !ts.foodAvailable {
        ts.foodRespawnTimer = ts.foodRespawnTimer +. dt
        if ts.foodRespawnTimer >= 12.0 {
          ts.foodAvailable = true
          ts.foodRespawnTimer = 0.0
        }
      }

      //  Hunger: set nearest component as hunger target
      if Moletaire.getHunger(mole) > 0.4 {
        // When hungry, target the nearest edible thing
        let nearestTarget = if Moletaire.isStarving(mole) && !ts.usbPickedUp {
          // Starving — will eat the USB objective!
          ts.usbX
        } else if ts.foodAvailable {
          ts.foodX
        } else if !ts.usbPickedUp {
          ts.usbX
        } else {
          ts.wireX // Just wander toward the wire
        }
        Moletaire.setHungerTarget(mole, ~targetX=nearestTarget)

        // If starving mole reaches USB, it eats it
        if Moletaire.isStarving(mole) && !ts.usbPickedUp {
          let usbDist = Moletaire.distanceTo(mole, ~x=ts.usbX)
          if usbDist < 20.0 && Moletaire.isResistingControl(mole) {
            // Mole ate the USB! Can't complete the objective now.
            ts.usbPickedUp = true // Mark as "gone"
            ts.usbEatenByMole = true
            Moletaire.feed(mole) // Mole is satisfied now
          }
        }
      }

      //  Dog-Mole AI
      switch gameState.dogs[0] {
      | Some(dog) => {
          updateDogMoleAI(ts, dog, dt)
          // Dog-mole chase safety: suppress Jessica detection when dog is
          // focused on Moletaire to prevent unfair chain failure (per spec H4)
          if ts.dogConfusionTimer > 0.0 || ts.dogDigging || ts.dogLastMoleSide != 0 {
            dog.suspicion = 0.0
            dog.lastScentX = None
          }
        }
      | None => ()
      }

      // Dog hearing range and pawing visualisation
      switch (gameState.dogs[0], ts.dogHearingGraphic) {
      | (Some(dog), Some(gfx)) => {
          let _ = Graphics.clear(gfx)
          // Hearing range circle
          let hearingColor = if ts.dogDigging {
            0xff4444 // Red  digging!
          } else if ts.dogConfusionTimer > 0.0 {
            0xffff44 // Yellow  confused
          } else if ts.dogLastMoleSide != 0 {
            0xff8844 // Orange  tracking
          } else {
            0x44aa44 // Green  calm
          }
          let _ =
            gfx
            ->Graphics.circle(dog.x, groundY -. 15.0, DogMoleAI.hearingRange)
            ->Graphics.fill({"color": hearingColor, "alpha": 0.06})
            ->Graphics.stroke({"color": hearingColor, "width": 1.0})

          // Digging dirt particles
          if ts.dogDigging {
            let _ =
              gfx
              ->Graphics.rect(dog.x -. 8.0, groundY -. 3.0, 4.0, 3.0)
              ->Graphics.fill({"color": 0xaa8833, "alpha": 0.6})
            let _ =
              gfx
              ->Graphics.rect(dog.x +. 5.0, groundY -. 5.0, 3.0, 3.0)
              ->Graphics.fill({"color": 0xaa8833, "alpha": 0.5})
          }

          // Confusion indicator (spinning circle above dog)
          if ts.dogConfusionTimer > 0.0 {
            let _ =
              gfx
              ->Graphics.circle(dog.x, groundY -. 50.0, 6.0)
              ->Graphics.stroke({"color": 0xffff44, "width": 2.0})
            let _ =
              gfx
              ->Graphics.circle(dog.x, groundY -. 50.0, 3.0)
              ->Graphics.fill({"color": 0xffff44, "alpha": 0.5})
          }
        }
      | _ => ()
      }

      // Check if dog caught the mole (within dig range + mole within dog's shallow reach)
      switch gameState.dogs[0] {
      | Some(dog) =>
        if (
          ts.dogDigging &&
          absFloat(dog.x -. mole.x) < 30.0 &&
          Moletaire.isUnderground(mole) &&
          mole.depth < DogMoleAI.dogDigDepth
        ) {
          // Dog caught the mole! Reset in training.
          Moletaire.catchByDog(mole)
        }
      | None => ()
      }

      //  Music: play when underground, stop when on surface
      if Moletaire.isUnderground(mole) {
        if !MoletaireMusic.isPlaying() {
          MoletaireMusic.start()
          ts.musicStarted = true
        }
      } else if MoletaireMusic.isPlaying() {
        MoletaireMusic.stop()
      }

      // Training: faster hunger rate so the mechanic is visible quickly (spec training overrides)
      // Override hunger directly since Moletaire.update uses its internal Tuning.hungerRate
      let trainingHungerBoost = 0.02 *. dt // 0.035 total - 0.015 base = 0.02 extra
      if mole.alive {
        mole.hunger = Math.min(1.0, mole.hunger +. trainingHungerBoost)
      }

      //  Update mole entity
      let moleEvent = Moletaire.update(mole, ~dt)

      //  Process mole events
      switch moleEvent {
      | Some(Moletaire.TrapTriggered(trapX, _trapY)) => {
          let guardCaught = gameState.guards->Array.some(guard => {
            let guardDist = absFloat(guard.x -. trapX)
            guardDist < 40.0
          })
          if guardCaught {
            ts.trapTriggered = true
          }
        }
      | Some(Moletaire.ItemDelivered(_)) => {
          let dropDist = Moletaire.distanceTo(mole, ~x=ts.dropoffX)
          if dropDist < 60.0 {
            ts.usbDelivered = true
          }
        }
      | Some(Moletaire.ItemEaten(_)) => ()
      | Some(Moletaire.MoleDied(_)) => {
          // Training: reset mole instead of permadeath
          let newMole = Moletaire.make(
            ~id="training_mole",
            ~x=200.0,
            ~y=groundY,
            ~equipment={head: None, body: Moletaire.NoBody},
          )
          let _ = Container.addChild(_worldContainer, newMole.container)
          ts.mole = newMole
        }
      | _ => ()
      }

      //  Update status + hunger bar
      updateMoleStatus(ts)
      updateHungerBar(mole)

      //  Check victory: both objectives met
      if ts.trapTriggered && ts.usbDelivered {
        MoletaireMusic.stop()
        Victory
      } else {
        Continue
      }
    }
  }
}

//  Screen Constructor

let constructorRef: ref<option<Navigation.appScreenConstructor>> = ref(None)

let make = (): Navigation.appScreen => {
  let screen = TrainingBase.makeTrainingScreen(
    config,
    ~setupEntities,
    ~onBack=() => {
      MoletaireMusic.stop()
      TrainingBase.backToMenu()
    },
    ~onReset=() => {
      MoletaireMusic.stop()
      trainingStateRef := None
      switch (GetEngine.get(), constructorRef.contents) {
      | (Some(engine), Some(c)) => Navigation.showScreen(engine.navigation, c)->ignore
      | _ => ()
      }
    },
    ~onUpdate,
    ~selfConstructor=?constructorRef.contents,
  )

  // Add mole controls HUD, status, and hunger bar to the screen container
  drawMoleControlsHUD(screen.container)
  drawMoleStatus(screen.container)
  drawHungerBar(screen.container)

  screen
}

let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(["main"]),
}

let _ = constructorRef := Some(constructor)
