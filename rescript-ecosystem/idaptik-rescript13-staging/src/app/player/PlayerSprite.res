// SPDX-License-Identifier: PMPL-1.0-or-later
// PlayerSprite  AnimatedSprite-based player rendering
//
// Drop-in alternative to PlayerGraphics. When a sprite sheet is provided
// (e.g. raw-assets/main{m}/player/jessica-spritesheet.json), this module
// will use AnimatedSprite to flip through frames. Until then, it generates
// placeholder frames from procedural Graphics.
//
// Animation states:
//   idle      4 frames, subtle breathing bob
//   walk      8 frames, walk cycle
//   jump      4 frames, crouch  rise  peak  fall
//   interact  4 frames, arms reach forward
//   crouch    2 frames, low pose
//   stunned   4 frames, flash/shake
//
// Sprite sheet layout (48x48 per frame):
//   Row 0: idle (4 frames)        y=0
//   Row 1: walk (8 frames)        y=48
//   Row 2: jump (4 frames)        y=96
//   Row 3: interact (4 frames)    y=144
//   Row 4: crouch (2 frames)      y=192
//   Row 5: stunned (4 frames)     y=240

open Pixi

// Frame size
let frameW = 48.0
let frameH = 48.0

// Animation name to frame count
type animationId = Idle | Walk | Jump | Interact | Crouch | Stunned | ChargingJump | Sprint

let frameCount = (anim: animationId): int => {
  switch anim {
  | Idle => 4
  | Walk => 8
  | Jump => 4
  | Interact => 4
  | Crouch => 2
  | Stunned => 4
  | ChargingJump => 2
  | Sprint => 8
  }
}

// Speeds (frames per tick at 60fps)
let animSpeed = (anim: animationId): float => {
  switch anim {
  | Idle => 0.05
  | Walk => 0.15
  | Jump => 0.1
  | Interact => 0.12
  | Crouch => 0.04
  | Stunned => 0.2
  | ChargingJump => 0.08
  | Sprint => 0.2
  }
}

// Map PlayerState visual state to our animation
let stateToAnim = (state: PlayerState.visualState): animationId => {
  switch state {
  | Idle => Idle
  | Walking => Walk
  | Sprinting => Sprint
  | Crouching => Crouch
  | Jumping => Jump
  | ChargingJump => ChargingJump
  }
}

//  Placeholder Frame Generation 
// Generates textures from Graphics for each animation frame.
// This is replaced once you drop in a real sprite sheet PNG.

type placeholderColor = {body: int, head: int}

let stateColor = (anim: animationId): placeholderColor => {
  switch anim {
  | Idle => {body: 0x1a1a2e, head: 0xe94560}
  | Walk => {body: 0x16213e, head: 0xe94560}
  | Sprint => {body: 0x0f3460, head: 0xe94560}
  | Jump => {body: 0x1a1a2e, head: 0xf5c518}
  | Interact => {body: 0x1a1a2e, head: 0x00ff88}
  | Crouch => {body: 0x2d2d44, head: 0xe94560}
  | ChargingJump => {body: 0x533483, head: 0xf5c518}
  | Stunned => {body: 0x880000, head: 0xff4444}
  }
}

// Generate a single placeholder frame as a Texture (via renderToTexture)
// For now, we return the Graphics drawing  the AnimatedSprite will be
// wired once a real spritesheet exists. The placeholder uses tint on a
// white pixel texture to simulate frames.
let generatePlaceholderTextures = (_anim: animationId, _count: int): array<Texture.t> => {
  // Use Texture.WHITE and tint the AnimatedSprite  simplest placeholder.
  // All frames are the same white texture; the sprite is tinted per-state.
  Array.make(~length=_count, Texture.white)
}

//  Sprite State 

type t = {
  container: Container.t,
  sprite: AnimatedSprite.t,
  mutable currentAnim: animationId,
  mutable facingLeft: bool,
  mutable damageFlashTimer: float,
  // Frame cache per animation (placeholder until real spritesheet)
  animations: dict<array<Texture.t>>,
}

let make = (): t => {
  let container = Container.make()

  // Build animation frame sets (placeholder white textures for now)
  let animations = Dict.make()
  let allAnims = [Idle, Walk, Jump, Interact, Crouch, Stunned, ChargingJump, Sprint]
  allAnims->Array.forEach(anim => {
    let frames = generatePlaceholderTextures(anim, frameCount(anim))
    let key = switch anim {
    | Idle => "idle"
    | Walk => "walk"
    | Jump => "jump"
    | Interact => "interact"
    | Crouch => "crouch"
    | Stunned => "stunned"
    | ChargingJump => "chargingjump"
    | Sprint => "sprint"
    }
    Dict.set(animations, key, frames)
  })

  // Create animated sprite with idle frames
  let idleFrames = Dict.get(animations, "idle")->Option.getOr([Texture.white])
  let sprite = AnimatedSprite.make(idleFrames)
  ObservablePoint.set(AnimatedSprite.anchor(sprite), 0.5, ~y=1.0) // Anchor at bottom-center (feet)
  AnimatedSprite.setAnimationSpeed(sprite, animSpeed(Idle))
  AnimatedSprite.setLoop(sprite, true)
  AnimatedSprite.play(sprite)

  // Apply placeholder body color via tint
  let colors = stateColor(Idle)
  AnimatedSprite.setTint(sprite, colors.body)

  // Set placeholder size
  AnimatedSprite.setWidth(sprite, frameW)
  AnimatedSprite.setHeight(sprite, frameH)

  let _ = Container.addChild(container, AnimatedSprite.toContainer(sprite))

  {
    container,
    sprite,
    currentAnim: Idle,
    facingLeft: false,
    damageFlashTimer: 0.0,
    animations,
  }
}

let getContainer = (ps: t): Container.t => ps.container

// Switch animation if it changed
let setAnimation = (ps: t, anim: animationId): unit => {
  if ps.currentAnim != anim {
    ps.currentAnim = anim
    let key = switch anim {
    | Idle => "idle"
    | Walk => "walk"
    | Jump => "jump"
    | Interact => "interact"
    | Crouch => "crouch"
    | Stunned => "stunned"
    | ChargingJump => "chargingjump"
    | Sprint => "sprint"
    }
    let frames = Dict.get(ps.animations, key)->Option.getOr([Texture.white])
    AnimatedSprite.setTextures(ps.sprite, frames)
    AnimatedSprite.setAnimationSpeed(ps.sprite, animSpeed(anim))
    AnimatedSprite.setLoop(ps.sprite, true)
    AnimatedSprite.play(ps.sprite)

    // Update tint for placeholder (will be identity tint with real sprites)
    let colors = stateColor(anim)
    AnimatedSprite.setTint(ps.sprite, colors.body)
  }
}

// Update state and facing
let updateState = (ps: t, ~state: PlayerState.visualState, ~facing: PlayerState.facing): unit => {
  let anim = stateToAnim(state)
  setAnimation(ps, anim)

  // Flip sprite horizontally for left-facing
  let isLeft = facing == PlayerState.Left
  if isLeft != ps.facingLeft {
    ps.facingLeft = isLeft
    let scaleX = if isLeft {
      -1.0
    } else {
      1.0
    }
    ObservablePoint.setX(AnimatedSprite.scale(ps.sprite), scaleX)
  }
}

// Damage flash (red tint flicker during invincibility)
let updateDamageFlash = (ps: t, ~invincibleTimer: float, ~deltaTime: float): unit => {
  if invincibleTimer > 0.0 {
    ps.damageFlashTimer = ps.damageFlashTimer +. deltaTime
    let remainder: float = %raw(`ps.damageFlashTimer % 0.2`)
    let flashOn = remainder < 0.1
    if flashOn {
      AnimatedSprite.setTint(ps.sprite, 0xff0000)
    } else {
      let colors = stateColor(ps.currentAnim)
      AnimatedSprite.setTint(ps.sprite, colors.body)
    }
  } else {
    ps.damageFlashTimer = 0.0
    let colors = stateColor(ps.currentAnim)
    AnimatedSprite.setTint(ps.sprite, colors.body)
  }
}

// Sync position
let syncPosition = (ps: t, ~x: float, ~y: float): unit => {
  Container.setX(ps.container, x)
  Container.setY(ps.container, y)
}
