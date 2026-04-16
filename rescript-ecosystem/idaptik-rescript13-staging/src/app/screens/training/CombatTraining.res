// SPDX-License-Identifier: PMPL-1.0-or-later
// CombatTraining  Full combat practice with all enemy types
//
// Spawns a mix of guards and dogs for free-form combat practice.
// HP system active, contact damage on. Goal: survive and neutralise all enemies.
// Shows "FIGHT!" flash on start with synthesised dramatic sound.

open Pixi

let config: TrainingBase.trainingConfig = {
  title: "Full Combat Training",
  instructions: [
    "All enemy types together  guards and dogs.",
    "Stomp and charge to neutralise. Watch your HP!",
    "Sentinel and Assassin are immune to knockdown.",
  ],
  arenaWidth: 1400.0,
  groundY: 500.0,
}

let setupEntities = (gameState: GameLoop.gameState, _worldContainer: Pixi.Container.t): unit => {
  // Guards  Basic + Elite mix
  let guards = [
    GuardNPC.make(
      ~id="combat_basic",
      ~rank=BasicGuard,
      ~x=500.0,
      ~y=500.0,
      ~waypoints=[{x: 400.0, pauseDurationSec: 2.0}, {x: 700.0, pauseDurationSec: 2.0}],
    ),
    GuardNPC.make(
      ~id="combat_elite",
      ~rank=EliteGuard,
      ~x=1000.0,
      ~y=500.0,
      ~waypoints=[{x: 850.0, pauseDurationSec: 1.0}, {x: 1150.0, pauseDurationSec: 1.0}],
    ),
  ]
  gameState.guards = guards

  // Dogs  one of each
  let dogs = [
    SecurityDog.make(
      ~id="combat_robodog",
      ~variant=RoboDog,
      ~x=700.0,
      ~y=500.0,
      ~waypoints=[{x: 550.0, pauseDurationSec: 1.5}, {x: 850.0, pauseDurationSec: 1.5}],
      (),
    ),
    SecurityDog.make(
      ~id="combat_guarddog",
      ~variant=GuardDog,
      ~x=1100.0,
      ~y=500.0,
      ~waypoints=[{x: 950.0, pauseDurationSec: 1.0}, {x: 1250.0, pauseDurationSec: 1.0}],
      (),
    ),
  ]
  gameState.dogs = dogs
}

//  FIGHT! Sound Effect 

// Synthesise a dramatic "FIGHT!" sound using Web Audio API
// Two-tone burst: low impact hit + high metallic ring
let playFightSound: unit => unit = %raw(`
  function() {
    try {
      var ctx = new (window.AudioContext || window.webkitAudioContext)();

      // Oscillator 1: low impact hit (80 Hz, quick decay)
      var osc1 = ctx.createOscillator();
      var gain1 = ctx.createGain();
      osc1.type = 'square';
      osc1.frequency.setValueAtTime(80, ctx.currentTime);
      osc1.frequency.exponentialRampToValueAtTime(40, ctx.currentTime + 0.15);
      gain1.gain.setValueAtTime(0.4, ctx.currentTime);
      gain1.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.2);
      osc1.connect(gain1);
      gain1.connect(ctx.destination);
      osc1.start(ctx.currentTime);
      osc1.stop(ctx.currentTime + 0.2);

      // Oscillator 2: metallic ring (440 Hz  220 Hz)
      var osc2 = ctx.createOscillator();
      var gain2 = ctx.createGain();
      osc2.type = 'sawtooth';
      osc2.frequency.setValueAtTime(440, ctx.currentTime);
      osc2.frequency.exponentialRampToValueAtTime(220, ctx.currentTime + 0.3);
      gain2.gain.setValueAtTime(0.25, ctx.currentTime);
      gain2.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.35);
      osc2.connect(gain2);
      gain2.connect(ctx.destination);
      osc2.start(ctx.currentTime);
      osc2.stop(ctx.currentTime + 0.35);

      // Noise burst for impact texture
      var bufferSize = ctx.sampleRate * 0.1;
      var buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
      var data = buffer.getChannelData(0);
      for (var i = 0; i < bufferSize; i++) {
        data[i] = (Math.random() * 2 - 1) * 0.3;
      }
      var noise = ctx.createBufferSource();
      var noiseGain = ctx.createGain();
      noise.buffer = buffer;
      noiseGain.gain.setValueAtTime(0.3, ctx.currentTime);
      noiseGain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.1);
      noise.connect(noiseGain);
      noiseGain.connect(ctx.destination);
      noise.start(ctx.currentTime);
    } catch(e) {}
  }
`)

//  Screen Constructor 

let constructorRef: ref<option<Navigation.appScreenConstructor>> = ref(None)

let make = (): Navigation.appScreen => {
  // FIGHT! overlay text
  let fightText = Text.make({
    "text": "FIGHT!",
    "style": {
      "fontFamily": "Impact, Arial Black, sans-serif",
      "fontSize": 96,
      "fill": 0xff2200,
      "fontWeight": "bold",
      "letterSpacing": 8,
      "stroke": {"color": 0xffcc00, "width": 4},
    },
  })
  ObservablePoint.set(Text.anchor(fightText), 0.5, ~y=0.5)
  Text.setAlpha(fightText, 0.0)

  let fightContainer = Container.make()
  Container.setZIndex(fightContainer, 999)
  // Start centered (will be re-positioned by resize handler and update loop)
  Container.setX(fightContainer, 400.0)
  Container.setY(fightContainer, 250.0)
  let _ = Container.addChildText(fightContainer, fightText)

  // State for FIGHT! animation and victory.
  // In reduced-motion mode, show text instantly without animation.
  let reducedMotion = AccessibilitySettings.isReducedMotionEnabled()
  let fightTimer = ref(
    if reducedMotion {
      1.0
    } else {
      1.8
    },
  )
  let fightActive = ref(true)
  let fightSoundPlayed = ref(false)
  let victoryTriggered = ref(false)
  let victoryDelay = ref(0.0)

  // Screen dimensions for centering the FIGHT text
  let fightScreenW = ref(800.0)
  let fightScreenH = ref(600.0)

  let onUpdate = (
    _player: Player.t,
    _keyState: WorldBuilder.keyState,
    _hud: HUD.t,
    gameState: GameLoop.gameState,
    _worldContainer: Container.t,
    dt: float,
  ): TrainingBase.trainingResult => {
    //  FIGHT! flash animation 
    if fightActive.contents {
      // Play sound on first frame
      if !fightSoundPlayed.contents {
        fightSoundPlayed := true
        playFightSound()
      }

      // Keep FIGHT text centered in screen space every frame
      Container.setX(fightContainer, fightScreenW.contents /. 2.0)
      Container.setY(fightContainer, fightScreenH.contents /. 2.0 -. 50.0)

      fightTimer := fightTimer.contents -. dt

      if reducedMotion {
        // Accessibility: show at full size instantly, then fade after hold
        Text.setAlpha(
          fightText,
          if fightTimer.contents > 0.0 {
            1.0
          } else {
            0.0
          },
        )
        ObservablePoint.set(Container.scale(fightContainer), 1.0, ~y=1.0)
      } else {
        // Phase 1 (0.00.2s): Scale up from 0.5 to 1.5, fade in
        // Phase 2 (0.21.0s): Hold at full
        // Phase 3 (1.01.8s): Fade out and scale down
        let t = 1.8 -. fightTimer.contents
        if t < 0.2 {
          let progress = t /. 0.2
          Text.setAlpha(fightText, progress)
          let scale = 0.5 +. progress *. 1.0
          ObservablePoint.set(Container.scale(fightContainer), scale, ~y=scale)
        } else if t < 1.0 {
          Text.setAlpha(fightText, 1.0)
          ObservablePoint.set(Container.scale(fightContainer), 1.5, ~y=1.5)
        } else {
          let fadeProgress = (t -. 1.0) /. 0.8
          Text.setAlpha(fightText, 1.0 -. fadeProgress)
          let scale = 1.5 -. fadeProgress *. 0.5
          ObservablePoint.set(Container.scale(fightContainer), scale, ~y=scale)
        }
      }

      if fightTimer.contents <= 0.0 {
        fightActive := false
        Text.setAlpha(fightText, 0.0)
      }

      Continue
    } //  Victory delay 
    else if victoryTriggered.contents {
      victoryDelay := victoryDelay.contents -. dt
      if victoryDelay.contents <= 0.0 {
        Victory
      } else {
        Continue
      }
    } else {
      //  Check victory: all guards and dogs neutralised 

      let allGuardsDown = Array.every(gameState.guards, guard => GuardNPC.isKnockedDown(guard))
      let allDogsDown = Array.every(gameState.dogs, dog =>
        dog.state == SecurityDog.Disabled || dog.state == SecurityDog.Stunned
      )

      if allGuardsDown && allDogsDown {
        victoryTriggered := true
        victoryDelay := 1.5
      }

      Continue
    }
  }

  let screen = TrainingBase.makeTrainingScreen(
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
    ~legendEntries=TrainingBase.combatLegendEntries,
  )

  // Add FIGHT! text to screen container (screen space, not world space)
  // so it stays centered regardless of camera position
  let _ = Container.addChild(screen.container, fightContainer)

  // Wrap resize handler to also position the FIGHT text at screen center
  let origResize = screen.resize
  screen.resize = Some(
    (width, height) => {
      fightScreenW := width
      fightScreenH := height
      switch origResize {
      | Some(fn) => fn(width, height)
      | None => ()
      }
      // Position fight container at screen center
      Container.setX(fightContainer, width /. 2.0)
      Container.setY(fightContainer, height /. 2.0 -. 50.0)
    },
  )

  screen
}

let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(["main"]),
}

let _ = constructorRef := Some(constructor)
