// SPDX-License-Identifier: PMPL-1.0-or-later
// Load Screen for ReScript

open Pixi

// Asset bundles required by this screen
let assetBundles = ["preload"]

// Create the load screen
let make = (): Navigation.appScreen => {
  let container = Container.make()

  // Create simple progress bar using graphics
  let progressBg = Graphics.make()
  let _ = Graphics.rect(progressBg, -100.0, -10.0, 200.0, 20.0)
  let _ = Graphics.fill(progressBg, {"color": 0x333333})
  let _ = Container.addChildGraphics(container, progressBg)

  let progressFill = Graphics.make()
  let _ = Graphics.rect(progressFill, -100.0, -10.0, 200.0, 20.0)
  let _ = Graphics.fill(progressFill, {"color": 0xec1561})
  ObservablePoint.set(Container.scale(Graphics.toContainer(progressFill)), 0.0, ~y=1.0)
  let _ = Container.addChildGraphics(container, progressFill)

  let pixiLogo = Sprite.make({
    "texture": Texture.from("logo.svg"),
    "anchor": 0.5,
    "scale": 0.2,
  })
  let _ = Container.addChild(container, Sprite.toContainer(pixiLogo))

  // "Powered by PixiJS" credit
  let creditText = Text.make({
    "text": "Powered by PixiJS",
    "style": {"fontSize": 11.0, "fill": "#666666", "fontFamily": "monospace"},
  })
  ObservablePoint.set(Text.anchor(creditText), 0.5, ~y=0.0)
  let _ = Container.addChildText(container, creditText)

  {
    container,
    prepare: None,
    show: Some(
      async () => {
        Container.setAlpha(container, 1.0)
      },
    ),
    hide: Some(
      async () => {
        await Motion.animateAsync(
          container,
          {"alpha": 0.0},
          {duration: 0.3, ease: "linear", delay: 1.0},
        )
      },
    ),
    pause: None,
    resume: None,
    reset: None,
    update: None,
    resize: Some(
      (width, height) => {
        ObservablePoint.set(Sprite.position(pixiLogo), width *. 0.5, ~y=height *. 0.5)
        Text.setX(creditText, width *. 0.5)
        Text.setY(creditText, height *. 0.5 +. 50.0)
        Graphics.setX(progressBg, width *. 0.5)
        Graphics.setY(progressBg, height *. 0.5 +. 80.0)
        Graphics.setX(progressFill, width *. 0.5)
        Graphics.setY(progressFill, height *. 0.5 +. 80.0)
      },
    ),
    blur: None,
    focus: None,
    onLoad: Some(
      progress => {
        // Scale the fill based on progress (0-100)
        ObservablePoint.setX(Container.scale(Graphics.toContainer(progressFill)), progress /. 100.0)
      },
    ),
  }
}

// Screen constructor
let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(assetBundles),
}
