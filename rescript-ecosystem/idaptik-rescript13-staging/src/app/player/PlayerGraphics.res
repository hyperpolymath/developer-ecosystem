// SPDX-License-Identifier: PMPL-1.0-or-later
// Player Graphics - Visual representation with state-based appearance
// Dev art: Simple geometric shapes that change based on player state

open Pixi

// Color palette
module Colors = {
  let body = 0x3366cc // Blue body
  let bodyDark = 0x224488 // Darker blue for sprint
  let bodyCrouch = 0x445599 // Purple tint for crouch
  let bodyCharge = 0xcc6633 // Orange when charging jump
  let skin = 0xffccaa // Skin tone
  let laptop = 0x333333 // Laptop case
  let laptopScreen = 0x00ff00 // Green terminal
  let outline = 0x000000 // Outline color
}

// Body dimensions for different states
module Dimensions = {
  // Standing (idle, walk, sprint, jump)
  let standingWidth = 24.0
  let standingHeight = 40.0
  let headRadius = 12.0
  let headY = -52.0 // Relative to feet

  // Crouching
  let crouchWidth = 28.0
  let crouchHeight = 24.0
  let crouchHeadY = -36.0

  // Laptop (held in front)
  let laptopWidth = 20.0
  let laptopHeight = 12.0
  let laptopY = -25.0 // Relative to feet
  let laptopScreenPadding = 2.0
}

type t = {
  container: Container.t,
  body: Graphics.t,
  head: Graphics.t,
  laptop: Graphics.t,
  laptopScreen: Graphics.t,
  mutable currentState: PlayerState.visualState,
  mutable currentFacing: PlayerState.facing,
  mutable damageFlashTimer: float,
}

// Draw the body shape
let drawBody = (
  graphics: Graphics.t,
  ~state: PlayerState.visualState,
  ~facing: PlayerState.facing,
): unit => {
  let _ = Graphics.clear(graphics)

  let (width, height, color) = switch state {
  | Idle => (Dimensions.standingWidth, Dimensions.standingHeight, Colors.body)
  | Walking => (Dimensions.standingWidth, Dimensions.standingHeight, Colors.body)
  | Sprinting => (Dimensions.standingWidth, Dimensions.standingHeight, Colors.bodyDark)
  | Crouching => (Dimensions.crouchWidth, Dimensions.crouchHeight, Colors.bodyCrouch)
  | Jumping => (Dimensions.standingWidth, Dimensions.standingHeight, Colors.body)
  | ChargingJump => (Dimensions.crouchWidth, Dimensions.crouchHeight, Colors.bodyCharge)
  }

  // Body rectangle centered horizontally, with feet at y=0
  let _ =
    graphics
    ->Graphics.rect(-.width /. 2.0, -.height, width, height)
    ->Graphics.fill({"color": color})

  // Add slight lean when moving
  let _leanOffset = switch (state, facing) {
  | (Walking, Right) | (Sprinting, Right) => 2.0
  | (Walking, Left) | (Sprinting, Left) => -2.0
  | _ => 0.0
  }
}

// Draw the head
let drawHead = (graphics: Graphics.t, ~state: PlayerState.visualState): unit => {
  let _ = Graphics.clear(graphics)

  let headY = switch state {
  | Crouching | ChargingJump => Dimensions.crouchHeadY
  | _ => Dimensions.headY
  }

  let _ =
    graphics
    ->Graphics.circle(0.0, headY, Dimensions.headRadius)
    ->Graphics.fill({"color": Colors.skin})
}

// Draw the laptop
let drawLaptop = (
  graphics: Graphics.t,
  ~state: PlayerState.visualState,
  ~facing: PlayerState.facing,
): unit => {
  let _ = Graphics.clear(graphics)

  // Don't show laptop when crouching or charging
  switch state {
  | Crouching | ChargingJump => ()
  | _ =>
    let offsetX = switch facing {
    | Right => 2.0
    | Left => -2.0
    }

    let y = Dimensions.laptopY

    let _ =
      graphics
      ->Graphics.rect(
        -.Dimensions.laptopWidth /. 2.0 +. offsetX,
        y,
        Dimensions.laptopWidth,
        Dimensions.laptopHeight,
      )
      ->Graphics.fill({"color": Colors.laptop})
  }
}

// Draw laptop screen
let drawLaptopScreen = (
  graphics: Graphics.t,
  ~state: PlayerState.visualState,
  ~facing: PlayerState.facing,
): unit => {
  let _ = Graphics.clear(graphics)

  switch state {
  | Crouching | ChargingJump => ()
  | _ =>
    let offsetX = switch facing {
    | Right => 2.0
    | Left => -2.0
    }

    let y = Dimensions.laptopY +. Dimensions.laptopScreenPadding
    let screenWidth = Dimensions.laptopWidth -. Dimensions.laptopScreenPadding *. 2.0
    let screenHeight = Dimensions.laptopHeight -. Dimensions.laptopScreenPadding *. 2.0

    let _ =
      graphics
      ->Graphics.rect(-.screenWidth /. 2.0 +. offsetX, y, screenWidth, screenHeight)
      ->Graphics.fill({"color": Colors.laptopScreen})
  }
}

let make = (): t => {
  let container = Container.make()

  // Create graphics layers (order matters for z-index)
  let body = Graphics.make()
  let laptop = Graphics.make()
  let laptopScreen = Graphics.make()
  let head = Graphics.make()

  // Add in order (body first, head on top)
  let _ = Container.addChildGraphics(container, body)
  let _ = Container.addChildGraphics(container, laptop)
  let _ = Container.addChildGraphics(container, laptopScreen)
  let _ = Container.addChildGraphics(container, head)

  // Initial draw
  drawBody(body, ~state=Idle, ~facing=Right)
  drawHead(head, ~state=Idle)
  drawLaptop(laptop, ~state=Idle, ~facing=Right)
  drawLaptopScreen(laptopScreen, ~state=Idle, ~facing=Right)

  {
    container,
    body,
    head,
    laptop,
    laptopScreen,
    currentState: Idle,
    currentFacing: Right,
    damageFlashTimer: 0.0,
  }
}

// Update graphics based on state
let updateState = (gfx: t, ~state: PlayerState.visualState, ~facing: PlayerState.facing): unit => {
  // Only redraw if state changed
  if state != gfx.currentState || facing != gfx.currentFacing {
    gfx.currentState = state
    gfx.currentFacing = facing

    drawBody(gfx.body, ~state, ~facing)
    drawHead(gfx.head, ~state)
    drawLaptop(gfx.laptop, ~state, ~facing)
    drawLaptopScreen(gfx.laptopScreen, ~state, ~facing)

    // Flip container based on facing direction
    // Note: We handle facing in the drawing itself, but could also use scale.x = -1
  }
}

// Update damage flash  alternate alpha 0.3/1.0 every 0.1s during i-frames
let updateDamageFlash = (gfx: t, ~invincibleTimer: float, ~deltaTime: float): unit => {
  if invincibleTimer > 0.0 {
    gfx.damageFlashTimer = gfx.damageFlashTimer +. deltaTime
    // Alternate every 0.1 seconds
    let cycle = Math.floor(gfx.damageFlashTimer /. 0.1)
    let alpha = if mod(Float.toInt(cycle), 2) == 0 {
      1.0
    } else {
      0.3
    }
    Container.setAlpha(gfx.container, alpha)
  } else {
    gfx.damageFlashTimer = 0.0
    Container.setAlpha(gfx.container, 1.0)
  }
}

// Sync graphics position with state
let syncPosition = (gfx: t, ~x: float, ~y: float): unit => {
  Container.setX(gfx.container, x)
  Container.setY(gfx.container, y)
}

// Get container for adding to scene
let getContainer = (gfx: t): Container.t => {
  gfx.container
}
