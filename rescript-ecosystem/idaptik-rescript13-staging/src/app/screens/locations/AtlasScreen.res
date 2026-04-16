// SPDX-License-Identifier: PMPL-1.0-or-later
// Atlas Screen - Atlas Data Center location

// Asset bundles required by this screen
let assetBundles = ["main"]

// Get location data
let locationData = switch LocationData.getLocationById("atlas") {
| Some(loc) => loc
| None => {
    id: "atlas",
    name: "Atlas Data Center",
    description: "Error loading location",
    devicePositions: [],
    environment: "datacenter",
    worldWidth: 3000.0,
    backgroundColor: 0x4285F4,
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
let _ = LocationRegistry.register("atlas", constructor)
