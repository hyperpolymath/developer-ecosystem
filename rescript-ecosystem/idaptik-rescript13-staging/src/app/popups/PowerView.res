// SPDX-License-Identifier: PMPL-1.0-or-later
// Power View - Debug screen showing power infrastructure

open Pixi
open PixiUI
open DeviceTypes

// Asset bundles for this popup
let assetBundles = ["desktop"]

// Interval bindings
let setInterval: (unit => unit, int) => int = %raw(`function(fn, ms) { return setInterval(fn, ms); }`)
let clearInterval: int => unit = %raw(`function(id) { clearInterval(id); }`)

// Power node in the diagram
module PowerNode = {
  type t = {
    container: Container.t,
    ipAddress: string,
    statusIndicator: Graphics.t,
    statusText: Text.t,
    powerButton: Graphics.t,
    powerButtonText: Text.t,
  }

  let make = (ipAddress: string, name: string, deviceType: deviceType, x: float, y: float): t => {
    let container = Container.make()
    Container.setX(container, x)
    Container.setY(container, y)

    // Node background
    let bg = Graphics.make()
    let bgColor = getDeviceColor(deviceType)
    let _ = bg
      ->Graphics.roundRect(-60.0, -30.0, 120.0, 80.0, 8.0)
      ->Graphics.fill({"color": bgColor, "alpha": 0.3})
      ->Graphics.stroke({"width": 2, "color": bgColor})
    let _ = Container.addChildGraphics(container, bg)

    // Status indicator
    let statusIndicator = Graphics.make()
    let hasPower = PowerManager.deviceHasPower(ipAddress)
    let isShutdown = PowerManager.isDeviceShutdown(ipAddress)
    let indicatorColor = if isShutdown {
      0x444444  // Grey when shutdown
    } else if hasPower {
      0x00ff00  // Green when powered
    } else {
      0xff0000  // Red when no power
    }
    let _ = statusIndicator
      ->Graphics.circle(40.0, -15.0, 8.0)
      ->Graphics.fill({"color": indicatorColor})
    let _ = Container.addChildGraphics(container, statusIndicator)

    // Device name
    let nameText = Text.make({
      "text": name,
      "style": {"fontSize": 10, "fill": 0xffffff, "fontFamily": "monospace", "fontWeight": "bold"},
    })
    ObservablePoint.set(Text.anchor(nameText), 0.5, ~y=0.5)
    Text.setX(nameText, 0.0)
    Text.setY(nameText, -10.0)
    let _ = Container.addChildText(container, nameText)

    // IP address
    let ipText = Text.make({
      "text": ipAddress,
      "style": {"fontSize": 8, "fill": 0xaaaaaa, "fontFamily": "monospace"},
    })
    ObservablePoint.set(Text.anchor(ipText), 0.5, ~y=0.5)
    Text.setX(ipText, 0.0)
    Text.setY(ipText, 5.0)
    let _ = Container.addChildText(container, ipText)

    // Power status text
    let powerSource = PowerManager.getDevicePowerSource(ipAddress)
    let statusStr = if isShutdown {
      "SHUTDOWN"
    } else {
      switch powerSource {
      | PowerManager.MainsPower => "MAINS"
      | PowerManager.UPSBattery => "BATTERY"
      | PowerManager.NoPower => "NO POWER"
      }
    }
    let statusColor = if isShutdown {
      0x888888
    } else if hasPower {
      0x00ff00
    } else {
      0xff0000
    }
    let statusText = Text.make({
      "text": statusStr,
      "style": {"fontSize": 8, "fill": statusColor, "fontFamily": "monospace"},
    })
    ObservablePoint.set(Text.anchor(statusText), 0.5, ~y=0.5)
    Text.setX(statusText, 0.0)
    Text.setY(statusText, 18.0)
    let _ = Container.addChildText(container, statusText)

    // Power button (for devices that can be shutdown - not power station or UPS)
    let powerButton = Graphics.make()
    let powerButtonText = Text.make({
      "text": if isShutdown { "BOOT" } else { "SHUTDOWN" },
      "style": {"fontSize": 7, "fill": 0xffffff, "fontFamily": "monospace"},
    })

    // Only show power button for non-infrastructure devices
    let showButton = switch deviceType {
    | PowerStation | UPS => false
    | _ => true
    }

    if showButton {
      let btnColor = if isShutdown { 0x00aa00 } else { 0xaa0000 }
      let _ = powerButton
        ->Graphics.roundRect(-35.0, 30.0, 70.0, 18.0, 4.0)
        ->Graphics.fill({"color": btnColor})
        ->Graphics.stroke({"width": 1, "color": 0x333333})
      Graphics.setEventMode(powerButton, "static")
      Graphics.setCursor(powerButton, "pointer")
      let _ = Container.addChildGraphics(container, powerButton)

      ObservablePoint.set(Text.anchor(powerButtonText), 0.5, ~y=0.5)
      Text.setX(powerButtonText, 0.0)
      Text.setY(powerButtonText, 39.0)
      let _ = Container.addChildText(container, powerButtonText)

      // Click handler for power button
      Graphics.on(powerButton, "pointertap", _ => {
        let currentlyShutdown = PowerManager.isDeviceShutdown(ipAddress)
        if currentlyShutdown {
          // Boot the device
          if PowerManager.deviceHasPower(ipAddress) {
            PowerManager.bootDevice(ipAddress)
          } else {
            ()
          }
        } else {
          // Shutdown the device
          PowerManager.manualShutdownDevice(ipAddress)
        }
      })
    }

    {container, ipAddress, statusIndicator, statusText, powerButton, powerButtonText}
  }

  let update = (node: t): unit => {
    let hasPower = PowerManager.deviceHasPower(node.ipAddress)
    let isShutdown = PowerManager.isDeviceShutdown(node.ipAddress)
    let powerSource = PowerManager.getDevicePowerSource(node.ipAddress)

    // Update indicator color
    Graphics.clear(node.statusIndicator)->ignore
    let indicatorColor = if isShutdown {
      0x444444  // Grey when shutdown
    } else if hasPower {
      0x00ff00  // Green when powered
    } else {
      0xff0000  // Red when no power
    }
    let _ = node.statusIndicator
      ->Graphics.circle(40.0, -15.0, 8.0)
      ->Graphics.fill({"color": indicatorColor})

    // Update status text
    let statusStr = if isShutdown {
      "SHUTDOWN"
    } else {
      switch powerSource {
      | PowerManager.MainsPower => "MAINS"
      | PowerManager.UPSBattery => "BATTERY"
      | PowerManager.NoPower => "NO POWER"
      }
    }
    Text.setText(node.statusText, statusStr)

    // Update button appearance
    Graphics.clear(node.powerButton)->ignore
    let btnColor = if isShutdown { 0x00aa00 } else { 0xaa0000 }
    let _ = node.powerButton
      ->Graphics.roundRect(-35.0, 30.0, 70.0, 18.0, 4.0)
      ->Graphics.fill({"color": btnColor})
      ->Graphics.stroke({"width": 1, "color": 0x333333})
    Text.setText(node.powerButtonText, if isShutdown { "BOOT" } else { "SHUTDOWN" })
  }
}

// Screen state
type screenState = {
  container: Container.t,
  mutable intervalId: option<int>,
}

// Create the power view
let make = (): Navigation.appScreen => {
  let container = Container.make()
  let networkManager = GlobalNetworkManager.get()

  // Desktop background
  let desktopBg = Graphics.make()
  Graphics.setEventMode(desktopBg, "static")
  let _ = Container.addChildGraphics(container, desktopBg)

  // Title
  let title = Text.make({
    "text": "POWER INFRASTRUCTURE",
    "style": {"fontSize": 24, "fill": 0xFFEB3B, "fontFamily": "monospace", "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(title), 0.5, ~y=0.0)
  let _ = Container.addChildText(container, title)

  // Close button
  let closeButton = Button.make(~options={text: "Back to World", width: 140.0, height: 40.0}, ())
  Signal.connect(FancyButton.onPress(closeButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.dismissPopup(engine.navigation)
    | None => ()
    }
  })
  let _ = Container.addChild(container, FancyButton.toContainer(closeButton))

  // Connection lines container
  let linesContainer = Graphics.make()
  let _ = Container.addChildGraphics(container, linesContainer)

  // Create power nodes
  let nodes = ref([])

  // Power Station (center-left)
  let stationNode = PowerNode.make("192.168.1.250", "MAIN-PWR-STATION", PowerStation, 150.0, 300.0)
  let _ = Container.addChild(container, stationNode.container)
  nodes := Array.concat(nodes.contents, [stationNode])

  // UPS (center)
  let upsNode = PowerNode.make("192.168.1.251", "UPS-CRITICAL", UPS, 350.0, 300.0)
  let _ = Container.addChild(container, upsNode.container)
  nodes := Array.concat(nodes.contents, [upsNode])

  // UPS Battery indicator
  let batteryBg = Graphics.make()
  let _ = Container.addChildGraphics(container, batteryBg)
  let batteryFill = Graphics.make()
  let _ = Container.addChildGraphics(container, batteryFill)
  let batteryText = Text.make({
    "text": "100%",
    "style": {"fontSize": 12, "fill": 0xffffff, "fontFamily": "monospace", "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(batteryText), 0.5, ~y=0.5)
  let _ = Container.addChildText(container, batteryText)

  // Devices powered by UPS (right side)
  let upsDevices = PowerManager.getUPSConnectedDevices("192.168.1.251")
  let upsDeviceNodes = Array.mapWithIndex(upsDevices, (ip, i) => {
    let deviceOpt = NetworkManager.getDevice(networkManager, ip)
    let (name, devType) = switch deviceOpt {
    | Some(d) =>
      let info = d.getInfo()
      (info.name, info.deviceType)
    | None => (ip, Server)
    }
    let yPos = 150.0 +. Int.toFloat(i) *. 80.0
    let node = PowerNode.make(ip, name, devType, 550.0, yPos)
    let _ = Container.addChild(container, node.container)
    nodes := Array.concat(nodes.contents, [node])
    node
  })

  // Non-UPS devices (bottom)
  let allDevices = NetworkManager.getAllDevices(networkManager)
  let nonUpsDevices = Array.filter(allDevices, device => {
    let info = device.getInfo()
    let ip = info.ipAddress
    // Exclude power devices and UPS-connected devices
    info.deviceType != PowerStation &&
    info.deviceType != UPS &&
    !Array.includes(upsDevices, ip)
  })

  // Only show first 6 non-UPS devices to fit screen
  let limitedNonUps = Array.slice(nonUpsDevices, ~start=0, ~end=6)
  let nonUpsNodes = Array.mapWithIndex(limitedNonUps, (device, i) => {
    let info = device.getInfo()
    let xPos = 100.0 +. Int.toFloat(i) *. 120.0
    let node = PowerNode.make(info.ipAddress, info.name, info.deviceType, xPos, 500.0)
    let _ = Container.addChild(container, node.container)
    nodes := Array.concat(nodes.contents, [node])
    node
  })

  // Legend
  let legendY = 80.0
  let legendItems = [
    (0x00ff00, "Powered (Mains)"),
    (0xffaa00, "Powered (Battery)"),
    (0xff0000, "No Power"),
    (0x444444, "Shutdown"),
  ]
  Array.forEachWithIndex(legendItems, ((color, label), i) => {
    let dot = Graphics.make()
    let _ = dot
      ->Graphics.circle(50.0 +. Int.toFloat(i) *. 150.0, legendY, 6.0)
      ->Graphics.fill({"color": color})
    let _ = Container.addChildGraphics(container, dot)

    let labelText = Text.make({
      "text": label,
      "style": {"fontSize": 10, "fill": 0xaaaaaa, "fontFamily": "monospace"},
    })
    Text.setX(labelText, 62.0 +. Int.toFloat(i) *. 150.0)
    Text.setY(labelText, legendY -. 6.0)
    let _ = Container.addChildText(container, labelText)
  })

  // State for interval
  let screenState = {
    container,
    intervalId: None,
  }

  {
    container,
    prepare: None,
    show: Some(async () => {
      Container.setAlpha(container, 0.0)

      // Start update interval
      let intervalId = setInterval(() => {
        // Update all nodes
        Array.forEach(nodes.contents, PowerNode.update)

        // Update battery display
        let batteryLevel = PowerManager.getUPSBatteryLevel("192.168.1.251")
        Text.setText(batteryText, `${Float.toFixed(batteryLevel, ~digits=0)}%`)

        let batteryColor = if batteryLevel > 50.0 {
          0x00ff00
        } else if batteryLevel > 20.0 {
          0xffaa00
        } else {
          0xff0000
        }

        Graphics.clear(batteryFill)->ignore
        let fillWidth = batteryLevel /. 100.0 *. 76.0
        let _ = batteryFill
          ->Graphics.rect(312.0, 355.0, fillWidth, 20.0)
          ->Graphics.fill({"color": batteryColor})
      }, 200)

      screenState.intervalId = Some(intervalId)

      await Motion.animateAsync(container, {"alpha": 1.0}, {duration: 0.5, ease: "easeOut"})
    }),
    hide: Some(async () => {
      // Clear interval
      switch screenState.intervalId {
      | Some(id) => clearInterval(id)
      | None => ()
      }
      screenState.intervalId = None

      await Motion.animateAsync(container, {"alpha": 0.0}, {duration: 0.3})
    }),
    pause: None,
    resume: None,
    reset: None,
    update: Some(_time => ()),
    resize: Some((width, height) => {
      let _ = Graphics.clear(desktopBg)
      let _ = desktopBg
        ->Graphics.rect(0.0, 0.0, width, height)
        ->Graphics.fill({"color": 0x0a0a0a, "alpha": 1.0})

      // Grid pattern
      let gridGraphics = Graphics.make()
      let x = ref(0.0)
      while x.contents < width {
        let _ = gridGraphics
          ->Graphics.moveTo(x.contents, 0.0)
          ->Graphics.lineTo(x.contents, height)
          ->Graphics.stroke({"width": 1, "color": 0x1a1a1a, "alpha": 0.3})
        x := x.contents +. 50.0
      }
      let y = ref(0.0)
      while y.contents < height {
        let _ = gridGraphics
          ->Graphics.moveTo(0.0, y.contents)
          ->Graphics.lineTo(width, y.contents)
          ->Graphics.stroke({"width": 1, "color": 0x1a1a1a, "alpha": 0.3})
        y := y.contents +. 50.0
      }
      let _ = Graphics.addChild(desktopBg, gridGraphics)

      // Position title
      Text.setX(title, width /. 2.0)
      Text.setY(title, 20.0)

      // Position close button
      FancyButton.setX(closeButton, width -. 80.0)
      FancyButton.setY(closeButton, 30.0)

      // Draw connection lines
      Graphics.clear(linesContainer)->ignore

      // Station to UPS line
      let _ = linesContainer
        ->Graphics.moveTo(210.0, 300.0)
        ->Graphics.lineTo(290.0, 300.0)
        ->Graphics.stroke({"width": 3, "color": 0xFFEB3B, "alpha": 0.8})

      // UPS to devices lines
      Array.forEachWithIndex(upsDeviceNodes, (node, _i) => {
        let nodeY = Container.y(node.container)
        let _ = linesContainer
          ->Graphics.moveTo(410.0, 300.0)
          ->Graphics.lineTo(450.0, 300.0)
          ->Graphics.lineTo(450.0, nodeY)
          ->Graphics.lineTo(490.0, nodeY)
          ->Graphics.stroke({"width": 2, "color": 0x795548, "alpha": 0.6})
      })

      // Station to non-UPS devices lines
      Array.forEachWithIndex(nonUpsNodes, (node, _i) => {
        let nodeX = Container.x(node.container)
        let _ = linesContainer
          ->Graphics.moveTo(150.0, 330.0)
          ->Graphics.lineTo(150.0, 420.0)
          ->Graphics.lineTo(nodeX, 420.0)
          ->Graphics.lineTo(nodeX, 470.0)
          ->Graphics.stroke({"width": 2, "color": 0xFFEB3B, "alpha": 0.4})
      })

      // Battery display background
      Graphics.clear(batteryBg)->ignore
      let _ = batteryBg
        ->Graphics.rect(310.0, 353.0, 80.0, 24.0)
        ->Graphics.fill({"color": 0x222222})
        ->Graphics.stroke({"width": 1, "color": 0x444444})
      // Battery terminal
      let _ = batteryBg
        ->Graphics.rect(390.0, 359.0, 5.0, 12.0)
        ->Graphics.fill({"color": 0x444444})

      // Position battery text
      Text.setX(batteryText, 350.0)
      Text.setY(batteryText, 365.0)
    }),
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
