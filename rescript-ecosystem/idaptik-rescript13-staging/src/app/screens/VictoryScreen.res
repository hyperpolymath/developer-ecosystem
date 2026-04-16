// SPDX-License-Identifier: PMPL-1.0-or-later
// Victory Screen  shown when all objectives are completed
//
// Green-themed success screen with "OPERATION COMPLETE" header,
// performance grade (S/A/B/C/D), stats breakdown, and continue button.

open Pixi
open PixiUI

let assetBundles = ["main"]

// Performance grade based on run quality
type grade = S | A | B | C | D

let gradeToString = (g: grade): string => {
  switch g {
  | S => "S"
  | A => "A"
  | B => "B"
  | C => "C"
  | D => "D"
  }
}

let gradeColor = (g: grade): string => {
  switch g {
  | S => "#ffdd00"
  | A => "#00ff88"
  | B => "#44aaff"
  | C => "#ff8844"
  | D => "#888888"
  }
}

let gradeDescription = (g: grade): string => {
  switch g {
  | S => GameI18n.t("victory.grade.s")
  | A => GameI18n.t("victory.grade.a")
  | B => GameI18n.t("victory.grade.b")
  | C => GameI18n.t("victory.grade.c")
  | D => GameI18n.t("victory.grade.d")
  }
}

// Run statistics
type victoryStats = {
  devicesHacked: int,
  commandsExecuted: int,
  timeElapsedSec: float,
  alertLevelReached: int,
  undosUsed: int,
  covertLinksDiscovered: int,
}

let defaultStats: victoryStats = {
  devicesHacked: 0,
  commandsExecuted: 0,
  timeElapsedSec: 0.0,
  alertLevelReached: 0,
  undosUsed: 0,
  covertLinksDiscovered: 0,
}

// Calculate grade from stats
let calculateGrade = (stats: victoryStats): grade => {
  let score = ref(100)

  // Penalise high alert
  score := score.contents - stats.alertLevelReached * 15

  // Penalise slow time (over 5 minutes)
  if stats.timeElapsedSec > 300.0 {
    score := score.contents - 10
  }
  if stats.timeElapsedSec > 600.0 {
    score := score.contents - 10
  }

  // Bonus for finding covert links
  score := score.contents + stats.covertLinksDiscovered * 5

  // Penalise excessive commands
  if stats.commandsExecuted > 100 {
    score := score.contents - 5
  }

  if score.contents >= 95 {
    S
  } else if score.contents >= 80 {
    A
  } else if score.contents >= 60 {
    B
  } else if score.contents >= 40 {
    C
  } else {
    D
  }
}

// Mutable state
let currentStats = ref(defaultStats)

let setStats = (stats: victoryStats): unit => {
  currentStats := stats
}

// Navigation target for continue button  set by TrainingBase to go back to training menu.
// When None, defaults to WorldMapScreen.
let continueTarget: ref<option<Navigation.appScreenConstructor>> = ref(None)

let setContinueTarget = (ctor: Navigation.appScreenConstructor): unit => {
  continueTarget := Some(ctor)
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

  // Header
  let header = Text.make({
    "text": GameI18n.t("victory.title"),
    "style": {
      "fontSize": FontScale.size(48.0),
      "fill": "#00ff44",
      "fontFamily": "monospace",
      "fontWeight": "bold",
      "letterSpacing": 6.0,
    },
  })
  ObservablePoint.set(Text.anchor(header), 0.5, ~y=0.5)
  let _ = Container.addChildText(container, header)

  // Grade
  let stats = currentStats.contents
  let grade = calculateGrade(stats)

  let gradeText = Text.make({
    "text": `GRADE: ${gradeToString(grade)}`,
    "style": {
      "fontSize": FontScale.size(36.0),
      "fill": gradeColor(grade),
      "fontFamily": "monospace",
      "fontWeight": "bold",
    },
  })
  ObservablePoint.set(Text.anchor(gradeText), 0.5, ~y=0.5)
  let _ = Container.addChildText(container, gradeText)

  let gradeDesc = Text.make({
    "text": gradeDescription(grade),
    "style": {"fontSize": FontScale.size(13.0), "fill": "#669966", "fontFamily": "monospace"},
  })
  ObservablePoint.set(Text.anchor(gradeDesc), 0.5, ~y=0.5)
  let _ = Container.addChildText(container, gradeDesc)

  // Stats
  let coreStats = [
    `${GameI18n.t("victory.stat.devices")}    ${Int.toString(stats.devicesHacked)}`,
    `${GameI18n.t("victory.stat.commands")}      ${Int.toString(stats.commandsExecuted)}`,
    `${GameI18n.t("victory.stat.time")}           ${Float.toFixed(
        stats.timeElapsedSec,
        ~digits=1,
      )}s`,
    `${GameI18n.t("victory.stat.alert")}        ${Int.toString(stats.alertLevelReached)}/5`,
  ]
  let vmStats = if FeaturePacks.isInvertibleProgrammingEnabled() {
    [`${GameI18n.t("victory.stat.undos")}        ${Int.toString(stats.undosUsed)}`]
  } else {
    []
  }
  let endStats = [
    `${GameI18n.t("victory.stat.covert")} ${Int.toString(stats.covertLinksDiscovered)}`,
  ]
  let statsLines = Array.concat(coreStats, Array.concat(vmStats, endStats))->Array.join("\n")

  let statsText = Text.make({
    "text": statsLines,
    "style": {
      "fontSize": FontScale.size(12.0),
      "fill": "#88aa88",
      "fontFamily": "monospace",
      "lineHeight": FontScale.size(20.0),
    },
  })
  ObservablePoint.set(Text.anchor(statsText), 0.5, ~y=0.5)
  let _ = Container.addChildText(container, statsText)

  // Continue button
  let continueBtn = Button.make(
    ~options={text: GameI18n.t("ui.continue"), width: 240., height: 50., fontSize: 18},
    (),
  )
  let _ = Container.addChild(container, FancyButton.toContainer(continueBtn))

  // Escape key handler ref
  let escKeyHandler: ref<option<{..}>> = ref(None)

  // Continue button handler  return to training menu or world map
  Signal.connect(FancyButton.onPress(continueBtn), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let target = switch continueTarget.contents {
      | Some(ctor) => ctor
      | None => WorldMapScreen.constructor
      }
      continueTarget := None
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

        // Register Escape key to continue
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
              let target = switch continueTarget.contents {
              | Some(ctor) => ctor
              | None => WorldMapScreen.constructor
              }
              continueTarget := None
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
    update: None,
    resize: Some(
      (width, height) => {
        let _ = Graphics.clear(overlay)
        let _ =
          overlay
          ->Graphics.rect(0.0, 0.0, width, height)
          ->Graphics.fill({"color": 0x001a00})

        Text.setX(header, width /. 2.0)
        Text.setY(header, height *. 0.15)

        Text.setX(gradeText, width /. 2.0)
        Text.setY(gradeText, height *. 0.30)

        Text.setX(gradeDesc, width /. 2.0)
        Text.setY(gradeDesc, height *. 0.38)

        Text.setX(statsText, width /. 2.0)
        Text.setY(statsText, height *. 0.55)

        FancyButton.setX(continueBtn, width /. 2.0)
        FancyButton.setY(continueBtn, height *. 0.80)
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
