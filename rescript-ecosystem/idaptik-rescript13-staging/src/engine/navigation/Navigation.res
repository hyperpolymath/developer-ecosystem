// SPDX-License-Identifier: PMPL-1.0-or-later
// Navigation system for ReScript

open Pixi

// Screen interface type
type rec appScreen = {
  container: Container.t,
  mutable prepare: option<unit => unit>,
  mutable show: option<unit => promise<unit>>,
  mutable hide: option<unit => promise<unit>>,
  mutable pause: option<unit => promise<unit>>,
  mutable resume: option<unit => promise<unit>>,
  mutable reset: option<unit => unit>,
  mutable update: option<Ticker.t => unit>,
  mutable resize: option<(float, float) => unit>,
  mutable blur: option<unit => unit>,
  mutable focus: option<unit => unit>,
  mutable onLoad: option<float => unit>,
}

// Screen constructor type
type appScreenConstructor = {
  make: unit => appScreen,
  assetBundles: option<array<string>>,
}

// Navigation state
type t = {
  mutable app: option<Application.t>,
  container: Container.t,
  mutable width: float,
  mutable height: float,
  mutable background: option<appScreen>,
  mutable currentScreen: option<appScreen>,
  mutable currentPopup: option<appScreen>,
}

// Create a new navigation instance
let make = (): t => {
  app: None,
  container: Container.make(),
  width: 0.0,
  height: 0.0,
  background: None,
  currentScreen: None,
  currentPopup: None,
}

// Initialize navigation with app reference
let init = (nav: t, app: Application.t): unit => {
  nav.app = Some(app)
}

// Helper: Add and show a screen
let addAndShowScreen = async (nav: t, screen: appScreen): unit => {
  switch nav.app {
  | None => ()
  | Some(app) =>
    // Add container to stage if needed
    if Container.parent(nav.container)->Nullable.isNullable {
      let _ = Container.addChild(Application.stage(app), nav.container)
    }

    // Add screen to container
    let _ = Container.addChild(nav.container, screen.container)

    // Prepare screen
    switch screen.prepare {
    | Some(fn) => fn()
    | None => ()
    }

    // Resize
    switch screen.resize {
    | Some(fn) => fn(nav.width, nav.height)
    | None => ()
    }

    // Add update function
    switch screen.update {
    | Some(updateFn) =>
      Ticker.add(Application.ticker(app), updateFn, screen)
    | None => ()
    }

    // Show screen
    switch screen.show {
    | Some(showFn) =>
      Container.setInteractiveChildren(screen.container, false)
      await showFn()
      Container.setInteractiveChildren(screen.container, true)
    | None => ()
    }
  }
}

// Helper: Hide and remove a screen
let hideAndRemoveScreen = async (nav: t, screen: appScreen): unit => {
  Container.setInteractiveChildren(screen.container, false)

  switch screen.hide {
  | Some(hideFn) => await hideFn()
  | None => ()
  }

  switch nav.app {
  | Some(app) =>
    switch screen.update {
    | Some(updateFn) => Ticker.remove(Application.ticker(app), updateFn, screen)
    | None => ()
    }
  | None => ()
  }

  if Container.parent(screen.container)->Nullable.isNullable == false {
    let _ = Container.removeChild(nav.container, screen.container)
  }

  switch screen.reset {
  | Some(fn) => fn()
  | None => ()
  }
}

// Set background screen
let setBackground = (nav: t, ctor: appScreenConstructor): unit => {
  let screen = ctor.make()
  nav.background = Some(screen)
  let _ = addAndShowScreen(nav, screen)
}

// Show a new screen
let showScreen = async (nav: t, ctor: appScreenConstructor): unit => {
  // Block interactivity on current screen
  switch nav.currentScreen {
  | Some(screen) => Container.setInteractiveChildren(screen.container, false)
  | None => ()
  }

  // Load assets if needed
  switch ctor.assetBundles {
  | Some(bundles) =>
    await Assets.loadBundle(bundles, progress => {
      switch nav.currentScreen {
      | Some(screen) =>
        switch screen.onLoad {
        | Some(fn) => fn(progress *. 100.0)
        | None => ()
        }
      | None => ()
      }
    })
  | None => ()
  }

  // Report 100% loaded
  switch nav.currentScreen {
  | Some(screen) =>
    switch screen.onLoad {
    | Some(fn) => fn(100.0)
    | None => ()
    }
  | None => ()
  }

  // Hide current screen
  switch nav.currentScreen {
  | Some(screen) => await hideAndRemoveScreen(nav, screen)
  | None => ()
  }

  // Create and show new screen
  let newScreen = ctor.make()
  nav.currentScreen = Some(newScreen)
  await addAndShowScreen(nav, newScreen)
}

// Resize all screens
let resize = (nav: t, width: float, height: float): unit => {
  nav.width = width
  nav.height = height

  switch nav.currentScreen {
  | Some(screen) =>
    switch screen.resize {
    | Some(fn) => fn(width, height)
    | None => ()
    }
  | None => ()
  }

  switch nav.currentPopup {
  | Some(popup) =>
    switch popup.resize {
    | Some(fn) => fn(width, height)
    | None => ()
    }
  | None => ()
  }

  switch nav.background {
  | Some(bg) =>
    switch bg.resize {
    | Some(fn) => fn(width, height)
    | None => ()
    }
  | None => ()
  }
}

// Present a popup
let presentPopup = async (nav: t, ctor: appScreenConstructor): unit => {
  switch nav.currentScreen {
  | Some(screen) =>
    Container.setInteractiveChildren(screen.container, false)
    switch screen.pause {
    | Some(fn) => await fn()
    | None => ()
    }
  | None => ()
  }

  switch nav.currentPopup {
  | Some(popup) => await hideAndRemoveScreen(nav, popup)
  | None => ()
  }

  let newPopup = ctor.make()
  nav.currentPopup = Some(newPopup)
  await addAndShowScreen(nav, newPopup)
}

// Dismiss current popup
let dismissPopup = async (nav: t): unit => {
  switch nav.currentPopup {
  | Some(popup) =>
    nav.currentPopup = None
    await hideAndRemoveScreen(nav, popup)

    switch nav.currentScreen {
    | Some(screen) =>
      Container.setInteractiveChildren(screen.container, true)
      switch screen.resume {
      | Some(fn) => let _ = fn()
      | None => ()
      }
    | None => ()
    }
  | None => ()
  }
}

// Blur all screens (lose focus)
let blur = (nav: t): unit => {
  switch nav.currentScreen {
  | Some(screen) =>
    switch screen.blur {
    | Some(fn) => fn()
    | None => ()
    }
  | None => ()
  }

  switch nav.currentPopup {
  | Some(popup) =>
    switch popup.blur {
    | Some(fn) => fn()
    | None => ()
    }
  | None => ()
  }

  switch nav.background {
  | Some(bg) =>
    switch bg.blur {
    | Some(fn) => fn()
    | None => ()
    }
  | None => ()
  }
}

// Focus all screens
let focus = (nav: t): unit => {
  switch nav.currentScreen {
  | Some(screen) =>
    switch screen.focus {
    | Some(fn) => fn()
    | None => ()
    }
  | None => ()
  }

  switch nav.currentPopup {
  | Some(popup) =>
    switch popup.focus {
    | Some(fn) => fn()
    | None => ()
    }
  | None => ()
  }

  switch nav.background {
  | Some(bg) =>
    switch bg.focus {
    | Some(fn) => fn()
    | None => ()
    }
  | None => ()
  }
}
