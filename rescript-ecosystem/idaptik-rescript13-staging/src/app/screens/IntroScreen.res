// SPDX-License-Identifier: PMPL-1.0-or-later
// Intro Screen  tutorial and controls overview
//
// Shown on first launch. Pages through game concept, controls, and key
// mechanics. Skippable, can be re-accessed from settings.

open Pixi
open PixiUI

let assetBundles = ["main"]

// Tutorial pages
type featurePack = InvertibleProgramming

type tutorialPage = {
  title: string,
  lines: array<string>,
  highlight: string, // colour for the title
  featurePack: option<featurePack>, // None = core (always shown)
}

// Build all pages from translated strings  called at render time
// so language changes take effect on next page render
let getAllPages = (): array<tutorialPage> => [
  {
    title: GameI18n.t("intro.welcome.title"),
    lines: [
      GameI18n.t("intro.welcome.line1"),
      GameI18n.t("intro.welcome.line2"),
      GameI18n.t("intro.welcome.line3"),
      GameI18n.t("intro.welcome.line4"),
      GameI18n.t("intro.welcome.line5"),
      GameI18n.t("intro.welcome.line6"),
    ],
    highlight: "#00ff44",
    featurePack: None,
  },
  {
    title: GameI18n.t("intro.controls.title"),
    lines: [
      GameI18n.t("intro.controls.line1"),
      GameI18n.t("intro.controls.line2"),
      GameI18n.t("intro.controls.line3"),
      GameI18n.t("intro.controls.line4"),
      GameI18n.t("intro.controls.line5"),
      GameI18n.t("intro.controls.line6"),
      GameI18n.t("intro.controls.line7"),
      GameI18n.t("intro.controls.line8"),
      GameI18n.t("intro.controls.line9"),
      GameI18n.t("intro.controls.line10"),
      GameI18n.t("intro.controls.line11"),
    ],
    highlight: "#4488ff",
    featurePack: None,
  },
  {
    title: GameI18n.t("intro.vm.title"),
    lines: [
      GameI18n.t("intro.vm.line1"),
      GameI18n.t("intro.vm.line2"),
      GameI18n.t("intro.vm.line3"),
      GameI18n.t("intro.vm.line4"),
      GameI18n.t("intro.vm.line5"),
      GameI18n.t("intro.vm.line6"),
      GameI18n.t("intro.vm.line7"),
      GameI18n.t("intro.vm.line8"),
      GameI18n.t("intro.vm.line9"),
      GameI18n.t("intro.vm.line10"),
      GameI18n.t("intro.vm.line11"),
    ],
    highlight: "#ff8844",
    featurePack: Some(InvertibleProgramming),
  },
  {
    title: GameI18n.t("intro.alerts.title"),
    lines: [
      GameI18n.t("intro.alerts.line1"),
      GameI18n.t("intro.alerts.line2"),
      GameI18n.t("intro.alerts.line3"),
      GameI18n.t("intro.alerts.line4"),
      GameI18n.t("intro.alerts.line5"),
      GameI18n.t("intro.alerts.line6"),
      GameI18n.t("intro.alerts.line7"),
      GameI18n.t("intro.alerts.line8"),
      GameI18n.t("intro.alerts.line9"),
      GameI18n.t("intro.alerts.line10"),
    ],
    highlight: "#ff4444",
    featurePack: None,
  },
  {
    title: GameI18n.t("intro.coop.title"),
    lines: [
      GameI18n.t("intro.coop.line1"),
      GameI18n.t("intro.coop.line2"),
      GameI18n.t("intro.coop.line3"),
      GameI18n.t("intro.coop.line4"),
      GameI18n.t("intro.coop.line5"),
      GameI18n.t("intro.coop.line6"),
      GameI18n.t("intro.coop.line7"),
      GameI18n.t("intro.coop.line8"),
      GameI18n.t("intro.coop.line9"),
      GameI18n.t("intro.coop.line10"),
      GameI18n.t("intro.coop.line11"),
    ],
    highlight: "#cc44ff",
    featurePack: None,
  },
]

// Filter pages based on enabled feature packs
let isFeatureEnabled = (pack: featurePack): bool => {
  switch pack {
  | InvertibleProgramming => FeaturePacks.isInvertibleProgrammingEnabled()
  }
}

let getPages = (): array<tutorialPage> => {
  getAllPages()->Array.filter(page => {
    switch page.featurePack {
    | None => true
    | Some(pack) => isFeatureEnabled(pack)
    }
  })
}

let make = (): Navigation.appScreen => {
  let container = Container.make()
  Container.setAlpha(container, 0.0)

  // Background
  let bg = Graphics.make()
  let _ = Container.addChildGraphics(container, bg)

  // Page content container
  let pageContainer = Container.make()
  let _ = Container.addChild(container, pageContainer)

  // Current page index
  let currentPage = ref(0)

  // Page indicator text
  let pageIndicator = Text.make({
    "text": "1 / 5",
    "style": {"fontSize": 12.0, "fill": "#555555", "fontFamily": "monospace"},
  })
  ObservablePoint.set(Text.anchor(pageIndicator), 0.5, ~y=0.0)
  let _ = Container.addChildText(container, pageIndicator)

  // Navigation buttons
  let nextBtn = Button.make(
    ~options={text: GameI18n.t("ui.next"), width: 160., height: 44., fontSize: 16},
    (),
  )
  let _ = Container.addChild(container, FancyButton.toContainer(nextBtn))

  let skipBtn = Button.make(
    ~options={text: GameI18n.t("ui.skip"), width: 120., height: 36., fontSize: 13},
    (),
  )
  let _ = Container.addChild(container, FancyButton.toContainer(skipBtn))

  let screenWidth = ref(1024.0)
  let screenHeight = ref(768.0)

  // Render the current page
  let renderPage = () => {
    Container.removeChildren(pageContainer)

    let pages = getPages()
    let page = pages[currentPage.contents]
    switch page {
    | Some(p) => {
        // Title
        let title = Text.make({
          "text": p.title,
          "style": {
            "fontSize": 28.0,
            "fill": p.highlight,
            "fontFamily": "monospace",
            "fontWeight": "bold",
            "letterSpacing": 3.0,
          },
        })
        ObservablePoint.set(Text.anchor(title), 0.5, ~y=0.0)
        Text.setX(title, screenWidth.contents /. 2.0)
        Text.setY(title, 60.0)
        let _ = Container.addChildText(pageContainer, title)

        // Horizontal line under title
        let line = Graphics.make()
        let _ =
          line
          ->Graphics.moveTo(screenWidth.contents *. 0.2, 100.0)
          ->Graphics.lineTo(screenWidth.contents *. 0.8, 100.0)
          ->Graphics.stroke({"width": 1, "color": 0x333333})
        let _ = Container.addChildGraphics(pageContainer, line)

        // Body text lines
        p.lines->Array.forEachWithIndex((lineText, idx) => {
          let t = Text.make({
            "text": lineText,
            "style": {"fontSize": 14.0, "fill": "#cccccc", "fontFamily": "monospace"},
          })
          Text.setX(t, screenWidth.contents *. 0.15)
          Text.setY(t, 120.0 +. Int.toFloat(idx) *. 26.0)
          let _ = Container.addChildText(pageContainer, t)
        })

        // Update page indicator
        Text.setText(
          pageIndicator,
          `${Int.toString(currentPage.contents + 1)} / ${Int.toString(Array.length(pages))}`,
        )

        // Update button text on last page
        if currentPage.contents == Array.length(pages) - 1 {
          FancyButton.setText(nextBtn, GameI18n.t("ui.start"))
        } else {
          FancyButton.setText(nextBtn, GameI18n.t("ui.next"))
        }
      }
    | None => ()
    }
  }

  // Navigate to world map (used by skip and last-page next)
  let goToWorldMap = () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ =
        Navigation.showScreen(engine.navigation, WorldMapScreen.constructor)->Promise.catch(
          PanicHandler.handleException,
        )
    | None => Console.error("[IntroScreen] goToWorldMap: Engine not initialised")
    }
  }

  // Button handlers
  Signal.connect(FancyButton.onPress(nextBtn), () => {
    let pages = getPages()
    if currentPage.contents < Array.length(pages) - 1 {
      currentPage := currentPage.contents + 1
      renderPage()
    } else {
      // Last page  start the game
      goToWorldMap()
    }
  })

  Signal.connect(FancyButton.onPress(skipBtn), () => {
    goToWorldMap()
  })

  {
    container,
    prepare: Some(
      () => {
        currentPage := 0
        renderPage()
      },
    ),
    show: Some(
      async () => {
        Container.setAlpha(container, 1.0)
      },
    ),
    hide: Some(
      async () => {
        Container.setAlpha(container, 0.0)
      },
    ),
    pause: None,
    resume: None,
    reset: Some(
      () => {
        currentPage := 0
      },
    ),
    update: None,
    resize: Some(
      (width, height) => {
        screenWidth := width
        screenHeight := height

        let _ = Graphics.clear(bg)
        let _ =
          bg
          ->Graphics.rect(0.0, 0.0, width, height)
          ->Graphics.fill({"color": 0x0a0a0a})

        // Page indicator
        Text.setX(pageIndicator, width /. 2.0)
        Text.setY(pageIndicator, height -. 80.0)

        // Buttons
        FancyButton.setX(nextBtn, width /. 2.0)
        FancyButton.setY(nextBtn, height -. 50.0)

        FancyButton.setX(skipBtn, width -. 80.0)
        FancyButton.setY(skipBtn, 24.0)

        renderPage()
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
