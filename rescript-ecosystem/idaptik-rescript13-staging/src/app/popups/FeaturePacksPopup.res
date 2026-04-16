// SPDX-License-Identifier: PMPL-1.0-or-later
// Feature Packs Popup  toggle optional gameplay expansions
//
// Pattern follows AccessibilityPopup.res exactly.
// Reuses AccessibilityPopup.makeToggle() for toggle buttons.

@@warning("-44")
open Pixi
open PixiUI

// Create the feature packs popup
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
  let title = Label.make(
    ~text=GameI18n.t("featurePacks.title"),
    ~style={fill: 0xec1561, fontSize: 40},
    (),
  )
  Text.setY(title, -.panelBase.boxHeight *. 0.5 +. 50.0)
  let _ = Container.addChildText(panel, title)

  // Subtitle
  let subtitle = Label.make(
    ~text=GameI18n.t("featurePacks.subtitle"),
    ~style={fill: 0x888888, fontSize: 14},
    (),
  )
  Text.setY(subtitle, -.panelBase.boxHeight *. 0.5 +. 85.0)
  let _ = Container.addChildText(panel, subtitle)

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
  List.setY(layout, -60.0)
  let _ = Container.addChild(panel, List.toContainer(layout))

  //  Invertible Programming 
  let invertibleToggle = AccessibilityPopup.makeToggle(
    ~label=GameI18n.t("featurePacks.invertible"),
    ~initial=FeaturePacks.isInvertibleProgrammingEnabled(),
    ~onToggle=enabled => FeaturePacks.setInvertibleProgramming(enabled),
  )
  let _ = List.addChild(layout, FancyButton.toContainer(invertibleToggle))

  // Description text
  let desc = Label.make(
    ~text=GameI18n.t("featurePacks.invertibleDesc"),
    ~style={fill: 0x666666, fontSize: 11},
    (),
  )
  Text.setY(desc, 10.0)
  let _ = List.addChild(layout, Text.toContainer(desc))

  //  Moletaire Companion 
  let moletaireToggle = AccessibilityPopup.makeToggle(
    ~label=GameI18n.t("featurePacks.moletaire"),
    ~initial=FeaturePacks.isMoletaireEnabled(),
    ~onToggle=enabled => FeaturePacks.setMoletaire(enabled),
  )
  let _ = List.addChild(layout, FancyButton.toContainer(moletaireToggle))

  let moletaireDesc = Label.make(
    ~text=GameI18n.t("featurePacks.moletaireDesc"),
    ~style={fill: 0x666666, fontSize: 11},
    (),
  )
  Text.setY(moletaireDesc, 10.0)
  let _ = List.addChild(layout, Text.toContainer(moletaireDesc))

  {
    container,
    prepare: Some(
      () => {
        Announcer.status("Feature Packs settings")
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
