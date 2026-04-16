// SPDX-License-Identifier: PMPL-1.0-or-later
// DevHub Screen - DevHub Repository location

// Asset bundles required by this screen
let assetBundles = ["main"]

// Get location data
let locationData = switch LocationData.getLocationById("devhub") {
| Some(loc) => loc
| None => {
    id: "devhub",
    name: "DevHub Repository",
    description: "Error loading location",
    devicePositions: [],
    environment: "datacenter",
    worldWidth: 3000.0,
    backgroundColor: 0x24292e,
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
let _ = LocationRegistry.register("devhub", constructor)
