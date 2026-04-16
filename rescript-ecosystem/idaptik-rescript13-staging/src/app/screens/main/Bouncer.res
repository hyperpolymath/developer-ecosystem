// SPDX-License-Identifier: PMPL-1.0-or-later
// Bouncer - manages bouncing logos

open Pixi

let logoCount = 3
let animationDuration = 1.0
let waitDuration = 0.5

type t = {
  mutable screen: option<Container.t>,
  mutable mainContainer: option<Container.t>,
  mutable allLogoArray: array<Logo.t>,
  mutable activeLogoArray: array<Logo.t>,
  mutable yMin: float,
  mutable yMax: float,
  mutable xMin: float,
  mutable xMax: float,
}

// Create a new Bouncer
let make = (): t => {
  screen: None,
  mainContainer: None,
  allLogoArray: [],
  activeLogoArray: [],
  yMin: -400.0,
  yMax: 400.0,
  xMin: -400.0,
  xMax: 400.0,
}

// Add a new logo
let add = (bouncer: t): unit => {
  switch bouncer.mainContainer {
  | Some(container) =>
    let width = Random.float(bouncer.xMin, bouncer.xMax)
    let height = Random.float(bouncer.yMin, bouncer.yMax)
    let logo = Logo.make()

    Sprite.setAlpha(logo.sprite, 0.0)
    ObservablePoint.set(Sprite.position(logo.sprite), width, ~y=height)
    let _ = Motion.animate(logo.sprite, {"alpha": 1.0}, {duration: animationDuration})
    let _ = Container.addChildSprite(container, logo.sprite)
    bouncer.allLogoArray = Array.concat(bouncer.allLogoArray, [logo])
    bouncer.activeLogoArray = Array.concat(bouncer.activeLogoArray, [logo])
  | None => ()
  }
}

// Remove a logo
let remove = (bouncer: t): unit => {
  let len = Array.length(bouncer.activeLogoArray)
  if len > 0 {
    switch Array.get(bouncer.activeLogoArray, len - 1) {
    | Some(logo) =>
      bouncer.activeLogoArray = Array.slice(bouncer.activeLogoArray, ~start=0, ~end=len - 1)

      let _ = Motion.animate(logo.sprite, {"alpha": 0.0}, {duration: animationDuration})
        ->Motion.then_(() => {
          switch bouncer.mainContainer {
          | Some(container) =>
            let _ = Container.removeChild(container, Sprite.toContainer(logo.sprite))
            let idx = Array.findIndex(bouncer.allLogoArray, l => l === logo)
            if idx >= 0 {
              bouncer.allLogoArray = Array.filterWithIndex(bouncer.allLogoArray, (_, i) => i != idx)
            }
          | None => ()
          }
        })
    | None => ()
    }
  }
}

// Set direction based on current direction
let setDirection = (logo: Logo.t): unit => {
  let sprite = logo.sprite
  let speed = logo.speed

  switch logo.direction {
  | NE =>
    Sprite.setX(sprite, Sprite.x(sprite) +. speed)
    Sprite.setY(sprite, Sprite.y(sprite) -. speed)
  | NW =>
    Sprite.setX(sprite, Sprite.x(sprite) -. speed)
    Sprite.setY(sprite, Sprite.y(sprite) -. speed)
  | SE =>
    Sprite.setX(sprite, Sprite.x(sprite) +. speed)
    Sprite.setY(sprite, Sprite.y(sprite) +. speed)
  | SW =>
    Sprite.setX(sprite, Sprite.x(sprite) -. speed)
    Sprite.setY(sprite, Sprite.y(sprite) +. speed)
  }
}

// Check and update direction based on limits
let setLimits = (bouncer: t, logo: Logo.t): unit => {
  let pos = Sprite.position(logo.sprite)
  let x = ObservablePoint.x(pos)
  let y = ObservablePoint.y(pos)
  let topBound = Logo.top(logo)
  let bottomBound = Logo.bottom(logo)
  let leftBound = Logo.left(logo)
  let rightBound = Logo.right(logo)

  let direction = ref(logo.direction)

  if y +. topBound <= bouncer.yMin {
    direction := switch direction.contents {
    | NW => SW
    | _ => SE
    }
  }
  if y +. bottomBound >= bouncer.yMax {
    direction := switch direction.contents {
    | SE => NE
    | _ => NW
    }
  }
  if x +. leftBound <= bouncer.xMin {
    direction := switch direction.contents {
    | NW => NE
    | _ => SE
    }
  }
  if x +. rightBound >= bouncer.xMax {
    direction := switch direction.contents {
    | NE => NW
    | _ => SW
    }
  }

  logo.direction = direction.contents
}

// Update all logos
let update = (bouncer: t): unit => {
  Array.forEach(bouncer.allLogoArray, logo => {
    setDirection(logo)
    setLimits(bouncer, logo)
  })
}

// Show the bouncer
let show = async (bouncer: t, mainContainer: Container.t): unit => {
  bouncer.mainContainer = Some(mainContainer)
  for _ in 0 to logoCount - 1 {
    add(bouncer)
    await WaitFor.waitFor(~delayInSecs=waitDuration, ())
  }
}

// Resize bounds
let resize = (bouncer: t, w: float, h: float): unit => {
  bouncer.xMin = -.w /. 2.0
  bouncer.xMax = w /. 2.0
  bouncer.yMin = -.h /. 2.0
  bouncer.yMax = h /. 2.0
}
