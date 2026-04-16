// SPDX-License-Identifier: PMPL-1.0-or-later
// Player State - Movement state tracking and physics
// Handles: position, velocity, ground state, facing direction, visual state

// Visual state of the player
type visualState =
  | Idle
  | Walking
  | Sprinting
  | Crouching
  | Jumping
  | ChargingJump

// Facing direction
type facing =
  | Left
  | Right

// Physics constants
module Physics = {
  let gravity = 400.0 // Gravitational acceleration (pixels/sec^2)
  let friction = 0.55 // Ground friction multiplier (lower = grippier)
  let frictionThreshold = 1.0 // Stop completely below this velocity (pixels/sec)
  let baseSpeed = 160.0 // Base movement speed (pixels/sec)
  let sprintMultiplier = 2.0 // Sprint speed multiplier
  let crouchMultiplier = 0.5 // Crouch speed multiplier

  // Jump angle limits (prevent jumping straight down)
  let angleJumpLimitEast = Math.Constants.pi /. 4.0 // 45 (SE limit)
  let angleJumpLimitWest = 3.0 *. Math.Constants.pi /. 4.0 // 135 (SW limit)

  // Displacement divisor - lower = more sensitive to cursor distance
  let displacementDivisor = 100.0
}

// Player state
type t = {
  // Position
  mutable x: float,
  mutable y: float,
  // Velocity
  mutable velX: float,
  mutable velY: float,
  // State flags
  mutable onGround: bool,
  mutable facing: facing,
  mutable visualState: visualState,
  // Jump charging
  mutable jumpPotential: float,
  mutable isChargingJump: bool,
  // Sprint state - resets when character stops moving
  mutable isSprinting: bool,
  // Attributes reference
  attributes: PlayerAttributes.t,
  // Health and combat
  mutable hp: PlayerHP.t,
  // Ground Y position (set by world)
  mutable groundY: float,
}

let make = (~startX: float, ~startY: float, ~groundY: float): t => {
  let attributes = PlayerAttributes.make()
  {
    x: startX,
    y: startY,
    velX: 0.0,
    velY: 0.0,
    onGround: true,
    facing: Right,
    visualState: Idle,
    jumpPotential: 0.0,
    isChargingJump: false,
    isSprinting: false,
    attributes,
    hp: PlayerHP.make(~con=attributes.con),
    groundY,
  }
}

// Float absolute value helper (replaces deprecated Pervasives.abs_float)
let absFloat = (x: float): float =>
  if x < 0.0 {
    -.x
  } else {
    x
  }

// Update ground state based on velocity
let updateGroundState = (state: t): unit => {
  state.onGround = state.velY == 0.0 && state.y >= state.groundY
}

// Apply friction when on ground
let applyFriction = (state: t): unit => {
  if state.onGround && !state.isChargingJump {
    state.velX = state.velX *. Physics.friction
    if absFloat(state.velX) < Physics.frictionThreshold {
      state.velX = 0.0
    }
  }
}

// Get effective movement speed based on state and attributes
let getEffectiveSpeed = (state: t, ~sprinting: bool, ~crouching: bool): float => {
  let baseSpeed = Physics.baseSpeed *. PlayerAttributes.getSpeedMultiplier(state.attributes)

  if sprinting {
    baseSpeed *. Physics.sprintMultiplier
  } else if crouching {
    baseSpeed *. Physics.crouchMultiplier
  } else {
    baseSpeed
  }
}

// Calculate jump parameters from mouse position
type jumpParams = {
  angle: float,
  magnitude: float,
  velX: float,
  velY: float,
}

let calculateJumpParams = (state: t, ~mouseX: float, ~mouseY: float): jumpParams => {
  // Relative position from player to mouse
  let relX = mouseX -. state.x
  let relY = mouseY -. state.y

  // Calculate angle using SafeAngle (guards against NaN from invalid inputs).
  // atan2 is well-defined for all finite inputs including (0,0)  returns 0.
  let rawAngle = SafeAngle.fromAtan2(~y=relY, ~x=relX)

  // Clamp angle to prevent jumping downward.
  // If angle is in the "forbidden zone" (between E and W limits, i.e., pointing down),
  // snap to the nearest limit.
  let angle = if rawAngle > Physics.angleJumpLimitEast && rawAngle < Physics.angleJumpLimitWest {
    // In forbidden zone - snap to nearest limit
    if rawAngle > Math.Constants.pi /. 2.0 {
      Physics.angleJumpLimitWest
    } else {
      Physics.angleJumpLimitEast
    }
  } else {
    rawAngle
  }

  // Calculate magnitude based on distance and jump potential.
  // SafeFloat.divOr guards against Physics.displacementDivisor being zero.
  let distance = Math.sqrt(relX *. relX +. relY *. relY)
  let maxJump = PlayerAttributes.getMaxJump(state.attributes)
  let rawMagnitude =
    state.jumpPotential *. SafeFloat.divOr(distance, Physics.displacementDivisor, ~default=0.0)
  let magnitude = Math.min(rawMagnitude, maxJump)

  // Calculate velocity components using SafeAngle trig (guards against NaN)
  let velX = magnitude *. SafeAngle.cos(angle)
  let velY = magnitude *. SafeAngle.sin(angle)

  {angle, magnitude, velX, velY}
}

// Start charging a jump
let startJumpCharge = (state: t): unit => {
  if state.onGround && !state.isChargingJump {
    state.isChargingJump = true
    state.jumpPotential = 0.0
    state.velX = 0.0 // Lock position while aiming
    state.visualState = ChargingJump
  }
}

// Continue charging jump (call each frame while jump key held)
let chargeJump = (state: t, ~mouseX: float): unit => {
  if state.isChargingJump {
    let maxJump = PlayerAttributes.getMaxJump(state.attributes)
    let jumpAcc = PlayerAttributes.getJumpAcceleration(state.attributes)

    if state.jumpPotential < maxJump {
      state.jumpPotential = state.jumpPotential +. jumpAcc
    }

    // Update facing based on mouse position
    state.facing = if mouseX < state.x {
      Left
    } else {
      Right
    }
  }
}

// Release jump
let releaseJump = (state: t, ~mouseX: float, ~mouseY: float): unit => {
  if state.isChargingJump && state.jumpPotential > 0.0 {
    let params = calculateJumpParams(state, ~mouseX, ~mouseY)

    state.velX = params.velX
    state.velY = params.velY
    state.onGround = false
    state.visualState = Jumping
  }

  state.isChargingJump = false
  state.jumpPotential = 0.0
}

// Cancel jump charge without jumping
let cancelJumpCharge = (state: t): unit => {
  state.isChargingJump = false
  state.jumpPotential = 0.0
}

// Set horizontal movement (for walking/sprinting)
// sprintKeyHeld: true if shift is currently held down
let setHorizontalMovement = (
  state: t,
  ~direction: option<facing>,
  ~sprintKeyHeld: bool,
  ~crouching: bool,
): unit => {
  // Don't allow movement while charging jump
  if state.isChargingJump {
    ()
  } else if state.onGround {
    switch direction {
    | Some(dir) =>
      // Sprint if shift is held while moving, OR if we were already sprinting and still moving
      if sprintKeyHeld {
        state.isSprinting = true
      }
      // Keep sprinting as long as we're moving (even if shift released)
      // Sprint stops when we stop moving

      let effectivelySprinting = state.isSprinting && !crouching
      let speed = getEffectiveSpeed(state, ~sprinting=effectivelySprinting, ~crouching)
      let sign = switch dir {
      | Left => -1.0
      | Right => 1.0
      }
      state.velX = speed *. sign
      state.facing = dir

      // Set visual state
      state.visualState = if effectivelySprinting {
        Sprinting
      } else if crouching {
        Crouching
      } else {
        Walking
      }
    | None =>
      // No movement input - reset sprint state
      state.isSprinting = false

      // Let friction handle deceleration
      if crouching {
        state.visualState = Crouching
      } else {
        state.visualState = Idle
      }
    }
  }
}

// Platform  a one-way surface the player can land on (jump up through, land on top)
type platform = {
  x: float, // Left edge
  y: float, // Top surface Y
  width: float, // Width of the platform
}

// Mutable platforms list  set by the current screen before physics runs
let activePlatforms: ref<array<platform>> = ref([])

// Set platforms for the current level
let setPlatforms = (platforms: array<platform>): unit => {
  activePlatforms := platforms
}

// Clear platforms (on screen exit)
let clearPlatforms = (): unit => {
  activePlatforms := []
}

// Check if player is standing on a platform (within horizontal bounds, at platform Y)
let isOnPlatform = (state: t): option<platform> => {
  Array.find(activePlatforms.contents, p => {
    state.x >= p.x && state.x <= p.x +. p.width && absFloat(state.y -. p.y) < 2.0
  })
}

// Update physics (call each frame)
let updatePhysics = (state: t, ~deltaTime: float): unit => {
  // Apply gravity if not on ground
  if !state.onGround {
    state.velY = state.velY +. Physics.gravity *. deltaTime
  }

  // Apply friction
  applyFriction(state)

  // Apply knockback from combat damage
  let (kbX, kbY) = PlayerHP.update(state.hp, ~dt=deltaTime)
  if kbX != 0.0 || kbY != 0.0 {
    state.velX = kbX
    state.velY = kbY
    state.onGround = false
  }

  // Update position
  state.x = state.x +. state.velX *. deltaTime
  state.y = state.y +. state.velY *. deltaTime

  // Platform collision  one-way: only when falling (velY > 0)
  if state.velY > 0.0 {
    let prevY = state.y -. state.velY *. deltaTime
    Array.forEach(activePlatforms.contents, p => {
      // Player is within horizontal bounds and crossed the platform surface this frame
      if state.x >= p.x && state.x <= p.x +. p.width && prevY <= p.y && state.y >= p.y {
        state.y = p.y
        state.velY = 0.0
        state.onGround = true
        if state.visualState == Jumping {
          state.visualState = Idle
        }
      }
    })
  }

  // Walking off a platform edge  start falling
  if state.onGround && state.y < state.groundY {
    switch isOnPlatform(state) {
    | Some(_) => () // Still on a platform
    | None =>
      // Walked off the edge
      state.onGround = false
    }
  }

  // Ground collision
  if state.y >= state.groundY {
    state.y = state.groundY
    state.velY = 0.0
    state.onGround = true

    // Reset visual state when landing
    if state.visualState == Jumping {
      state.visualState = Idle
    }
  }

  // Update ground state
  updateGroundState(state)
}

// Get position as tuple (for external use like camera feed)
let getPosition = (state: t): (float, float) => {
  (state.x, state.y)
}
