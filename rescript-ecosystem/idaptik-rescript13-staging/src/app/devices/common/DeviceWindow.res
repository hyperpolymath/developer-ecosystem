// SPDX-License-Identifier: PMPL-1.0-or-later
// Base draggable window for device interfaces

open Pixi

// Separate type for drag offset
type dragOffset = {x: float, y: float}

type t = {
  container: Container.t,
  titleBar: Graphics.t,
  content: Container.t,
  closeBtn: Graphics.t,
  mutable isDragging: bool,
  mutable dragOffset: dragOffset,
  mutable onCloseCallback: option<unit => unit>,
}

// Create a device window
let make = (
  ~title: string,
  ~width: float,
  ~height: float,
  ~titleBarColor: int=0x0078D4,
  ~backgroundColor: int=0x1a1a1a,
  (),
): t => {
  let container = Container.make()
  Container.setEventMode(container, "static")
  Container.setInteractiveChildren(container, true)
  Container.setZIndex(container, 10)
  Container.setX(container, 100.0 +. Random.float(0.0, 100.0))
  Container.setY(container, 100.0 +. Random.float(0.0, 50.0))

  // Window background
  let bg = Graphics.make()
  let _ = bg
    ->Graphics.rect(0.0, 0.0, width, height)
    ->Graphics.fill({"color": backgroundColor})
    ->Graphics.stroke({"width": 2, "color": 0x000000})
  let _ = Container.addChildGraphics(container, bg)

  // Title bar
  let titleBar = Graphics.make()
  let _ = titleBar
    ->Graphics.rect(0.0, 0.0, width, 30.0)
    ->Graphics.fill({"color": titleBarColor})
  Graphics.setEventMode(titleBar, "static")
  Graphics.setInteractiveChildren(titleBar, true)
  Graphics.setCursor(titleBar, "grab")
  let _ = Container.addChildGraphics(container, titleBar)

  // Title text
  let titleText = Text.make({
    "text": title,
    "style": {"fontSize": 12, "fill": 0xffffff, "fontFamily": "monospace"},
  })
  Text.setX(titleText, 10.0)
  Text.setY(titleText, 8.0)
  let _ = Graphics.addChild(titleBar, titleText)

  // Close button - position the Graphics object, draw rect at origin for proper hit detection
  let closeBtn = Graphics.make()
  Graphics.setX(closeBtn, width -. 30.0)
  Graphics.setY(closeBtn, 5.0)
  let _ = closeBtn
    ->Graphics.rect(0.0, 0.0, 25.0, 20.0)
    ->Graphics.fill({"color": 0xff0000})
  Graphics.setEventMode(closeBtn, "static")
  Graphics.setCursor(closeBtn, "pointer")

  let closeX = Text.make({
    "text": "X",
    "style": {"fontSize": 14, "fill": 0xffffff, "fontWeight": "bold"},
  })
  Text.setX(closeX, 8.0)
  Text.setY(closeX, 2.0)
  let _ = Graphics.addChild(closeBtn, closeX)
  let _ = Graphics.addChild(titleBar, closeBtn)

  // Content container
  let content = Container.make()
  Container.setEventMode(content, "static")
  Container.setInteractiveChildren(content, true)
  Container.setY(content, 30.0)
  let _ = Container.addChild(container, content)

  let windowState = {
    container,
    titleBar,
    content,
    closeBtn,
    isDragging: false,
    dragOffset: {x: 0.0, y: 0.0},
    onCloseCallback: None,
  }

  // Setup dragging
  Graphics.on(titleBar, "pointerdown", (e: FederatedPointerEvent.t) => {
    windowState.isDragging = true
    Graphics.setCursor(titleBar, "grabbing")
    windowState.dragOffset = {
      x: FederatedPointerEvent.global(e).x -. Container.x(container),
      y: FederatedPointerEvent.global(e).y -. Container.y(container),
    }

    switch Container.parent(container)->Nullable.toOption {
    | Some(parent) =>
      Container.on(parent, "pointermove", (e: FederatedPointerEvent.t) => {
        if windowState.isDragging {
          Container.setX(container, FederatedPointerEvent.global(e).x -. windowState.dragOffset.x)
          Container.setY(container, FederatedPointerEvent.global(e).y -. windowState.dragOffset.y)
        }
      })
      Container.on(parent, "pointerup", _ => {
        windowState.isDragging = false
        Graphics.setCursor(titleBar, "grab")
      })
      Container.on(parent, "pointerupoutside", _ => {
        windowState.isDragging = false
        Graphics.setCursor(titleBar, "grab")
      })
    | None => ()
    }
  })

  // Setup close button - use pointerdown for more reliable detection
  Graphics.on(closeBtn, "pointerdown", _ => {
    // Call onClose callback if set
    switch windowState.onCloseCallback {
    | Some(callback) => callback()
    | None => ()
    }
    Container.destroy(container)
  })

  windowState
}

// Set close callback
let setOnClose = (win: t, callback: unit => unit): unit => {
  win.onCloseCallback = Some(callback)
}

// Get content container
let getContent = (win: t): Container.t => win.content

// Close the window
let close = (win: t): unit => {
  Container.destroy(win.container)
}
