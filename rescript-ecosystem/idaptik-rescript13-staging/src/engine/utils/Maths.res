// SPDX-License-Identifier: PMPL-1.0-or-later
// Math utilities for ReScript

@val @scope("Math") external sqrt: float => float = "sqrt"

// Get the distance between two points
let getDistance = (~bx=0.0, ~by=0.0, ax: float, ay: float): float => {
  let dx = bx -. ax
  let dy = by -. ay
  sqrt(dx *. dx +. dy *. dy)
}

// Linear interpolation
let lerp = (a: float, b: float, t: float): float => {
  (1.0 -. t) *. a +. t *. b
}

// Clamp a number to minimum and maximum values
let clamp = (~min=0.0, ~max=1.0, v: float): float => {
  let (minVal, maxVal) = if min > max {
    (max, min)
  } else {
    (min, max)
  }

  if v < minVal {
    minVal
  } else if v > maxVal {
    maxVal
  } else {
    v
  }
}
