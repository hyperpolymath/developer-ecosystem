// SPDX-License-Identifier: PMPL-1.0-or-later
// Rural ISP Screen - Rural ISP location

// Asset bundles required by this screen
let assetBundles = ["main"]

// Get location data
let locationData = switch LocationData.getLocationById("rural-isp") {
| Some(loc) => loc
| None => {
    // Fallback if location not found
    id: "rural-isp",
    name: "Rural ISP",
    description: "Error loading location",
    devicePositions: [],
    environment: "datacenter",
    worldWidth: 2000.0,
    backgroundColor: 0x1a4d2e,
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
let _ = LocationRegistry.register("rural-isp", constructor)
