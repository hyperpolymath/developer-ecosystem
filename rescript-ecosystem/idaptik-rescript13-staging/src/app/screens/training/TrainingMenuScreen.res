// SPDX-License-Identifier: PMPL-1.0-or-later
// TrainingMenuScreen  Hub listing all training scenarios
//
// Accessible from WorldMapScreen. Lists Guard, Dog, and Full Combat
// training scenarios with descriptions.

open Pixi
open PixiUI

let assetBundles = ["main"]

let buttonAnimations = {
  "hover": {"props": {"scale": {"x": 1.1, "y": 1.1}}, "duration": 100},
  "pressed": {"props": {"scale": {"x": 0.9, "y": 0.9}}, "duration": 100},
}

// Menu entry definition
type menuEntry = {
  title: string,
  description: string,
  getConstructor: unit => Navigation.appScreenConstructor,
}

// Build entries as a function so language changes take effect.
// Moletaire entry only appears when the feature pack is enabled.
let getEntries = (): array<menuEntry> => {
  let baseEntries = [
    {
      title: GameI18n.t("training.guard.title"),
      description: GameI18n.t("training.guard.desc"),
      getConstructor: () => GuardTraining.constructor,
    },
    {
      title: GameI18n.t("training.dog.title"),
      description: GameI18n.t("training.dog.desc"),
      getConstructor: () => DogTraining.constructor,
    },
    {
      title: GameI18n.t("training.combat.title"),
      description: GameI18n.t("training.combat.desc"),
      getConstructor: () => CombatTraining.constructor,
    },
    {
      title: GameI18n.t("training.scavenger.title"),
      description: GameI18n.t("training.scavenger.desc"),
      getConstructor: () => ScavengerTraining.constructor,
    },
    {
      title: GameI18n.t("training.assassin.title"),
      description: GameI18n.t("training.assassin.desc"),
      getConstructor: () => AssassinTraining.constructor,
    },
    {
      title: GameI18n.t("training.drone.title"),
      description: GameI18n.t("training.drone.desc"),
      getConstructor: () => DroneTraining.constructor,
    },
    {
      title: GameI18n.t("training.droneground.title"),
      description: GameI18n.t("training.droneground.desc"),
      getConstructor: () => DroneTrainingGround.constructor,
    },
  ]

  // Conditionally add Moletaire training screens when feature pack is enabled.
  // Both the main Moletaire training and the Highway Crossing minigame require
  // Moletaire to be unlocked. Highway Crossing is a "second column" interlude.
  if FeaturePacks.isMoletaireEnabled() {
    Array.concat(
      baseEntries,
      [
        {
          title: GameI18n.t("training.moletaire.title"),
          description: GameI18n.t("training.moletaire.desc"),
          getConstructor: () => MoletaireTraining.constructor,
        },
        {
          title: GameI18n.t("training.highway.title"),
          description: GameI18n.t("training.highway.desc"),
          getConstructor: () => HighwayCrossingTraining.constructor,
        },
      ],
    )
  } else {
    baseEntries
  }
}

let make = (): Navigation.appScreen => {
  let container = Container.make()
  let entries = getEntries()

  // Full-screen background  prevents previous screen from bleeding through.
  // eventMode="static" blocks pointer events from reaching screens behind.
  let menuBg = Graphics.make()
  Graphics.setEventMode(menuBg, "static")
  Container.setEventMode(container, "static")
  Container.setInteractiveChildren(container, true)
  let _ = Container.addChildGraphics(container, menuBg)

  // Title
  let titleText = Text.make({
    "text": GameI18n.t("training.title"),
    "style": {
      "fontFamily": "Arial",
      "fontSize": 48,
      "fill": 0x00ff88,
      "fontWeight": "bold",
    },
  })
  ObservablePoint.set(Text.anchor(titleText), 0.5, ~y=0.5)
  let _ = Container.addChildText(container, titleText)

  // Subtitle
  let subtitleText = Text.make({
    "text": GameI18n.t("training.subtitle"),
    "style": {
      "fontFamily": "Arial",
      "fontSize": 18,
      "fill": 0x888888,
      "fontStyle": "italic",
    },
  })
  ObservablePoint.set(Text.anchor(subtitleText), 0.5, ~y=0.5)
  let _ = Container.addChildText(container, subtitleText)

  // Create entry buttons
  let entryButtons = Array.mapWithIndex(entries, (entry, index) => {
    let buttonContainer = Container.make()
    Container.setEventMode(buttonContainer, "static")
    Container.setCursor(buttonContainer, "pointer")

    // Background
    let bg = Graphics.make()
    let _ =
      bg
      ->Graphics.roundRect(-200.0, -50.0, 400.0, 100.0, 10.0)
      ->Graphics.fill({"color": 0x1a2a1a})
      ->Graphics.stroke({"width": 2, "color": 0x335533})
    let _ = Container.addChildGraphics(buttonContainer, bg)

    // Title
    let nameText = Text.make({
      "text": entry.title,
      "style": {
        "fontFamily": "Arial",
        "fontSize": 26,
        "fill": 0xffffff,
        "fontWeight": "bold",
      },
    })
    ObservablePoint.set(Text.anchor(nameText), 0.5, ~y=0.5)
    Text.setY(nameText, -15.0)
    let _ = Container.addChildText(buttonContainer, nameText)

    // Description
    let descText = Text.make({
      "text": entry.description,
      "style": {
        "fontFamily": "Arial",
        "fontSize": 14,
        "fill": 0xaaaaaa,
        "wordWrap": true,
        "wordWrapWidth": 360,
      },
    })
    ObservablePoint.set(Text.anchor(descText), 0.5, ~y=0.5)
    Text.setY(descText, 15.0)
    let _ = Container.addChildText(buttonContainer, descText)

    // Hover effect
    Container.on(buttonContainer, "pointerover", _ => {
      Graphics.clear(bg)->ignore
      let _ =
        bg
        ->Graphics.roundRect(-200.0, -50.0, 400.0, 100.0, 10.0)
        ->Graphics.fill({"color": 0x2a3a2a})
        ->Graphics.stroke({"width": 2, "color": 0x00ff88})
    })
    Container.on(buttonContainer, "pointerout", _ => {
      Graphics.clear(bg)->ignore
      let _ =
        bg
        ->Graphics.roundRect(-200.0, -50.0, 400.0, 100.0, 10.0)
        ->Graphics.fill({"color": 0x1a2a1a})
        ->Graphics.stroke({"width": 2, "color": 0x335533})
    })

    // Click to enter training scenario
    Container.on(buttonContainer, "pointertap", _ => {
      switch GetEngine.get() {
      | Some(engine) => Navigation.showScreen(engine.navigation, entry.getConstructor())->ignore
      | None => ()
      }
    })

    // Accessibility
    Container.setAccessible(buttonContainer, true)
    Container.setAccessibleTitle(buttonContainer, `${entry.title}: ${entry.description}`)
    Container.setAccessibleType(buttonContainer, "button")
    Container.setTabIndex(buttonContainer, index + 1)

    let _ = Container.addChild(container, buttonContainer)
    buttonContainer
  })

  // Back to Map button
  let backContainer = Container.make()
  Container.setEventMode(backContainer, "static")
  Container.setCursor(backContainer, "pointer")

  let backBg = Graphics.make()
  let _ =
    backBg
    ->Graphics.roundRect(-100.0, -25.0, 200.0, 50.0, 8.0)
    ->Graphics.fill({"color": 0x333333})
    ->Graphics.stroke({"width": 2, "color": 0x555555})
  let _ = Container.addChildGraphics(backContainer, backBg)

  let backText = Text.make({
    "text": GameI18n.t("training.exitToMenu"),
    "style": {
      "fontFamily": "Arial",
      "fontSize": 18,
      "fill": 0xcccccc,
    },
  })
  ObservablePoint.set(Text.anchor(backText), 0.5, ~y=0.5)
  let _ = Container.addChildText(backContainer, backText)

  Container.on(backContainer, "pointerover", _ => {
    Graphics.clear(backBg)->ignore
    let _ =
      backBg
      ->Graphics.roundRect(-100.0, -25.0, 200.0, 50.0, 8.0)
      ->Graphics.fill({"color": 0x444444})
      ->Graphics.stroke({"width": 2, "color": 0xaaaaaa})
  })
  Container.on(backContainer, "pointerout", _ => {
    Graphics.clear(backBg)->ignore
    let _ =
      backBg
      ->Graphics.roundRect(-100.0, -25.0, 200.0, 50.0, 8.0)
      ->Graphics.fill({"color": 0x333333})
      ->Graphics.stroke({"width": 2, "color": 0x555555})
  })
  Container.on(backContainer, "pointertap", _ => {
    switch GetEngine.get() {
    | Some(engine) => Navigation.showScreen(engine.navigation, WorldMapScreen.constructor)->ignore
    | None => ()
    }
  })

  Container.setAccessible(backContainer, true)
  Container.setAccessibleTitle(backContainer, GameI18n.t("training.exitToMenu"))
  Container.setAccessibleType(backContainer, "button")
  Container.setTabIndex(backContainer, Array.length(entries) + 1)

  let _ = Container.addChild(container, backContainer)

  //  Quit to Desktop button 
  // Closes the browser tab/window. In Tauri, uses the Tauri close API.
  let quitDesktopContainer = Container.make()
  Container.setEventMode(quitDesktopContainer, "static")
  Container.setCursor(quitDesktopContainer, "pointer")

  let quitDesktopBg = Graphics.make()
  let _ =
    quitDesktopBg
    ->Graphics.roundRect(-100.0, -25.0, 200.0, 50.0, 8.0)
    ->Graphics.fill({"color": 0x442222})
    ->Graphics.stroke({"width": 2, "color": 0x664444})
  let _ = Container.addChildGraphics(quitDesktopContainer, quitDesktopBg)

  let quitDesktopText = Text.make({
    "text": "Quit to Desktop",
    "style": {
      "fontFamily": "Arial",
      "fontSize": 16,
      "fill": 0xff8888,
    },
  })
  ObservablePoint.set(Text.anchor(quitDesktopText), 0.5, ~y=0.5)
  let _ = Container.addChildText(quitDesktopContainer, quitDesktopText)

  Container.on(quitDesktopContainer, "pointerover", _ => {
    Graphics.clear(quitDesktopBg)->ignore
    let _ =
      quitDesktopBg
      ->Graphics.roundRect(-100.0, -25.0, 200.0, 50.0, 8.0)
      ->Graphics.fill({"color": 0x553333})
      ->Graphics.stroke({"width": 2, "color": 0xff4444})
  })
  Container.on(quitDesktopContainer, "pointerout", _ => {
    Graphics.clear(quitDesktopBg)->ignore
    let _ =
      quitDesktopBg
      ->Graphics.roundRect(-100.0, -25.0, 200.0, 50.0, 8.0)
      ->Graphics.fill({"color": 0x442222})
      ->Graphics.stroke({"width": 2, "color": 0x664444})
  })

  // Close the window/tab. In Tauri, __TAURI__ global is available.
  let closeWindow: unit => unit = %raw(`
    function() {
      try {
        if (window.__TAURI__) {
          window.__TAURI__.process.exit(0);
        } else {
          window.close();
        }
      } catch(e) {
        window.close();
      }
    }
  `)
  Container.on(quitDesktopContainer, "pointertap", _ => closeWindow())

  Container.setAccessible(quitDesktopContainer, true)
  Container.setAccessibleTitle(quitDesktopContainer, "Quit to Desktop")
  Container.setAccessibleType(quitDesktopContainer, "button")
  Container.setTabIndex(quitDesktopContainer, Array.length(entries) + 2)

  let _ = Container.addChild(container, quitDesktopContainer)

  // Settings button
  // Settings button
  let settingsBtn = FancyButton.make({
    "defaultView": "icon-settings.png",
    "anchor": 0.5,
    "animations": buttonAnimations,
  })
  Signal.connect(FancyButton.onPress(settingsBtn), () => {
    switch GetEngine.get() {
    | Some(engine) => Navigation.presentPopup(engine.navigation, SettingsPopup.constructor)->ignore
    | None => ()
    }
  })
  let _ = Container.addChild(container, FancyButton.toContainer(settingsBtn))


  // Escape key handler ref
  let escKeyHandler: ref<option<{..}>> = ref(None)

  {
    container,
    prepare: None,
    show: Some(
      async () => {
        Container.setAlpha(container, 0.0)

        // Register Escape key to go back to world map (single-fire guard)
        let escNavigating = ref(false)
        let escHandler = (_e: {..}) => {
          let key: string = %raw(`_e.key`)
          if key == "Escape" && !escNavigating.contents {
            escNavigating := true
            let _ = %raw(`_e.preventDefault()`)
            switch escKeyHandler.contents {
            | Some(_handler) => %raw(`window.removeEventListener('keydown', _handler)`)
            | None => ()
            }
            switch GetEngine.get() {
            | Some(engine) =>
              let _ =
                Navigation.showScreen(engine.navigation, WorldMapScreen.constructor)->Promise.catch(
                  PanicHandler.handleException,
                )
            | None => ()
            }
          }
        }
        let handler = %raw(`function(fn) { var h = function(e) { fn(e); }; window.addEventListener('keydown', h); return h; }`)(
          escHandler,
        )
        escKeyHandler := Some(handler)

        await Motion.animateAsync(
          container,
          {"alpha": 1.0},
          {duration: 0.5, ease: "easeOut", delay: 0.0},
        )
      },
    ),
    hide: Some(
      async () => {
        // Remove Escape key listener
        switch escKeyHandler.contents {
        | Some(_handler) => %raw(`window.removeEventListener('keydown', _handler)`)
        | None => ()
        }

        await Motion.animateAsync(
          container,
          {"alpha": 0.0},
          {duration: 0.3, ease: "linear", delay: 0.0},
        )
      },
    ),
    pause: None,
    resume: None,
    reset: Some(
      () => {
        switch escKeyHandler.contents {
        | Some(_handler) => %raw(`window.removeEventListener('keydown', _handler)`)
        | None => ()
        }
      },
    ),
    update: None,
    resize: Some(
      (width, height) => {
        // Full-screen background
        let _ = Graphics.clear(menuBg)
        let _ =
          menuBg
          ->Graphics.rect(0.0, 0.0, width, height)
          ->Graphics.fill({"color": 0x0a0a14})

        // Entry count determines layout density
        let numEntries = Int.toFloat(Array.length(entryButtons))

        // Title  moves up when there are more entries
        let titleY = if numEntries > 5.0 {
          50.0
        } else {
          80.0
        }
        Text.setX(titleText, width *. 0.5)
        Text.setY(titleText, titleY)

        // Subtitle
        Text.setX(subtitleText, width *. 0.5)
        Text.setY(subtitleText, titleY +. 40.0)

        // Entry buttons  stacked vertically, spacing adapts to entry count.
        // With 6+ entries (Moletaire enabled), spacing shrinks to fit on screen.
        let startY = if numEntries > 5.0 {
          170.0
        } else {
          220.0
        }
        let spacingY = if numEntries > 5.0 {
          // Fit all entries + buttons within ~700px of vertical space
          Math.min(110.0, 700.0 /. (numEntries +. 2.0))
        } else {
          130.0
        }
        Array.forEachWithIndex(entryButtons, (button, index) => {
          Container.setX(button, width *. 0.5)
          Container.setY(button, startY +. Int.toFloat(index) *. spacingY)
        })

        // Back button  positioned after last entry with a small gap
        let afterEntries = startY +. numEntries *. spacingY
        Container.setX(backContainer, width *. 0.5)
        Container.setY(backContainer, afterEntries +. 30.0)

        // Quit to Desktop button (below back button)
        Container.setX(quitDesktopContainer, width *. 0.5)
        Container.setY(quitDesktopContainer, afterEntries +. 80.0)
        FancyButton.setX(settingsBtn, width *. 0.5)
        FancyButton.setY(settingsBtn, afterEntries +. 130.0)
      },
    ),
    blur: None,
    focus: None,
    onLoad: None,
  }
}

let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(assetBundles),
}

// Register this constructor so training screens and WorldMapScreen can navigate here
let _ = TrainingBase.trainingMenuConstructor := Some(constructor)
let _ = TrainingRegistry.trainingMenuConstructor := Some(constructor)
