// SPDX-License-Identifier: MPL-2.0
// Font Scale Helper
//
// Multiplies pixel font sizes by the user's font scale preference.
// The scale is cached in AccessibilitySettings  zero per-frame cost.

// Scale a font size in pixels by the user's font scale preference
let size = (px: float): float => {
  px *. AccessibilitySettings.getFontScale()
}

// Scale an integer font size (returns float for PixiJS TextStyle)
let sizeInt = (px: int): float => {
  Int.toFloat(px) *. AccessibilitySettings.getFontScale()
}
