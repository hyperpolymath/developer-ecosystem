// SPDX-License-Identifier: PMPL-1.0-or-later
// PlayerHP  Health, damage, invincibility frames, and knockback
// Contact damage from alert enemies reduces HP. I-frames prevent stun-locking.


// Damage amounts by source
module Damage = {
  let roboDogContact = 15.0
  let guardDogBite = 10.0
  let assassinStrike = 35.0
  let guardMelee = 10.0
}

// Knockback constants
module Knockback = {
  let speed = 200.0 // Pixels per second away from damage source
  let duration = 0.3 // Seconds of knockback
  let iFrames = 1.0 // Seconds of invincibility after hit
}

type t = {
  mutable current: float,
  mutable max: float,
  mutable invincibleTimer: float,
  mutable knockbackVelX: float,
  mutable knockbackVelY: float,
  mutable knockbackTimer: float,
}

// Create HP scaled by CON attribute (100.0 is baseline)
let make = (~con: float): t => {
  let maxHP = 80.0 +. 20.0 *. (con /. 100.0)
  {
    current: maxHP,
    max: maxHP,
    invincibleTimer: 0.0,
    knockbackVelX: 0.0,
    knockbackVelY: 0.0,
    knockbackTimer: 0.0,
  }
}

// Check if currently invincible (i-frames active)
let isInvincible = (hp: t): bool => hp.invincibleTimer > 0.0

// Check if player is alive
let isAlive = (hp: t): bool => hp.current > 0.0

// Take damage from a source position. No-op if invincible.
let takeDamage = (hp: t, ~amount: float, ~fromX: float, ~playerX: float): unit => {
  if !isInvincible(hp) {
    hp.current = Math.max(0.0, hp.current -. amount)
    hp.invincibleTimer = Knockback.iFrames

    // Knockback direction: push player away from source
    let dx = playerX -. fromX
    let direction = if dx >= 0.0 {
      1.0
    } else {
      -1.0
    }
    hp.knockbackVelX = direction *. Knockback.speed
    hp.knockbackVelY = -80.0 // Slight upward pop
    hp.knockbackTimer = Knockback.duration
  }
}

// Update timers. Returns (velX, velY) knockback to apply to player this frame.
let update = (hp: t, ~dt: float): (float, float) => {
  // Decay invincibility
  if hp.invincibleTimer > 0.0 {
    hp.invincibleTimer = Math.max(0.0, hp.invincibleTimer -. dt)
  }

  // Decay knockback
  if hp.knockbackTimer > 0.0 {
    hp.knockbackTimer = Math.max(0.0, hp.knockbackTimer -. dt)
    let vel = (hp.knockbackVelX, hp.knockbackVelY)
    if hp.knockbackTimer <= 0.0 {
      hp.knockbackVelX = 0.0
      hp.knockbackVelY = 0.0
    }
    vel
  } else {
    (0.0, 0.0)
  }
}
