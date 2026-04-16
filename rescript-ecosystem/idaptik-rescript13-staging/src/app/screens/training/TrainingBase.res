// SPDX-License-Identifier: PMPL-1.0-or-later
// TrainingBase  Shared arena builder for training/tutorial screens
//
// Builds a minimal platformer arena (flat ground, walls) with:
// - Instructional text panel
// - Reset button (restart the scenario)
// - Back button (return to training menu)
// - Combat system active (stomp, charge, contact damage)
//
// Training screens use this to focus on specific enemy types
// without the full mission/network/device systems.

open Pixi
open PixiUI

let buttonAnimations = {
  "hover": {"props": {"scale": {"x": 1.1, "y": 1.1}}, "duration": 100},
  "pressed": {"props": {"scale": {"x": 0.9, "y": 0.9}}, "duration": 100},
}

//  Configuration 

type trainingConfig = {
  title: string,
  instructions: array<string>,
  arenaWidth: float,
  groundY: float,
}

//  Arena Rendering 

// Draw a simple flat arena with ground, ceiling, and walls
let drawArena = (worldContainer: Container.t, ~width: float, ~groundY: float): unit => {
  // Sky
  let sky = Graphics.make()
  let _ =
    sky
    ->Graphics.rect(0.0, 0.0, width, groundY +. 200.0)
    ->Graphics.fill({"color": 0x1a1a2e})
  let _ = Container.addChildGraphics(worldContainer, sky)

  // Ground
  let ground = Graphics.make()
  let _ =
    ground
    ->Graphics.rect(0.0, groundY, width, 200.0)
    ->Graphics.fill({"color": 0x2d4a3e})
  let _ =
    ground
    ->Graphics.rect(0.0, groundY, width, 4.0)
    ->Graphics.fill({"color": 0x4a7a5e})
  let _ = Container.addChildGraphics(worldContainer, ground)

  // Left wall
  let leftWall = Graphics.make()
  let _ =
    leftWall
    ->Graphics.rect(0.0, 0.0, 20.0, groundY)
    ->Graphics.fill({"color": 0x333355})
  let _ = Container.addChildGraphics(worldContainer, leftWall)

  // Right wall
  let rightWall = Graphics.make()
  let _ =
    rightWall
    ->Graphics.rect(width -. 20.0, 0.0, 20.0, groundY)
    ->Graphics.fill({"color": 0x333355})
  let _ = Container.addChildGraphics(worldContainer, rightWall)

  // "TRAINING" markers on floor
  let markerLeft = Text.make({
    "text": "START",
    "style": {"fontSize": 12, "fill": 0x4a7a5e, "fontWeight": "bold"},
  })
  Text.setX(markerLeft, 80.0)
  Text.setY(markerLeft, groundY +. 10.0)
  let _ = Container.addChildText(worldContainer, markerLeft)

  let markerRight = Text.make({
    "text": "ENEMY ZONE",
    "style": {"fontSize": 12, "fill": 0x7a4a4e, "fontWeight": "bold"},
  })
  Text.setX(markerRight, width -. 200.0)
  Text.setY(markerRight, groundY +. 10.0)
  let _ = Container.addChildText(worldContainer, markerRight)
}

//  Instruction Panel 

let drawInstructionPanel = (
  container: Container.t,
  ~title: string,
  ~instructions: array<string>,
): Text.t => {
  // Panel background
  let panelBg = Graphics.make()
  let _ =
    panelBg
    ->Graphics.roundRect(0.0, 0.0, 500.0, 100.0, 8.0)
    ->Graphics.fill({"color": 0x000000, "alpha": 0.7})
    ->Graphics.stroke({"width": 1, "color": 0x444444})
  let _ = Container.addChildGraphics(container, panelBg)

  // Title
  let titleText = Text.make({
    "text": title,
    "style": {
      "fontFamily": "Arial",
      "fontSize": 20,
      "fill": 0x00ff88,
      "fontWeight": "bold",
    },
  })
  Text.setX(titleText, 15.0)
  Text.setY(titleText, 8.0)
  let _ = Container.addChildText(container, titleText)

  // Instructions
  let instructionStr = Array.join(instructions, "\n")
  let instructionText = Text.make({
    "text": instructionStr,
    "style": {
      "fontFamily": "Arial",
      "fontSize": 14,
      "fill": 0xcccccc,
      "wordWrap": true,
      "wordWrapWidth": 470,
    },
  })
  Text.setX(instructionText, 15.0)
  Text.setY(instructionText, 35.0)
  let _ = Container.addChildText(container, instructionText)

  instructionText
}

//  Enemy Legend 

// Legend entry: colored dot + name + short description
type legendEntry = {
  color: int,
  name: string,
  desc: string,
}

// Draw a legend panel showing enemy types in this training scenario.
// Returns the container so it can be positioned by the resize handler.
let drawLegend = (parentContainer: Container.t, ~entries: array<legendEntry>): Container.t => {
  let legendContainer = Container.make()

  // Semi-transparent background panel
  let bg = Graphics.make()
  let panelW = 260.0
  let panelH = 20.0 +. Int.toFloat(Array.length(entries)) *. 22.0
  let _ =
    bg
    ->Graphics.roundRect(0.0, 0.0, panelW, panelH, 6.0)
    ->Graphics.fill({"color": 0x000000, "alpha": 0.6})
    ->Graphics.stroke({"width": 1, "color": 0x333344})
  let _ = Container.addChildGraphics(legendContainer, bg)

  // "ENEMIES" header
  let headerText = Text.make({
    "text": "ENEMIES",
    "style": {"fontFamily": "monospace", "fontSize": 10, "fill": 0x888899, "fontWeight": "bold"},
  })
  Text.setX(headerText, 8.0)
  Text.setY(headerText, 4.0)
  let _ = Container.addChildText(legendContainer, headerText)

  // Draw each entry: colored dot + name + description
  Array.forEachWithIndex(entries, (entry, i) => {
    let y = 20.0 +. Int.toFloat(i) *. 22.0

    // Colored dot
    let dot = Graphics.make()
    let _ =
      dot
      ->Graphics.circle(12.0, y +. 8.0, 5.0)
      ->Graphics.fill({"color": entry.color})
    let _ = Container.addChildGraphics(legendContainer, dot)

    // Name + description
    let entryText = Text.make({
      "text": `${entry.name} - ${entry.desc}`,
      "style": {"fontFamily": "monospace", "fontSize": 11, "fill": 0xbbbbcc},
    })
    Text.setX(entryText, 24.0)
    Text.setY(entryText, y)
    let _ = Container.addChildText(legendContainer, entryText)
  })

  let _ = Container.addChild(parentContainer, legendContainer)
  legendContainer
}

// Pre-built legend entry sets for each training type
let guardLegendEntries: array<legendEntry> = [
  {color: 0x44aa44, name: "Basic Guard", desc: "Slow, dumb patrol"},
  {color: 0xaaaa22, name: "Security Guard", desc: "Radio comms, backup"},
  {color: 0xaa4444, name: "Sentinel", desc: "Stationary, wide cone"},
  {color: 0xff8800, name: "Elite Guard", desc: "Adaptive AI, fast"},
]

let dogLegendEntries: array<legendEntry> = [
  {color: 0x8888ff, name: "RoboDog", desc: "Camera cone, hackable"},
  {color: 0xcc8844, name: "GuardDog", desc: "Scent (360\u00B0), food bait"},
]

let combatLegendEntries: array<legendEntry> = [
  {color: 0x44aa44, name: "Basic Guard", desc: "Knockdown OK"},
  {color: 0xff8800, name: "Elite Guard", desc: "Fast, adaptive"},
  {color: 0x8888ff, name: "RoboDog", desc: "Camera, hackable"},
  {color: 0xcc8844, name: "GuardDog", desc: "Scent, food bait"},
]

let assassinLegendEntries: array<legendEntry> = [
  {color: 0xff2222, name: "Assassin", desc: "Hide-ambush-stalk cycle"},
]

let scavengerLegendEntries: array<legendEntry> = [
  {color: 0x44aa44, name: "Basic Guard", desc: "Wide patrol"},
]

//  Training Result 

// Return from onUpdate to signal victory or defeat
type trainingResult =
  | Continue // Keep playing
  | Victory // Objective complete  show VictoryScreen
  | Defeat(string) // Failed  show GameOverScreen with reason

// Store a reference to the training menu constructor (set by TrainingMenuScreen to break circular dep)
let trainingMenuConstructor: ref<option<Navigation.appScreenConstructor>> = ref(None)

//  Build Training Screen 

// Builds a complete training arena screen.
// `setupEntities` is called to spawn guards/dogs into the game state
// and add their containers to the world.
let makeTrainingScreen = (
  config: trainingConfig,
  ~setupEntities: (GameLoop.gameState, Container.t) => unit,
  ~onBack: unit => unit,
  ~onReset: unit => unit,
  ~onUpdate: option<
    (
      Player.t,
      WorldBuilder.keyState,
      HUD.t,
      GameLoop.gameState,
      Container.t,
      float,
    ) => trainingResult,
  >=?,
  ~selfConstructor: option<Navigation.appScreenConstructor>=?,
  ~legendEntries: option<array<legendEntry>>=?,
): Navigation.appScreen => {
  let container = Container.make()
  Container.setEventMode(container, "static")
  Container.setInteractiveChildren(container, true)

  // Full-screen background  covers entire viewport, prevents screen bleed-through.
  // Set interactive so pointer events are captured and don't pass through to screens behind.
  let screenBg = Graphics.make()
  Graphics.setEventMode(screenBg, "static")
  let _ = Container.addChildGraphics(container, screenBg)

  let worldContainer = Container.make()
  let _ = Container.addChild(container, worldContainer)

  // Draw arena
  drawArena(worldContainer, ~width=config.arenaWidth, ~groundY=config.groundY)

  // Create player (spawn on the left)
  let player = Player.make(~startX=150.0, ~startY=config.groundY, ~groundY=config.groundY)
  let _ = Container.addChild(worldContainer, Player.getTrajectoryContainer(player))
  let _ = Container.addChild(worldContainer, Player.getContainer(player))

  // Game state  Accessible tier, no mission
  let gameState = GameLoop.make(~tier=Inventory.Accessible)

  // Guard & dog containers (in world space)
  let guardContainer = Container.make()
  let _ = Container.addChild(worldContainer, guardContainer)
  let dogContainer = Container.make()
  let _ = Container.addChild(worldContainer, dogContainer)

  // Spawn entities via callback
  setupEntities(gameState, worldContainer)

  // Add entity containers after spawning
  Array.forEach(gameState.guards, guard => {
    let _ = Container.addChild(guardContainer, guard.container)
  })
  Array.forEach(gameState.dogs, dog => {
    let _ = Container.addChild(dogContainer, dog.container)
  })

  // HUD overlay
  let hud = HUD.make()
  let _ = Container.addChild(container, hud.container)

  // Instruction panel (UI layer)
  let instructionContainer = Container.make()
  
  let _ = Container.addChild(container, instructionContainer)
  let _ = drawInstructionPanel(
    instructionContainer,
    ~title=config.title,
    ~instructions=config.instructions,
  )

  // Enemy type legend (top-right corner)
  let legendPanel = switch legendEntries {
  | Some(entries) => Some(drawLegend(container, ~entries))
  | None => None
  }

  // Controls hint
  let controlsText = Text.make({
    "text": "A/D move | Shift sprint | Space/W jump | C crouch",
    "style": {"fontSize": 13, "fill": 0x666666},
  })
  let _ = Container.addChildText(container, controlsText)

  //  Back button 
  let backBtn = Graphics.make()
  let _ =
    backBtn
    ->Graphics.roundRect(0.0, 0.0, 140.0, 36.0, 6.0)
    ->Graphics.fill({"color": 0x444444})
    ->Graphics.stroke({"width": 1, "color": 0x666666})
  Graphics.setEventMode(backBtn, "static")
  Graphics.setCursor(backBtn, "pointer")
  let _ = Container.addChildGraphics(container, backBtn)

  let backText = Text.make({
    "text": "Back to Menu",
    "style": {"fontFamily": "Arial", "fontSize": 14, "fill": 0xffffff},
  })
  ObservablePoint.set(Text.anchor(backText), 0.5, ~y=0.5)
  Text.setX(backText, 70.0)
  Text.setY(backText, 18.0)
  let _ = Container.addChildText(container, backText)

  Graphics.on(backBtn, "pointertap", _ => onBack())

  //  Reset button 
  let resetBtn = Graphics.make()
  let _ =
    resetBtn
    ->Graphics.roundRect(0.0, 0.0, 100.0, 36.0, 6.0)
    ->Graphics.fill({"color": 0x006644})
    ->Graphics.stroke({"width": 1, "color": 0x00aa66})
  Graphics.setEventMode(resetBtn, "static")
  Graphics.setCursor(resetBtn, "pointer")
  let _ = Container.addChildGraphics(container, resetBtn)

  let resetText = Text.make({
    "text": "Reset",
    "style": {"fontFamily": "Arial", "fontSize": 14, "fill": 0xffffff},
  })
  ObservablePoint.set(Text.anchor(resetText), 0.5, ~y=0.5)
  Text.setX(resetText, 50.0)
  Text.setY(resetText, 18.0)
  let _ = Container.addChildText(container, resetText)

  // Reset  re-navigate to same screen to restart
  Graphics.on(resetBtn, "pointertap", _ => onReset())

  //  Settings button (gear icon) 
  let settingsBtn = FancyButton.make({
    "defaultView": "icon-settings.png",
    "anchor": 0.5,
    "animations": buttonAnimations,
  })
  Signal.connect(FancyButton.onPress(settingsBtn), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.presentPopup(engine.navigation, SettingsPopup.constructor)->Promise.catch(
        PanicHandler.handleException,
      )
    | None => ()
    }
  })
  // Add to UI layer to ensure it is above world/HUD
  
  


  let _ = Container.addChild(container, FancyButton.toContainer(settingsBtn))

  // Keyboard input  reuse WorldBuilder's pattern
  let keyState: WorldBuilder.keyState = {
    up: false,
    down: false,
    left: false,
    right: false,
    sprint: false,
    crouch: false,
    interact: false,
    aimLeft: false,
    aimRight: false,
    moleLeft: false,
    moleRight: false,
    moleToggle: false,
    moleTrap: false,
    moleItem: false,
    moleForward: false,
    moleBackward: false,
    hardware: false,
  }

  WorldBuilder.setupKeyboard(ks => {
    // Mole key handling (moleLeft/moleRight) is passive — no action needed here
    keyState.up = ks.up
    keyState.down = ks.down
    keyState.left = ks.left
    keyState.right = ks.right
    keyState.sprint = ks.sprint
    keyState.crouch = ks.crouch
    keyState.interact = ks.interact
    keyState.aimLeft = ks.aimLeft
    keyState.aimRight = ks.aimRight
    keyState.moleLeft = ks.moleLeft
    keyState.moleRight = ks.moleRight
    keyState.moleToggle = ks.moleToggle
    keyState.moleTrap = ks.moleTrap
    keyState.moleItem = ks.moleItem
    keyState.moleForward = ks.moleForward
    keyState.moleBackward = ks.moleBackward
  })

  // Mouse tracking
  WorldBuilder.setupMouseTrackingOnStage(container, ms => {
    WorldBuilder.globalMouseScreenPos.screenX = ms.screenX
    WorldBuilder.globalMouseScreenPos.screenY = ms.screenY
  })

  // Store screen dimensions for camera
  let screenWidth = ref(800.0)
  let screenHeight = ref(600.0)

  // Guard to prevent multiple game-over/victory screen spawns.
  // The detection check fires every frame, but we only want to navigate once.
  let screenTransitionFired = ref(false)

  // Escape key handler ref (cleanup on hide/reset)
  let escKeyHandler: ref<option<{..}>> = ref(None)

  {
    container,
    prepare: None,
    show: Some(
      async () => {
        Container.setAlpha(container, 0.0)

        // Register Escape key to go back to training menu, F1/P for settings
        let escNavigating = ref(false)
        let rec escHandler = (_e: {..}) => {
          let key: string = %raw(`_e.key`)
          if (key == "Escape" || key == "F1" || key == "Tab" || key == "p" || key == "P") && !escNavigating.contents {
            escNavigating := true
            let _ = %raw(`_e.preventDefault()`)
            switch escKeyHandler.contents {
            | Some(_handler) => %raw(`window.removeEventListener('keydown', _handler)`)
            | None => ()
            }
            if (key == "Escape") {
              onBack()
            } else {
              switch GetEngine.get() {
              | Some(engine) =>
                let _ = Navigation.presentPopup(
                  engine.navigation,
                  SettingsPopup.constructor,
                )->Promise.thenResolve(_ => {
                  escNavigating := false
                  // Re-add listener
                  escKeyHandler := Some(
                    %raw(`function(fn) { var h = function(e) { fn(e); }; window.addEventListener('keydown', h); return h; }`)(
                      escHandler,
                    ),
                  )
                })
              | None => escNavigating := false
              }
            }
          }
        }
        let handler = %raw(`function(fn) { var h = function(e) { fn(e); }; window.addEventListener('keydown', h); return h; }`)(
          escHandler,
        )
        escKeyHandler := Some(handler)

        await Motion.animateAsync(
          container,
          {"alpha": 1.0},
          {duration: 0.4, ease: "easeOut", delay: 0.0},
        )
      },
    ),
    hide: Some(
      async () => {
        // Remove Escape key listener
        switch escKeyHandler.contents {
        | Some(_handler) => %raw(`window.removeEventListener('keydown', _handler)`)
        | None => ()
        }

        await Motion.animateAsync(
          container,
          {"alpha": 0.0},
          {duration: 0.3, ease: "linear", delay: 0.0},
        )
      },
    ),
    pause: None,
    resume: None,
    reset: Some(
      () => {
        // Cleanup Escape key listener on reset
        switch escKeyHandler.contents {
        | Some(_handler) => %raw(`window.removeEventListener('keydown', _handler)`)
        | None => ()
        }
      },
    ),
    update: Some(
      ticker => {
        try {
          let dt = Ticker.deltaTime(ticker) /. 60.0
          // Convert mouse to world coordinates
          let worldContainerX = Container.x(worldContainer)
          let mouseWorldX = WorldBuilder.globalMouseScreenPos.screenX -. worldContainerX
          let mouseWorldY = WorldBuilder.globalMouseScreenPos.screenY

          // Build input
          let input: Player.inputState = {
            left: keyState.left,
            right: keyState.right,
            up: keyState.up,
            crouch: keyState.crouch || keyState.down,
            sprint: keyState.sprint,
            mouseX: mouseWorldX,
            mouseY: mouseWorldY,
          }

          // Update player
          Player.update(player, ~input, ~deltaTime=dt)

          // Keep player in arena bounds
          let playerX = Player.getX(player)
          if playerX < 50.0 {
            Player.setX(player, 50.0)
          }
          if playerX > config.arenaWidth -. 50.0 {
            Player.setX(player, config.arenaWidth -. 50.0)
          }

          // Camera follow  center arena if it's smaller than the viewport
          let clampedCameraX = if config.arenaWidth <= screenWidth.contents {
            // Arena fits entirely on screen: center it
            (screenWidth.contents -. config.arenaWidth) /. 2.0
          } else {
            // Arena is wider than screen: scroll to follow player
            let targetCameraX = -.Player.getX(player) +. screenWidth.contents /. 2.0
            let maxCameraX = 0.0
            let minCameraX = -.config.arenaWidth +. screenWidth.contents
            Math.max(minCameraX, Math.min(maxCameraX, targetCameraX))
          }
          Container.setX(worldContainer, clampedCameraX)

          // Combat
          let _combatEvents = Combat.update(
            ~player,
            ~dogs=gameState.dogs,
            ~guards=gameState.guards,
            ~_deltaTime=dt,
          )

          // Game systems update (guard AI, detection, etc.)
          let frameResult = GameLoop.update(
            gameState,
            ~dt,
            ~playerX=Player.getX(player),
            ~playerY=Player.getY(player),
            ~playerCrouching=keyState.crouch,
            ~playerSprinting=keyState.sprint,
          )

          // Sync HP to HUD
          let hp = Player.getHP(player)
          HUD.setHP(hud, ~current=hp.current, ~max=hp.max)

          // Check detection game over (guard: only fire transition once)
          if frameResult.gameOver && !screenTransitionFired.contents {
            screenTransitionFired := true
            GameOverScreen.setFailure(~reason=SecurityDetected, ~stats=GameOverScreen.defaultStats)
            switch selfConstructor {
            | Some(ctor) => GameOverScreen.setRetryTarget(ctor)
            | None => ()
            }
            switch trainingMenuConstructor.contents {
            | Some(menuCtor) => GameOverScreen.setQuitTarget(menuCtor)
            | None => ()
            }
            switch GetEngine.get() {
            | Some(engine) =>
              let _ =
                Navigation.showScreen(engine.navigation, GameOverScreen.constructor)->Promise.catch(
                  PanicHandler.handleException,
                )
            | None => ()
            }
          }

          // Check HP death (guard: only fire transition once)
          if !PlayerHP.isAlive(hp) && !screenTransitionFired.contents {
            screenTransitionFired := true
            GameOverScreen.setFailure(~reason=SecurityDetected, ~stats=GameOverScreen.defaultStats)
            switch selfConstructor {
            | Some(ctor) => GameOverScreen.setRetryTarget(ctor)
            | None => ()
            }
            switch trainingMenuConstructor.contents {
            | Some(menuCtor) => GameOverScreen.setQuitTarget(menuCtor)
            | None => ()
            }
            switch GetEngine.get() {
            | Some(engine) =>
              let _ =
                Navigation.showScreen(engine.navigation, GameOverScreen.constructor)->Promise.catch(
                  PanicHandler.handleException,
                )
            | None => ()
            }
          }

          // Custom update callback (for scavenger pickups, traps, etc.)
          let trainingResult = if screenTransitionFired.contents {
            Continue
          } else {
            switch onUpdate {
            | Some(updateFn) => updateFn(player, keyState, hud, gameState, worldContainer, dt)
            | None => Continue
            }
          }

          // Handle training result (victory/defeat from custom logic)
          // Guard: only fire transition once
          switch trainingResult {
          | Continue => ()
          | Victory =>
            if !screenTransitionFired.contents {
              screenTransitionFired := true
              VictoryScreen.setStats(VictoryScreen.defaultStats)
              switch trainingMenuConstructor.contents {
              | Some(menuCtor) => VictoryScreen.setContinueTarget(menuCtor)
              | None => ()
              }
              switch GetEngine.get() {
              | Some(engine) =>
                let _ =
                  Navigation.showScreen(
                    engine.navigation,
                    VictoryScreen.constructor,
                  )->Promise.catch(PanicHandler.handleException)
              | None => ()
              }
            }
          | Defeat(_reason) =>
            if !screenTransitionFired.contents {
              screenTransitionFired := true
              GameOverScreen.setFailure(
                ~reason=SecurityDetected,
                ~stats=GameOverScreen.defaultStats,
              )
              switch selfConstructor {
              | Some(ctor) => GameOverScreen.setRetryTarget(ctor)
              | None => ()
              }
              switch trainingMenuConstructor.contents {
              | Some(menuCtor) => GameOverScreen.setQuitTarget(menuCtor)
              | None => ()
              }
              switch GetEngine.get() {
              | Some(engine) =>
                let _ =
                  Navigation.showScreen(
                    engine.navigation,
                    GameOverScreen.constructor,
                  )->Promise.catch(PanicHandler.handleException)
              | None => ()
              }
            }
          }

          // Render guards
          Array.forEach(gameState.guards, guard => {
            GuardNPC.renderGuard(guard)
          })

          // Sync HUD
          GameLoop.syncHUD(gameState, ~hud)
        } catch {
        | exn =>
          Console.error2("[TrainingBase] UPDATE CRASH:", exn)
          // Log the raw JS error for stack trace
          %raw(`console.error("Raw error:", exn, exn && exn.RE_EXN_ID, exn && exn._1)`)
        }
      },
    ),
    resize: Some(
      (width, height) => {
        screenWidth := width
        screenHeight := height

        // Full-screen background  dark sky colour, prevents bleed-through
        let _ = Graphics.clear(screenBg)
        let _ =
          screenBg
          ->Graphics.rect(0.0, 0.0, width, height)
          ->Graphics.fill({"color": 0x1a1a2e})

        // Vertically center the arena in the viewport
        let arenaVisibleHeight = config.groundY +. 200.0
        let yOffset = if height > arenaVisibleHeight {
          (height -. arenaVisibleHeight) /. 2.0
        } else {
          0.0
        }
        Container.setY(worldContainer, yOffset)

        // Position instruction panel (top center)
        Container.setX(instructionContainer, (width -. 500.0) /. 2.0)
        Container.setY(instructionContainer, 10.0)

        // Position enemy legend (top right)
        switch legendPanel {
        | Some(panel) =>
          Container.setX(panel, width -. 270.0)
          Container.setY(panel, 10.0)
        | None => ()
        }

        // Position back button (bottom left)
        Graphics.setX(backBtn, 20.0)
        Graphics.setY(backBtn, height -. 56.0)
        Text.setX(backText, 90.0)
        Text.setY(backText, height -. 38.0)

        // Position reset button (bottom left, next to back)
        Graphics.setX(resetBtn, 180.0)
        Graphics.setY(resetBtn, height -. 56.0)
        Text.setX(resetText, 230.0)
        Text.setY(resetText, height -. 38.0)

        // Position settings button (bottom left, next to reset)
        // FancyButton uses anchor 0.5 (centered), so offset Y by half button height
        // to align with back/reset buttons which use top-left origin
        FancyButton.setX(settingsBtn, 318.0)
        FancyButton.setY(settingsBtn, height -. 38.0)

        // Position controls hint (bottom center)
        Text.setX(controlsText, width /. 2.0 -. 150.0)
        Text.setY(controlsText, height -. 25.0)

        // HUD resize
        HUD.resize(hud, ~width, ~height)
      },
    ),
    blur: None,
    focus: None,
    onLoad: None,
  }
}

// Navigate back to training menu
let backToMenu = (): unit => {
  switch (GetEngine.get(), trainingMenuConstructor.contents) {
  | (Some(engine), Some(menuConstructor)) =>
    let _ =
      Navigation.showScreen(engine.navigation, menuConstructor)->Promise.catch(
        PanicHandler.handleException,
      )
  | _ => Console.error("[TrainingBase] Engine or menu constructor not available")
  }
}
