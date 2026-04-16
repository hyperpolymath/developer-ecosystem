// SPDX-License-Identifier: PMPL-1.0-or-later
// Resize calculation logic for ReScript

@val @scope("window") external innerWidth: int = "innerWidth"
@val @scope("window") external innerHeight: int = "innerHeight"
@val @scope("Math") external min: (float, float) => float = "min"
@val @scope("Math") external floor: float => int = "floor"

type resizeResult = {
  width: int,
  height: int,
}

let resize = (
  ~w: float,
  ~h: float,
  ~minWidth: float,
  ~minHeight: float,
  ~letterbox: bool,
): resizeResult => {
  let aspectRatio = minWidth /. minHeight
  let canvasWidth = ref(w)
  let canvasHeight = ref(h)

  if letterbox {
    if minWidth < minHeight {
      canvasHeight := Int.toFloat(innerHeight)
      canvasWidth := min(
        min(Int.toFloat(innerWidth), minWidth),
        canvasHeight.contents *. aspectRatio,
      )
    } else {
      canvasWidth := Int.toFloat(innerWidth)
      canvasHeight := min(
        min(Int.toFloat(innerHeight), minHeight),
        canvasWidth.contents /. aspectRatio,
      )
    }
  }

  let scaleX = if canvasWidth.contents < minWidth {
    minWidth /. canvasWidth.contents
  } else {
    1.0
  }
  let scaleY = if canvasHeight.contents < minHeight {
    minHeight /. canvasHeight.contents
  } else {
    1.0
  }
  let scale = if scaleX > scaleY { scaleX } else { scaleY }

  {
    width: floor(canvasWidth.contents *. scale),
    height: floor(canvasHeight.contents *. scale),
  }
}
