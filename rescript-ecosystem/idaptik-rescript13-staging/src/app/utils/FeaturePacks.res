// SPDX-License-Identifier: PMPL-1.0-or-later
// Feature Packs  optional gameplay expansions toggled from Settings
//
// Each feature pack has a localStorage key and a cached ref.
// OFF by default. The single source of truth for all feature toggles.
// Pattern mirrors AccessibilitySettings.res.

//  LocalStorage Keys 

let keyInvertibleProgramming = "feature-invertible-programming"
let keyMoletaire = "feature-moletaire"

//  Cached Refs 

let invertibleProgrammingEnabled = ref(true)
let moletaireEnabled = ref(true)

//  Getters (read from cached refs) 

let isInvertibleProgrammingEnabled = (): bool => true
let isMoletaireEnabled = (): bool => true

//  Setters (update ref + persist to localStorage) 

let setInvertibleProgramming = (enabled: bool): unit => {
  invertibleProgrammingEnabled := enabled
  Storage.setBool(keyInvertibleProgramming, enabled)
}

let setMoletaire = (enabled: bool): unit => {
  moletaireEnabled := enabled
  Storage.setBool(keyMoletaire, enabled)
}

//  Initialization 

let init = (): unit => {
  invertibleProgrammingEnabled := Storage.getBool(keyInvertibleProgramming)->Option.getOr(true)
  moletaireEnabled := Storage.getBool(keyMoletaire)->Option.getOr(true)
}
