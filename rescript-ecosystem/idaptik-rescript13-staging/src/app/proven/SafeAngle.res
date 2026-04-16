// SPDX-License-Identifier: PMPL-1.0-or-later
// SafeAngle.res - Proven-safe angle calculations
//
// Guards against non-finite values in angle calculations to prevent
// NaN/Infinity from poisoning vision cone and rotation calculations

// Create angle from atan2, guarding against non-finite inputs
let fromAtan2 = (~y: float, ~x: float): float => {
  if !Float.isFinite(y) || !Float.isFinite(x) {
    0.0 // Default to 0 if inputs are invalid
  } else {
    Math.atan2(~y, ~x)
  }
}

// Normalize angle to [-PI, PI]
let normalize = (angle: float): float => {
  if !Float.isFinite(angle) {
    0.0
  } else {
    let pi = Math.Constants.pi
    @warning("-3")
    let normalized = mod_float(angle +. pi, 2.0 *. pi) -. pi
    if !Float.isFinite(normalized) {
      0.0
    } else {
      normalized
    }
  }
}

// Angle difference, normalized to [-PI, PI]
let diff = (a: float, b: float): float => {
  normalize(a -. b)
}

// Safe cosine (guards against NaN/Infinity)
let cos = (angle: float): float => {
  if !Float.isFinite(angle) {
    1.0 // Default to 1.0 if input is invalid
  } else {
    Math.cos(angle)
  }
}

// Safe sine (guards against NaN/Infinity)
let sin = (angle: float): float => {
  if !Float.isFinite(angle) {
    0.0 // Default to 0.0 if input is invalid
  } else {
    Math.sin(angle)
  }
}
