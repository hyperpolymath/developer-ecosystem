// SPDX-License-Identifier: PMPL-1.0-or-later
// SafeFloat  NaN/Infinity-guarded floating point operations
//
// Pure ReScript equivalent of proven's ProvenSafeFloat module. In the
// Idris2 implementation, dependent types ensure floating point operations
// never produce NaN or Infinity. Here we enforce the same invariants at
// runtime with explicit NaN/Infinity checks after each operation.
//
// This module is critical for IDApTIK's physics engine (PlayerState,
// TrajectoryPreview) and rendering pipeline (alpha blending, sizing)
// where NaN values would cause invisible sprites or frozen animations.
//
// Design principle: every operation that can produce NaN or Infinity
// returns `result<float, ProvenError.provenError>`. Operations that
// are mathematically bounded (clamp, lerp with valid t) return plain
// floats.
//
// Usage:
//   // Safe division in physics
//   switch SafeFloat.div(velocity, deltaTime) {
//   | Ok(speed) => updatePosition(speed)
//   | Error(_) => // deltaTime was 0, skip frame
//   }
//
//   // Clamped lerp for animations (always produces valid float)
//   let alpha = SafeFloat.lerp(0.0, 1.0, ~t=progress)

//  Finite Validation 
// The fundamental guard: checks that a float is neither NaN nor Infinity.
// In proven's Idris2, this is a type-level constraint (Finite : Double -> Type).
// Here it's a runtime check that gates all potentially dangerous operations.
@val external isFinite: float => bool = "Number.isFinite"
@val external isNaN: float => bool = "Number.isNaN"

//  Guard Helper 
// Wraps a float computation result, returning Error if NaN or Infinity.
// This is the core safety mechanism  every unsafe operation passes
// through this gate before returning to the caller.
let guard = (value: float, ~operation: string): result<float, ProvenError.provenError> => {
  if isNaN(value) {
    Error(ProvenError.notANumber(~operation, ~message="Operation produced NaN"))
  } else if !isFinite(value) {
    Error(ProvenError.infinity(~operation, ~message="Operation produced Infinity"))
  } else {
    Ok(value)
  }
}

//  Safe Division 
// Float division with zero-divisor and NaN/Infinity guards. This is
// the single most important safety function in the game  used by
// Resize.res (aspect ratio), PlayerAttributes.res (stat scaling),
// TrajectoryPreview.res (alpha fade), and PowerManager.res (drain rate).
//
// Proven equivalent: ProvenSafeFloat.div (divisor has NonZero proof,
// result has Finite proof)
let div = (a: float, b: float): result<float, ProvenError.provenError> => {
  if b == 0.0 {
    Error(ProvenError.divisionByZero(~operation="SafeFloat.div", ~message="Division by zero"))
  } else {
    guard(a /. b, ~operation="SafeFloat.div")
  }
}

//  Division with Default 
// Divides a by b, returning `default` if b is zero or result is
// non-finite. Preferred for rendering code where a fallback is always
// acceptable (e.g. sprite sizing, alpha blending).
let divOr = (a: float, b: float, ~default: float): float => {
  if b == 0.0 {
    default
  } else {
    let result = a /. b
    if isFinite(result) {
      result
    } else {
      default
    }
  }
}

//  Safe Multiplication 
// Float multiplication with Infinity guard. Can produce Infinity
// when multiplying very large values (e.g. velocity * large deltaTime).
let mul = (a: float, b: float): result<float, ProvenError.provenError> => {
  guard(a *. b, ~operation="SafeFloat.mul")
}

//  Safe Addition 
// Float addition with Infinity guard. Rare but possible with
// accumulating position values over long play sessions.
let add = (a: float, b: float): result<float, ProvenError.provenError> => {
  guard(a +. b, ~operation="SafeFloat.add")
}

//  Safe Subtraction 
let sub = (a: float, b: float): result<float, ProvenError.provenError> => {
  guard(a -. b, ~operation="SafeFloat.sub")
}

//  Clamping (Always Safe) 
// Restricts a float to [lo, hi]. If value is NaN, returns lo as a
// safe default (NaN comparisons always return false, so the < check
// triggers). This makes clamp a total function  it always succeeds.
//
// Proven equivalent: dependent type lo <= result <= hi
let clamp = (value: float, ~lo: float, ~hi: float): float => {
  if isNaN(value) || value < lo {
    lo
  } else if value > hi {
    hi
  } else {
    value
  }
}

//  Linear Interpolation 
// Interpolates between a and b by factor t. Clamps t to [0, 1] to
// prevent extrapolation. Always produces a finite result when a and b
// are finite (which they are for all game values).
//
// Formula: a + (b - a) * clamp(t, 0, 1)
//
// Proven equivalent: ProvenSafeFloat.lerp (t has 0 <= t <= 1 proof)
let lerp = (a: float, b: float, ~t: float): float => {
  let safeT = clamp(t, ~lo=0.0, ~hi=1.0)
  a +. (b -. a) *. safeT
}

//  Inverse Lerp 
// Given a range [a, b] and a value, returns where the value falls in
// that range as a [0, 1] fraction. Returns 0.0 if a == b (degenerate
// range) instead of dividing by zero.
let inverseLerp = (a: float, b: float, ~value: float): float => {
  let range = b -. a
  if range == 0.0 {
    0.0
  } else {
    clamp((value -. a) /. range, ~lo=0.0, ~hi=1.0)
  }
}

//  Remap 
// Maps a value from range [inLo, inHi] to range [outLo, outHi].
// Safe against degenerate input ranges. Useful for mapping game
// values (e.g. HP 0-100) to visual properties (e.g. alpha 0.2-1.0).
let remap = (value: float, ~inLo: float, ~inHi: float, ~outLo: float, ~outHi: float): float => {
  let t = inverseLerp(inLo, inHi, ~value)
  lerp(outLo, outHi, ~t)
}

//  Safe Square Root 
// Square root with negative input guard. Returns Error for negative
// values instead of producing NaN.
let sqrt = (n: float): result<float, ProvenError.provenError> => {
  if n < 0.0 {
    Error(
      ProvenError.invalidArgument(
        ~operation="SafeFloat.sqrt",
        ~message=`Cannot take square root of negative number: ${Float.toString(n)}`,
      ),
    )
  } else {
    Ok(Math.sqrt(n))
  }
}

//  Absolute Value (Always Safe) 
let abs = (n: float): float =>
  if n < 0.0 {
    -.n
  } else {
    n
  }

//  Sign Function 
// Returns -1.0, 0.0, or 1.0. Returns 0.0 for NaN.
let sign = (n: float): float => {
  if isNaN(n) {
    0.0
  } else if n > 0.0 {
    1.0
  } else if n < 0.0 {
    -1.0
  } else {
    0.0
  }
}

//  Finite Check 
// Returns Ok(value) if finite, Error otherwise. Use this to validate
// external inputs (e.g. values from JavaScript callbacks or network).
let finite = (value: float): result<float, ProvenError.provenError> => {
  guard(value, ~operation="SafeFloat.finite")
}

//  Minimum and Maximum (NaN-safe) 
// Standard min/max but with NaN handling: if either input is NaN,
// returns the other. If both are NaN, returns 0.0.
let min = (a: float, b: float): float => {
  if isNaN(a) && isNaN(b) {
    0.0
  } else if isNaN(a) {
    b
  } else if isNaN(b) {
    a
  } else if a < b {
    a
  } else {
    b
  }
}

let max = (a: float, b: float): float => {
  if isNaN(a) && isNaN(b) {
    0.0
  } else if isNaN(a) {
    b
  } else if isNaN(b) {
    a
  } else if a > b {
    a
  } else {
    b
  }
}

//  Range Check 
// Returns true if value is within [lo, hi] inclusive and is finite.
let inRange = (value: float, ~lo: float, ~hi: float): bool => {
  isFinite(value) && value >= lo && value <= hi
}

//  Nearly Equal 
// Floating point comparison with epsilon tolerance. Default epsilon
// is 1e-10 which is suitable for game physics calculations.
let nearlyEqual = (a: float, b: float, ~epsilon: float=1e-10): bool => {
  abs(a -. b) < epsilon
}

//  Float Modulo Helper 
// JavaScript's % operator for floats (fmod equivalent).
// ReScript 12 removed Float.mod; we use raw JS operator directly.
let fmod: (float, float) => float = %raw(`function(a, b) { return a % b; }`)

//  Safe Modulo 
// Float modulo with zero-divisor guard.
let mod = (a: float, b: float): result<float, ProvenError.provenError> => {
  if b == 0.0 {
    Error(ProvenError.divisionByZero(~operation="SafeFloat.mod", ~message="Modulo by zero"))
  } else {
    guard(fmod(a, b), ~operation="SafeFloat.mod")
  }
}
