// SPDX-License-Identifier: PMPL-1.0-or-later
// Button component for ReScript

open PixiUI

type options = {
  text?: string,
  width?: float,
  height?: float,
  fontSize?: int,
}

let defaultOptions: options = {
  text: "",
  width: 301.0,
  height: 112.0,
  fontSize: 28,
}

type t = {
  button: FancyButton.t,
}

// Play sound effects
let playSfx = (alias: string): unit => {
  // Get engine and play sound
  let engine = GetEngine.get()
  switch engine {
  | Some(e) => Audio.SFX.play(e.audio.sfx, alias, ())
  | None => ()
  }
}

// Create a Button
let make = (~options: options=defaultOptions, ()): FancyButton.t => {
  let text = options.text->Option.getOr("")
  let width = options.width->Option.getOr(301.0)
  let height = options.height->Option.getOr(112.0)
  let fontSize = options.fontSize->Option.getOr(28)
  // Apply user's font scale preference to button text
  let scaledFontSize = Float.toInt(FontScale.sizeInt(fontSize))

  let label = Label.make(
    ~text,
    ~style={
      fill: 0x4a4a4a,
      align: "center",
      fontSize: scaledFontSize,
    },
    (),
  )

  let button = FancyButton.make({
    "defaultView": "button.png",
    "nineSliceSprite": [38, 50, 38, 50],
    "anchor": 0.5,
    "text": label,
    "textOffset": {"x": 0, "y": -13},
    "defaultTextAnchor": 0.5,
    "animations": {
      "hover": {
        "props": {"scale": {"x": 1.03, "y": 1.03}, "y": 0},
        "duration": 100,
      },
      "pressed": {
        "props": {"scale": {"x": 0.97, "y": 0.97}, "y": 10},
        "duration": 100,
      },
    },
  })

  FancyButton.setWidth(button, width)
  FancyButton.setHeight(button, height)

  // Accessibility  PixiJS shadow DOM handles Tab/Enter/Space automatically
  let buttonContainer = FancyButton.toContainer(button)
  Pixi.Container.setAccessible(buttonContainer, true)
  Pixi.Container.setAccessibleTitle(buttonContainer, text)
  Pixi.Container.setAccessibleType(buttonContainer, "button")

  // Connect sound handlers
  Signal.connect(FancyButton.onDown(button), () => {
    playSfx("main/sounds/sfx-press.wav")
  })
  Signal.connect(FancyButton.onHover(button), () => {
    playSfx("main/sounds/sfx-hover.wav")
  })

  button
}
