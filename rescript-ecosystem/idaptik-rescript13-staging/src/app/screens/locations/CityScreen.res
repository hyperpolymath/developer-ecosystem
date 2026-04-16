// SPDX-License-Identifier: PMPL-1.0-or-later
// City Screen - Downtown Office location

// Asset bundles required by this screen
let assetBundles = ["main"]

// Get location data
let locationData = switch LocationData.getLocationById("city") {
| Some(loc) => loc
| None => {
    // Fallback if location not found
    id: "city",
    name: "Downtown Office",
    description: "Error loading location",
    devicePositions: [],
    environment: "city",
    worldWidth: 1800.0,
    backgroundColor: 0x4A4A4A,
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
let _ = LocationRegistry.register("city", constructor)
