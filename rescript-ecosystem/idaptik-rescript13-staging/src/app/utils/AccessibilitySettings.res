// SPDX-License-Identifier: PMPL-1.0-or-later
// Accessibility Settings  persisted preferences with cached refs
//
// All settings are cached in module-level refs for zero per-frame cost.
// Values are read from localStorage on init(), with OS preferences as defaults.
// Pattern mirrors UserSettings.res.

//  Color Blind Mode Variants 

type colorBlindMode =
  | Normal
  | Protanopia
  | Deuteranopia
  | Tritanopia
  | Achromatopsia

let colorBlindModeToString = (mode: colorBlindMode): string => {
  switch mode {
  | Normal => "normal"
  | Protanopia => "protanopia"
  | Deuteranopia => "deuteranopia"
  | Tritanopia => "tritanopia"
  | Achromatopsia => "achromatopsia"
  }
}

let colorBlindModeFromString = (s: string): colorBlindMode => {
  switch s {
  | "protanopia" => Protanopia
  | "deuteranopia" => Deuteranopia
  | "tritanopia" => Tritanopia
  | "achromatopsia" => Achromatopsia
  | _ => Normal
  }
}

// Cycle to next color blind mode
let nextColorBlindMode = (mode: colorBlindMode): colorBlindMode => {
  switch mode {
  | Normal => Protanopia
  | Protanopia => Deuteranopia
  | Deuteranopia => Tritanopia
  | Tritanopia => Achromatopsia
  | Achromatopsia => Normal
  }
}

//  LocalStorage Keys 

let keyScreenReader = "a11y-screen-reader"
let keyReducedMotion = "a11y-reduced-motion"
let keyColorBlindMode = "a11y-color-blind-mode"
let keyFontScale = "a11y-font-scale"
let keyHighContrast = "a11y-high-contrast"
let keyKeyboardOnly = "a11y-keyboard-only"
let keyPauseOnFocusLoss = "a11y-pause-on-focus-loss"
let keyGameSpeed = "a11y-game-speed"
let keyCalmMode = "a11y-calm-mode"

//  Cached Refs 

let screenReaderEnabled = ref(false)
let reducedMotionEnabled = ref(false)
let colorBlindModeRef = ref(Normal)
let fontScaleRef = ref(1.0)
let highContrastEnabled = ref(false)
let keyboardOnlyEnabled = ref(false)
let pauseOnFocusLossEnabled = ref(true)
let gameSpeedRef = ref(1.0)
let calmModeEnabled = ref(false)

//  Getters (read from cached refs) 

let isScreenReaderEnabled = (): bool => screenReaderEnabled.contents
let isReducedMotionEnabled = (): bool => reducedMotionEnabled.contents
let getColorBlindMode = (): colorBlindMode => colorBlindModeRef.contents
let getFontScale = (): float => fontScaleRef.contents
let isHighContrastEnabled = (): bool => highContrastEnabled.contents
let isKeyboardOnlyEnabled = (): bool => keyboardOnlyEnabled.contents
let isPauseOnFocusLossEnabled = (): bool => pauseOnFocusLossEnabled.contents
let getGameSpeed = (): float => gameSpeedRef.contents
let isCalmModeEnabled = (): bool => calmModeEnabled.contents

//  Setters (update ref + persist to localStorage) 

let setScreenReader = (enabled: bool): unit => {
  screenReaderEnabled := enabled
  Storage.setBool(keyScreenReader, enabled)
}

let setReducedMotion = (enabled: bool): unit => {
  reducedMotionEnabled := enabled
  Storage.setBool(keyReducedMotion, enabled)
}

let setColorBlindMode = (mode: colorBlindMode): unit => {
  colorBlindModeRef := mode
  Storage.setString(keyColorBlindMode, colorBlindModeToString(mode))
}

let setFontScale = (scale: float): unit => {
  // Clamp to valid range
  let clamped = Math.max(0.75, Math.min(2.0, scale))
  fontScaleRef := clamped
  Storage.setNumber(keyFontScale, clamped)
}

let setHighContrast = (enabled: bool): unit => {
  highContrastEnabled := enabled
  Storage.setBool(keyHighContrast, enabled)
}

let setKeyboardOnly = (enabled: bool): unit => {
  keyboardOnlyEnabled := enabled
  Storage.setBool(keyKeyboardOnly, enabled)
}

let setPauseOnFocusLoss = (enabled: bool): unit => {
  pauseOnFocusLossEnabled := enabled
  Storage.setBool(keyPauseOnFocusLoss, enabled)
}

let setGameSpeed = (speed: float): unit => {
  // Clamp to valid range: 0.25x (very slow) to 1.0x (normal)
  let clamped = Math.max(0.25, Math.min(1.0, speed))
  gameSpeedRef := clamped
  Storage.setNumber(keyGameSpeed, clamped)
}

let setCalmMode = (enabled: bool): unit => {
  calmModeEnabled := enabled
  Storage.setBool(keyCalmMode, enabled)
}

// Cycle color blind mode forward
let cycleColorBlindMode = (): colorBlindMode => {
  let next = nextColorBlindMode(colorBlindModeRef.contents)
  setColorBlindMode(next)
  next
}

//  Initialization 

let init = (): unit => {
  // Read OS preferences as defaults
  let osReducedMotion = DomA11y.prefersReducedMotion()
  let osHighContrast = DomA11y.prefersHighContrast()

  // Load from localStorage, falling back to OS prefs then defaults
  screenReaderEnabled := Storage.getBool(keyScreenReader)->Option.getOr(false)
  reducedMotionEnabled := Storage.getBool(keyReducedMotion)->Option.getOr(osReducedMotion)
  colorBlindModeRef :=
    Storage.getString(keyColorBlindMode)
    ->Option.map(colorBlindModeFromString)
    ->Option.getOr(Normal)
  fontScaleRef := Storage.getNumber(keyFontScale)->Option.getOr(1.0)
  highContrastEnabled := Storage.getBool(keyHighContrast)->Option.getOr(osHighContrast)
  keyboardOnlyEnabled := Storage.getBool(keyKeyboardOnly)->Option.getOr(false)
  pauseOnFocusLossEnabled := Storage.getBool(keyPauseOnFocusLoss)->Option.getOr(true)
  gameSpeedRef := Storage.getNumber(keyGameSpeed)->Option.getOr(1.0)
  calmModeEnabled := Storage.getBool(keyCalmMode)->Option.getOr(false)

  // Listen for OS reduced-motion changes (update if user hasn't overridden)
  DomA11y.onReducedMotionChange(matches => {
    if Storage.getBool(keyReducedMotion)->Option.isNone {
      reducedMotionEnabled := matches
    }
  })

  // Ensure ARIA live regions exist in the DOM
  DomA11y.createLiveRegion("a11y-status", "polite")
  DomA11y.createLiveRegion("a11y-alert", "assertive")
  DomA11y.createLiveRegion("a11y-terminal", "polite")
}
