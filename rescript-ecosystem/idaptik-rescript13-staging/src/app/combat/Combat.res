// SPDX-License-Identifier: PMPL-1.0-or-later
// Combat  Per-frame collision dispatcher for physical combat
// Checks player against all entities: stomp, charge, contact damage,
// and solid body collision (guards block player movement).
//
// Called once per frame from WorldBuilder/TrainingBase after physics update.
// Mutates entity state directly (stomp  stun/disable, charge  knockdown).
//
// Guard behaviour modulation:
//   Suspicious guards slow down and look carefully (? indicator from GuardNPC).
//   Alerted guards speed up and move directly toward player.
//   Assassins dodge stomps (sidestep) instead of letting player ride them.

let absFloat = (x: float): float =>
  if x < 0.0 {
    -.x
  } else {
    x
  }

//  Tuning Constants
// Named constants for gameplay-critical values. Centralised here so
// designers can tweak combat feel without hunting through logic code.

module Tuning = {
  // Stomp detection: vertical tolerance (px) for "landing on top" check.
  // Larger = more forgiving stomps; smaller = pixel-precise requirement.
  let stompVerticalTolerance = 12.0

  // Minimum horizontal speed (px/s) for a sprint-charge to register.
  // Below this threshold, running into an enemy deals no knockdown.
  let chargeMinSpeed = 200.0

  // Player hitbox dimensions (pixels)
  let playerStandingWidth = 24.0
  let playerStandingHeight = 40.0
  let playerCrouchingWidth = 28.0
  let playerCrouchingHeight = 24.0

  // Bounce velocities (px/s, negative = upward) applied to the player
  // after successfully stomping an entity
  let headStompBounce = -180.0
  let bodyStompBounce = -250.0
  let guardStompBounce = -200.0

  // Knockdown durations (seconds) for guard ranks
  let eliteKnockdownDuration = 1.5
  let normalKnockdownDuration = 3.0

  // Solid body collision: push-back velocity applied to player when
  // walking into a guard (not stomping, not charging). Prevents
  // the player from ghosting through guards.
  let bodyBlockPushback = 80.0

  // Assassin dodge: horizontal distance the assassin teleports
  // sideways when the player attempts a stomp
  let assassinDodgeDistance = 60.0

  // Assassin throw: upward velocity applied to player when assassin
  // throws them off after a failed stomp attempt
  let assassinThrowVelY = -300.0
  let assassinThrowVelX = 150.0
}

//  Result Types

type stompResult = BodyBounce | HeadKO | Miss
type chargeResult = Knockdown | Blocked | Miss

// Events returned from update for WorldBuilder to act on
type combatEvents = {
  mutable contactDamageDealt: bool,
  mutable stompCount: int,
  mutable knockdownCount: int,
  mutable bodyBlockCount: int,
}

let makeEvents = (): combatEvents => {
  contactDamageDealt: false,
  stompCount: 0,
  knockdownCount: 0,
  bodyBlockCount: 0,
}

//  Collision Checks

// Check if player is stomping an entity (falling from above onto its top)
let checkStomp = (
  ~playerRect: Hitbox.rect,
  ~playerVelY: float,
  ~entityBodyRect: Hitbox.rect,
  ~entityHeadRect: Hitbox.rect,
): stompResult => {
  // Player must be falling downward
  if playerVelY <= 0.0 {
    Miss
  } else {
    let playerBottom = playerRect.y +. playerRect.h
    let entityTop = entityBodyRect.y
    // Player bottom must be entering the entity's top zone
    let verticalOverlap =
      playerBottom >= entityTop && playerBottom <= entityTop +. Tuning.stompVerticalTolerance
    // Horizontal overlap required
    let horizontalOverlap =
      playerRect.x +. playerRect.w > entityBodyRect.x &&
        playerRect.x < entityBodyRect.x +. entityBodyRect.w

    if verticalOverlap && horizontalOverlap {
      // Head zone check (top ~25% of entity)
      if Hitbox.overlaps(playerRect, entityHeadRect) {
        HeadKO
      } else {
        BodyBounce
      }
    } else {
      Miss
    }
  }
}

// Check if player is sprint-charging into an entity
let checkCharge = (
  ~playerRect: Hitbox.rect,
  ~playerVelX: float,
  ~playerSprinting: bool,
  ~entityRect: Hitbox.rect,
): chargeResult => {
  if !playerSprinting || absFloat(playerVelX) < Tuning.chargeMinSpeed {
    Miss
  } else if Hitbox.overlaps(playerRect, entityRect) {
    Knockdown
  } else {
    Miss
  }
}

// Check if alert entity is touching player (contact damage)
let checkContactDamage = (
  ~playerRect: Hitbox.rect,
  ~entityRect: Hitbox.rect,
  ~entityAlert: bool,
): bool => {
  entityAlert && Hitbox.overlaps(playerRect, entityRect)
}

// Check solid body collision (player walking horizontally into guard).
// Returns the push-back direction: negative = push player left, positive = right.
// Returns 0.0 if no collision.
let checkBodyBlock = (
  ~playerRect: Hitbox.rect,
  ~playerVelY: float,
  ~entityRect: Hitbox.rect,
): float => {
  // Only block when player is on the ground (not falling/jumping)
  // and overlapping the entity horizontally
  if playerVelY > 2.0 || playerVelY < -2.0 {
    // Player is airborne — don't block (stomp/jump takes priority)
    0.0
  } else if Hitbox.overlaps(playerRect, entityRect) {
    // Player centre vs entity centre determines push direction
    let playerCenterX = playerRect.x +. playerRect.w /. 2.0
    let entityCenterX = entityRect.x +. entityRect.w /. 2.0
    if playerCenterX < entityCenterX {
      -.Tuning.bodyBlockPushback // Push player left
    } else {
      Tuning.bodyBlockPushback // Push player right
    }
  } else {
    0.0
  }
}

//  Player Hitbox

// Build player rect from state. Feet are at (x, y), body extends upward.
let playerRect = (~x: float, ~y: float, ~crouching: bool): Hitbox.rect => {
  let w = if crouching {
    Tuning.playerCrouchingWidth
  } else {
    Tuning.playerStandingWidth
  }
  let h = if crouching {
    Tuning.playerCrouchingHeight
  } else {
    Tuning.playerStandingHeight
  }
  {
    x: x -. w /. 2.0,
    y: y -. h,
    w,
    h,
  }
}

//  Per-Frame Update

let update = (
  ~player: Player.t,
  ~dogs: array<SecurityDog.t>,
  ~guards: array<GuardNPC.t>,
  ~_deltaTime: float,
): combatEvents => {
  let events = makeEvents()
  let state = player.state
  let hp = state.hp

  let playerInvincible = PlayerHP.isInvincible(hp)
  let isCrouching = state.visualState == PlayerState.Crouching
  let pRect = playerRect(~x=state.x, ~y=state.y, ~crouching=isCrouching)

  //  Check dogs
  Array.forEach(dogs, dog => {
    if dog.state != SecurityDog.Disabled && dog.state != SecurityDog.Stunned {
      let bodyRect = SecurityDog.getBodyRect(dog)
      let headRect = SecurityDog.getHeadRect(dog)

      // 1. Stomp check (player falling onto dog)
      let stomp = checkStomp(
        ~playerRect=pRect,
        ~playerVelY=state.velY,
        ~entityBodyRect=bodyRect,
        ~entityHeadRect=headRect,
      )
      switch stomp {
      | HeadKO => {
          SecurityDog.applyHeadStomp(dog)
          state.velY = Tuning.headStompBounce
          events.stompCount = events.stompCount + 1
        }
      | BodyBounce => {
          SecurityDog.applyBodyStomp(dog)
          state.velY = Tuning.bodyStompBounce
          events.stompCount = events.stompCount + 1
        }
      | Miss => {
          // 2. Body block check (player walking into dog)
          let pushback = checkBodyBlock(
            ~playerRect=pRect,
            ~playerVelY=state.velY,
            ~entityRect=bodyRect,
          )
          if pushback != 0.0 {
            // Push player away from dog
            state.x = state.x +. pushback *. _deltaTime
            state.velX = pushback *. 0.5
            events.bodyBlockCount = events.bodyBlockCount + 1
          }

          // 3. Contact damage (alert dog touching player)
          if !playerInvincible && SecurityDog.isAggressiveContact(dog) {
            if checkContactDamage(~playerRect=pRect, ~entityRect=bodyRect, ~entityAlert=true) {
              let dmg = switch dog.variant {
              | SecurityDog.RoboDog => PlayerHP.Damage.roboDogContact
              | SecurityDog.GuardDog => PlayerHP.Damage.guardDogBite
              }
              PlayerHP.takeDamage(hp, ~amount=dmg, ~fromX=dog.x, ~playerX=state.x)
              events.contactDamageDealt = true
            }
          }
        }
      }
    }
  })

  //  Check guards
  Array.forEach(guards, guard => {
    if guard.state != GuardNPC.KnockedDown {
      let guardBodyRect = GuardNPC.getBodyRect(guard)
      let guardHeadRect = GuardNPC.getHeadRect(guard)

      // 1. Stomp check
      let stomp = checkStomp(
        ~playerRect=pRect,
        ~playerVelY=state.velY,
        ~entityBodyRect=guardBodyRect,
        ~entityHeadRect=guardHeadRect,
      )
      switch stomp {
      | HeadKO | BodyBounce => {
          switch guard.rank {
          | GuardNPC.Assassin => {
              // Assassin dodges the stomp — sidesteps and throws player off.
              // Player is flung sideways and upward. Assassin repositions.
              let dodgeDir = if state.x < guard.x {
                1.0 // Assassin dodges right
              } else {
                -1.0 // Assassin dodges left
              }
              guard.x = guard.x +. dodgeDir *. Tuning.assassinDodgeDistance
              guard.state = GuardNPC.Stalking

              // Throw player off — strong upward + sideways velocity
              state.velY = Tuning.assassinThrowVelY
              state.velX = -.dodgeDir *. Tuning.assassinThrowVelX
            }
          | GuardNPC.Sentinel => {
              // Sentinel is armored — player bounces off, no knockdown
              state.velY = Tuning.guardStompBounce
            }
          | _ => {
              // Normal guards get knocked down
              state.velY = Tuning.guardStompBounce
              let duration = switch guard.rank {
              | GuardNPC.SecurityChief | GuardNPC.EliteGuard => Tuning.eliteKnockdownDuration
              | _ => Tuning.normalKnockdownDuration
              }
              GuardNPC.applyKnockdown(guard, ~duration)
              events.knockdownCount = events.knockdownCount + 1
            }
          }
          events.stompCount = events.stompCount + 1
        }
      | Miss => {
          // 2. Charge check (sprinting into guard)
          let charge = checkCharge(
            ~playerRect=pRect,
            ~playerVelX=state.velX,
            ~playerSprinting=state.isSprinting,
            ~entityRect=guardBodyRect,
          )
          switch charge {
          | Knockdown => switch guard.rank {
            | GuardNPC.Sentinel | GuardNPC.Assassin =>
              // Immune to knockdown — player bounces back, stops momentum
              state.velX = -.state.velX *. 0.5
              state.x = state.x +. (if state.x < guard.x { -8.0 } else { 8.0 })
            | GuardNPC.SecurityChief | GuardNPC.EliteGuard => {
                GuardNPC.applyKnockdown(guard, ~duration=Tuning.eliteKnockdownDuration)
                events.knockdownCount = events.knockdownCount + 1
              }
            | _ => {
                GuardNPC.applyKnockdown(guard, ~duration=Tuning.normalKnockdownDuration)
                events.knockdownCount = events.knockdownCount + 1
              }
            }
          | Blocked | Miss => {
              // 3. Body block check (player walking into guard — solid collision)
              let pushback = checkBodyBlock(
                ~playerRect=pRect,
                ~playerVelY=state.velY,
                ~entityRect=guardBodyRect,
              )
              if pushback != 0.0 {
                // Push player away from guard — can't walk through
                state.x = state.x +. pushback *. _deltaTime
                state.velX = pushback *. 0.3
                events.bodyBlockCount = events.bodyBlockCount + 1
              }

              // 4. Contact damage (alert guard touching player)
              if !playerInvincible {
                let isAlert = guard.state == GuardNPC.Alerted || guard.state == GuardNPC.Ambushing
                if (
                  checkContactDamage(
                    ~playerRect=pRect,
                    ~entityRect=guardBodyRect,
                    ~entityAlert=isAlert,
                  )
                ) {
                  let dmg = switch guard.rank {
                  | GuardNPC.Assassin => PlayerHP.Damage.assassinStrike
                  | _ => PlayerHP.Damage.guardMelee
                  }
                  PlayerHP.takeDamage(hp, ~amount=dmg, ~fromX=guard.x, ~playerX=state.x)
                  events.contactDamageDealt = true
                }
              }
            }
          }
        }
      }
    }
  })

  events
}
