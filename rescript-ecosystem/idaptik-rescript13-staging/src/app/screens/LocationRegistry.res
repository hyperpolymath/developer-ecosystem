// SPDX-License-Identifier: PMPL-1.0-or-later
// Location Registry - Breaks circular dependencies by using a registry pattern

type locationScreenConstructor = Navigation.appScreenConstructor

let registry: dict<locationScreenConstructor> = Dict.make()

// Register a location screen
let register = (locationId: string, constructor: locationScreenConstructor): unit => {
  Dict.set(registry, locationId, constructor)
}

// Get a location screen constructor
let get = (locationId: string): option<locationScreenConstructor> => {
  Dict.get(registry, locationId)
}

// Navigate to a location
let navigateTo = (locationId: string): unit => {
  switch GetEngine.get() {
  | Some(engine) =>
    switch get(locationId) {
    | Some(constructor) =>
      let _ =
        Navigation.showScreen(engine.navigation, constructor)->Promise.catch(
          PanicHandler.handleException,
        )
    | None => Console.error(`[LocationRegistry] Location "${locationId}" not found`)
    }
  | None => Console.error("[LocationRegistry] Engine not initialised")
  }
}
