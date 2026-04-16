// SPDX-License-Identifier: PMPL-1.0-or-later
// Credits Screen  scrolling credits roll
//
// Displays project credits with smooth upward scroll.
// Auto-returns to main screen when complete, or skip with any key.

open Pixi

let assetBundles = ["main"]

// Credit entries
type creditEntry =
  | Header(string)
  | Name(string)
  | Spacer

let credits: array<creditEntry> = [
  Header("IDApTIK"),
  Spacer,
  Header("Design & Programming"),
  Name("Joshua B. Jewell"),
  Name("Jonathan D.A. Jewell"),
  Spacer,
  Header("Reversible VM Architecture"),
  Name("Joshua B. Jewell"),
  Name("Jonathan D.A. Jewell"),
  Spacer,
  Header("Level Design"),
  Name("Joshua B. Jewell"),
  Spacer,
  Header("Art & Visual Design"),
  Name("Joshua B. Jewell"),
  Spacer,
  Header("Sound Design"),
  Name("Joshua B. Jewell"),
  Spacer,
  Header("Multiplayer Architecture"),
  Name("Jonathan D.A. Jewell"),
  Spacer,
  Header("Puzzle Design"),
  Name("Joshua B. Jewell"),
  Name("Jonathan D.A. Jewell"),
  Spacer,
  Header("Technology"),
  Name("ReScript  rescript-lang.org"),
  Name("PixiJS  pixijs.com"),
  Name("Deno  deno.land"),
  Name("Tauri  tauri.app"),
  Name("Elixir + Phoenix  elixir-lang.org"),
  Name("Idris2  idris-lang.org"),
  Name("Zig  ziglang.org"),
  Name("Chapel  chapel-lang.org"),
  Spacer,
  Header("Standards"),
  Name("Rhodium Standard Repositories"),
  Name("Palimpsest License (PMPL-1.0-or-later)"),
  Spacer,
  Header("Special Thanks"),
  Name("The ReScript community"),
  Name("The Deno community"),
  Name("Reversible computing researchers"),
  Name("Bennett, Landauer, and Toffoli"),
  Spacer,
  Spacer,
  Header("Thank you for playing"),
  Spacer,
  Spacer,
  Name("Copyright (c) 2026 Joshua B. Jewell and Jonathan D.A. Jewell"),
  Name("(hyperpolymath)"),
]

let make = (): Navigation.appScreen => {
  let container = Container.make()
  Container.setAlpha(container, 0.0)

  // Dark background
  let bg = Graphics.make()
  let _ = Container.addChildGraphics(container, bg)

  // Scrolling container
  let scrollContainer = Container.make()
  let _ = Container.addChild(container, scrollContainer)

  // Build credit text elements
  let yOffset = ref(0.0)
  credits->Array.forEach(entry => {
    switch entry {
    | Header(text) => {
        let t = Text.make({
          "text": text,
          "style": {
            "fontSize": 20.0,
            "fill": "#44ff88",
            "fontFamily": "monospace",
            "fontWeight": "bold",
            "letterSpacing": 2.0,
          },
        })
        ObservablePoint.set(Text.anchor(t), 0.5, ~y=0.0)
        Text.setY(t, yOffset.contents)
        let _ = Container.addChildText(scrollContainer, t)
        yOffset := yOffset.contents +. 36.0
      }
    | Name(text) => {
        let t = Text.make({
          "text": text,
          "style": {"fontSize": 14.0, "fill": "#aaccaa", "fontFamily": "monospace"},
        })
        ObservablePoint.set(Text.anchor(t), 0.5, ~y=0.0)
        Text.setY(t, yOffset.contents)
        let _ = Container.addChildText(scrollContainer, t)
        yOffset := yOffset.contents +. 24.0
      }
    | Spacer => yOffset := yOffset.contents +. 30.0
    }
  })

  let totalHeight = yOffset.contents
  let scrollSpeed = 40.0 // pixels per second
  let screenHeight = ref(768.0)
  let finished = ref(false)

  // "Press any key to skip" hint
  let skipText = Text.make({
    "text": "Press any key to skip",
    "style": {"fontSize": 11.0, "fill": "#444444", "fontFamily": "monospace"},
  })
  let _ = Container.addChildText(container, skipText)

  {
    container,
    prepare: None,
    show: Some(
      async () => {
        Container.setAlpha(container, 1.0)
        // Start scroll from below screen
        Container.setY(scrollContainer, screenHeight.contents)
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
        finished := false
      },
    ),
    update: Some(
      ticker => {
        if !finished.contents {
          let dt = Ticker.deltaTime(ticker) /. 60.0
          let currentY = Container.y(scrollContainer)
          let newY = currentY -. scrollSpeed *. dt
          Container.setY(scrollContainer, newY)

          // Finished when all credits have scrolled past top
          if newY < -.totalHeight {
            finished := true
          }
        }
      },
    ),
    resize: Some(
      (width, height) => {
        screenHeight := height

        let _ = Graphics.clear(bg)
        let _ =
          bg
          ->Graphics.rect(0.0, 0.0, width, height)
          ->Graphics.fill({"color": 0x0a0a0a})

        // Centre all credit text horizontally
        let children = Container.getChildCount(scrollContainer)
        for i in 0 to children - 1 {
          let child = Container.getChildAt(scrollContainer, i)
          Container.setX(child, width /. 2.0)
        }

        // Skip hint at bottom-right
        Text.setX(skipText, width -. 180.0)
        Text.setY(skipText, height -. 24.0)
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
