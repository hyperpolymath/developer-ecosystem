// SPDX-License-Identifier: PMPL-1.0-or-later
// Backbone Screen - Internet Backbone location

// Asset bundles required by this screen
let assetBundles = ["main"]

// Get location data
let locationData = switch LocationData.getLocationById("backbone") {
| Some(loc) => loc
| None => {
    // Fallback if location not found
    id: "backbone",
    name: "Internet Backbone",
    description: "Error loading location",
    devicePositions: [],
    environment: "datacenter",
    worldWidth: 2000.0,
    backgroundColor: 0x2e1a1a,
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
let _ = LocationRegistry.register("backbone", constructor)
