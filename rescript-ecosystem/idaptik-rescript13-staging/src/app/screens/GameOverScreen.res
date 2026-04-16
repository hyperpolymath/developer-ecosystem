// SPDX-License-Identifier: PMPL-1.0-or-later
// Game Over Screen  shown when the hacker is detected/caught
//
// Full-screen dark overlay with red "DETECTED" header, failure reason,
// stats summary, and retry/quit buttons. Glitch animation on text.

open Pixi
open PixiUI

let fmod = %raw(`function(a, b) { return a % b; }`)

let assetBundles = ["main"]

// Failure reasons for display
type failureReason =
  | SecurityDetected
  | PowerCutTraced
  | TimeLimitExceeded
  | FirewallLockdown
  | CanaryTripped

let reasonToString = (reason: failureReason): string => {
  switch reason {
  | SecurityDetected => GameI18n.t("gameover.reason.security")
  | PowerCutTraced => GameI18n.t("gameover.reason.power")
  | TimeLimitExceeded => GameI18n.t("gameover.reason.time")
  | FirewallLockdown => GameI18n.t("gameover.reason.firewall")
  | CanaryTripped => GameI18n.t("gameover.reason.canary")
  }
}

// Stats from the failed run
type runStats = {
  devicesHacked: int,
  commandsExecuted: int,
  timeElapsedSec: float,
  alertLevelReached: int,
}

let defaultStats: runStats = {
  devicesHacked: 0,
  commandsExecuted: 0,
  timeElapsedSec: 0.0,
  alertLevelReached: 0,
}

// Mutable state for the current failure
let currentReason = ref(SecurityDetected)
let currentStats = ref(defaultStats)

let setFailure = (~reason: failureReason, ~stats: runStats): unit => {
  currentReason := reason
  currentStats := stats
}

// Retry/quit navigation targets  set by TrainingBase before showing this screen.
// When set, retry goes back to the same training level and quit goes to training menu.
// When None, both default to WorldMapScreen.
let retryTarget: ref<option<Navigation.appScreenConstructor>> = ref(None)
let quitTarget: ref<option<Navigation.appScreenConstructor>> = ref(None)

let setRetryTarget = (ctor: Navigation.appScreenConstructor): unit => {
  retryTarget := Some(ctor)
}

let setQuitTarget = (ctor: Navigation.appScreenConstructor): unit => {
  quitTarget := Some(ctor)
}

let make = (): Navigation.appScreen => {
  let container = Container.make()
  Container.setAlpha(container, 0.0)
  // Block pointer events from reaching screens behind this one
  Container.setEventMode(container, "static")
  Container.setInteractiveChildren(container, true)

  // Full-screen opaque overlay  completely covers the previous screen
  let overlay = Graphics.make()
  Graphics.setEventMode(overlay, "static")
  let _ = Container.addChildGraphics(container, overlay)

  // Red header: DETECTED
  let header = Text.make({
    "text": GameI18n.t("gameover.title"),
    "style": {
      "fontSize": 64.0,
      "fill": "#ff0000",
      "fontFamily": "monospace",
      "fontWeight": "bold",
      "letterSpacing": 12.0,
    },
  })
  ObservablePoint.set(Text.anchor(header), 0.5, ~y=0.5)
  let _ = Container.addChildText(container, header)

  // Horizontal red line
  let redLine = Graphics.make()
  let _ = Container.addChildGraphics(container, redLine)

  // Failure reason text
  let reasonText = Text.make({
    "text": reasonToString(currentReason.contents),
    "style": {"fontSize": 16.0, "fill": "#cc4444", "fontFamily": "monospace"},
  })
  ObservablePoint.set(Text.anchor(reasonText), 0.5, ~y=0.5)
  let _ = Container.addChildText(container, reasonText)

  // Stats box
  let stats = currentStats.contents
  let statsLines =
    [
      `${GameI18n.t("gameover.stat.devices")}  ${Int.toString(stats.devicesHacked)}`,
      `${GameI18n.t("gameover.stat.commands")}    ${Int.toString(stats.commandsExecuted)}`,
      `${GameI18n.t("gameover.stat.time")}         ${Float.toFixed(
          stats.timeElapsedSec,
          ~digits=1,
        )}s`,
      `${GameI18n.t("gameover.stat.alert")}  ${Int.toString(stats.alertLevelReached)}/5`,
    ]->Array.join("\n")

  let statsText = Text.make({
    "text": statsLines,
    "style": {"fontSize": 13.0, "fill": "#888888", "fontFamily": "monospace", "lineHeight": 22.0},
  })
  ObservablePoint.set(Text.anchor(statsText), 0.5, ~y=0.5)
  let _ = Container.addChildText(container, statsText)

  // Retry button
  let retryBtn = Button.make(
    ~options={text: GameI18n.t("ui.retry"), width: 200., height: 50., fontSize: 18},
    (),
  )
  let _ = Container.addChild(container, FancyButton.toContainer(retryBtn))

  // Quit button
  let quitBtn = Button.make(
    ~options={text: GameI18n.t("ui.quit"), width: 200., height: 50., fontSize: 18},
    (),
  )
  let _ = Container.addChild(container, FancyButton.toContainer(quitBtn))

  // Glitch timer for header animation
  let glitchTimer = ref(0.0)

  // Escape key handler ref (for cleanup)
  let escKeyHandler: ref<option<{..}>> = ref(None)

  // Button handlers
  Signal.connect(FancyButton.onPress(retryBtn), () => {
    // Navigate back to the same training level (or world map if not from training)
    switch GetEngine.get() {
    | Some(engine) =>
      let target = switch retryTarget.contents {
      | Some(ctor) => ctor
      | None => WorldMapScreen.constructor
      }
      retryTarget := None
      quitTarget := None
      Navigation.showScreen(engine.navigation, target)->ignore
    | None => ()
    }
  })

  Signal.connect(FancyButton.onPress(quitBtn), () => {
    // Go to training menu (if from training) or world map
    switch GetEngine.get() {
    | Some(engine) =>
      let target = switch quitTarget.contents {
      | Some(ctor) => ctor
      | None => WorldMapScreen.constructor
      }
      retryTarget := None
      quitTarget := None
      Navigation.showScreen(engine.navigation, target)->ignore
    | None => ()
    }
  })

  {
    container,
    prepare: None,
    show: Some(
      async () => {
        Container.setAlpha(container, 1.0)

        // Register Escape key to quit (go to training menu or world map)
        let escNavigating = ref(false)
        let escHandler = (_e: {..}) => {
          let key: string = %raw(`_e.key`)
          if key == "Escape" && !escNavigating.contents {
            escNavigating := true
            let _ = %raw(`_e.preventDefault()`)
            switch escKeyHandler.contents {
            | Some(_handler) => %raw(`window.removeEventListener('keydown', _handler)`)
            | None => ()
            }
            switch GetEngine.get() {
            | Some(engine) =>
              let target = switch quitTarget.contents {
              | Some(ctor) => ctor
              | None => WorldMapScreen.constructor
              }
              retryTarget := None
              quitTarget := None
              Navigation.showScreen(engine.navigation, target)->ignore
            | None => ()
            }
          }
        }
        let handler = %raw(`function(fn) { var h = function(e) { fn(e); }; window.addEventListener('keydown', h); return h; }`)(
          escHandler,
        )
        escKeyHandler := Some(handler)
      },
    ),
    hide: Some(
      async () => {
        // Remove Escape key listener
        switch escKeyHandler.contents {
        | Some(_handler) => %raw(`window.removeEventListener('keydown', _handler)`)
        | None => ()
        }
        Container.setAlpha(container, 0.0)
      },
    ),
    pause: None,
    resume: None,
    reset: Some(
      () => {
        switch escKeyHandler.contents {
        | Some(_handler) => %raw(`window.removeEventListener('keydown', _handler)`)
        | None => ()
        }
      },
    ),
    update: Some(
      ticker => {
        let dt = Ticker.deltaTime(ticker) /. 60.0
        glitchTimer := glitchTimer.contents +. dt

        // Glitch effect: occasional random offset on header
        if fmod(glitchTimer.contents, 2.0) < 0.05 {
          let offsetX = (Math.random() -. 0.5) *. 8.0
          Text.setX(header, Text.x(header) +. offsetX)
        }
      },
    ),
    resize: Some(
      (width, height) => {
        // Overlay
        let _ = Graphics.clear(overlay)
        let _ =
          overlay
          ->Graphics.rect(0.0, 0.0, width, height)
          ->Graphics.fill({"color": 0x0a0000})

        // Header
        Text.setX(header, width /. 2.0)
        Text.setY(header, height *. 0.25)

        // Red line
        let _ = Graphics.clear(redLine)
        let lineY = height *. 0.33
        let _ =
          redLine
          ->Graphics.moveTo(width *. 0.15, lineY)
          ->Graphics.lineTo(width *. 0.85, lineY)
          ->Graphics.stroke({"width": 2, "color": 0xff0000})

        // Reason
        Text.setX(reasonText, width /. 2.0)
        Text.setY(reasonText, height *. 0.40)

        // Stats
        Text.setX(statsText, width /. 2.0)
        Text.setY(statsText, height *. 0.55)

        // Buttons
        FancyButton.setX(retryBtn, width /. 2.0 -. 120.0)
        FancyButton.setY(retryBtn, height *. 0.75)
        FancyButton.setX(quitBtn, width /. 2.0 +. 120.0)
        FancyButton.setY(quitBtn, height *. 0.75)
      },
    ),
    blur: None,
    focus: None,
    onLoad: None,
  }
}

let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(assetBundles),
}
