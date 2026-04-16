// SPDX-License-Identifier: PMPL-1.0-or-later
// Player Attributes System
// RPG-style attributes that influence movement and abilities
//
// STR (Strength): Increases max jump height
// DEX (Dexterity): Increases movement speed and jump charge speed
// INT (Intelligence): Increases trajectory prediction distance
// CON (Constitution): Reserved for future use (health/stamina)
// WIL (Willpower): Reserved for future use (hacking resistance)
// CHA (Charisma): Reserved for future use (NPC interactions)

type t = {
  mutable str: float, // Strength - jump power
  mutable dex: float, // Dexterity - speed
  mutable con: float, // Constitution - reserved
  mutable int: float, // Intelligence - trajectory preview
  mutable wil: float, // Willpower - reserved
  mutable cha: float, // Charisma - reserved
}

// Default attributes (100 is baseline)
let make = (): t => {
  str: 100.0,
  dex: 100.0,
  con: 100.0,
  int: 100.0,
  wil: 100.0,
  cha: 100.0,
}

// Attribute-derived values
// These multipliers translate attributes into gameplay effects

// Movement speed multiplier (based on DEX)
let getSpeedMultiplier = (attrs: t): float => {
  attrs.dex /. 100.0
}

// Max jump magnitude (based on STR)
let getMaxJump = (attrs: t): float => {
  5.0 *. attrs.str // MAXJMP_MULT * STR
}

// Jump charge accumulation rate (based on DEX)
let getJumpAcceleration = (attrs: t): float => {
  0.1 *. attrs.dex // JMPACC_MULT * DEX
}

// Trajectory preview length divisor (based on INT)
// Higher INT = more trajectory points visible.
// SafeFloat.divOr guards against trajectoryLength=0 which would produce
// NaN and break the trajectory preview rendering entirely.
let getTrajectoryDivisor = (attrs: t, baseIncrement: float, trajectoryLength: float): float => {
  SafeFloat.divOr(baseIncrement *. attrs.int, trajectoryLength, ~default=1.0)
}
