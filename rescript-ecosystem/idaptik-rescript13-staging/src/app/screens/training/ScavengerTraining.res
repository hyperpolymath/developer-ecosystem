// SPDX-License-Identifier: PMPL-1.0-or-later
// ScavengerTraining  Find the USB drive, avoid the microchip trap
//
// Teaches the player that not every item is safe to grab.
// Objectives:
//   - Find and pick up the hidden USB stick (behind crates on the right)
//   - Avoid the microchip trap (visible, tempting, but deadly)
//
// Microchip trap mechanic:
//   Player presses E near the chip  frozen for 4 seconds,
//   "This weighs a tonne!" text appears, guards rush over,
//   then "CAUGHT"  level resets.

open Pixi

let config: TrainingBase.trainingConfig = {
  title: "Scavenger Hunt",
  instructions: [
    "Find the hidden USB drive. Press E near items to pick them up.",
    "Not everything is safe to grab...",
    "Some passages require crouching (C key) to pass through.",
  ],
  arenaWidth: 1600.0,
  groundY: 500.0,
}

//  Crouch Passage 

// Low ceiling zone: player must crouch (C key) to pass through.
// Zone spans x=1050..1130, with a ceiling at groundY - 35 (crouch height).
let crouchZoneX1 = 1050.0
let crouchZoneX2 = 1130.0
let crouchCeilingY = 500.0 -. 35.0 // Ceiling sits at crouch height

// Draw the crouch passage (low overhead pipe/duct)
let drawCrouchPassage = (worldContainer: Pixi.Container.t, ~groundY: float): unit => {
  // Overhead pipe  forces crouching
  let pipe = Graphics.make()
  let _ =
    pipe
    ->Graphics.rect(crouchZoneX1, crouchCeilingY -. 8.0, crouchZoneX2 -. crouchZoneX1, 8.0)
    ->Graphics.fill({"color": 0x555577})
    ->Graphics.stroke({"width": 1, "color": 0x777799})
  let _ = Container.addChildGraphics(worldContainer, pipe)

  // Support pillars on each side
  let leftPillar = Graphics.make()
  let _ =
    leftPillar
    ->Graphics.rect(
      crouchZoneX1 -. 6.0,
      crouchCeilingY -. 8.0,
      6.0,
      groundY -. crouchCeilingY +. 8.0,
    )
    ->Graphics.fill({"color": 0x444466})
  let _ = Container.addChildGraphics(worldContainer, leftPillar)

  let rightPillar = Graphics.make()
  let _ =
    rightPillar
    ->Graphics.rect(crouchZoneX2, crouchCeilingY -. 8.0, 6.0, groundY -. crouchCeilingY +. 8.0)
    ->Graphics.fill({"color": 0x444466})
  let _ = Container.addChildGraphics(worldContainer, rightPillar)

  // Warning sign
  let warnText = Text.make({
    "text": "CROUCH",
    "style": {
      "fontFamily": "monospace",
      "fontSize": 10,
      "fill": 0xffaa00,
      "fontWeight": "bold",
    },
  })
  Text.setX(warnText, crouchZoneX1 +. 15.0)
  Text.setY(warnText, crouchCeilingY -. 22.0)
  let _ = Container.addChildText(worldContainer, warnText)
}

//  Crate Props 

// Draw simple crate rectangles as cover/scenery
let drawCrate = (
  worldContainer: Container.t,
  ~x: float,
  ~groundY: float,
  ~w: float,
  ~h: float,
): unit => {
  let crate = Graphics.make()
  let _ =
    crate
    ->Graphics.rect(x, groundY -. h, w, h)
    ->Graphics.fill({"color": 0x5a4a3a})
    ->Graphics.stroke({"width": 1, "color": 0x7a6a5a})
  let _ = Container.addChildGraphics(worldContainer, crate)

  // Cross brace detail
  let brace = Graphics.make()
  let _ =
    brace
    ->Graphics.rect(x +. w *. 0.15, groundY -. h *. 0.5 -. 2.0, w *. 0.7, 4.0)
    ->Graphics.fill({"color": 0x4a3a2a})
  let _ = Container.addChildGraphics(worldContainer, brace)
}

//  Entities Setup 

let setupEntities = (gameState: GameLoop.gameState, _worldContainer: Pixi.Container.t): unit => {
  // One basic guard on a wide patrol through the arena
  let guards = [
    GuardNPC.make(
      ~id="scav_patrol",
      ~rank=BasicGuard,
      ~x=600.0,
      ~y=500.0,
      ~waypoints=[{x: 400.0, pauseDurationSec: 4.0}, {x: 1000.0, pauseDurationSec: 3.0}],
    ),
  ]
  gameState.guards = guards
}

//  Floating Text 

// Show a floating text that rises and fades out
let showFloatingText = (
  worldContainer: Container.t,
  ~x: float,
  ~y: float,
  ~text: string,
  ~color: int,
  ~fontSize: float,
): unit => {
  let floatText = Text.make({
    "text": text,
    "style": {
      "fontFamily": "Arial",
      "fontSize": fontSize,
      "fill": color,
      "fontWeight": "bold",
    },
  })
  ObservablePoint.set(Text.anchor(floatText), 0.5, ~y=0.5)
  Text.setX(floatText, x)
  Text.setY(floatText, y -. 40.0)
  let _ = Container.addChildText(worldContainer, floatText)

  let _ = Motion.animate(
    floatText,
    {"alpha": 0.0, "y": y -. 100.0},
    {duration: 1.5, ease: "easeOut"},
  )
}

//  Screen Constructor 

let constructorRef: ref<option<Navigation.appScreenConstructor>> = ref(None)

let make = (): Navigation.appScreen => {
  // Create pickups (these live outside the TrainingBase setup)
  let usbPickup = WorldPickup.makeUSBStick(~x=1300.0, ~groundY=500.0)
  let chipPickup = WorldPickup.makeMicrochip(~x=800.0, ~groundY=500.0)
  // Jump drive sits on top of the stacked crate (crate top = 500 - 65 - 40 = 395)
  let jumpDrivePickup = WorldPickup.makeJumpDrive(~x=1225.0, ~groundY=395.0)

  // Register crate tops as platforms so the player can land on them
  PlayerState.setPlatforms([
    {x: 1150.0, y: 500.0 -. 50.0, width: 60.0}, // Left crate (top at 450)
    {x: 1220.0, y: 500.0 -. 65.0, width: 70.0}, // Middle crate (top at 435)
    {x: 1200.0, y: 500.0 -. 65.0 -. 40.0, width: 55.0}, // Stacked crate (top at 395)
    {x: 1350.0, y: 500.0 -. 45.0, width: 50.0}, // Right crate (top at 455)
  ])

  // Trap state
  let trapped = ref(false)
  let trapTimer = ref(0.0)
  let caughtShown = ref(false)
  let caughtTimer = ref(0.0)
  let gameTime = ref(0.0)
  let objectiveComplete = ref(false)

  // Containers for pickups and overlays  added after world is built
  let pickupContainer = Container.make()
  let overlayContainer = Container.make()
  let _ = Container.addChild(pickupContainer, usbPickup.container)
  let _ = Container.addChild(pickupContainer, chipPickup.container)
  let _ = Container.addChild(pickupContainer, jumpDrivePickup.container)

  // Trap overlay text (created once, hidden until needed)
  let trapText = Text.make({
    "text": "This weighs a tonne!",
    "style": {
      "fontFamily": "Arial",
      "fontSize": 36,
      "fill": 0xff3333,
      "fontWeight": "bold",
    },
  })
  ObservablePoint.set(Text.anchor(trapText), 0.5, ~y=0.5)
  Text.setAlpha(trapText, 0.0)
  let _ = Container.addChildText(overlayContainer, trapText)

  let caughtText = Text.make({
    "text": "CAUGHT!",
    "style": {
      "fontFamily": "Arial",
      "fontSize": 56,
      "fill": 0xff0000,
      "fontWeight": "bold",
    },
  })
  ObservablePoint.set(Text.anchor(caughtText), 0.5, ~y=0.5)
  Text.setAlpha(caughtText, 0.0)
  let _ = Container.addChildText(overlayContainer, caughtText)

  // Victory delay  show floating text for a moment before transitioning
  let victoryDelay = ref(0.0)
  let victoryTriggered = ref(false)

  // Custom per-frame update
  let onUpdate = (
    player: Player.t,
    keyState: WorldBuilder.keyState,
    hud: HUD.t,
    gameState: GameLoop.gameState,
    worldContainer: Container.t,
    dt: float,
  ): TrainingBase.trainingResult => {
    gameTime := gameTime.contents +. dt

    // Ensure pickup containers are parented to world (idempotent check)
    if Container.parent(pickupContainer)->Nullable.isNullable {
      let _ = Container.addChild(worldContainer, pickupContainer)
    }

    // Ensure overlay container is parented
    if Container.parent(overlayContainer)->Nullable.isNullable {
      let _ = Container.addChild(worldContainer, overlayContainer)
    }

    // Pulse animation on pickups
    WorldPickup.updateAnimation(usbPickup, ~gameTime=gameTime.contents)
    WorldPickup.updateAnimation(chipPickup, ~gameTime=gameTime.contents)
    WorldPickup.updateAnimation(jumpDrivePickup, ~gameTime=gameTime.contents)

    let playerX = Player.getX(player)
    let playerY = Player.getY(player)

    //  Victory delay countdown 
    if victoryTriggered.contents {
      victoryDelay := victoryDelay.contents -. dt
      if victoryDelay.contents <= 0.0 {
        Victory
      } else {
        Continue
      }
    } //  Trapped state: freeze controls, countdown, then DEFEAT 
    else if trapped.contents {
      // Override player movement  zero velocity, force crouch
      Player.stopMovement(player)

      // Position trap text in screen centre (above player)
      Text.setX(trapText, playerX)
      Text.setY(trapText, playerY -. 120.0)

      trapTimer := trapTimer.contents -. dt

      if trapTimer.contents <= 0.0 && !caughtShown.contents {
        // Show CAUGHT overlay
        caughtShown := true
        caughtTimer := 1.5
        Text.setAlpha(caughtText, 1.0)
        Text.setX(caughtText, playerX)
        Text.setY(caughtText, playerY -. 80.0)
      }

      if caughtShown.contents {
        caughtTimer := caughtTimer.contents -. dt
        if caughtTimer.contents <= 0.0 {
          Defeat("Picked up the microchip trap!")
        } else {
          Continue
        }
      } else {
        Continue
      }
    } else {
      //  Crouch passage collision: push player back if standing 
      if playerX > crouchZoneX1 && playerX < crouchZoneX2 && !keyState.crouch {
        // Player is in the crouch zone but not crouching  push them back
        if playerX < (crouchZoneX1 +. crouchZoneX2) /. 2.0 {
          Player.setX(player, crouchZoneX1 -. 5.0) // Push left
        } else {
          Player.setX(player, crouchZoneX2 +. 5.0) // Push right
        }
      }

      //  Normal gameplay: handle E key pickups 
      if keyState.interact {
        keyState.interact = false // Consume the keypress

        // Check jump drive proximity (on top of crate)
        if (
          !jumpDrivePickup.collected && WorldPickup.isInRange(jumpDrivePickup, ~playerX, ~playerY)
        ) {
          WorldPickup.animateCollect(jumpDrivePickup)
          showFloatingText(
            worldContainer,
            ~x=jumpDrivePickup.x,
            ~y=jumpDrivePickup.y,
            ~text="+Jump Drive (4GB)",
            ~color=0x4488ff,
            ~fontSize=20.0,
          )
          switch jumpDrivePickup.kind {
          | Collectible(item) => {
              let _ = Inventory.addItem(gameState.inventory, ~item)
            }
          | Trap(_) => ()
          }
        } // Check USB stick proximity
        else if !usbPickup.collected && WorldPickup.isInRange(usbPickup, ~playerX, ~playerY) {
          WorldPickup.animateCollect(usbPickup)
          objectiveComplete := true
          HUD.setObjective(hud, ~text="USB recovered!")
          showFloatingText(
            worldContainer,
            ~x=usbPickup.x,
            ~y=usbPickup.y,
            ~text="+USB Drive (2GB)",
            ~color=0x00ff88,
            ~fontSize=20.0,
          )

          // Add to inventory
          switch usbPickup.kind {
          | Collectible(item) => {
              let _ = Inventory.addItem(gameState.inventory, ~item)
            }
          | Trap(_) => ()
          }

          // Trigger victory after a short delay
          victoryTriggered := true
          victoryDelay := 1.5
        } // Check microchip trap proximity
        else if !chipPickup.collected && WorldPickup.isInRange(chipPickup, ~playerX, ~playerY) {
          chipPickup.collected = true
          trapped := true
          trapTimer := 4.0

          // Show trap text
          Text.setAlpha(trapText, 1.0)

          // Force player freeze
          Player.stopMovement(player)

          // Alert all guards  they rush toward the player
          Array.forEach(gameState.guards, guard => {
            guard.state = Alerted
            guard.lastKnownPlayerX = Some(playerX)
            guard.suspicion = 1.0
          })

          showFloatingText(
            worldContainer,
            ~x=chipPickup.x,
            ~y=chipPickup.y,
            ~text="TRAP!",
            ~color=0xff3333,
            ~fontSize=24.0,
          )
        }
      }

      // Update HUD objective
      if !objectiveComplete.contents {
        HUD.setObjective(hud, ~text="Find the USB drive")
      }

      Continue
    }
  }

  // Build the training screen with crates drawn in setupEntities wrapper
  let setupWithCrates = (gameState: GameLoop.gameState, worldContainer: Pixi.Container.t) => {
    setupEntities(gameState, worldContainer)

    // Draw crouch passage (between the trap and the crates)
    drawCrouchPassage(worldContainer, ~groundY=500.0)

    // Draw crate props near the right side (hiding the USB stick)
    drawCrate(worldContainer, ~x=1150.0, ~groundY=500.0, ~w=60.0, ~h=50.0)
    drawCrate(worldContainer, ~x=1220.0, ~groundY=500.0, ~w=70.0, ~h=65.0)
    drawCrate(worldContainer, ~x=1200.0, ~groundY=435.0, ~w=55.0, ~h=40.0) // Stacked
    drawCrate(worldContainer, ~x=1350.0, ~groundY=500.0, ~w=50.0, ~h=45.0)
  }

  TrainingBase.makeTrainingScreen(
    config,
    ~setupEntities=setupWithCrates,
    ~onBack=TrainingBase.backToMenu,
    ~onReset=() => {
      PlayerState.clearPlatforms()
      switch (GetEngine.get(), constructorRef.contents) {
      | (Some(engine), Some(c)) =>
        let _ =
          Navigation.showScreen(engine.navigation, c)->Promise.catch(PanicHandler.handleException)
      | _ => ()
      }
    },
    ~onUpdate,
    ~selfConstructor=?constructorRef.contents,
    ~legendEntries=TrainingBase.scavengerLegendEntries,
  )
}

let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(["main"]),
}

let _ = constructorRef := Some(constructor)
