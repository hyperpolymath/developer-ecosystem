// SPDX-License-Identifier: PMPL-1.0-or-later
// Logo sprite for bouncing animation

open Pixi

// Direction enum
type direction =
  | NE
  | NW
  | SE
  | SW

type t = {
  sprite: Sprite.t,
  mutable direction: direction,
  mutable speed: float,
}

// Convert direction to int for random selection
let directionFromInt = (i: int): direction => {
  switch mod(i, 4) {
  | 0 => NE
  | 1 => NW
  | 2 => SE
  | _ => SW
  }
}

// Get bounds
let left = (logo: t): float => {
  -.Sprite.width(logo.sprite) *. 0.5
}

let right = (logo: t): float => {
  Sprite.width(logo.sprite) *. 0.5
}

let top = (logo: t): float => {
  -.Sprite.height(logo.sprite) *. 0.5
}

let bottom = (logo: t): float => {
  Sprite.height(logo.sprite) *. 0.5
}

// Create a new Logo
let make = (): t => {
  let tex = if Random.bool(()) {
    "logo.svg"
  } else {
    "logo-white.svg"
  }

  let sprite = Sprite.make({
    "texture": Texture.from(tex),
    "anchor": 0.5,
    "scale": 0.25,
  })

  {
    sprite,
    direction: directionFromInt(Random.int(0, 3)),
    speed: Random.float(1.0, 6.0),
  }
}
