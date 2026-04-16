// SPDX-License-Identifier: PMPL-1.0-or-later
// Keyboard-Only Aiming for Jump
//
// When keyboard-only mode is enabled and the player is charging a jump,
// Q/E adjust the aim angle and W/S adjust the power. The result is
// converted to a (mouseX, mouseY) equivalent so Player.res needs no changes.

// Aiming state
let angle = ref(Math.Constants.pi *. -0.25) // Default: 45 degrees up-right
let power = ref(0.5) // 0.0 to 1.0

// Angle adjustment speed (radians per frame)
let angleStep = 0.03

// Power adjustment speed (per frame)
let powerStep = 0.02

// Max aim distance (pixels from player)
let maxDistance = 300.0

// Reset to defaults
let reset = (): unit => {
  angle := Math.Constants.pi *. -0.25
  power := 0.5
}

// Update angle and power based on key state
// Returns true if keyboard aiming is active (keyboard-only mode enabled)
let update = (~qKey: bool, ~eKey: bool, ~wKey: bool, ~sKey: bool): bool => {
  if !AccessibilitySettings.isKeyboardOnlyEnabled() {
    false
  } else {
    // Q rotates counter-clockwise, E rotates clockwise
    if qKey {
      angle := angle.contents -. angleStep
    }
    if eKey {
      angle := angle.contents +. angleStep
    }
    // Clamp angle to upper half (-PI to 0, i.e. aiming upward)
    angle := Math.max(Math.Constants.pi *. -1.0, Math.min(0.0, angle.contents))

    // W increases power, S decreases
    if wKey {
      power := Math.min(1.0, power.contents +. powerStep)
    }
    if sKey {
      power := Math.max(0.0, power.contents -. powerStep)
    }

    true
  }
}

// Convert current angle/power to a mouse-equivalent position
// relative to the player's screen position
let getMouseEquivalent = (~playerScreenX: float, ~playerScreenY: float): (float, float) => {
  let dist = power.contents *. maxDistance
  let mx = playerScreenX +. dist *. Math.cos(angle.contents)
  let my = playerScreenY +. dist *. Math.sin(angle.contents)
  (mx, my)
}
