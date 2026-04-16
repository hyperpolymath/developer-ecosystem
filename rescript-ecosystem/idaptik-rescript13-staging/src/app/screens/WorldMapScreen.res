// SPDX-License-Identifier: PMPL-1.0-or-later
// World Map Screen - Shows locations player can visit

open Pixi
open PixiUI

// Asset bundles required by this screen
let assetBundles = ["main"]

let buttonAnimations = {
  "hover": {"props": {"scale": {"x": 1.1, "y": 1.1}}, "duration": 100},
  "pressed": {"props": {"scale": {"x": 0.9, "y": 0.9}}, "duration": 100},
}

// Create the world map screen
let make = (): Navigation.appScreen => {
  let container = Container.make()

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

  // Title
  let titleText = Text.make({
    "text": GameI18n.t("worldmap.title"),
    "style": {
      "fontFamily": "Arial",
      "fontSize": FontScale.sizeInt(48),
      "fill": 0xffffff,
      "fontWeight": "bold",
    },
  })
  ObservablePoint.set(Text.anchor(titleText), 0.5, ~y=0.5)
  let _ = Container.addChildText(container, titleText)

  // Subtitle
  let subtitleText = Text.make({
    "text": GameI18n.t("worldmap.subtitle"),
    "style": {
      "fontFamily": "Arial",
      "fontSize": FontScale.sizeInt(20),
      "fill": 0xaaaaaa,
      "fontStyle": "italic",
    },
  })
  ObservablePoint.set(Text.anchor(subtitleText), 0.5, ~y=0.5)
  let _ = Container.addChildText(container, subtitleText)

  // Get all locations
  let locations = LocationData.allLocations

  // Create location markers (clickable buttons)
  let locationButtons = Array.mapWithIndex(locations, (location, index) => {
    let buttonContainer = Container.make()
    Container.setEventMode(buttonContainer, "static")
    Container.setCursor(buttonContainer, "pointer")

    // Button background
    let bg = Graphics.make()
    let _ =
      bg
      ->Graphics.roundRect(-150.0, -60.0, 300.0, 120.0, 10.0)
      ->Graphics.fill({"color": 0x2a2a2a})
      ->Graphics.stroke({"width": 2, "color": 0x444444})
    let _ = Container.addChildGraphics(buttonContainer, bg)

    // Location name
    let nameText = Text.make({
      "text": location.name,
      "style": {
        "fontFamily": "Arial",
        "fontSize": FontScale.sizeInt(24),
        "fill": 0xffffff,
        "fontWeight": "bold",
      },
    })
    ObservablePoint.set(Text.anchor(nameText), 0.5, ~y=0.5)
    Text.setY(nameText, -20.0)
    let _ = Container.addChildText(buttonContainer, nameText)

    // Location description
    let descText = Text.make({
      "text": location.description,
      "style": {
        "fontFamily": "Arial",
        "fontSize": FontScale.sizeInt(14),
        "fill": 0xaaaaaa,
        "wordWrap": true,
        "wordWrapWidth": 260,
      },
    })
    ObservablePoint.set(Text.anchor(descText), 0.5, ~y=0.5)
    Text.setY(descText, 10.0)
    let _ = Container.addChildText(buttonContainer, descText)

    // Device count
    let deviceCount = Array.length(location.devicePositions)
    let countText = Text.make({
      "text": `${Int.toString(deviceCount)} ${GameI18n.t("worldmap.devices")}`,
      "style": {
        "fontFamily": "Arial",
        "fontSize": FontScale.sizeInt(12),
        "fill": 0x00ff00,
      },
    })
    ObservablePoint.set(Text.anchor(countText), 0.5, ~y=0.5)
    Text.setY(countText, 35.0)
    let _ = Container.addChildText(buttonContainer, countText)

    // Hover effect
    Container.on(buttonContainer, "pointerover", _ => {
      Graphics.clear(bg)->ignore
      let _ =
        bg
        ->Graphics.roundRect(-150.0, -60.0, 300.0, 120.0, 10.0)
        ->Graphics.fill({"color": 0x3a3a3a})
        ->Graphics.stroke({"width": 2, "color": 0x00ff00})
    })

    Container.on(buttonContainer, "pointerout", _ => {
      Graphics.clear(bg)->ignore
      let _ =
        bg
        ->Graphics.roundRect(-150.0, -60.0, 300.0, 120.0, 10.0)
        ->Graphics.fill({"color": 0x2a2a2a})
        ->Graphics.stroke({"width": 2, "color": 0x444444})
    })

    // Click to enter location
    Container.on(buttonContainer, "pointertap", _ => {
      // Navigate using registry to avoid circular dependency
      LocationRegistry.navigateTo(location.id)
    })

    // Accessibility  make location buttons navigable via Tab/Enter
    Container.setAccessible(buttonContainer, true)
    Container.setAccessibleTitle(
      buttonContainer,
      `${location.name}: ${location.description}. ${Int.toString(deviceCount)} devices`,
    )
    Container.setAccessibleType(buttonContainer, "button")
    Container.setTabIndex(buttonContainer, index + 1)

    let _ = Container.addChild(container, buttonContainer)
    buttonContainer
  })

  // Training Grounds button  separate from mission locations
  let trainingContainer = Container.make()
  Container.setEventMode(trainingContainer, "static")
  Container.setCursor(trainingContainer, "pointer")

  let trainingBg = Graphics.make()
  let _ =
    trainingBg
    ->Graphics.roundRect(-150.0, -35.0, 300.0, 70.0, 10.0)
    ->Graphics.fill({"color": 0x1a2a1a})
    ->Graphics.stroke({"width": 2, "color": 0x00ff88})
  let _ = Container.addChildGraphics(trainingContainer, trainingBg)

  let trainingText = Text.make({
    "text": GameI18n.t("worldmap.training"),
    "style": {
      "fontFamily": "Arial",
      "fontSize": FontScale.sizeInt(22),
      "fill": 0x00ff88,
      "fontWeight": "bold",
    },
  })
  ObservablePoint.set(Text.anchor(trainingText), 0.5, ~y=0.5)
  let _ = Container.addChildText(trainingContainer, trainingText)

  Container.on(trainingContainer, "pointerover", _ => {
    Graphics.clear(trainingBg)->ignore
    let _ =
      trainingBg
      ->Graphics.roundRect(-150.0, -35.0, 300.0, 70.0, 10.0)
      ->Graphics.fill({"color": 0x2a3a2a})
      ->Graphics.stroke({"width": 2, "color": 0x44ff99})
  })
  Container.on(trainingContainer, "pointerout", _ => {
    Graphics.clear(trainingBg)->ignore
    let _ =
      trainingBg
      ->Graphics.roundRect(-150.0, -35.0, 300.0, 70.0, 10.0)
      ->Graphics.fill({"color": 0x1a2a1a})
      ->Graphics.stroke({"width": 2, "color": 0x00ff88})
  })
  Container.on(trainingContainer, "pointertap", _ => {
    TrainingRegistry.navigateToTraining()
  })

  Container.setAccessible(trainingContainer, true)
  Container.setAccessibleTitle(trainingContainer, GameI18n.t("worldmap.training"))
  Container.setAccessibleType(trainingContainer, "button")
  Container.setTabIndex(trainingContainer, Array.length(locations) + 1)

  let _ = Container.addChild(container, trainingContainer)

  {
    container,
    prepare: None,
    show: Some(
      async () => {
        Container.setAlpha(container, 0.0)
        await Motion.animateAsync(
          container,
          {"alpha": 1.0},
          {duration: 0.5, ease: "easeOut", delay: 0.0},
        )
      },
    ),
    hide: Some(
      async () => {
        await Motion.animateAsync(
          container,
          {"alpha": 0.0},
          {duration: 0.3, ease: "linear", delay: 0.0},
        )
      },
    ),
    pause: None,
    resume: None,
    reset: None,
    update: None,
    resize: Some(
      (width, height) => {
        // Position title
        Text.setX(titleText, width *. 0.5)
        Text.setY(titleText, 80.0)

        // Position subtitle
        Text.setX(subtitleText, width *. 0.5)
        Text.setY(subtitleText, 130.0)
        FancyButton.setX(settingsBtn, 40.0)
        FancyButton.setY(settingsBtn, height -. 40.0)

        // Position location buttons in a grid layout
        // Group locations by category:
        // Row 1 (Y=220): Edge Networks - Field, City, Lab
        // Row 2 (Y=380): ISP Infrastructure - Rural ISP, Business ISP, Regional ISP, Backbone
        // Row 3 (Y=540): Services - Atlas, Nexus, DevHub

        let spacingX = 350.0
        let rowHeight = 160.0
        let startY = 220.0

        // Define grid positions by location ID
        let getGridPosition = (locationId: string): (int, int) => {
          switch locationId {
          // Row 1: Edge Networks
          | "field" => (0, 0)
          | "city" => (1, 0)
          | "lab" => (2, 0)
          // Row 2: ISP Infrastructure
          | "rural-isp" => (0, 1)
          | "business-isp" => (1, 1)
          | "regional-isp" => (2, 1)
          | "backbone" => (3, 1)
          // Row 3: Services
          | "atlas" => (0, 2)
          | "nexus" => (1, 2)
          | "devhub" => (2, 2)
          | _ => (0, 0) // Fallback
          }
        }

        Array.forEachWithIndex(locationButtons, (button, index) => {
          switch locations[index] {
          | Some(location) =>
            let (col, row) = getGridPosition(location.id)

            // Calculate positions with centering for each row
            let rowWidth = switch row {
            | 0 => 2.0 *. spacingX // 3 items
            | 1 => 3.0 *. spacingX // 4 items
            | 2 => 2.0 *. spacingX // 3 items
            | _ => 2.0 *. spacingX
            }

            let startX = (width -. rowWidth) /. 2.0
            let posX = startX +. Int.toFloat(col) *. spacingX
            let posY = startY +. Int.toFloat(row) *. rowHeight

            Container.setX(button, posX)
            Container.setY(button, posY)
          | None => () // Skip if location not found
          }
        })

        // Training button  centered below mission grid
        Container.setX(trainingContainer, width *. 0.5)
        Container.setY(trainingContainer, startY +. 3.0 *. rowHeight +. 40.0)
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
  assetBundles: Some(assetBundles),
}
