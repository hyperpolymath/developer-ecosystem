// SPDX-License-Identifier: PMPL-1.0-or-later
// RoundedBox component for ReScript

open Pixi

type options = {
  color?: int,
  width?: float,
  height?: float,
  shadow?: bool,
  shadowColor?: int,
  shadowOffset?: float,
}

let defaultOptions: options = {
  color: 0xffffff,
  width: 350.0,
  height: 600.0,
  shadow: true,
  shadowColor: 0xa0a0a0,
  shadowOffset: 22.0,
}

type t = {
  container: Container.t,
  image: NineSliceSprite.t,
  shadow: option<NineSliceSprite.t>,
  boxWidth: float,
  boxHeight: float,
}

// Create a RoundedBox
let make = (~options: options=defaultOptions, ()): t => {
  let container = Container.make()

  let color = options.color->Option.getOr(0xffffff)
  let width = options.width->Option.getOr(350.0)
  let height = options.height->Option.getOr(600.0)
  let showShadow = options.shadow->Option.getOr(true)
  let shadowColor = options.shadowColor->Option.getOr(0xa0a0a0)
  let shadowOffset = options.shadowOffset->Option.getOr(22.0)

  let image = NineSliceSprite.make({
    "texture": Texture.from("rounded-rectangle.png"),
    "leftWidth": 34,
    "topHeight": 34,
    "rightWidth": 34,
    "bottomHeight": 34,
    "width": width,
    "height": height,
    "tint": color,
  })
  NineSliceSprite.setX(image, -.width *. 0.5)
  NineSliceSprite.setY(image, -.height *. 0.5)
  let _ = Container.addChild(container, NineSliceSprite.toContainer(image))

  let shadow = if showShadow {
    let shadowSprite = NineSliceSprite.make({
      "texture": Texture.from("rounded-rectangle.png"),
      "leftWidth": 34,
      "topHeight": 34,
      "rightWidth": 34,
      "bottomHeight": 34,
      "width": width,
      "height": height,
      "tint": shadowColor,
    })
    NineSliceSprite.setX(shadowSprite, -.width *. 0.5)
    NineSliceSprite.setY(shadowSprite, -.height *. 0.5 +. shadowOffset)
    let _ = Container.addChildAt(container, NineSliceSprite.toContainer(shadowSprite), 0)
    Some(shadowSprite)
  } else {
    None
  }

  {
    container,
    image,
    shadow,
    boxWidth: width,
    boxHeight: height,
  }
}
