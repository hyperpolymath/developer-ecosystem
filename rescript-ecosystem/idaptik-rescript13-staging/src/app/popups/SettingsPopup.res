// SPDX-License-Identifier: PMPL-1.0-or-later
// Settings Popup for ReScript

@@warning("-44")
open Pixi
open PixiUI

// App version (will be defined via Vite)
@val external appVersion: string = "APP_VERSION"

// Create the settings popup
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

  // Panel base (taller to accommodate Language button)
  let panelBase = RoundedBox.make(~options={height: 600.0}, ())
  let _ = Container.addChild(panel, panelBase.container)

  // Title
  let title = Label.make(
    ~text=GameI18n.t("settings.title"),
    ~style={fill: 0xec1561, fontSize: 50},
    (),
  )
  Text.setY(title, -.panelBase.boxHeight *. 0.5 +. 60.0)
  let _ = Container.addChildText(panel, title)

  // Accessibility button  opens AccessibilityPopup
  let a11yButton = Button.make(
    ~options={text: GameI18n.t("settings.accessibility"), fontSize: 22, height: 80.0},
    (),
  )
  FancyButton.setY(a11yButton, panelBase.boxHeight *. 0.5 -. 340.0)
  Signal.connect(FancyButton.onPress(a11yButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      // Dismiss current popup, then open accessibility popup
      let _ = Navigation.dismissPopup(engine.navigation)->Promise.thenResolve(_ => {
        let _ = Navigation.presentPopup(engine.navigation, AccessibilityPopup.constructor)
      })
    | None => ()
    }
  })
  let _ = Container.addChild(panel, FancyButton.toContainer(a11yButton))

  // Feature Packs button  opens FeaturePacksPopup
  let featureButton = Button.make(
    ~options={text: GameI18n.t("settings.featurePacks"), fontSize: 22, height: 80.0},
    (),
  )
  FancyButton.setY(featureButton, panelBase.boxHeight *. 0.5 -. 250.0)
  Signal.connect(FancyButton.onPress(featureButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.dismissPopup(engine.navigation)->Promise.thenResolve(_ => {
        let _ = Navigation.presentPopup(engine.navigation, FeaturePacksPopup.constructor)
      })
    | None => ()
    }
  })
  let _ = Container.addChild(panel, FancyButton.toContainer(featureButton))

  // Language button  opens LanguagePopup
  let langButton = Button.make(
    ~options={text: GameI18n.t("settings.language"), fontSize: 22, height: 80.0},
    (),
  )
  FancyButton.setY(langButton, panelBase.boxHeight *. 0.5 -. 160.0)
  Signal.connect(FancyButton.onPress(langButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.dismissPopup(engine.navigation)->Promise.thenResolve(_ => {
        let _ = Navigation.presentPopup(engine.navigation, LanguagePopup.constructor)
      })
    | None => ()
    }
  })
  let _ = Container.addChild(panel, FancyButton.toContainer(langButton))

  // Integrations button  only visible in Tauri
  if DesktopIntegration.hasTauri() {
    let integrationButton = Button.make(
      ~options={text: GameI18n.t("settings.integrations"), fontSize: 22, height: 80.0},
      (),
    )
    FancyButton.setY(integrationButton, panelBase.boxHeight *. 0.5 -. 70.0)
    // Shift the done button down further
    Signal.connect(FancyButton.onPress(integrationButton), () => {
      switch GetEngine.get() {
      | Some(engine) =>
        let _ = Navigation.dismissPopup(engine.navigation)->Promise.thenResolve(_ => {
          let _ = Navigation.presentPopup(engine.navigation, IntegrationsPopup.constructor)
        })
      | None => ()
      }
    })
    let _ = Container.addChild(panel, FancyButton.toContainer(integrationButton))
  }

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

  // Version label
  let versionLabel = Label.make(
    ~text=`Version ${appVersion}`,
    ~style={fill: 0xffffff, fontSize: 12},
    (),
  )
  Text.setAlpha(versionLabel, 0.5)
  Text.setY(versionLabel, panelBase.boxHeight *. 0.5 -. 15.0)
  let _ = Container.addChildText(panel, versionLabel)

  // Layout for sliders
  let layout = List.make({"type": "vertical", "elementsMargin": 4})
  List.setX(layout, -140.0)
  List.setY(layout, -80.0)
  let _ = Container.addChild(panel, List.toContainer(layout))

  // Master slider
  let masterSlider = VolumeSlider.make(~label=GameI18n.t("volume.master"), ())
  Signal.connect(Slider.onUpdate(masterSlider.slider), v => {
    UserSettings.setMasterVolume(v /. 100.0)
  })
  let _ = List.addChild(layout, Slider.toContainer(masterSlider.slider))

  // BGM slider
  let bgmSlider = VolumeSlider.make(~label=GameI18n.t("volume.bgm"), ())
  Signal.connect(Slider.onUpdate(bgmSlider.slider), v => {
    UserSettings.setBgmVolume(v /. 100.0)
  })
  let _ = List.addChild(layout, Slider.toContainer(bgmSlider.slider))

  // SFX slider
  let sfxSlider = VolumeSlider.make(~label=GameI18n.t("volume.sfx"), ())
  Signal.connect(Slider.onUpdate(sfxSlider.slider), v => {
    UserSettings.setSfxVolume(v /. 100.0)
  })
  let _ = List.addChild(layout, Slider.toContainer(sfxSlider.slider))

  {
    container,
    prepare: Some(
      () => {
        Slider.setValue(masterSlider.slider, UserSettings.getMasterVolume() *. 100.0)
        Slider.setValue(bgmSlider.slider, UserSettings.getBgmVolume() *. 100.0)
        Slider.setValue(sfxSlider.slider, UserSettings.getSfxVolume() *. 100.0)
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
