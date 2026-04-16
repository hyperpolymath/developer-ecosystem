// SPDX-License-Identifier: PMPL-1.0-or-later
// AssassinTraining  Reactive AI demonstration
//
// Demonstrates the Assassin's hide-ambush-stalk-hide AI cycle.
// Arena has crate cover spots. The assassin hides, peeks out,
// stalks the player when their back is turned, lunges to attack,
// and flees if the player gets too close while facing them.
//
// Victory: survive and force the assassin into 3 failed ambushes.
// (Assassin is immune to knockdown but can be scared off.)

open Pixi

let config: TrainingBase.trainingConfig = {
  title: "Assassin AI Demo",
  instructions: [
    "The assassin hides and strikes when you're not looking.",
    "Face them to scare them off. Survive 3 ambush attempts to win!",
    "Watch for the red eye glow in the shadows...",
  ],
  arenaWidth: 1200.0,
  groundY: 500.0,
}

//  Cover Props 

// Draw cover spots (tall pillars/crates the assassin hides behind)
let drawCover = (
  worldContainer: Container.t,
  ~x: float,
  ~groundY: float,
  ~w: float,
  ~h: float,
): unit => {
  let pillar = Graphics.make()
  let _ =
    pillar
    ->Graphics.rect(x, groundY -. h, w, h)
    ->Graphics.fill({"color": 0x2a2a3a})
    ->Graphics.stroke({"width": 1, "color": 0x444466})
  let _ = Container.addChildGraphics(worldContainer, pillar)

  // Shadow detail at base
  let shadow = Graphics.make()
  let _ =
    shadow
    ->Graphics.rect(x -. 4.0, groundY -. 4.0, w +. 8.0, 4.0)
    ->Graphics.fill({"color": 0x111122})
  let _ = Container.addChildGraphics(worldContainer, shadow)
}

//  Entities Setup 

let setupEntities = (gameState: GameLoop.gameState, worldContainer: Pixi.Container.t): unit => {
  // Draw cover spots across the arena
  drawCover(worldContainer, ~x=300.0, ~groundY=500.0, ~w=40.0, ~h=80.0)
  drawCover(worldContainer, ~x=550.0, ~groundY=500.0, ~w=35.0, ~h=90.0)
  drawCover(worldContainer, ~x=800.0, ~groundY=500.0, ~w=45.0, ~h=75.0)
  drawCover(worldContainer, ~x=1000.0, ~groundY=500.0, ~w=35.0, ~h=85.0)

  // Single assassin with waypoints at cover spots
  let guards = [
    GuardNPC.make(
      ~id="assassin_demo",
      ~rank=Assassin,
      ~x=800.0,
      ~y=500.0,
      ~waypoints=[
        {x: 310.0, pauseDurationSec: 3.0},
        {x: 560.0, pauseDurationSec: 2.5},
        {x: 810.0, pauseDurationSec: 3.0},
        {x: 1010.0, pauseDurationSec: 2.5},
      ],
    ),
  ]
  gameState.guards = guards
}

//  Screen Constructor 

let constructorRef: ref<option<Navigation.appScreenConstructor>> = ref(None)

let make = (): Navigation.appScreen => {
  // Warning text overlay
  let warningContainer = Container.make()
  Container.setZIndex(warningContainer, 100)

  let warningText = Text.make({
    "text": "ASSASSIN ACTIVE",
    "style": {
      "fontFamily": "monospace",
      "fontSize": 14,
      "fill": 0xff2222,
      "fontWeight": "bold",
    },
  })
  ObservablePoint.set(Text.anchor(warningText), 0.5, ~y=0.5)
  let _ = Container.addChildText(warningContainer, warningText)

  // Ambush counter text
  let counterText = Text.make({
    "text": "Ambushes survived: 0 / 3",
    "style": {
      "fontFamily": "monospace",
      "fontSize": 13,
      "fill": 0xcccc44,
    },
  })
  ObservablePoint.set(Text.anchor(counterText), 0.5, ~y=0.5)
  let _ = Container.addChildText(warningContainer, counterText)

  // State tracking
  let lastKnownAttempts = ref(0)
  let victoryTriggered = ref(false)
  let victoryDelay = ref(0.0)
  let gameTime = ref(0.0)

  let onUpdate = (
    _player: Player.t,
    _keyState: WorldBuilder.keyState,
    hud: HUD.t,
    gameState: GameLoop.gameState,
    worldContainer: Container.t,
    dt: float,
  ): TrainingBase.trainingResult => {
    gameTime := gameTime.contents +. dt

    // Ensure warning container is parented
    if Container.parent(warningContainer)->Nullable.isNullable {
      let _ = Container.addChild(worldContainer, warningContainer)
    }

    // Position warning text
    Text.setX(warningText, 600.0)
    Text.setY(warningText, 30.0)
    Text.setX(counterText, 600.0)
    Text.setY(counterText, 50.0)

    // Pulse the warning text
    let pulse = 0.5 +. 0.5 *. Math.sin(gameTime.contents *. 3.0)
    Text.setAlpha(warningText, pulse)

    // Track assassin ambush attempts
    let attempts = Array.reduce(gameState.guards, 0, (acc, guard) => {
      acc + GuardNPC.getAssassinKillAttempts(guard)
    })

    if attempts != lastKnownAttempts.contents {
      lastKnownAttempts := attempts
      Text.setText(counterText, `Ambushes survived: ${Int.toString(attempts)} / 3`)

      if attempts >= 3 && !victoryTriggered.contents {
        victoryTriggered := true
        victoryDelay := 1.5
        HUD.setObjective(hud, ~text="Assassin exhausted!")
      }
    }

    if !victoryTriggered.contents {
      HUD.setObjective(hud, ~text=`Survive the assassin (${Int.toString(attempts)}/3)`)
    }

    // Victory delay
    if victoryTriggered.contents {
      victoryDelay := victoryDelay.contents -. dt
      if victoryDelay.contents <= 0.0 {
        Victory
      } else {
        Continue
      }
    } else {
      Continue
    }
  }

  TrainingBase.makeTrainingScreen(
    config,
    ~setupEntities,
    ~onBack=TrainingBase.backToMenu,
    ~onReset=() => {
      switch (GetEngine.get(), constructorRef.contents) {
      | (Some(engine), Some(c)) =>
        let _ =
          Navigation.showScreen(engine.navigation, c)->Promise.catch(PanicHandler.handleException)
      | _ => ()
      }
    },
    ~onUpdate,
    ~selfConstructor=?constructorRef.contents,
    ~legendEntries=TrainingBase.assassinLegendEntries,
  )
}

let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(["main"]),
}

let _ = constructorRef := Some(constructor)
