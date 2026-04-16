// SPDX-License-Identifier: PMPL-1.0-or-later
// Color Palette  color blind mode support
//
// Provides 5 named palettes (Normal + 4 color blind variants).
// All color lookups go through cached functions that read from a ref.
// Only recalculated when the user changes color blind mode.
//
// Note: alertColor takes an int (0-5) to avoid a dependency cycle with HUD.res.

open AccessibilitySettings

//  Alert Level Colors 

// Accepts alert level as int: 0=Clear, 1=Noticed, 2=Caution, 3=Alert, 4=Danger, 5=Lockdown
// Normal palette: green  yellow  orange  red
// Color blind palettes use distinguishable alternatives
let alertColor = (levelInt: int): int => {
  // High contrast: maximum brightness, pure white/yellow/red
  if isHighContrastEnabled() {
    switch levelInt {
    | 0 => 0x00ff00
    | 1 => 0xffff00
    | 2 => 0xffaa00
    | 3 => 0xff4400
    | 4 => 0xff0000
    | _ => 0xff0000
    }
  } else {
    let mode = getColorBlindMode()
    switch mode {
    | Normal =>
      switch levelInt {
      | 0 => 0x00ff00
      | 1 => 0x88ff00
      | 2 => 0xffff00
      | 3 => 0xff8800
      | 4 => 0xff4400
      | _ => 0xff0000
      }
    | Protanopia | Deuteranopia =>
      // Blue  orange spectrum (avoids red-green confusion)
      switch levelInt {
      | 0 => 0x0088ff
      | 1 => 0x44aaff
      | 2 => 0xffdd44
      | 3 => 0xffaa00
      | 4 => 0xff8800
      | _ => 0xff6600
      }
    | Tritanopia =>
      // Magenta  bright-green spectrum (avoids blue-yellow confusion)
      switch levelInt {
      | 0 => 0x00ee88
      | 1 => 0x66dd66
      | 2 => 0xdddd00
      | 3 => 0xee6688
      | 4 => 0xdd2266
      | _ => 0xcc0044
      }
    | Achromatopsia =>
      // Brightness-only (grayscale-safe)
      switch levelInt {
      | 0 => 0xffffff
      | 1 => 0xcccccc
      | 2 => 0x999999
      | 3 => 0x777777
      | 4 => 0x444444
      | _ => 0x222222
      }
    }
  }
}

//  Device Type Colors 

let deviceColor = (deviceType: DeviceTypes.deviceType): int => {
  // High contrast: bright, saturated colors on dark backgrounds
  if isHighContrastEnabled() {
    switch deviceType {
    | Laptop => 0x00ccff
    | Router => 0xff8800
    | Server => 0xaa44ff
    | IotCamera => 0xff0044
    | Terminal => 0x00ff44
    | PowerStation => 0xffff00
    | UPS => 0xffaa44
    | Firewall => 0xff2200
    }
  } else {
    let mode = getColorBlindMode()
    switch mode {
    | Normal => DeviceTypes.getDeviceColor(deviceType)
    | Protanopia | Deuteranopia =>
      switch deviceType {
      | Laptop => 0x4488ff // Blue (unchanged  safe)
      | Router => 0xff9900 // Orange (shifted slightly)
      | Server => 0xaa44dd // Purple (safe)
      | IotCamera => 0xff6644 // Orange-red (shifted from pure red)
      | Terminal => 0x0088ff // Blue (was green, problematic)
      | PowerStation => 0xffdd44 // Yellow (safe)
      | UPS => 0x886644 // Brown (safe)
      | Firewall => 0xcc4400 // Dark orange-red (distinct from router)
      }
    | Tritanopia =>
      switch deviceType {
      | Laptop => 0x4488ff
      | Router => 0xff6644
      | Server => 0xcc44cc
      | IotCamera => 0xff4444
      | Terminal => 0x44dd44
      | PowerStation => 0xff9944
      | UPS => 0x886644
      | Firewall => 0xdd2222
      }
    | Achromatopsia =>
      // Use distinct brightness levels + patterns
      switch deviceType {
      | Laptop => 0x6688bb
      | Router => 0xbbaa66
      | Server => 0x8866aa
      | IotCamera => 0xaa6666
      | Terminal => 0x66aa88
      | PowerStation => 0xbbbb66
      | UPS => 0x887766
      | Firewall => 0x995555
      }
    }
  }
}

//  Security Level Colors 

let securityColor = (level: DeviceType.securityLevel): int => {
  // High contrast: bold, distinct levels
  if isHighContrastEnabled() {
    switch level {
    | Open => 0x00ff00
    | Weak => 0xffff00
    | Medium => 0xff8800
    | Strong => 0xff0000
    }
  } else {
    let mode = getColorBlindMode()
    switch mode {
    | Normal => DeviceTypes.getSecurityColor((level :> DeviceTypes.securityLevel))
    | Protanopia | Deuteranopia =>
      switch level {
      | Open => 0x0088ff // Blue (was green)
      | Weak => 0xffdd44 // Yellow (safe)
      | Medium => 0xff9900 // Orange (safe)
      | Strong => 0xff6600 // Dark orange (was red)
      }
    | Tritanopia =>
      switch level {
      | Open => 0x00ee88
      | Weak => 0xeeee00
      | Medium => 0xee6688
      | Strong => 0xcc0044
      }
    | Achromatopsia =>
      switch level {
      | Open => 0xdddddd
      | Weak => 0xaaaaaa
      | Medium => 0x666666
      | Strong => 0x333333
      }
    }
  }
}
