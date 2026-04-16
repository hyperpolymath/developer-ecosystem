// SPDX-License-Identifier: PMPL-1.0-or-later
// Accessibility Settings Popup
//
// Toggle buttons for each accessibility feature:
// - Screen reader announcements
// - Reduced motion
// - Color blind mode (cycle through 5 modes)
// - Font scale (slider 75% to 200%)
// - Keyboard-only mode
// - Pause on focus loss
//
// Pattern follows SettingsPopup.res exactly.

@@warning("-44")
open Pixi
open PixiUI

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

  FancyButton.setWidth(button, 280.0)
  FancyButton.setHeight(button, 56.0)

  // Accessibility for the toggle itself
  let buttonContainer = FancyButton.toContainer(button)
  Container.setAccessible(buttonContainer, true)
  Container.setAccessibleType(buttonContainer, "button")
  Container.setAccessibleTitle(buttonContainer, labelText.contents)

  Signal.connect(FancyButton.onPress(button), () => {
    state := !state.contents
    let newLabel = if state.contents {
      `${label}: ON`
    } else {
      `${label}: OFF`
    }
    labelText := newLabel
    Text.setText(textLabel, newLabel)
    Container.setAccessibleTitle(buttonContainer, newLabel)
    onToggle(state.contents)
  })

  button
}

// Helper: create a cycle button (for color blind mode)
let makeCycleButton = (~getLabel: unit => string, ~onCycle: unit => unit): FancyButton.t => {
  let textLabel = Label.make(
    ~text=getLabel(),
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

  FancyButton.setWidth(button, 280.0)
  FancyButton.setHeight(button, 56.0)

  let buttonContainer = FancyButton.toContainer(button)
  Container.setAccessible(buttonContainer, true)
  Container.setAccessibleType(buttonContainer, "button")
  Container.setAccessibleTitle(buttonContainer, getLabel())

  Signal.connect(FancyButton.onPress(button), () => {
    onCycle()
    let newLabel = getLabel()
    Text.setText(textLabel, newLabel)
    Container.setAccessibleTitle(buttonContainer, newLabel)
  })

  button
}

// Create the accessibility popup
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

  // Panel base (taller to accommodate all settings including game speed + calm mode)
  let panelBase = RoundedBox.make(~options={height: 800.0}, ())
  let _ = Container.addChild(panel, panelBase.container)

  // Title
  let title = Label.make(~text=GameI18n.t("a11y.title"), ~style={fill: 0xec1561, fontSize: 40}, ())
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

  // Layout for settings
  let layout = List.make({"type": "vertical", "elementsMargin": 6})
  List.setX(layout, -140.0)
  List.setY(layout, -180.0)
  let _ = Container.addChild(panel, List.toContainer(layout))

  //  Screen Reader 
  let screenReaderToggle = makeToggle(
    ~label=GameI18n.t("a11y.screenReader"),
    ~initial=AccessibilitySettings.isScreenReaderEnabled(),
    ~onToggle=enabled => AccessibilitySettings.setScreenReader(enabled),
  )
  let _ = List.addChild(layout, FancyButton.toContainer(screenReaderToggle))

  //  Reduced Motion 
  let reducedMotionToggle = makeToggle(
    ~label=GameI18n.t("a11y.reducedMotion"),
    ~initial=AccessibilitySettings.isReducedMotionEnabled(),
    ~onToggle=enabled => AccessibilitySettings.setReducedMotion(enabled),
  )
  let _ = List.addChild(layout, FancyButton.toContainer(reducedMotionToggle))

  //  Keyboard Only 
  let keyboardOnlyToggle = makeToggle(
    ~label=GameI18n.t("a11y.keyboardOnly"),
    ~initial=AccessibilitySettings.isKeyboardOnlyEnabled(),
    ~onToggle=enabled => AccessibilitySettings.setKeyboardOnly(enabled),
  )
  let _ = List.addChild(layout, FancyButton.toContainer(keyboardOnlyToggle))

  //  Pause on Focus Loss 
  let pauseFocusToggle = makeToggle(
    ~label=GameI18n.t("a11y.pauseOnTabAway"),
    ~initial=AccessibilitySettings.isPauseOnFocusLossEnabled(),
    ~onToggle=enabled => AccessibilitySettings.setPauseOnFocusLoss(enabled),
  )
  let _ = List.addChild(layout, FancyButton.toContainer(pauseFocusToggle))

  //  High Contrast 
  let highContrastToggle = makeToggle(
    ~label=GameI18n.t("a11y.highContrast"),
    ~initial=AccessibilitySettings.isHighContrastEnabled(),
    ~onToggle=enabled => AccessibilitySettings.setHighContrast(enabled),
  )
  let _ = List.addChild(layout, FancyButton.toContainer(highContrastToggle))

  //  Color Blind Mode 
  let colorBlindButton = makeCycleButton(
    ~getLabel=() => {
      let modeName = AccessibilitySettings.colorBlindModeToString(
        AccessibilitySettings.getColorBlindMode(),
      )
      `${GameI18n.t("a11y.colorBlind")}: ${modeName}`
    },
    ~onCycle=() => {
      let _ = AccessibilitySettings.cycleColorBlindMode()
    },
  )
  let _ = List.addChild(layout, FancyButton.toContainer(colorBlindButton))

  //  Game Speed 
  let gameSpeedSlider = VolumeSlider.make(
    ~label=GameI18n.t("a11y.gameSpeed"),
    ~min=25.0,
    ~max=100.0,
    ~value=AccessibilitySettings.getGameSpeed() *. 100.0,
    (),
  )
  Signal.connect(Slider.onUpdate(gameSpeedSlider.slider), v => {
    AccessibilitySettings.setGameSpeed(v /. 100.0)
  })
  let _ = List.addChild(layout, Slider.toContainer(gameSpeedSlider.slider))

  //  Calm Mode 
  let calmModeToggle = makeToggle(
    ~label=GameI18n.t("a11y.calmMode"),
    ~initial=AccessibilitySettings.isCalmModeEnabled(),
    ~onToggle=enabled => AccessibilitySettings.setCalmMode(enabled),
  )
  let _ = List.addChild(layout, FancyButton.toContainer(calmModeToggle))

  //  Font Scale 
  let fontScaleSlider = VolumeSlider.make(
    ~label=GameI18n.t("a11y.fontScale"),
    ~min=75.0,
    ~max=200.0,
    ~value=AccessibilitySettings.getFontScale() *. 100.0,
    (),
  )
  Signal.connect(Slider.onUpdate(fontScaleSlider.slider), v => {
    AccessibilitySettings.setFontScale(v /. 100.0)
  })
  let _ = List.addChild(layout, Slider.toContainer(fontScaleSlider.slider))

  {
    container,
    prepare: Some(
      () => {
        // Refresh toggle states when popup opens (in case settings changed externally)
        Announcer.status("Accessibility settings")
      },
    ),
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
