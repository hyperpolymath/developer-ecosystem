// SPDX-License-Identifier: PMPL-1.0-or-later
// Volume Slider component for ReScript

open Pixi
open PixiUI

type t = {
  slider: Slider.t,
  messageLabel: Text.t,
}

// Create a VolumeSlider
let make = (~label: string, ~min=-0.1, ~max=100.0, ~value=100.0, ()): t => {
  let width = 280.0
  let height = 20.0
  let radius = 20.0
  let border = 4.0
  let handleRadius = 14.0
  let handleBorder = 4.0
  let meshColor = 0xec1561
  let fillColor = 0xef6294
  let borderColor = 0xec1561
  let backgroundColor = 0xffffff

  // Background track
  let bg = Graphics.make()
  let _ =
    bg
    ->Graphics.roundRect(0.0, 0.0, width, height, radius)
    ->Graphics.fill({"color": borderColor})
    ->Graphics.roundRect(border, border, width -. border *. 2.0, height -. border *. 2.0, radius)
    ->Graphics.fill({"color": backgroundColor})

  // Fill track
  let fill = Graphics.make()
  let _ =
    fill
    ->Graphics.roundRect(0.0, 0.0, width, height, radius)
    ->Graphics.fill({"color": borderColor})
    ->Graphics.roundRect(border, border, width -. border *. 2.0, height -. border *. 2.0, radius)
    ->Graphics.fill({"color": fillColor})

  // Slider handle
  let sliderHandle = Graphics.make()
  let _ =
    sliderHandle
    ->Graphics.circle(0.0, 0.0, handleRadius +. handleBorder)
    ->Graphics.fill({"color": meshColor})

  let slider = Slider.make({
    "bg": bg,
    "fill": fill,
    "slider": sliderHandle,
    "min": min,
    "max": max,
  })

  Slider.setValue(slider, value)

  let messageLabel = Label.make(
    ~text=label,
    ~style={
      align: "left",
      fill: 0x4a4a4a,
      fontSize: 18,
    },
    (),
  )
  ObservablePoint.setX(Text.anchor(messageLabel), 0.0)
  Text.setX(messageLabel, 10.0)
  Text.setY(messageLabel, -18.0)
  let _ = Slider.addChild(slider, messageLabel)

  {
    slider,
    messageLabel,
  }
}
