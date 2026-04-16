// SPDX-License-Identifier: PMPL-1.0-or-later
// HUD  In-game heads-up display overlay
//
// Renders persistent UI on top of WorldScreen:
// - Alert level indicator (top-left)
// - Network zone name (top-centre)
// - Inventory quickbar (bottom-centre)
// - Objective text (top-right)
// - Minimap (bottom-right)

open Pixi

//  Alert Level 

// Alert level: 0 = undetected, 5 = full lockdown
type alertLevel =
  | Clear // 0  no suspicion
  | Noticed // 1  anomaly detected
  | Caution // 2  active investigation
  | Alert // 3  security dispatched
  | Danger // 4  intruder confirmed
  | Lockdown // 5  full facility lockdown

let alertToInt = (level: alertLevel): int => {
  switch level {
  | Clear => 0
  | Noticed => 1
  | Caution => 2
  | Alert => 3
  | Danger => 4
  | Lockdown => 5
  }
}

let alertToString = (level: alertLevel): string => {
  switch level {
  | Clear => "CLEAR"
  | Noticed => "NOTICED"
  | Caution => "CAUTION"
  | Alert => "ALERT"
  | Danger => "DANGER"
  | Lockdown => "LOCKDOWN"
  }
}

// Alert color  delegates to ColorPalette for color blind support
let alertColor = (level: alertLevel): int => {
  ColorPalette.alertColor(alertToInt(level))
}

//  Inventory Slot 

type inventorySlot = {
  itemName: option<string>,
  itemIcon: option<string>, // icon texture name
  quantity: int,
}

let emptySlot: inventorySlot = {
  itemName: None,
  itemIcon: None,
  quantity: 0,
}

//  HUD State 

type t = {
  container: Container.t,
  // Sub-containers for each HUD element
  alertContainer: Container.t,
  zoneContainer: Container.t,
  inventoryContainer: Container.t,
  objectiveContainer: Container.t,
  minimapContainer: Container.t,
  hpContainer: Container.t,
  // Mutable state
  mutable currentAlert: alertLevel,
  mutable currentZone: string,
  mutable objectiveText: string,
  mutable inventorySlots: array<inventorySlot>,
  mutable currentHP: float,
  mutable maxHP: float,
  mutable hpVisible: bool,
  // Cached text objects for efficient updates
  mutable alertText: Text.t,
  mutable alertBar: Graphics.t,
  mutable hpBar: Graphics.t,
  mutable hpText: Text.t,
  mutable zoneText: Text.t,
  mutable objectiveLabel: Text.t,
  mutable minimapGraphics: Graphics.t,
  minimapLabel: Text.t,
  mutable screenWidth: float,
  mutable screenHeight: float,
  mutable inventoryDirty: bool,
}

//  Helpers 

// Convert int color (0xRRGGBB) to CSS hex string "#rrggbb"
let intToHexColor: int => string = %raw(`function(n) { return "#" + n.toString(16).padStart(6, "0") }`)

//  Construction 

let monoStyle = (~fontSize: float, ~fill: string, ()): Pixi.TextStyle.t => {
  Pixi.TextStyle.make({"fontFamily": "monospace", "fontSize": fontSize, "fill": fill})
}

let make = (): t => {
  let container = Container.make()
  Container.setEventMode(container, "none")
  Container.setSortableChildren(container, true)

  //  Alert level (top-left) 
  let alertContainer = Container.make()
  Container.setX(alertContainer, 16.0)
  Container.setY(alertContainer, 16.0)
  let _ = Container.addChild(container, alertContainer)

  let alertBar = Graphics.make()
  let _ = Container.addChildGraphics(alertContainer, alertBar)

  let alertText = Text.make({
    "text": "CLEAR",
    "style": monoStyle(~fontSize=12.0, ~fill="#00ff00", ()),
  })
  Text.setX(alertText, 8.0)
  Text.setY(alertText, 4.0)
  let _ = Container.addChildText(alertContainer, alertText)

  //  Zone name (top-centre) 
  let zoneContainer = Container.make()
  let _ = Container.addChild(container, zoneContainer)

  let zoneText = Text.make({
    "text": "DOWNTOWN LAN",
    "style": monoStyle(~fontSize=11.0, ~fill="#aaaaaa", ()),
  })
  ObservablePoint.set(Text.anchor(zoneText), 0.5, ~y=0.0)
  Text.setY(zoneText, 16.0)
  let _ = Container.addChildText(zoneContainer, zoneText)

  //  Objective (top-right) 
  let objectiveContainer = Container.make()
  let _ = Container.addChild(container, objectiveContainer)

  let objHeader = Text.make({
    "text": "OBJECTIVE",
    "style": monoStyle(~fontSize=10.0, ~fill="#666666", ()),
  })
  Text.setY(objHeader, 16.0)
  let _ = Container.addChildText(objectiveContainer, objHeader)

  let objectiveLabel = Text.make({
    "text": "Infiltrate the network",
    "style": monoStyle(~fontSize=11.0, ~fill="#44ff44", ()),
  })
  Text.setY(objectiveLabel, 32.0)
  let _ = Container.addChildText(objectiveContainer, objectiveLabel)

  //  Inventory quickbar (bottom-centre) 
  let inventoryContainer = Container.make()
  let _ = Container.addChild(container, inventoryContainer)

  //  HP bar (below alert, top-left) 
  let hpContainer = Container.make()
  Container.setX(hpContainer, 16.0)
  Container.setY(hpContainer, 48.0)
  Container.setAlpha(hpContainer, 0.0) // Hidden by default until setHP is called
  let _ = Container.addChild(container, hpContainer)

  let hpBar = Graphics.make()
  let _ = Container.addChildGraphics(hpContainer, hpBar)

  let hpText = Text.make({"text": "HP", "style": monoStyle(~fontSize=10.0, ~fill="#cc4444", ())})
  Text.setX(hpText, 138.0)
  Text.setY(hpText, 1.0)
  let _ = Container.addChildText(hpContainer, hpText)

  //  Minimap (bottom-right) 
  let minimapContainer = Container.make()
  let _ = Container.addChild(container, minimapContainer)

  let minimapGraphics = Graphics.make()
  let _ = Container.addChildGraphics(minimapContainer, minimapGraphics)

  let minimapLabel = Text.make({
    "text": "MAP",
    "style": monoStyle(~fontSize=8.0, ~fill="#555555", ()),
  })
  Text.setX(minimapLabel, 3.0)
  Text.setY(minimapLabel, 1.0)
  let _ = Container.addChildText(minimapContainer, minimapLabel)

  {
    container,
    alertContainer,
    zoneContainer,
    inventoryContainer,
    objectiveContainer,
    minimapContainer,
    currentAlert: Clear,
    currentZone: "UNKNOWN",
    objectiveText: "Infiltrate the network",
    inventorySlots: [emptySlot, emptySlot, emptySlot],
    alertText,
    alertBar,
    hpContainer,
    hpBar,
    hpText,
    currentHP: 100.0,
    maxHP: 100.0,
    hpVisible: false,
    zoneText,
    objectiveLabel,
    minimapGraphics,
    minimapLabel,
    screenWidth: 1024.0,
    screenHeight: 768.0,
    inventoryDirty: true,
  }
}

//  Alert Level Rendering 

// Draw a shape indicator inside an alert bar segment
// Shapes ensure color is never the sole differentiator (WCAG 1.4.1)
let drawAlertShape = (g: Graphics.t, x: float, segmentIndex: int): unit => {
  let cx = x +. 9.0 // Centre of 18px segment
  let cy = 12.0
  switch segmentIndex {
  | 0 =>
    // Horizontal line (Clear)
    let _ =
      g
      ->Graphics.moveTo(cx -. 5.0, cy)
      ->Graphics.lineTo(cx +. 5.0, cy)
      ->Graphics.stroke({"width": 2, "color": 0x000000})
  | 1 =>
    // Small dot (Noticed)
    let _ = g->Graphics.circle(cx, cy, 3.0)->Graphics.fill({"color": 0x000000})
  | 2 =>
    // Triangle (Caution)
    let _ =
      g
      ->Graphics.moveTo(cx, cy -. 5.0)
      ->Graphics.lineTo(cx +. 5.0, cy +. 4.0)
      ->Graphics.lineTo(cx -. 5.0, cy +. 4.0)
      ->Graphics.lineTo(cx, cy -. 5.0)
      ->Graphics.fill({"color": 0x000000})
  | 3 =>
    // Double dot (Alert)
    let _ = g->Graphics.circle(cx -. 4.0, cy, 2.5)->Graphics.fill({"color": 0x000000})
    let _ = g->Graphics.circle(cx +. 4.0, cy, 2.5)->Graphics.fill({"color": 0x000000})
  | 4 =>
    // X mark (Danger)
    let _ =
      g
      ->Graphics.moveTo(cx -. 4.0, cy -. 4.0)
      ->Graphics.lineTo(cx +. 4.0, cy +. 4.0)
      ->Graphics.stroke({"width": 2, "color": 0x000000})
    let _ =
      g
      ->Graphics.moveTo(cx +. 4.0, cy -. 4.0)
      ->Graphics.lineTo(cx -. 4.0, cy +. 4.0)
      ->Graphics.stroke({"width": 2, "color": 0x000000})
  | _ =>
    // Filled square (Lockdown)
    let _ =
      g
      ->Graphics.rect(cx -. 4.0, cy -. 4.0, 8.0, 8.0)
      ->Graphics.fill({"color": 0x000000})
  }
}

let renderAlert = (hud: t): unit => {
  let level = hud.currentAlert
  let color = alertColor(level)
  let filled = alertToInt(level)

  // Clear and redraw the alert bar
  let _ = Graphics.clear(hud.alertBar)

  // Background bar (6 segments) with shape indicators
  for i in 0 to 5 {
    let x = Int.toFloat(i) *. 22.0
    let fillColor = if i <= filled {
      color
    } else {
      0x333333
    }
    let _ =
      hud.alertBar
      ->Graphics.rect(x, 0.0, 18.0, 24.0)
      ->Graphics.fill({"color": fillColor})

    // Draw shape indicator inside filled segments
    if i <= filled {
      drawAlertShape(hud.alertBar, x, i)
    }
  }

  // Border
  let _ =
    hud.alertBar
    ->Graphics.rect(0.0, 0.0, 132.0, 24.0)
    ->Graphics.stroke({"width": 1, "color": 0x666666})

  // Update text
  Text.setText(hud.alertText, alertToString(level))
  Text.setX(hud.alertText, 140.0)
  Text.setY(hud.alertText, 4.0)

  let style = monoStyle(~fontSize=FontScale.size(12.0), ~fill=intToHexColor(color), ())
  Text.setStyle(hud.alertText, style)
}

//  HP Rendering 

let renderHP = (hud: t): unit => {
  if hud.hpVisible {
    Container.setAlpha(hud.hpContainer, 1.0)
    let _ = Graphics.clear(hud.hpBar)
    let barWidth = 132.0
    let barHeight = 14.0
    let ratio = if hud.maxHP > 0.0 {
      hud.currentHP /. hud.maxHP
    } else {
      0.0
    }
    let fillWidth = barWidth *. ratio

    // Background (dark)
    let _ =
      hud.hpBar
      ->Graphics.rect(0.0, 0.0, barWidth, barHeight)
      ->Graphics.fill({"color": 0x1a0000})

    // Fill (green  yellow  red based on HP ratio)
    let fillColor = if ratio > 0.6 {
      0x00cc44
    } else if ratio > 0.3 {
      0xccaa00
    } else {
      0xcc2222
    }
    if fillWidth > 0.0 {
      let _ =
        hud.hpBar
        ->Graphics.rect(0.0, 0.0, fillWidth, barHeight)
        ->Graphics.fill({"color": fillColor})
    }

    // Border
    let _ =
      hud.hpBar
      ->Graphics.rect(0.0, 0.0, barWidth, barHeight)
      ->Graphics.stroke({"width": 1, "color": 0x666666})

    // Text label
    let hpPct = Int.toString(Float.toInt(ratio *. 100.0))
    Text.setText(hud.hpText, `HP ${hpPct}%`)
    let textColor = intToHexColor(fillColor)
    Text.setStyle(hud.hpText, monoStyle(~fontSize=10.0, ~fill=textColor, ()))
  } else {
    Container.setAlpha(hud.hpContainer, 0.0)
  }
}

let setHP = (hud: t, ~current: float, ~max: float): unit => {
  hud.currentHP = current
  hud.maxHP = max
  hud.hpVisible = true
  renderHP(hud)
}

//  Inventory Rendering 

let renderInventory = (hud: t): unit => {
  // Clear existing children
  Container.removeChildren(hud.inventoryContainer)

  let bg = Graphics.make()
  let slotCount = Array.length(hud.inventorySlots)
  let slotWidth = 56.0
  let slotHeight = 56.0
  let padding = 4.0
  let totalWidth = Int.toFloat(slotCount) *. (slotWidth +. padding) -. padding

  // Position at bottom-centre
  let startX = (hud.screenWidth -. totalWidth) /. 2.0
  Container.setX(hud.inventoryContainer, startX)
  Container.setY(hud.inventoryContainer, hud.screenHeight -. 72.0)

  // Render each slot
  hud.inventorySlots->Array.forEachWithIndex((slot, idx) => {
    let x = Int.toFloat(idx) *. (slotWidth +. padding)

    // Slot background
    let slotBg = if Option.isSome(slot.itemName) {
      0x2a2a2a
    } else {
      0x1a1a1a
    }
    let _ =
      bg
      ->Graphics.rect(x, 0.0, slotWidth, slotHeight)
      ->Graphics.fill({"color": slotBg})
    let _ =
      bg
      ->Graphics.rect(x, 0.0, slotWidth, slotHeight)
      ->Graphics.stroke({"width": 1, "color": 0x555555})

    // Slot number (1-indexed)
    let numText = Text.make({
      "text": Int.toString(idx + 1),
      "style": monoStyle(~fontSize=9.0, ~fill="#444444", ()),
    })
    Text.setX(numText, x +. 3.0)
    Text.setY(numText, 2.0)
    let _ = Container.addChildText(hud.inventoryContainer, numText)

    // Item name if present
    switch slot.itemName {
    | Some(name) => {
        let itemText = Text.make({
          "text": name,
          "style": monoStyle(~fontSize=10.0, ~fill="#cccccc", ()),
        })
        Text.setX(itemText, x +. 4.0)
        Text.setY(itemText, 22.0)
        let _ = Container.addChildText(hud.inventoryContainer, itemText)

        if slot.quantity > 1 {
          let qtyText = Text.make({
            "text": `x${Int.toString(slot.quantity)}`,
            "style": monoStyle(~fontSize=9.0, ~fill="#888888", ()),
          })
          Text.setX(qtyText, x +. 4.0)
          Text.setY(qtyText, 40.0)
          let _ = Container.addChildText(hud.inventoryContainer, qtyText)
        }
      }
    | None => ()
    }
  })

  let _ = Container.addChildAt(hud.inventoryContainer, Graphics.toContainer(bg), 0)
}

//  Minimap Rendering 

type minimapDevice = {
  x: float,
  y: float,
  deviceType: DeviceTypes.deviceType,
  powered: bool,
}

let renderMinimap = (
  hud: t,
  ~devices: array<minimapDevice>,
  ~playerX: float,
  ~playerY as _: float,
): unit => {
  let _ = Graphics.clear(hud.minimapGraphics)

  let mapWidth = 160.0
  let mapHeight = 80.0
  let margin = 12.0

  // Position bottom-right
  Container.setX(hud.minimapContainer, hud.screenWidth -. mapWidth -. margin)
  Container.setY(hud.minimapContainer, hud.screenHeight -. mapHeight -. margin)

  // Background
  let _ =
    hud.minimapGraphics
    ->Graphics.rect(0.0, 0.0, mapWidth, mapHeight)
    ->Graphics.fill({"color": 0x0a0a0a, "alpha": 0.8})
  let _ =
    hud.minimapGraphics
    ->Graphics.rect(0.0, 0.0, mapWidth, mapHeight)
    ->Graphics.stroke({"width": 1, "color": 0x333333})

  // Scale world coords to minimap
  let worldMinX = -500.0
  let worldMaxX = 3000.0
  let worldRange = worldMaxX -. worldMinX

  // Device dots
  devices->Array.forEach(dev => {
    let mx = (dev.x -. worldMinX) /. worldRange *. mapWidth
    let my = mapHeight *. 0.6 // All devices on ground plane
    let dotColor = if dev.powered {
      ColorPalette.deviceColor(dev.deviceType)
    } else {
      0x444444
    }
    let _ =
      hud.minimapGraphics
      ->Graphics.circle(mx, my, 3.0)
      ->Graphics.fill({"color": dotColor})
  })

  // Player position (bright green triangle)
  let px = (playerX -. worldMinX) /. worldRange *. mapWidth
  let py = mapHeight *. 0.6
  let _ =
    hud.minimapGraphics
    ->Graphics.moveTo(px, py -. 5.0)
    ->Graphics.lineTo(px +. 4.0, py +. 3.0)
    ->Graphics.lineTo(px -. 4.0, py +. 3.0)
    ->Graphics.lineTo(px, py -. 5.0)
    ->Graphics.fill({"color": 0x00ff00})

  // "MINIMAP" label background
  let _ =
    hud.minimapGraphics
    ->Graphics.rect(0.0, 0.0, 48.0, 12.0)
    ->Graphics.fill({"color": 0x0a0a0a})
}

//  State Updates 

let setAlertLevel = (hud: t, level: alertLevel): unit => {
  if hud.currentAlert != level {
    Announcer.alert(`Alert level: ${alertToString(level)}`)
  }
  hud.currentAlert = level
  renderAlert(hud)
}

// Labeled alias used by GameLoop.syncHUD
let setAlert = (hud: t, ~level: alertLevel): unit => setAlertLevel(hud, level)

let setZone = (hud: t, ~name: string): unit => {
  if hud.currentZone != name {
    Announcer.status(`Zone: ${name}`)
  }
  hud.currentZone = name
  Text.setText(hud.zoneText, name)
}

let setObjective = (hud: t, ~text: string): unit => {
  if hud.objectiveText != text {
    Announcer.status(`Objective: ${text}`)
  }
  hud.objectiveText = text
  Text.setText(hud.objectiveLabel, text)
}

// Full re-render (called at end of syncHUD)
let render = (hud: t): unit => {
  renderAlert(hud)
  renderHP(hud)
  if hud.inventoryDirty {
    renderInventory(hud)
    hud.inventoryDirty = false
  }
}

let setInventorySlot = (hud: t, ~index: int, ~slot: inventorySlot): unit => {
  if index >= 0 && index < Array.length(hud.inventorySlots) {
    hud.inventorySlots[index] = slot
    hud.inventoryDirty = true
    switch slot.itemName {
    | Some(name) =>
      let msg = if slot.quantity > 1 {
        `Inventory slot ${Int.toString(index + 1)}: ${name} x${Int.toString(slot.quantity)}`
      } else {
        `Inventory slot ${Int.toString(index + 1)}: ${name}`
      }
      Announcer.status(msg)
    | None => ()
    }
  }
}

let clearInventorySlot = (hud: t, ~index: int): unit => {
  if index >= 0 && index < Array.length(hud.inventorySlots) {
    Announcer.status(`Inventory slot ${Int.toString(index + 1)} cleared`)
    hud.inventorySlots[index] = emptySlot
    hud.inventoryDirty = true
  }
}

//  Layout 

let resize = (hud: t, ~width: float, ~height: float): unit => {
  hud.screenWidth = width
  hud.screenHeight = height

  // Zone text: top centre
  Text.setX(hud.zoneText, width /. 2.0)

  // Objective: top right
  Container.setX(hud.objectiveContainer, width -. 260.0)

  // Re-render positioned elements
  hud.inventoryDirty = true
  renderInventory(hud)
  hud.inventoryDirty = false
  renderAlert(hud)
}

//  Initialization 

let init = (hud: t, ~width: float, ~height: float): unit => {
  hud.screenWidth = width
  hud.screenHeight = height
  resize(hud, ~width, ~height)
  renderAlert(hud)
  renderInventory(hud)
}
