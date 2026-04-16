// SPDX-License-Identifier: PMPL-1.0-or-later
// Pause Popup for ReScript

open Pixi
open PixiUI

// Create the pause popup
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
  let panelBase = RoundedBox.make(~options={height: 400.0}, ())
  let _ = Container.addChild(panel, panelBase.container)

  // Title
  let title = Label.make(~text=GameI18n.t("pause.title"), ~style={fill: 0xec1561, fontSize: 50}, ())
  Text.setY(title, -130.0)
  let _ = Container.addChildText(panel, title)

  //  Buttons 
  
  // Use Button.res which wraps FancyButton for consistent look/feel
  
  // Resume button
  let resumeButton = Button.make(~options={text: GameI18n.t("pause.resume")}, ())
  FancyButton.setY(resumeButton, -30.0)
  Signal.connect(FancyButton.onPress(resumeButton), () => {
    switch GetEngine.get() {
    | Some(engine) => let _ = Navigation.dismissPopup(engine.navigation)
    | None => ()
    }
  })
  let _ = Container.addChild(panel, FancyButton.toContainer(resumeButton))

  // Settings button
  let settingsButton = Button.make(~options={text: GameI18n.t("settings.title")}, ())
  FancyButton.setY(settingsButton, 60.0)
  Signal.connect(FancyButton.onPress(settingsButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.dismissPopup(engine.navigation)->Promise.thenResolve(_ => {
        let _ = Navigation.presentPopup(engine.navigation, SettingsPopup.constructor)
      })
    | None => ()
    }
  })
  let _ = Container.addChild(panel, FancyButton.toContainer(settingsButton))

  // Quit to Map button
  let quitButton = Button.make(~options={text: GameI18n.t("ui.quit")}, ())
  FancyButton.setY(quitButton, 150.0)
  Signal.connect(FancyButton.onPress(quitButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.dismissPopup(engine.navigation)->Promise.thenResolve(_ => {
        let _ = Navigation.showScreen(engine.navigation, WorldMapScreen.constructor)
      })
    | None => ()
    }
  })
  let _ = Container.addChild(panel, FancyButton.toContainer(quitButton))

  {
    container,
    prepare: None,
    show: Some(async () => {
      Announcer.alert(GameI18n.t("pause.announced"))
      switch GetEngine.get() {
      | Some(engine) =>
        switch engine.navigation.currentScreen {
        | Some(screen) =>
          let blurFilter = BlurFilter.make({"strength": 5})
          Container.setFilters(screen.container, [BlurFilter.toFilter(blurFilter)])
        | None => ()
        }
      | None => ()
      }
      Sprite.setAlpha(bg, 0.0)
      ObservablePoint.setY(Container.pivot(panel), -400.0)
      let _ = Motion.animate(bg, {"alpha": 0.8}, {duration: 0.2, ease: "linear"})
      await Motion.animateAsync(Container.pivot(panel), {"y": 0.0}, {duration: 0.3, ease: "backOut"})
    }),
    hide: Some(async () => {
      Announcer.alert(GameI18n.t("pause.resumed"))
      
      switch GetEngine.get() {
      | Some(engine) =>
        switch engine.navigation.currentScreen {
        | Some(screen) => Container.setFilters(screen.container, [])
        | None => ()
        }
      | None => ()
      }
      let _ = Motion.animate(bg, {"alpha": 0.0}, {duration: 0.2, ease: "linear"})
      await Motion.animateAsync(Container.pivot(panel), {"y": -500.0}, {duration: 0.3, ease: "backIn"})
    }),
    pause: None, resume: None, reset: None, update: None,
    resize: Some((width, height) => {
      Sprite.setWidth(bg, width)
      Sprite.setHeight(bg, height)
      Container.setX(panel, width *. 0.5)
      Container.setY(panel, height *. 0.5)
    }),
    blur: None, focus: None, onLoad: None,
  }
}

let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: None,
}
