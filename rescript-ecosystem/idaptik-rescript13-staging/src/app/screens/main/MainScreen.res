// SPDX-License-Identifier: PMPL-1.0-or-later
// Main Screen for ReScript

open Pixi
open PixiUI

// Asset bundles required by this screen
let assetBundles = ["main"]

type t = {
  container: Container.t,
  mainContainer: Container.t,
  pauseButton: FancyButton.t,
  settingsButton: FancyButton.t,
  addButton: FancyButton.t,
  removeButton: FancyButton.t,
  desktopButton: FancyButton.t,
  bouncer: Bouncer.t,
  mutable paused: bool,
}

// Create button animations config
let buttonAnimations = {
  "hover": {
    "props": {"scale": {"x": 1.1, "y": 1.1}},
    "duration": 100,
  },
  "pressed": {
    "props": {"scale": {"x": 0.9, "y": 0.9}},
    "duration": 100,
  },
}

// Create the main screen
let make = (): Navigation.appScreen => {
  let container = Container.make()
  let mainContainer = Container.make()
  let _ = Container.addChild(container, mainContainer)

  let bouncer = Bouncer.make()

  // Pause button
  let pauseButton = FancyButton.make({
    "defaultView": "icon-pause.png",
    "anchor": 0.5,
    "animations": buttonAnimations,
  })
  Signal.connect(FancyButton.onPress(pauseButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.presentPopup(engine.navigation, PausePopup.constructor)
    | None => ()
    }
  })
  let _ = Container.addChild(container, FancyButton.toContainer(pauseButton))

  // Settings button
  let settingsButton = FancyButton.make({
    "defaultView": "icon-settings.png",
    "anchor": 0.5,
    "animations": buttonAnimations,
  })
  Signal.connect(FancyButton.onPress(settingsButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.presentPopup(engine.navigation, SettingsPopup.constructor)
    | None => ()
    }
  })
  let _ = Container.addChild(container, FancyButton.toContainer(settingsButton))

  // Add button
  let addButton = Button.make(~options={text: "Add", width: 175.0, height: 110.0}, ())
  Signal.connect(FancyButton.onPress(addButton), () => {
    Bouncer.add(bouncer)
  })
  let _ = Container.addChild(container, FancyButton.toContainer(addButton))

  // Remove button
  let removeButton = Button.make(~options={text: "Remove", width: 175.0, height: 110.0}, ())
  Signal.connect(FancyButton.onPress(removeButton), () => {
    Bouncer.remove(bouncer)
  })
  let _ = Container.addChild(container, FancyButton.toContainer(removeButton))

  // Desktop button
  let desktopButton = Button.make(~options={text: "Desktop", width: 175.0, height: 110.0}, ())
  Signal.connect(FancyButton.onPress(desktopButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.presentPopup(engine.navigation, NetworkDesktop.constructor)
    | None => ()
    }
  })
  let _ = Container.addChild(container, FancyButton.toContainer(desktopButton))

  let screenState = {
    container,
    mainContainer,
    pauseButton,
    settingsButton,
    addButton,
    removeButton,
    desktopButton,
    bouncer,
    paused: false,
  }

  {
    container,
    prepare: Some(() => ()),
    show: Some(async () => {
      switch GetEngine.get() {
      | Some(engine) =>
        let _ = Audio.BGM.play(engine.audio.bgm, "main/sounds/bgm-main.mp3", ~volume=0.5, ())
      | None => ()
      }

      let elementsToAnimate = [
        FancyButton.toContainer(pauseButton),
        FancyButton.toContainer(settingsButton),
        FancyButton.toContainer(addButton),
        FancyButton.toContainer(removeButton),
      ]

      Array.forEach(elementsToAnimate, element => {
        Container.setAlpha(element, 0.0)
        let _ = Motion.animate(
          element,
          {"alpha": 1.0},
          {duration: 0.3, delay: 0.75, ease: "backOut"},
        )
      })

      await WaitFor.waitFor(~delayInSecs=0.75, ())
      await Bouncer.show(bouncer, mainContainer)
    }),
    hide: Some(async () => ()),
    pause: Some(async () => {
      Container.setInteractiveChildren(mainContainer, false)
      screenState.paused = true
    }),
    resume: Some(async () => {
      Container.setInteractiveChildren(mainContainer, true)
      screenState.paused = false
    }),
    reset: Some(() => ()),
    update: Some(_time => {
      if !screenState.paused {
        Bouncer.update(bouncer)
      }
    }),
    resize: Some((width, height) => {
      let centerX = width *. 0.5
      let centerY = height *. 0.5

      Container.setX(mainContainer, centerX)
      Container.setY(mainContainer, centerY)
      FancyButton.setX(pauseButton, 30.0)
      FancyButton.setY(pauseButton, 30.0)
      FancyButton.setX(settingsButton, width -. 30.0)
      FancyButton.setY(settingsButton, 30.0)
      FancyButton.setX(removeButton, width /. 2.0 -. 100.0)
      FancyButton.setY(removeButton, height -. 75.0)
      FancyButton.setX(addButton, width /. 2.0 +. 100.0)
      FancyButton.setY(addButton, height -. 75.0)
      FancyButton.setX(desktopButton, width /. 2.0)
      FancyButton.setY(desktopButton, height /. 2.0)

      Bouncer.resize(bouncer, width, height)
    }),
    blur: Some(() => {
      switch GetEngine.get() {
      | Some(engine) =>
        switch engine.navigation.currentPopup {
        | None =>
          let _ = Navigation.presentPopup(engine.navigation, PausePopup.constructor)
        | Some(_) => ()
        }
      | None => ()
      }
    }),
    focus: None,
    onLoad: None,
  }
}

// Screen constructor
let constructor: Navigation.appScreenConstructor = {
  make,
  assetBundles: Some(assetBundles),
}
