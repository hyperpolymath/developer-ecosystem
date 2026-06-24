// SPDX-License-Identifier: MPL-2.0
// Location Base - Creates location screens using WorldBuilder
// Simply delegates to WorldBuilder.buildLocationScreen

// Create a location screen from location data and an exit handler
// The onExit parameter is currently unused since WorldBuilder handles ESC itself
// but kept for potential future use
@warning("-27")
let makeLocationScreen = (location: LocationData.location, ~onExit: unit => unit): Navigation.appScreen => {
  // Use WorldBuilder to create a full platformer scene for this location
  WorldBuilder.buildLocationScreen(location)
}
