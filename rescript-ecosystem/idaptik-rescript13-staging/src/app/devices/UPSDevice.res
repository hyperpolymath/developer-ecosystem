// SPDX-License-Identifier: PMPL-1.0-or-later
// UPS (Uninterruptible Power Supply) Device
// Battery backup powered by power station, provides power to connected devices

open Pixi
open DeviceTypes

type t = {
  name: string,
  ipAddress: string,
  securityLevel: securityLevel,
  connectedStationIp: string,
}

let make = (
  ~name: string,
  ~ipAddress: string,
  ~securityLevel: securityLevel,
  ~connectedStationIp: string,
  (),
): t => {
  // Register UPS connection to power station
  PowerManager.connectUPSToPowerStation(ipAddress, connectedStationIp)
  {
    name,
    ipAddress,
    securityLevel,
    connectedStationIp,
  }
}

let getInfo = (device: t): deviceInfo => {
  name: device.name,
  deviceType: UPS,
  ipAddress: device.ipAddress,
  securityLevel: device.securityLevel,
}

// Interval bindings
let setInterval: (
  unit => unit,
  int,
) => int = %raw(`function(fn, ms) { return setInterval(fn, ms); }`)
let clearInterval: int => unit = %raw(`function(id) { clearInterval(id); }`)

let createUPSInterface = (container: Container.t, ipAddress: string): int => {
  let upsState = PowerManager.getUPSState(ipAddress)

  // Header
  let headerStyle = {
    "fontFamily": "monospace",
    "fontSize": 16,
    "fill": 0x795548,
    "fontWeight": "bold",
  }
  let header = Text.make({"text": "UPS CONTROL PANEL", "style": headerStyle})
  Text.setX(header, 20.0)
  Text.setY(header, 15.0)
  let _ = Container.addChildText(container, header)

  // Status display background
  let statusBg = Graphics.make()
  let _ =
    statusBg
    ->Graphics.rect(20.0, 50.0, 360.0, 100.0)
    ->Graphics.fill({"color": 0x1a1a1a})
    ->Graphics.stroke({"width": 2, "color": 0x333333})
  let _ = Container.addChildGraphics(container, statusBg)

  // Power source indicator
  let powerSource = PowerManager.getDevicePowerSource(ipAddress)
  let sourceColor = switch powerSource {
  | PowerManager.MainsPower => 0x00ff00
  | PowerManager.UPSBattery => 0xffaa00
  | PowerManager.NoPower => 0xff0000
  }
  let sourceText = switch powerSource {
  | PowerManager.MainsPower => "AC MAINS"
  | PowerManager.UPSBattery => "BATTERY"
  | PowerManager.NoPower => "NO POWER"
  }

  let sourceIndicator = Graphics.make()
  let _ =
    sourceIndicator
    ->Graphics.circle(50.0, 85.0, 15.0)
    ->Graphics.fill({"color": sourceColor})
  let _ = Container.addChildGraphics(container, sourceIndicator)

  let sourceLabel = Text.make({
    "text": sourceText,
    "style": {"fontSize": 14, "fill": sourceColor, "fontFamily": "monospace", "fontWeight": "bold"},
  })
  Text.setX(sourceLabel, 75.0)
  Text.setY(sourceLabel, 75.0)
  let _ = Container.addChildText(container, sourceLabel)

  // Charging status
  let chargingLabel = Text.make({
    "text": if upsState.isCharging {
      " CHARGING"
    } else {
      " DISCHARGING"
    },
    "style": {
      "fontSize": 12,
      "fill": if upsState.isCharging {
        0x00ff00
      } else {
        0xffaa00
      },
      "fontFamily": "monospace",
    },
  })
  Text.setX(chargingLabel, 75.0)
  Text.setY(chargingLabel, 100.0)
  let _ = Container.addChildText(container, chargingLabel)

  // Connected devices count
  let connectedDevices = PowerManager.getUPSConnectedDevices(ipAddress)
  let devicesLabel = Text.make({
    "text": `Protected Devices: ${Int.toString(Array.length(connectedDevices))}`,
    "style": {"fontSize": 12, "fill": 0xaaaaaa, "fontFamily": "monospace"},
  })
  Text.setX(devicesLabel, 75.0)
  Text.setY(devicesLabel, 120.0)
  let _ = Container.addChildText(container, devicesLabel)

  // Battery level section
  let batteryLabel = Text.make({
    "text": "BATTERY LEVEL",
    "style": {"fontSize": 12, "fill": 0x888888, "fontFamily": "monospace"},
  })
  Text.setX(batteryLabel, 20.0)
  Text.setY(batteryLabel, 165.0)
  let _ = Container.addChildText(container, batteryLabel)

  // Battery bar background
  let batteryBg = Graphics.make()
  let _ =
    batteryBg
    ->Graphics.rect(20.0, 185.0, 300.0, 30.0)
    ->Graphics.fill({"color": 0x222222})
    ->Graphics.stroke({"width": 2, "color": 0x444444})
  let _ = Container.addChildGraphics(container, batteryBg)

  // Battery bar fill
  let batteryFill = Graphics.make()
  let batteryWidth = upsState.batteryLevel /. 100.0 *. 296.0
  let batteryColor = if upsState.batteryLevel > 50.0 {
    0x00ff00
  } else if upsState.batteryLevel > 20.0 {
    0xffaa00
  } else {
    0xff0000
  }
  let _ =
    batteryFill
    ->Graphics.rect(22.0, 187.0, batteryWidth, 26.0)
    ->Graphics.fill({"color": batteryColor})
  let _ = Container.addChildGraphics(container, batteryFill)

  // Battery percentage
  let batteryPercent = Text.make({
    "text": `${Float.toFixed(upsState.batteryLevel, ~digits=1)}%`,
    "style": {"fontSize": 14, "fill": 0xffffff, "fontFamily": "monospace", "fontWeight": "bold"},
  })
  Text.setX(batteryPercent, 330.0)
  Text.setY(batteryPercent, 190.0)
  let _ = Container.addChildText(container, batteryPercent)

  // Connected devices list
  let listLabel = Text.make({
    "text": "PROTECTED DEVICES:",
    "style": {"fontSize": 11, "fill": 0x888888, "fontFamily": "monospace"},
  })
  Text.setX(listLabel, 20.0)
  Text.setY(listLabel, 230.0)
  let _ = Container.addChildText(container, listLabel)

  // List background
  let listBg = Graphics.make()
  let _ =
    listBg
    ->Graphics.rect(20.0, 250.0, 360.0, 80.0)
    ->Graphics.fill({"color": 0x0a0a0a})
    ->Graphics.stroke({"width": 1, "color": 0x333333})
  let _ = Container.addChildGraphics(container, listBg)

  // Show connected devices
  Array.forEachWithIndex(connectedDevices, (deviceIp, i) => {
    if i < 4 {
      // Show max 4 devices
      let deviceText = Text.make({
        "text": ` ${deviceIp}`,
        "style": {"fontSize": 11, "fill": 0x00ff00, "fontFamily": "monospace"},
      })
      Text.setX(deviceText, 30.0)
      Text.setY(deviceText, 255.0 +. Int.toFloat(i) *. 18.0)
      let _ = Container.addChildText(container, deviceText)
    }
  })

  if Array.length(connectedDevices) == 0 {
    let noDevicesText = Text.make({
      "text": "No devices connected",
      "style": {"fontSize": 11, "fill": 0x666666, "fontFamily": "monospace", "fontStyle": "italic"},
    })
    Text.setX(noDevicesText, 30.0)
    Text.setY(noDevicesText, 280.0)
    let _ = Container.addChildText(container, noDevicesText)
  }

  // Runtime estimate
  let runtimeMinutes = if upsState.isCharging {
    999 // Infinite when charging
  } else {
    let deviceCount = Array.length(connectedDevices)
    if deviceCount > 0 {
      Float.toInt(upsState.batteryLevel /. (Int.toFloat(deviceCount) *. (1.0 /. 30.0) *. 60.0))
    } else {
      999
    }
  }
  let runtimeText = if runtimeMinutes >= 999 {
    "Runtime: "
  } else {
    `Runtime: ~${Int.toString(runtimeMinutes)} min`
  }
  let runtimeLabel = Text.make({
    "text": runtimeText,
    "style": {"fontSize": 12, "fill": 0xaaaaaa, "fontFamily": "monospace"},
  })
  Text.setX(runtimeLabel, 20.0)
  Text.setY(runtimeLabel, 345.0)
  let _ = Container.addChildText(container, runtimeLabel)

  // Update interval for battery display
  let intervalId = setInterval(() => {
    let currentState = PowerManager.getUPSState(ipAddress)
    let currentSource = PowerManager.getDevicePowerSource(ipAddress)

    // Update source indicator
    let newSourceColor = switch currentSource {
    | PowerManager.MainsPower => 0x00ff00
    | PowerManager.UPSBattery => 0xffaa00
    | PowerManager.NoPower => 0xff0000
    }
    let newSourceText = switch currentSource {
    | PowerManager.MainsPower => "AC MAINS"
    | PowerManager.UPSBattery => "BATTERY"
    | PowerManager.NoPower => "NO POWER"
    }

    Graphics.clear(sourceIndicator)->ignore
    let _ =
      sourceIndicator
      ->Graphics.circle(50.0, 85.0, 15.0)
      ->Graphics.fill({"color": newSourceColor})
    Text.setText(sourceLabel, newSourceText)

    // Update charging status
    Text.setText(
      chargingLabel,
      if currentState.isCharging {
        " CHARGING"
      } else {
        " DISCHARGING"
      },
    )

    // Update battery bar
    let newBatteryWidth = currentState.batteryLevel /. 100.0 *. 296.0
    let newBatteryColor = if currentState.batteryLevel > 50.0 {
      0x00ff00
    } else if currentState.batteryLevel > 20.0 {
      0xffaa00
    } else {
      0xff0000
    }
    Graphics.clear(batteryFill)->ignore
    let _ =
      batteryFill
      ->Graphics.rect(22.0, 187.0, newBatteryWidth, 26.0)
      ->Graphics.fill({"color": newBatteryColor})

    // Update percentage
    Text.setText(batteryPercent, `${Float.toFixed(currentState.batteryLevel, ~digits=1)}%`)
  }, 500) // Update twice per second

  intervalId
}

let openGUI = (device: t): DeviceWindow.t => {
  let win = DeviceWindow.make(
    ~title=`UPS - ${device.name} [${device.ipAddress}]`,
    ~width=400.0,
    ~height=400.0,
    ~titleBarColor=getDeviceColor(UPS),
    ~backgroundColor=0x0a0a0a,
    (),
  )

  let intervalId = createUPSInterface(DeviceWindow.getContent(win), device.ipAddress)

  // Clean up interval when window is closed
  DeviceWindow.setOnClose(win, () => {
    clearInterval(intervalId)
  })

  win
}

// Create device interface
let toDevice = (t: t): device => {
  getInfo: () => getInfo(t),
  openGUI: () => openGUI(t),
}
