// SPDX-License-Identifier: PMPL-1.0-or-later
// Lab Screen - Research Facility location

// Asset bundles required by this screen
let assetBundles = ["main"]

// Get location data
let locationData = switch LocationData.getLocationById("lab") {
| Some(loc) => loc
| None => {
    // Fallback if location not found
    id: "lab",
    name: "Research Facility",
    description: "Error loading location",
    devicePositions: [],
    environment: "lab",
    worldWidth: 1800.0,
    backgroundColor: 0x1a1a2e,
  }
}

// Create the screen
let make = (): Navigation.appScreen => {
  LocationBase.makeLocationScreen(locationData, ~onExit=() => {
    switch GetEngine.get() {
    | Some(engine) => Navigation.showScreen(engine.navigation, WorldMapScreen.constructor)->ignore
    | None => ()
    }
  })
}

// Screen constructor
let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(assetBundles),
}

// Register this screen in the location registry
let _ = LocationRegistry.register("lab", constructor)
