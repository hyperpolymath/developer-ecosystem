// SPDX-License-Identifier: PMPL-1.0-or-later
// Hitbox  Axis-aligned bounding box collision primitives
// Lightweight rectangle-based collision for stomp, charge, and contact damage checks.

type rect = {
  x: float,
  y: float,
  w: float,
  h: float,
}

// Check if two rectangles overlap
let overlaps = (a: rect, b: rect): bool => {
  a.x < b.x +. b.w && a.x +. a.w > b.x && a.y < b.y +. b.h && a.y +. a.h > b.y
}

// Check if a point is inside a rectangle
let contains = (r: rect, ~pointX: float, ~pointY: float): bool => {
  pointX >= r.x && pointX <= r.x +. r.w && pointY >= r.y && pointY <= r.y +. r.h
}

// Create a rectangle centered on a point
let fromCenter = (~cx: float, ~cy: float, ~w: float, ~h: float): rect => {
  x: cx -. w /. 2.0,
  y: cy -. h /. 2.0,
  w,
  h,
}
