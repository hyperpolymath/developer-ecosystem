// SPDX-License-Identifier: PMPL-1.0-or-later
// Integrations Settings Popup
//
// Allows users to manage native desktop integrations:
// - Create Desktop Shortcut
// - Create App Menu Shortcut
// - Toggle System Tray (Tauri)

@@warning("-44")
open Pixi
open PixiUI

// Helper: create a simple button for one-off actions
let makeActionButton = (~label: string, ~onPress: unit => unit): FancyButton.t => {
  let textLabel = Label.make(
    ~text=label,
    ~style={fill: 0x4a4a4a, fontSize: 16, align: "center"},
    (),
  )

  let button = FancyButton.make({
    "defaultView": "button.png",
    "nineSliceSprite": [38, 50, 38, 50],
    "anchor": 0.5,
    "text": textLabel,
    "textOffset": {"x": 0, "y": -13},
    "defaultTextAnchor": 0.5,
    "animations": {
      "hover": {"props": {"scale": {"x": 1.03, "y": 1.03}, "y": 0}, "duration": 100},
      "pressed": {"props": {"scale": {"x": 0.97, "y": 0.97}, "y": 5}, "duration": 100},
    },
  })

  FancyButton.setWidth(button, 320.0)
  FancyButton.setHeight(button, 56.0)

  Signal.connect(FancyButton.onPress(button), onPress)

  button
}

// Helper: create a toggle button that shows on/off state
let makeToggle = (~label: string, ~initial: bool, ~onToggle: bool => unit): FancyButton.t => {
  let state = ref(initial)
  let labelText = ref(
    if initial {
      `${label}: ON`
    } else {
      `${label}: OFF`
    },
  )

  let textLabel = Label.make(
    ~text=labelText.contents,
    ~style={fill: 0x4a4a4a, fontSize: 16, align: "center"},
    (),
  )

  let button = FancyButton.make({
    "defaultView": "button.png",
    "nineSliceSprite": [38, 50, 38, 50],
    "anchor": 0.5,
    "text": textLabel,
    "textOffset": {"x": 0, "y": -13},
    "defaultTextAnchor": 0.5,
    "animations": {
      "hover": {"props": {"scale": {"x": 1.03, "y": 1.03}, "y": 0}, "duration": 100},
      "pressed": {"props": {"scale": {"x": 0.97, "y": 0.97}, "y": 5}, "duration": 100},
    },
  })

  FancyButton.setWidth(button, 320.0)
  FancyButton.setHeight(button, 56.0)

  Signal.connect(FancyButton.onPress(button), () => {
    state := !state.contents
    let newLabel = if state.contents {
      `${label}: ON`
    } else {
      `${label}: OFF`
    }
    labelText := newLabel
    Text.setText(textLabel, newLabel)
    onToggle(state.contents)
  })

  button
}

// Create the integrations popup
let make = (): Navigation.appScreen => {
  let container = Container.make()

  // Background
  let bg = Sprite.make({"texture": Texture.white, "anchor": 0.0})
  Sprite.setTint(bg, 0x0)
  Sprite.setEventMode(bg, "static")
  let _ = Container.addChildSprite(container, bg)

  // Panel container
  let panel = Container.make()
  let _ = Container.addChild(container, panel)

  // Panel base
  let panelBase = RoundedBox.make(~options={height: 500.0}, ())
  let _ = Container.addChild(panel, panelBase.container)

  // Title
  let title = Label.make(
    ~text=GameI18n.t("integrations.title"),
    ~style={fill: 0xec1561, fontSize: 40},
    (),
  )
  Text.setY(title, -.panelBase.boxHeight *. 0.5 +. 50.0)
  let _ = Container.addChildText(panel, title)

  // Done button
  let doneButton = Button.make(~options={text: GameI18n.t("ui.ok")}, ())
  FancyButton.setY(doneButton, panelBase.boxHeight *. 0.5 -. 68.0)
  Signal.connect(FancyButton.onPress(doneButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.dismissPopup(engine.navigation)
    | None => ()
    }
  })
  let _ = Container.addChild(panel, FancyButton.toContainer(doneButton))

  // Layout for buttons
  let layout = List.make({"type": "vertical", "elementsMargin": 10})
  List.setX(layout, -160.0)
  List.setY(layout, -120.0)
  let _ = Container.addChild(panel, List.toContainer(layout))

  //  Create Desktop Shortcut 
  let desktopButton = makeActionButton(
    ~label=GameI18n.t("integrations.createDesktop"),
    ~onPress=() => {
      let _ = DesktopIntegration.createDesktopShortcut()->Promise.then(msg => {
        Announcer.status(msg)
        Promise.resolve()
      })
    },
  )
  let _ = List.addChild(layout, FancyButton.toContainer(desktopButton))

  //  Create App Menu Shortcut 
  let menuButton = makeActionButton(
    ~label=GameI18n.t("integrations.createMenu"),
    ~onPress=() => {
      let _ = DesktopIntegration.createMenuShortcut()->Promise.then(msg => {
        Announcer.status(msg)
        Promise.resolve()
      })
    },
  )
  let _ = List.addChild(layout, FancyButton.toContainer(menuButton))

  //  System Tray Toggle 
  let trayToggle = makeToggle(
    ~label=GameI18n.t("integrations.tray"),
    ~initial=UserSettings.isSystemTrayEnabled(),
    ~onToggle=enabled => UserSettings.setSystemTrayEnabled(enabled),
  )
  let _ = List.addChild(layout, FancyButton.toContainer(trayToggle))

  //  Helper Text 
  let trayLabel = Label.make(
    ~text=GameI18n.t("integrations.requires"),
    ~style={fill: 0xffffff, fontSize: 12},
    (),
  )
  Text.setY(trayLabel, 100.0)
  let _ = Container.addChildText(panel, trayLabel)

  {
    container,
    prepare: None,
    show: Some(
      async () => {
        switch GetEngine.get() {
        | Some(engine) =>
          switch engine.navigation.currentScreen {
          | Some(screen) =>
            let blurFilter = BlurFilter.make({"strength": 4})
            Container.setFilters(screen.container, [BlurFilter.toFilter(blurFilter)])
          | None => ()
          }
        | None => ()
        }

        Sprite.setAlpha(bg, 0.0)
        ObservablePoint.setY(Container.pivot(panel), -400.0)
        let _ = Motion.animate(bg, {"alpha": 0.8}, {duration: 0.2, ease: "linear"})
        await Motion.animateAsync(
          Container.pivot(panel),
          {"y": 0.0},
          {duration: 0.3, ease: "backOut"},
        )
      },
    ),
    hide: Some(
      async () => {
        switch GetEngine.get() {
        | Some(engine) =>
          switch engine.navigation.currentScreen {
          | Some(screen) => Container.setFilters(screen.container, [])
          | None => ()
          }
        | None => ()
        }

        let _ = Motion.animate(bg, {"alpha": 0.0}, {duration: 0.2, ease: "linear"})
        await Motion.animateAsync(
          Container.pivot(panel),
          {"y": -500.0},
          {duration: 0.3, ease: "backIn"},
        )
      },
    ),
    pause: None,
    resume: None,
    reset: None,
    update: None,
    resize: Some(
      (width, height) => {
        Sprite.setWidth(bg, width)
        Sprite.setHeight(bg, height)
        Container.setX(panel, width *. 0.5)
        Container.setY(panel, height *. 0.5)
      },
    ),
    blur: None,
    focus: None,
    onLoad: None,
  }
}

// Screen constructor
let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: None,
}
