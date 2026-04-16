// SPDX-License-Identifier: PMPL-1.0-or-later
// Language Popup  select game language from Settings
//
// Shows a cycle button for language selection with native display names.
// Pattern follows AccessibilityPopup.res exactly.

@@warning("-44")
open Pixi
open PixiUI

// Create the language popup
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

  // Panel base (compact  just one cycle button + subtitle)
  let panelBase = RoundedBox.make(~options={height: 350.0}, ())
  let _ = Container.addChild(panel, panelBase.container)

  // Title
  let title = Label.make(
    ~text=GameI18n.t("settings.language"),
    ~style={fill: 0xec1561, fontSize: 40},
    (),
  )
  Text.setY(title, -.panelBase.boxHeight *. 0.5 +. 50.0)
  let _ = Container.addChildText(panel, title)

  // Subtitle  shows current language name
  let subtitleText = Label.make(
    ~text=LanguageSettings.languageDisplayName(LanguageSettings.getLanguage()),
    ~style={fill: 0xaaaaaa, fontSize: 18},
    (),
  )
  Text.setY(subtitleText, -.panelBase.boxHeight *. 0.5 +. 100.0)
  let _ = Container.addChildText(panel, subtitleText)

  // Language cycle button  reuse AccessibilityPopup's cycle button pattern
  let langButton = AccessibilityPopup.makeCycleButton(
    ~getLabel=() => {
      let name = LanguageSettings.languageDisplayName(LanguageSettings.getLanguage())
      `${GameI18n.t("settings.language")}: ${name}`
    },
    ~onCycle=() => {
      let newLang = LanguageSettings.cycleLanguage()
      GameI18n.setLanguage(LanguageSettings.languageToCode(newLang))
      // Update subtitle to show new language name
      Text.setText(subtitleText, LanguageSettings.languageDisplayName(newLang))
      // Update title in case it's a translated label
      Text.setText(title, GameI18n.t("settings.language"))
    },
  )

  // Layout for the cycle button
  let layout = List.make({"type": "vertical", "elementsMargin": 6})
  List.setX(layout, -140.0)
  List.setY(layout, -20.0)
  let _ = Container.addChild(panel, List.toContainer(layout))
  let _ = List.addChild(layout, FancyButton.toContainer(langButton))

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

  {
    container,
    prepare: Some(
      () => {
        Announcer.status("Language settings")
        // Refresh label in case language changed externally
        Text.setText(
          subtitleText,
          LanguageSettings.languageDisplayName(LanguageSettings.getLanguage()),
        )
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
