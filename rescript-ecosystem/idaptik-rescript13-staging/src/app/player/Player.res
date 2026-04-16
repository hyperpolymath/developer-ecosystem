// SPDX-License-Identifier: PMPL-1.0-or-later
// Player - Main player module combining state, graphics, and trajectory
// This is the primary interface for creating and controlling the player

open Pixi

type t = {
  state: PlayerState.t,
  graphics: PlayerGraphics.t,
  trajectory: TrajectoryPreview.t,
  container: Container.t,
}

let make = (~startX: float, ~startY: float, ~groundY: float): t => {
  let state = PlayerState.make(~startX, ~startY, ~groundY)
  let graphics = PlayerGraphics.make()
  let trajectory = TrajectoryPreview.make()

  // Create main container for player graphics only
  // Trajectory is kept separate because it uses world coordinates
  let container = Container.make()

  // Add player graphics
  let _ = Container.addChild(container, PlayerGraphics.getContainer(graphics))

  // Set initial position
  PlayerGraphics.syncPosition(graphics, ~x=startX, ~y=startY)

  {
    state,
    graphics,
    trajectory,
    container,
  }
}

// Get trajectory container (for adding to world separately)
let getTrajectoryContainer = (player: t): Container.t => {
  TrajectoryPreview.getContainer(player.trajectory)
}

// Input state for player control
type inputState = {
  left: bool,
  right: bool,
  up: bool, // Jump key (hold to charge)
  crouch: bool, // Crouch key
  sprint: bool, // Sprint key
  mouseX: float,
  mouseY: float,
}

// Update player with input and delta time
let update = (player: t, ~input: inputState, ~deltaTime: float): unit => {
  let state = player.state

  // Handle jump charging
  if input.up && state.onGround {
    if !state.isChargingJump {
      PlayerState.startJumpCharge(state)
    }
    PlayerState.chargeJump(state, ~mouseX=input.mouseX)

    // Draw trajectory while charging
    // Start trajectory from player center (not feet) - offset up by ~30 pixels
    let params = PlayerState.calculateJumpParams(state, ~mouseX=input.mouseX, ~mouseY=input.mouseY)

    TrajectoryPreview.draw(
      player.trajectory,
      ~playerX=state.x,
      ~playerY=state.y -. 30.0, // Start from body center, not feet
      ~velX=params.velX,
      ~velY=params.velY,
      ~magnitude=params.magnitude,
      ~gravity=PlayerState.Physics.gravity,
      ~groundY=state.groundY,
      ~attributes=state.attributes,
    )
  } else if state.isChargingJump {
    // Jump key released - execute jump
    PlayerState.releaseJump(state, ~mouseX=input.mouseX, ~mouseY=input.mouseY)
    TrajectoryPreview.clear(player.trajectory)
  } else {
    // Clear trajectory when not charging
    TrajectoryPreview.clear(player.trajectory)
  }

  // Handle horizontal movement (only when not charging jump)
  if !state.isChargingJump {
    let direction = if input.left && !input.right {
      Some(PlayerState.Left)
    } else if input.right && !input.left {
      Some(PlayerState.Right)
    } else {
      None
    }

    PlayerState.setHorizontalMovement(
      state,
      ~direction,
      ~sprintKeyHeld=input.sprint,
      ~crouching=input.crouch,
    )
  }

  // Update physics
  PlayerState.updatePhysics(state, ~deltaTime)

  // Update trajectory animation
  TrajectoryPreview.update(player.trajectory, ~deltaTime)

  // Update graphics to match state
  PlayerGraphics.updateState(player.graphics, ~state=state.visualState, ~facing=state.facing)

  // Damage flash  alternate alpha during i-frames
  PlayerGraphics.updateDamageFlash(
    player.graphics,
    ~invincibleTimer=state.hp.invincibleTimer,
    ~deltaTime,
  )

  // Sync graphics position
  PlayerGraphics.syncPosition(player.graphics, ~x=state.x, ~y=state.y)
}

// Get player position (for camera follow, etc.)
let getPosition = (player: t): (float, float) => {
  PlayerState.getPosition(player.state)
}

// Get X position
let getX = (player: t): float => {
  player.state.x
}

// Get Y position
let getY = (player: t): float => {
  player.state.y
}

// Set X position (for clamping to world bounds)
let setX = (player: t, x: float): unit => {
  player.state.x = x
}

// Check if player is on ground
let isOnGround = (player: t): bool => {
  player.state.onGround
}

// Check if player is charging a jump
let isChargingJump = (player: t): bool => {
  player.state.isChargingJump
}

// Get the container for adding to scene
let getContainer = (player: t): Container.t => {
  player.container
}

// Get attributes for external modification
let getAttributes = (player: t): PlayerAttributes.t => {
  player.state.attributes
}

// Get HP state
let getHP = (player: t): PlayerHP.t => {
  player.state.hp
}

// Check if player is alive
let isAlive = (player: t): bool => {
  PlayerHP.isAlive(player.state.hp)
}

// Disable controls (stop movement)
let stopMovement = (player: t): unit => {
  player.state.velX = 0.0
  PlayerState.cancelJumpCharge(player.state)
  TrajectoryPreview.clear(player.trajectory)
}
