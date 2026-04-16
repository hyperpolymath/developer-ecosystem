// SPDX-License-Identifier: PMPL-1.0-or-later
// Network Router Device

open Pixi
open DeviceTypes

type t = {
  name: string,
  ipAddress: string,
  securityLevel: securityLevel,
}

let make = (~name: string, ~ipAddress: string, ~securityLevel: securityLevel, ()): t => {
  name,
  ipAddress,
  securityLevel,
}

// Interval bindings
let setInterval: (
  unit => unit,
  int,
) => int = %raw(`function(fn, ms) { return setInterval(fn, ms); }`)
let clearInterval: int => unit = %raw(`function(id) { clearInterval(id); }`)
let getCurrentTime: unit => float = %raw(`function() { return Date.now(); }`)

// ============================================
// Router Uptime Module
// ============================================

module RouterUptime = {
  let bootTimes: dict<float> = Dict.make()

  let recordBoot = (ip: string): unit => {
    Dict.set(bootTimes, ip, getCurrentTime())
  }

  let getUptime = (ip: string): option<float> => {
    switch Dict.get(bootTimes, ip) {
    | Some(bootTime) => Some(getCurrentTime() -. bootTime)
    | None => None
    }
  }

  let initialize = (ip: string): unit => {
    // Only set boot time if not already set
    switch Dict.get(bootTimes, ip) {
    | None => recordBoot(ip)
    | Some(_) => ()
    }
  }
}

let getInfo = (device: t): deviceInfo => {
  name: device.name,
  deviceType: Router,
  ipAddress: device.ipAddress,
  securityLevel: device.securityLevel,
}

// Create a simple input background
let createInputBg = (~width: float=200.0, ()): Graphics.t => {
  let bg = Graphics.make()
  let _ =
    bg
    ->Graphics.rect(0.0, 0.0, width, 25.0)
    ->Graphics.fill({"color": 0xffffff})
    ->Graphics.stroke({"width": 1, "color": 0x000000})
  bg
}

// Network manager interface type for router access
type networkManagerInterface = {
  getConnectedDevices: unit => array<(string, string, string)>,
  getConfiguredDns: unit => string,
  setConfiguredDns: string => unit,
}

// Global network manager reference (set by NetworkDesktop)
let globalNetworkManagerRef: ref<option<networkManagerInterface>> = ref(None)

let setGlobalNetworkManager = (manager: networkManagerInterface): unit => {
  globalNetworkManagerRef := Some(manager)
}

let createRouterInterface = (container: Container.t, ipAddress: string): (unit => unit, int) => {
  // Initialize router uptime
  RouterUptime.initialize(ipAddress)

  let headerStyle = {"fontFamily": "Arial", "fontSize": 14, "fill": 0xffffff, "fontWeight": "bold"}
  let labelStyle = {"fontFamily": "Arial", "fontSize": 12, "fill": 0xdddddd}
  let _dataStyle = {"fontFamily": "monospace", "fontSize": 10, "fill": 0xaaaaaa}

  // Traffic simulation state
  let uploadSpeed = ref(500.0) // KB/s
  let downloadSpeed = ref(1200.0) // KB/s

  // ============================================
  // Stats Section (Y: 10)
  // ============================================
  let statsY = 10.0
  let statsBg = Graphics.make()
  let _ =
    statsBg
    ->Graphics.rect(10.0, statsY, 580.0, 50.0)
    ->Graphics.fill({"color": 0x2a2a2a})
    ->Graphics.stroke({"width": 1, "color": 0x444444})
  let _ = Container.addChildGraphics(container, statsBg)

  // Status indicator
  let isOnline = !PowerManager.isDeviceShutdown(ipAddress)
  let statusDot = Graphics.make()
  statusDot
  ->Graphics.circle(25.0, statsY +. 15.0, 6.0)
  ->Graphics.fill({
    "color": if isOnline {
      0x00ff00
    } else {
      0x666666
    },
  })
  ->ignore
  let _ = Container.addChildGraphics(container, statusDot)

  let statusLabel = Text.make({
    "text": "STATUS",
    "style": {"fontFamily": "Arial", "fontSize": 10, "fill": 0xdddddd},
  })
  Text.setX(statusLabel, 40.0)
  Text.setY(statusLabel, statsY +. 5.0)
  let _ = Container.addChildText(container, statusLabel)

  let statusText = Text.make({
    "text": if isOnline {
      "ONLINE"
    } else {
      "OFFLINE"
    },
    "style": {
      "fontFamily": "monospace",
      "fontSize": 14,
      "fill": if isOnline {
        0x00ff00
      } else {
        0xff0000
      },
    },
  })
  Text.setX(statusText, 40.0)
  Text.setY(statusText, statsY +. 20.0)
  let _ = Container.addChildText(container, statusText)

  // Traffic stat
  let trafficLabel = Text.make({
    "text": "TRAFFIC",
    "style": {"fontFamily": "Arial", "fontSize": 10, "fill": 0xdddddd},
  })
  Text.setX(trafficLabel, 230.0)
  Text.setY(trafficLabel, statsY +. 5.0)
  let _ = Container.addChildText(container, trafficLabel)

  let trafficText = Text.make({
    "text": "500 KB/s 1.2 MB/s",
    "style": {"fontFamily": "monospace", "fontSize": 14, "fill": 0x00aaff},
  })
  Text.setX(trafficText, 230.0)
  Text.setY(trafficText, statsY +. 20.0)
  let _ = Container.addChildText(container, trafficText)

  // Uptime stat
  let uptimeLabel = Text.make({
    "text": "UPTIME",
    "style": {"fontFamily": "Arial", "fontSize": 10, "fill": 0xdddddd},
  })
  Text.setX(uptimeLabel, 450.0)
  Text.setY(uptimeLabel, statsY +. 5.0)
  let _ = Container.addChildText(container, uptimeLabel)

  let uptimeText = Text.make({
    "text": "0d 0h 0m",
    "style": {"fontFamily": "monospace", "fontSize": 14, "fill": 0x00ff00},
  })
  Text.setX(uptimeText, 450.0)
  Text.setY(uptimeText, statsY +. 20.0)
  let _ = Container.addChildText(container, uptimeText)

  // Get current DNS from network manager
  let currentDns = switch globalNetworkManagerRef.contents {
  | Some(nm) => nm.getConfiguredDns()
  | None => "8.8.8.8"
  }

  // ============================================
  // Config Section (Y: 70)
  // ============================================
  let configY = 70.0
  let configHeader = Text.make({"text": "CONFIGURATION", "style": headerStyle})
  Text.setX(configHeader, 20.0)
  Text.setY(configHeader, configY)
  let _ = Container.addChildText(container, configHeader)

  // DNS Settings
  let dnsY = configY +. 30.0
  let dnsLabel = Text.make({"text": "DNS Server:", "style": labelStyle})
  Text.setX(dnsLabel, 20.0)
  Text.setY(dnsLabel, dnsY)
  let _ = Container.addChildText(container, dnsLabel)

  // Use @pixi/ui Input component
  let dnsInput = PixiUI.Input.make({
    "bg": createInputBg(),
    "placeholder": "Enter DNS...",
    "value": currentDns,
    "textStyle": {"fontSize": 11, "fill": 0x000000},
    "padding": 5,
  })
  PixiUI.Input.setX(dnsInput, 130.0)
  PixiUI.Input.setY(dnsInput, dnsY -. 5.0)
  let _ = Container.addChild(container, PixiUI.Input.toContainer(dnsInput))

  // Update DNS when Enter is pressed
  PixiUI.Signal.connect(PixiUI.Input.onEnter(dnsInput), newDns => {
    switch globalNetworkManagerRef.contents {
    | Some(nm) => nm.setConfiguredDns(newDns)
    | None => ()
    }
  })

  // Apply button for DNS (positioned to the right of input)
  let applyBtn = Graphics.make()
  let _ =
    applyBtn
    ->Graphics.rect(340.0, dnsY -. 5.0, 60.0, 25.0)
    ->Graphics.fill({"color": 0x0078d4})
    ->Graphics.stroke({"width": 1, "color": 0x005a9e})
  Graphics.setEventMode(applyBtn, "static")
  Graphics.setCursor(applyBtn, "pointer")
  let _ = Container.addChildGraphics(container, applyBtn)

  let applyText = Text.make({
    "text": "Apply",
    "style": {"fontSize": 10, "fill": 0xffffff, "fontWeight": "bold"},
  })
  Text.setX(applyText, 355.0)
  Text.setY(applyText, dnsY)
  let _ = Graphics.addChild(applyBtn, applyText)

  Graphics.on(applyBtn, "pointertap", _ => {
    let newDns = PixiUI.Input.value(dnsInput)
    switch globalNetworkManagerRef.contents {
    | Some(nm) => nm.setConfiguredDns(newDns)
    | None => ()
    }
  })

  // DHCP Toggle
  let dhcpY = dnsY +. 40.0
  let dhcpLabel = Text.make({"text": "DHCP:", "style": labelStyle})
  Text.setX(dhcpLabel, 20.0)
  Text.setY(dhcpLabel, dhcpY)
  let _ = Container.addChildText(container, dhcpLabel)

  let dhcpBtn = Graphics.make()
  let _ =
    dhcpBtn
    ->Graphics.rect(130.0, dhcpY -. 5.0, 80.0, 25.0)
    ->Graphics.fill({"color": 0x00ff00})
    ->Graphics.stroke({"width": 1, "color": 0x000000})
  Graphics.setEventMode(dhcpBtn, "static")
  Graphics.setCursor(dhcpBtn, "pointer")
  let _ = Container.addChildGraphics(container, dhcpBtn)

  let dhcpText = Text.make({
    "text": "ENABLED",
    "style": {"fontSize": 11, "fill": 0x000000, "fontWeight": "bold"},
  })
  Text.setX(dhcpText, 138.0)
  Text.setY(dhcpText, dhcpY)
  let _ = Graphics.addChild(dhcpBtn, dhcpText)

  // ============================================
  // Connected Devices Section (Y: 180)
  // ============================================
  let devicesY = 180.0
  let devHeader = Text.make({"text": "CONNECTED DEVICES", "style": headerStyle})
  Text.setX(devHeader, 20.0)
  Text.setY(devHeader, devicesY)
  let _ = Container.addChildText(container, devHeader)

  // Column headers with STATUS
  let colHeaders = Text.make({
    "text": "  NAME                 IP ADDRESS        STATUS",
    "style": {"fontSize": 10, "fill": 0x888888, "fontFamily": "monospace"},
  })
  Text.setX(colHeaders, 20.0)
  Text.setY(colHeaders, devicesY +. 22.0)
  let _ = Container.addChildText(container, colHeaders)

  // Container for device list (will be updated)
  let devicesContainer = Container.make()
  Container.setY(devicesContainer, devicesY +. 40.0)
  let _ = Container.addChild(container, devicesContainer)

  // ============================================
  // Routing Table Section (Y: 350)
  // ============================================
  let routingY = 350.0
  let routingHeader = Text.make({"text": "ROUTING TABLE", "style": headerStyle})
  Text.setX(routingHeader, 20.0)
  Text.setY(routingHeader, routingY)
  let _ = Container.addChildText(container, routingHeader)

  // Column headers
  let routingColHeaders = Text.make({
    "text": "DESTINATION          GATEWAY            INTERFACE",
    "style": {"fontSize": 10, "fill": 0x888888, "fontFamily": "monospace"},
  })
  Text.setX(routingColHeaders, 20.0)
  Text.setY(routingColHeaders, routingY +. 22.0)
  let _ = Container.addChildText(container, routingColHeaders)

  // Static routing table entries
  let routes = [
    ("0.0.0.0/0", "10.0.0.1", "WAN"),
    ("192.168.1.0/24", "0.0.0.0", "LAN"),
    ("10.0.0.0/24", "0.0.0.0", "VLAN"),
  ]

  let routingContainer = Container.make()
  Container.setY(routingContainer, routingY +. 40.0)
  let _ = Container.addChild(container, routingContainer)

  Array.forEachWithIndex(routes, (route, idx) => {
    let (dest, gateway, iface) = route
    let destStr = String.padEnd(dest, 21, " ")
    let gatewayStr = String.padEnd(gateway, 19, " ")
    let routeText = Text.make({
      "text": `${destStr}${gatewayStr}${iface}`,
      "style": {"fontSize": 10, "fill": 0xaaaaaa, "fontFamily": "monospace"},
    })
    Text.setX(routeText, 20.0)
    Text.setY(routeText, Int.toFloat(idx) *. 16.0)
    let _ = Container.addChildText(routingContainer, routeText)
  })

  // ============================================
  // Power Button (Y: 460)
  // ============================================
  let powerBtnY = 460.0
  let powerBtn = Graphics.make()
  let isShutdown = PowerManager.isDeviceShutdown(ipAddress)
  let powerBtnColor = if isShutdown {
    0x00aa00
  } else {
    0xaa0000
  }
  let _ =
    powerBtn
    ->Graphics.rect(490.0, powerBtnY, 100.0, 30.0)
    ->Graphics.fill({"color": powerBtnColor})
    ->Graphics.stroke({"width": 1, "color": 0x000000})
  Graphics.setEventMode(powerBtn, "static")
  Graphics.setCursor(powerBtn, "pointer")
  let _ = Container.addChildGraphics(container, powerBtn)

  let powerText = Text.make({
    "text": if isShutdown {
      "POWER ON"
    } else {
      "POWER OFF"
    },
    "style": {"fontSize": 10, "fill": 0xffffff, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(powerText), 0.5, ~y=0.5)
  Text.setX(powerText, 540.0)
  Text.setY(powerText, powerBtnY +. 15.0)
  let _ = Container.addChildText(container, powerText)

  Graphics.on(powerBtn, "pointertap", _ => {
    let currentlyShutdown = PowerManager.isDeviceShutdown(ipAddress)
    if currentlyShutdown {
      // Boot the device
      if PowerManager.deviceHasPower(ipAddress) {
        PowerManager.bootDevice(ipAddress)
        RouterUptime.recordBoot(ipAddress)
        Text.setText(powerText, "POWER OFF")
        Graphics.clear(powerBtn)->ignore
        let _ =
          powerBtn
          ->Graphics.rect(490.0, powerBtnY, 100.0, 30.0)
          ->Graphics.fill({"color": 0xaa0000})
          ->Graphics.stroke({"width": 1, "color": 0x000000})
      }
    } else {
      // Shutdown the device
      PowerManager.manualShutdownDevice(ipAddress)
      Text.setText(powerText, "POWER ON")
      Graphics.clear(powerBtn)->ignore
      let _ =
        powerBtn
        ->Graphics.rect(490.0, powerBtnY, 100.0, 30.0)
        ->Graphics.fill({"color": 0x00aa00})
        ->Graphics.stroke({"width": 1, "color": 0x000000})
    }
  })

  // ============================================
  // Update Functions
  // ============================================

  let updateStats = (): unit => {
    // Update status
    let isOnline = !PowerManager.isDeviceShutdown(ipAddress)
    Graphics.clear(statusDot)->ignore
    statusDot
    ->Graphics.circle(25.0, statsY +. 15.0, 6.0)
    ->Graphics.fill({
      "color": if isOnline {
        0x00ff00
      } else {
        0x666666
      },
    })
    ->ignore
    Text.setText(
      statusText,
      if isOnline {
        "ONLINE"
      } else {
        "OFFLINE"
      },
    )

    // Get REAL traffic from active transfers
    let (realUploadMBps, realDownloadMBps) = NetworkTransfer.getRouterTraffic(ipAddress)

    // Add small background noise for realism (10-50 KB/s = 0.01-0.05 MB/s)
    let noise = Random.float(0.01, 0.05)
    uploadSpeed := realUploadMBps +. noise
    downloadSpeed := realDownloadMBps +. noise

    // Format with units
    let upStr = if uploadSpeed.contents >= 1.0 {
      `${Float.toFixed(uploadSpeed.contents, ~digits=1)} MB/s`
    } else {
      `${Int.toString(Float.toInt(uploadSpeed.contents *. 1024.0))} KB/s`
    }

    let downStr = if downloadSpeed.contents >= 1.0 {
      `${Float.toFixed(downloadSpeed.contents, ~digits=1)} MB/s`
    } else {
      `${Int.toString(Float.toInt(downloadSpeed.contents *. 1024.0))} KB/s`
    }

    Text.setText(trafficText, `${upStr} ${downStr}`)

    // Update uptime
    switch RouterUptime.getUptime(ipAddress) {
    | Some(uptimeMs) =>
      let uptimeSeconds = uptimeMs /. 1000.0
      let days = Float.toInt(uptimeSeconds /. 86400.0)
      let hours = mod(Float.toInt(uptimeSeconds /. 3600.0), 24)
      let minutes = mod(Float.toInt(uptimeSeconds /. 60.0), 60)
      Text.setText(
        uptimeText,
        `${Int.toString(days)}d ${Int.toString(hours)}h ${Int.toString(minutes)}m`,
      )
    | None => Text.setText(uptimeText, "0d 0h 0m")
    }
  }

  let updateDeviceList = (): unit => {
    // Clear existing device list
    Container.removeChildren(devicesContainer)

    // Get connected devices from network manager
    let devices = switch globalNetworkManagerRef.contents {
    | Some(nm) => nm.getConnectedDevices()
    | None => []
    }

    if Array.length(devices) == 0 {
      let noDevText = Text.make({
        "text": "(no devices connected)",
        "style": {"fontSize": 10, "fill": 0x666666, "fontStyle": "italic"},
      })
      Text.setX(noDevText, 20.0)
      let _ = Container.addChildText(devicesContainer, noDevText)
    } else {
      Array.forEachWithIndex(devices, ((name, ip, _mac), idx) => {
        // Status dot
        let isActive = DeviceActivity.isActive(ip)
        let dot = Graphics.make()
        dot
        ->Graphics.circle(0.0, 6.0, 4.0)
        ->Graphics.fill({
          "color": if isActive {
            0x00ff00
          } else {
            0x666666
          },
        })
        ->ignore
        Graphics.setX(dot, 20.0)
        Graphics.setY(dot, Int.toFloat(idx) *. 16.0)
        let _ = Container.addChildGraphics(devicesContainer, dot)

        // Device info
        let nameStr = String.padEnd(name, 20, " ")
        let ipStr = String.padEnd(ip, 18, " ")
        let statusStr = if isActive {
          "ACTIVE"
        } else {
          "IDLE"
        }
        let devText = Text.make({
          "text": `  ${nameStr}${ipStr}${statusStr}`,
          "style": {"fontSize": 10, "fill": 0xaaaaaa, "fontFamily": "monospace"},
        })
        Text.setX(devText, 20.0)
        Text.setY(devText, Int.toFloat(idx) *. 16.0)
        let _ = Container.addChildText(devicesContainer, devText)
      })
    }
  }

  // Initial updates
  updateStats()
  updateDeviceList()

  // Start update interval (2 seconds)
  let intervalId = setInterval(() => {
    updateStats()
    updateDeviceList()
  }, 2000)

  // Return cleanup function and interval ID
  let cleanup = () => {
    clearInterval(intervalId)
  }

  (cleanup, intervalId)
}

let openGUI = (device: t): DeviceWindow.t => {
  let win = DeviceWindow.make(
    ~title=`ROUTER - ${device.name} [${device.ipAddress}]`,
    ~width=600.0,
    ~height=500.0,
    ~titleBarColor=getDeviceColor(Router),
    ~backgroundColor=0x1a1a1a,
    (),
  )

  let (cleanup, _intervalId) = createRouterInterface(DeviceWindow.getContent(win), device.ipAddress)

  // Register cleanup callback
  DeviceWindow.setOnClose(win, cleanup)

  win
}

// Create device interface
let toDevice = (t: t): device => {
  getInfo: () => getInfo(t),
  openGUI: () => openGUI(t),
}
