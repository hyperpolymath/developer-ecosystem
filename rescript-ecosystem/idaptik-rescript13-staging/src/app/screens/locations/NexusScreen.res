// SPDX-License-Identifier: PMPL-1.0-or-later
// Nexus Screen - Nexus CDN location

// Asset bundles required by this screen
let assetBundles = ["main"]

// Get location data
let locationData = switch LocationData.getLocationById("nexus") {
| Some(loc) => loc
| None => {
    id: "nexus",
    name: "Nexus CDN",
    description: "Error loading location",
    devicePositions: [],
    environment: "datacenter",
    worldWidth: 3000.0,
    backgroundColor: 0xF38020,
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
let _ = LocationRegistry.register("nexus", constructor)
