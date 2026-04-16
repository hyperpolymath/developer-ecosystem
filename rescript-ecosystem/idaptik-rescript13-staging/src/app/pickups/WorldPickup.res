// SPDX-License-Identifier: PMPL-1.0-or-later
// WorldPickup  Reusable world-space pickup items
//
// Procedurally drawn items placed in the world that the player can
// pick up by pressing E within range. Supports both collectible items
// (USB sticks, keycards) and trap items (microchips that freeze the player).

open Pixi

//  Pickup Kind 

type pickupKind =
  | Collectible(Inventory.item) // Normal item  goes into inventory
  | Trap(string) // Trap  id describes the trap type

//  World Pickup 

type t = {
  container: Container.t,
  x: float,
  y: float,
  kind: pickupKind,
  mutable collected: bool,
  pickupRadius: float,
  glowPhase: float, // Random offset for pulse animation
}

//  Constructors 

// Draw a procedural USB stick and return a collectible pickup
let makeUSBStick = (~x: float, ~groundY: float): t => {
  let container = Container.make()
  Container.setX(container, x)
  Container.setY(container, groundY)

  // USB body  dark metallic rounded rectangle
  let body = Graphics.make()
  let _ =
    body
    ->Graphics.roundRect(-8.0, -28.0, 16.0, 24.0, 3.0)
    ->Graphics.fill({"color": 0x2a2a3a})
    ->Graphics.stroke({"width": 1, "color": 0x444466})
  let _ = Container.addChildGraphics(container, body)

  // Silver USB connector tab
  let connector = Graphics.make()
  let _ =
    connector
    ->Graphics.rect(-6.0, -6.0, 12.0, 6.0)
    ->Graphics.fill({"color": 0xaaaacc})
    ->Graphics.stroke({"width": 1, "color": 0x777799})
  let _ = Container.addChildGraphics(container, connector)

  // Green LED dot
  let led = Graphics.make()
  let _ =
    led
    ->Graphics.circle(0.0, -20.0, 2.5)
    ->Graphics.fill({"color": 0x00ff44})
  let _ = Container.addChildGraphics(container, led)

  // Label
  let label = Text.make({
    "text": "USB",
    "style": {"fontSize": 8, "fill": 0x888899, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(label), 0.5, ~y=0.5)
  Text.setY(label, -16.0)
  let _ = Container.addChildText(container, label)

  let item: Inventory.item = {
    id: "scav_usb_2gb",
    kind: Storage(USBDrive(2048)),
    name: "USB Drive (2GB)",
    weight: 0.02,
    condition: Pristine,
    usesRemaining: None,
    cableLength: None,
    description: "A small USB drive found during the mission",
  }

  {
    container,
    x,
    y: groundY,
    kind: Collectible(item),
    collected: false,
    pickupRadius: 60.0,
    glowPhase: Math.random() *. 6.28,
  }
}

// Draw a procedural microchip and return a trap pickup
let makeMicrochip = (~x: float, ~groundY: float): t => {
  let container = Container.make()
  Container.setX(container, x)
  Container.setY(container, groundY)

  // Chip body  small dark square
  let chip = Graphics.make()
  let _ =
    chip
    ->Graphics.rect(-10.0, -24.0, 20.0, 20.0)
    ->Graphics.fill({"color": 0x1a1a2e})
    ->Graphics.stroke({"width": 1, "color": 0x333355})
  let _ = Container.addChildGraphics(container, chip)

  // Gold pins on left edge
  for i in 0 to 3 {
    let pinY = -22.0 +. Int.toFloat(i) *. 5.0
    let pin = Graphics.make()
    let _ =
      pin
      ->Graphics.rect(-14.0, pinY, 4.0, 2.0)
      ->Graphics.fill({"color": 0xddaa44})
    let _ = Container.addChildGraphics(container, pin)
  }

  // Gold pins on right edge
  for i in 0 to 3 {
    let pinY = -22.0 +. Int.toFloat(i) *. 5.0
    let pin = Graphics.make()
    let _ =
      pin
      ->Graphics.rect(10.0, pinY, 4.0, 2.0)
      ->Graphics.fill({"color": 0xddaa44})
    let _ = Container.addChildGraphics(container, pin)
  }

  // Tiny die marking on centre
  let marking = Graphics.make()
  let _ =
    marking
    ->Graphics.rect(-4.0, -18.0, 8.0, 8.0)
    ->Graphics.fill({"color": 0x222244})
  let _ = Container.addChildGraphics(container, marking)

  // Label
  let label = Text.make({
    "text": "CHIP",
    "style": {"fontSize": 7, "fill": 0x666688},
  })
  ObservablePoint.set(Text.anchor(label), 0.5, ~y=0.5)
  Text.setY(label, -14.0)
  let _ = Container.addChildText(container, label)

  {
    container,
    x,
    y: groundY,
    kind: Trap("microchip_weight"),
    collected: false,
    pickupRadius: 60.0,
    glowPhase: Math.random() *. 6.28,
  }
}

// Draw a procedural USB "jump drive"  sits on elevated surfaces
let makeJumpDrive = (~x: float, ~groundY: float): t => {
  let container = Container.make()
  Container.setX(container, x)
  Container.setY(container, groundY)

  // USB body  blue metallic (to distinguish from regular USB)
  let body = Graphics.make()
  let _ =
    body
    ->Graphics.roundRect(-8.0, -28.0, 16.0, 24.0, 3.0)
    ->Graphics.fill({"color": 0x1a2a4a})
    ->Graphics.stroke({"width": 1, "color": 0x4466aa})
  let _ = Container.addChildGraphics(container, body)

  // Silver USB connector tab
  let connector = Graphics.make()
  let _ =
    connector
    ->Graphics.rect(-6.0, -6.0, 12.0, 6.0)
    ->Graphics.fill({"color": 0xaaaacc})
    ->Graphics.stroke({"width": 1, "color": 0x777799})
  let _ = Container.addChildGraphics(container, connector)

  // Blue LED dot (different from regular USB's green)
  let led = Graphics.make()
  let _ =
    led
    ->Graphics.circle(0.0, -20.0, 2.5)
    ->Graphics.fill({"color": 0x4488ff})
  let _ = Container.addChildGraphics(container, led)

  // Arrow-up icon (the "jump" hint)
  let arrow = Graphics.make()
  let _ =
    arrow
    ->Graphics.moveTo(0.0, -30.0)
    ->Graphics.lineTo(-4.0, -26.0)
    ->Graphics.lineTo(4.0, -26.0)
    ->Graphics.lineTo(0.0, -30.0)
    ->Graphics.fill({"color": 0x4488ff})
  let _ = Container.addChildGraphics(container, arrow)

  // Label
  let label = Text.make({
    "text": "JUMP",
    "style": {"fontSize": 7, "fill": 0x6688bb, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(label), 0.5, ~y=0.5)
  Text.setY(label, -16.0)
  let _ = Container.addChildText(container, label)

  let item: Inventory.item = {
    id: "scav_jump_drive",
    kind: Storage(USBDrive(4096)),
    name: "Jump Drive (4GB)",
    weight: 0.02,
    condition: Pristine,
    usesRemaining: None,
    cableLength: None,
    description: "A jump drive. Found on top of a crate. Naturally.",
  }

  {
    container,
    x,
    y: groundY,
    kind: Collectible(item),
    collected: false,
    pickupRadius: 60.0,
    glowPhase: Math.random() *. 6.28,
  }
}

// Draw a procedural generic collectible
let makeCollectible = (~item: Inventory.item, ~x: float, ~groundY: float): t => {
  let container = Container.make()
  Container.setX(container, x)
  Container.setY(container, groundY)

  // Crate body  metallic box
  let body = Graphics.make()
  let _ =
    body
    ->Graphics.roundRect(-12.0, -30.0, 24.0, 24.0, 2.0)
    ->Graphics.fill({"color": 0x3a3a4a})
    ->Graphics.stroke({"width": 1, "color": 0x555577})
  let _ = Container.addChildGraphics(container, body)

  // Cross-brace on crate
  let brace = Graphics.make()
  let _ =
    brace
    ->Graphics.moveTo(-10.0, -28.0)
    ->Graphics.lineTo(10.0, -8.0)
    ->Graphics.moveTo(10.0, -28.0)
    ->Graphics.lineTo(-10.0, -8.0)
    ->Graphics.stroke({"width": 1, "color": 0x555577})
  let _ = Container.addChildGraphics(container, brace)

  // Label with item name (truncated)
  let shortName = String.slice(item.name, ~start=0, ~end=8)
  let label = Text.make({
    "text": shortName,
    "style": {"fontSize": 7, "fill": 0xffffff, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(label), 0.5, ~y=0.5)
  Text.setY(label, -18.0)
  let _ = Container.addChildText(container, label)

  {
    container,
    x,
    y: groundY,
    kind: Collectible(item),
    collected: false,
    pickupRadius: 60.0,
    glowPhase: Math.random() *. 6.28,
  }
}

//  Animation 

// Pulse alpha 0.61.0 based on game time
let updateAnimation = (pickup: t, ~gameTime: float): unit => {
  if !pickup.collected {
    let pulse = 0.8 +. 0.2 *. Math.sin(gameTime *. 2.0 +. pickup.glowPhase)
    Container.setAlpha(pickup.container, pulse)
  }
}

//  Proximity Check 

// Returns true if player is within pickup radius
let isInRange = (pickup: t, ~playerX: float, ~playerY: float): bool => {
  if pickup.collected {
    false
  } else {
    let dx = playerX -. pickup.x
    let dy = playerY -. pickup.y
    let dist = Math.sqrt(dx *. dx +. dy *. dy)
    dist <= pickup.pickupRadius
  }
}

//  Collection Animation 

// Fade out the pickup container
let animateCollect = (pickup: t): unit => {
  pickup.collected = true
  let _ = Motion.animate(
    pickup.container,
    {"alpha": 0.0, "y": Container.y(pickup.container) -. 20.0},
    {duration: 0.4, ease: "easeOut"},
  )
}
