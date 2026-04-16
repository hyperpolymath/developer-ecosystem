// SPDX-License-Identifier: PMPL-1.0-or-later
// Trajectory Preview - Visual arc showing predicted jump path
// Draws animated dots along the parabolic trajectory

open Pixi

// Trajectory styling constants
module Style = {
  let maxTime = 2.0 // Max seconds of trajectory to show
  let pointSpacing = 0.05 // Time increment between points (seconds)
  let minPointRadius = 2.0 // Minimum dot radius
  let maxPointRadius = 3.0 // Maximum dot radius
  let pointFlickerSpeed = 0.15 // Animation speed for dot size oscillation
  let pointColor = 0x00ffaa // Cyan-green trajectory dots
  let pointAlpha = 0.8 // Dot transparency
}

// Container for trajectory points
type t = {
  container: Container.t,
  mutable points: array<Graphics.t>,
  mutable timeAlive: float, // For flicker animation
}

let make = (): t => {
  container: Container.make(),
  points: [],
  timeAlive: 0.0,
}

// Clear all trajectory points
let clear = (traj: t): unit => {
  Array.forEach(traj.points, point => {
    Graphics.destroy(point)
  })
  traj.points = []
}

// Calculate position at time t along trajectory
// Uses standard projectile motion equations:
// x(t) = x0 + vx * t
// y(t) = y0 + vy * t + 0.5 * g * t^2
let positionAtTime = (
  ~startX: float,
  ~startY: float,
  ~velX: float,
  ~velY: float,
  ~gravity: float,
  ~t: float,
): (float, float) => {
  let x = startX +. velX *. t
  let y = startY +. velY *. t +. 0.5 *. gravity *. t *. t
  (x, y)
}

// Draw trajectory preview
// Call this each frame while charging jump
let draw = (
  traj: t,
  ~playerX: float,
  ~playerY: float,
  ~velX: float,
  ~velY: float,
  ~magnitude: float,
  ~gravity: float,
  ~groundY: float,
  ~attributes as _: PlayerAttributes.t,
): unit => {
  // Clear previous trajectory
  clear(traj)

  // Don't draw if no/minimal jump charged
  if magnitude < 10.0 {
    ()
  } else {
    // Draw points along trajectory at fixed time intervals
    let t = ref(Style.pointSpacing) // Start slightly ahead of player
    let pointIndex = ref(0)
    let maxPoints = 40 // Limit number of points

    while t.contents < Style.maxTime && pointIndex.contents < maxPoints {
      let (px, py) = positionAtTime(
        ~startX=playerX,
        ~startY=playerY,
        ~velX,
        ~velY,
        ~gravity,
        ~t=t.contents,
      )

      // Stop if we hit the ground
      if py >= groundY {
        t := Style.maxTime // Exit loop
      } else {
        // Create point with flickering size
        let flickerPhase =
          traj.timeAlive *. Style.pointFlickerSpeed +. Int.toFloat(pointIndex.contents)
        let sizeOscillation = Math.sin(flickerPhase)
        let radius =
          Style.minPointRadius +.
          (Style.maxPointRadius -. Style.minPointRadius) *. (0.5 +. 0.5 *. sizeOscillation)

        // Fade out points further along trajectory
        let fadeRatio = 1.0 -. t.contents /. Style.maxTime
        let alpha = Style.pointAlpha *. fadeRatio

        let point = Graphics.make()
        let _ =
          point
          ->Graphics.circle(px, py, radius)
          ->Graphics.fill({"color": Style.pointColor, "alpha": alpha})

        let _ = Container.addChildGraphics(traj.container, point)
        traj.points = Array.concat(traj.points, [point])

        pointIndex := pointIndex.contents + 1
        t := t.contents +. Style.pointSpacing
      }
    }
  }
}

// Update animation timer
let update = (traj: t, ~deltaTime: float): unit => {
  traj.timeAlive = traj.timeAlive +. deltaTime
}

// Get container for adding to scene
let getContainer = (traj: t): Container.t => {
  traj.container
}
