// SPDX-License-Identifier: PMPL-1.0-or-later
// Power Station Device - Main power supply for the facility

open Pixi
open DeviceTypes

type t = {
  name: string,
  ipAddress: string,
  securityLevel: securityLevel,
}

let make = (~name: string, ~ipAddress: string, ~securityLevel: securityLevel, ()): t => {
  // Register this as main power station
  PowerManager.setMainPowerStation(ipAddress)
  {
    name,
    ipAddress,
    securityLevel,
  }
}

let getInfo = (device: t): deviceInfo => {
  name: device.name,
  deviceType: PowerStation,
  ipAddress: device.ipAddress,
  securityLevel: device.securityLevel,
}

let createPowerStationInterface = (container: Container.t, ipAddress: string): unit => {
  let state = PowerManager.getPowerStationState(ipAddress)

  // Header
  let headerStyle = {
    "fontFamily": "monospace",
    "fontSize": 16,
    "fill": 0xFFEB3B,
    "fontWeight": "bold",
  }
  let header = Text.make({"text": "POWER STATION CONTROL", "style": headerStyle})
  Text.setX(header, 20.0)
  Text.setY(header, 15.0)
  let _ = Container.addChildText(container, header)

  // Status display background
  let statusBg = Graphics.make()
  let _ =
    statusBg
    ->Graphics.rect(20.0, 50.0, 360.0, 120.0)
    ->Graphics.fill({"color": 0x1a1a1a})
    ->Graphics.stroke({"width": 2, "color": 0x333333})
  let _ = Container.addChildGraphics(container, statusBg)

  // Power status indicator
  let statusIndicator = Graphics.make()
  let _ =
    statusIndicator
    ->Graphics.circle(50.0, 90.0, 20.0)
    ->Graphics.fill({
      "color": if state.isOnline {
        0x00ff00
      } else {
        0xff0000
      },
    })
  let _ = Container.addChildGraphics(container, statusIndicator)

  let statusLabel = Text.make({
    "text": if state.isOnline {
      "ONLINE"
    } else {
      "OFFLINE"
    },
    "style": {
      "fontSize": 18,
      "fill": if state.isOnline {
        0x00ff00
      } else {
        0xff0000
      },
      "fontFamily": "monospace",
      "fontWeight": "bold",
    },
  })
  Text.setX(statusLabel, 85.0)
  Text.setY(statusLabel, 80.0)
  let _ = Container.addChildText(container, statusLabel)

  // Output power display
  let outputLabel = Text.make({
    "text": `Output: ${Float.toString(state.outputPower)}W`,
    "style": {"fontSize": 14, "fill": 0xaaaaaa, "fontFamily": "monospace"},
  })
  Text.setX(outputLabel, 85.0)
  Text.setY(outputLabel, 110.0)
  let _ = Container.addChildText(container, outputLabel)

  // Connected UPS count
  let connectedUPS = PowerManager.getPowerStationConnectedUPS(ipAddress)
  let upsCountLabel = Text.make({
    "text": `Connected UPS Units: ${Int.toString(Array.length(connectedUPS))}`,
    "style": {"fontSize": 14, "fill": 0xaaaaaa, "fontFamily": "monospace"},
  })
  Text.setX(upsCountLabel, 85.0)
  Text.setY(upsCountLabel, 135.0)
  let _ = Container.addChildText(container, upsCountLabel)

  // Power meter visualization
  let meterBg = Graphics.make()
  let _ =
    meterBg
    ->Graphics.rect(20.0, 185.0, 360.0, 30.0)
    ->Graphics.fill({"color": 0x222222})
    ->Graphics.stroke({"width": 1, "color": 0x444444})
  let _ = Container.addChildGraphics(container, meterBg)

  let meterFill = Graphics.make()
  let fillWidth = if state.isOnline {
    340.0
  } else {
    0.0
  }
  let _ =
    meterFill
    ->Graphics.rect(25.0, 190.0, fillWidth, 20.0)
    ->Graphics.fill({"color": 0xFFEB3B})
  let _ = Container.addChildGraphics(container, meterFill)

  let meterLabel = Text.make({
    "text": "POWER OUTPUT",
    "style": {"fontSize": 10, "fill": 0x888888, "fontFamily": "monospace"},
  })
  Text.setX(meterLabel, 160.0)
  Text.setY(meterLabel, 220.0)
  let _ = Container.addChildText(container, meterLabel)

  // Power toggle button
  let btnY = 260.0
  let toggleBtn = Graphics.make()
  let _ =
    toggleBtn
    ->Graphics.rect(20.0, btnY, 150.0, 40.0)
    ->Graphics.fill({
      "color": if state.isOnline {
        0xff4444
      } else {
        0x44ff44
      },
    })
    ->Graphics.stroke({"width": 2, "color": 0x000000})
  Graphics.setEventMode(toggleBtn, "static")
  Graphics.setCursor(toggleBtn, "pointer")
  let _ = Container.addChildGraphics(container, toggleBtn)

  let toggleText = Text.make({
    "text": if state.isOnline {
      "SHUTDOWN"
    } else {
      "START"
    },
    "style": {"fontSize": 14, "fill": 0xffffff, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(toggleText), 0.5, ~y=0.5)
  Text.setX(toggleText, 95.0)
  Text.setY(toggleText, btnY +. 20.0)
  let _ = Container.addChildText(container, toggleText)

  Graphics.on(toggleBtn, "pointertap", _ => {
    let newState = !state.isOnline
    PowerManager.setPowerStationOnline(ipAddress, newState)

    // Update UI
    // Clear and redraw status indicator
    Graphics.clear(statusIndicator)->ignore
    let _ =
      statusIndicator
      ->Graphics.circle(50.0, 90.0, 20.0)
      ->Graphics.fill({
        "color": if newState {
          0x00ff00
        } else {
          0xff0000
        },
      })

    Text.setText(
      statusLabel,
      if newState {
        "ONLINE"
      } else {
        "OFFLINE"
      },
    )

    // Update meter
    Graphics.clear(meterFill)->ignore
    let newFillWidth = if newState {
      340.0
    } else {
      0.0
    }
    let _ =
      meterFill
      ->Graphics.rect(25.0, 190.0, newFillWidth, 20.0)
      ->Graphics.fill({"color": 0xFFEB3B})

    // Update button
    Graphics.clear(toggleBtn)->ignore
    let _ =
      toggleBtn
      ->Graphics.rect(20.0, btnY, 150.0, 40.0)
      ->Graphics.fill({
        "color": if newState {
          0xff4444
        } else {
          0x44ff44
        },
      })
      ->Graphics.stroke({"width": 2, "color": 0x000000})

    Text.setText(
      toggleText,
      if newState {
        "SHUTDOWN"
      } else {
        "START"
      },
    )

    // Notify all devices of power change
    PowerManager.notifyPowerChange()
  })

  // Warning label
  let warningLabel = Text.make({
    "text": " Shutting down will cut power to all non-UPS devices",
    "style": {"fontSize": 11, "fill": 0xff8800, "fontFamily": "monospace"},
  })
  Text.setX(warningLabel, 20.0)
  Text.setY(warningLabel, 315.0)
  let _ = Container.addChildText(container, warningLabel)
}

let openGUI = (device: t): DeviceWindow.t => {
  let win = DeviceWindow.make(
    ~title=`POWER STATION - ${device.name} [${device.ipAddress}]`,
    ~width=400.0,
    ~height=380.0,
    ~titleBarColor=getDeviceColor(PowerStation),
    ~backgroundColor=0x0a0a0a,
    (),
  )

  createPowerStationInterface(DeviceWindow.getContent(win), device.ipAddress)

  win
}

// Create device interface
let toDevice = (t: t): device => {
  getInfo: () => getInfo(t),
  openGUI: () => openGUI(t),
}
