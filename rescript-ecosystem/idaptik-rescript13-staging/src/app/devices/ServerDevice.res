// SPDX-License-Identifier: PMPL-1.0-or-later
// Server Device with management GUI

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

let getInfo = (device: t): deviceInfo => {
  name: device.name,
  deviceType: Server,
  ipAddress: device.ipAddress,
  securityLevel: device.securityLevel,
}

let securityLevelToString = (level: securityLevel): string => {
  switch level {
  | Open => "OPEN"
  | Weak => "WEAK"
  | Medium => "MEDIUM"
  | Strong => "STRONG"
  }
}

// Interval bindings
let setInterval: (unit => unit, int) => int = %raw(`function(fn, ms) { return setInterval(fn, ms); }`)
let clearInterval: int => unit = %raw(`function(id) { clearInterval(id); }`)
let getCurrentTime: unit => float = %raw(`function() { return Date.now(); }`)

// ============================================
// Server States Module
// ============================================

module ServerStates = {
  let states: Dict.t<LaptopState.laptopState> = Dict.make()

  let register = (ip: string, state: LaptopState.laptopState): unit => {
    Dict.set(states, ip, state)
    // Initialize logs for this server
    SystemLogs.initializeLogs(ip)
    // Set boot time
    state.bootTime = getCurrentTime()
  }

  let get = (ip: string): option<LaptopState.laptopState> => {
    Dict.get(states, ip)
  }
}

// ============================================
// GUI Implementation
// ============================================

let openGUI = (device: t): DeviceWindow.t => {
  let win = DeviceWindow.make(
    ~title=`SERVER - ${device.name} [${device.ipAddress}] SEC:${securityLevelToString(device.securityLevel)}`,
    ~width=600.0,
    ~height=700.0,
    ~titleBarColor=getDeviceColor(Server),
    ~backgroundColor=0x000000,
    (),
  )

  let content = DeviceWindow.getContent(win)

  // Get or create server state
  let state = switch ServerStates.get(device.ipAddress) {
  | Some(s) => s
  | None =>
    let newState = LaptopState.createLaptopState(
      ~ipAddress=device.ipAddress,
      ~hostname=device.name,
      ~isServer=true,
      (),
    )
    ServerStates.register(device.ipAddress, newState)
    newState
  }

  // Styles
  let headerStyle = {"fontFamily": "Arial", "fontSize": 12, "fill": 0xbb86fc, "fontWeight": "bold"}
  let labelStyle = {"fontFamily": "Arial", "fontSize": 10, "fill": 0xdddddd}
  let _dataStyle = {"fontFamily": "monospace", "fontSize": 10, "fill": 0xaaaaaa}

  // ============================================
  // Stats Section (Y: 10)
  // ============================================
  let statsY = 10.0
  let statsBg = Graphics.make()
  let _ = statsBg
    ->Graphics.rect(10.0, statsY, 580.0, 40.0)
    ->Graphics.fill({"color": 0x2a2a2a})
    ->Graphics.stroke({"width": 1, "color": 0x444444})
  let _ = Container.addChildGraphics(content, statsBg)

  // CPU stat
  let cpuLabel = Text.make({"text": "CPU", "style": labelStyle})
  Text.setX(cpuLabel, 25.0)
  Text.setY(cpuLabel, statsY +. 8.0)
  let _ = Container.addChildText(content, cpuLabel)

  let cpuText = Text.make({"text": "0.0%", "style": {"fontFamily": "monospace", "fontSize": 16, "fill": 0x00ff00}})
  Text.setX(cpuText, 25.0)
  Text.setY(cpuText, statsY +. 20.0)
  let _ = Container.addChildText(content, cpuText)

  // Storage stat
  let storageLabel = Text.make({"text": "STORAGE", "style": labelStyle})
  Text.setX(storageLabel, 230.0)
  Text.setY(storageLabel, statsY +. 8.0)
  let _ = Container.addChildText(content, storageLabel)

  let storageText = Text.make({"text": "0/8192 Gq", "style": {"fontFamily": "monospace", "fontSize": 16, "fill": 0x00ff00}})
  Text.setX(storageText, 230.0)
  Text.setY(storageText, statsY +. 20.0)
  let _ = Container.addChildText(content, storageText)

  // Uptime stat
  let uptimeLabel = Text.make({"text": "UPTIME", "style": labelStyle})
  Text.setX(uptimeLabel, 450.0)
  Text.setY(uptimeLabel, statsY +. 8.0)
  let _ = Container.addChildText(content, uptimeLabel)

  let uptimeText = Text.make({"text": "0d 0h 0m", "style": {"fontFamily": "monospace", "fontSize": 16, "fill": 0x00ff00}})
  Text.setX(uptimeText, 450.0)
  Text.setY(uptimeText, statsY +. 20.0)
  let _ = Container.addChildText(content, uptimeText)

  // ============================================
  // Process Section (Y: 60) - Top 8 processes
  // ============================================
  let processY = 60.0
  let processHeader = Text.make({"text": "RUNNING PROCESSES", "style": headerStyle})
  Text.setX(processHeader, 10.0)
  Text.setY(processHeader, processY)
  let _ = Container.addChildText(content, processHeader)

  // Column headers
  let procColHeaders = Text.make({
    "text": "PID     NAME                 CPU%    Gq",
    "style": {"fontSize": 10, "fill": 0x888888, "fontFamily": "monospace"},
  })
  Text.setX(procColHeaders, 10.0)
  Text.setY(procColHeaders, processY +. 20.0)
  let _ = Container.addChildText(content, procColHeaders)

  // Container for process list (will be updated)
  let processContainer = Container.make()
  Container.setY(processContainer, processY +. 38.0)
  let _ = Container.addChild(content, processContainer)

  // ============================================
  // Network Connections Section (Y: 250)
  // ============================================
  let networkY = 250.0
  let networkHeader = Text.make({"text": "NETWORK CONNECTIONS", "style": headerStyle})
  Text.setX(networkHeader, 10.0)
  Text.setY(networkHeader, networkY)
  let _ = Container.addChildText(content, networkHeader)

  // Column headers
  let networkColHeaders = Text.make({
    "text": "PROTO  LOCAL              REMOTE             STATE",
    "style": {"fontSize": 10, "fill": 0x888888, "fontFamily": "monospace"},
  })
  Text.setX(networkColHeaders, 10.0)
  Text.setY(networkColHeaders, networkY +. 20.0)
  let _ = Container.addChildText(content, networkColHeaders)

  // Static network connections (listening ports)
  let connections = [
    ("TCP", `${device.ipAddress}:22`, "0.0.0.0:*", "LISTEN"),
    ("TCP", `${device.ipAddress}:80`, "0.0.0.0:*", "LISTEN"),
    ("TCP", `${device.ipAddress}:3389`, "0.0.0.0:*", "LISTEN"),
  ]

  let networkContainer = Container.make()
  Container.setY(networkContainer, networkY +. 38.0)
  let _ = Container.addChild(content, networkContainer)

  Array.forEachWithIndex(connections, ((proto, local, remote, state), idx) => {
    let protoStr = String.padEnd(proto, 7, " ")
    let localStr = String.padEnd(local, 19, " ")
    let remoteStr = String.padEnd(remote, 19, " ")
    let connText = Text.make({
      "text": `${protoStr}${localStr}${remoteStr}${state}`,
      "style": {"fontSize": 10, "fill": 0xaaaaaa, "fontFamily": "monospace"},
    })
    Text.setX(connText, 10.0)
    Text.setY(connText, Int.toFloat(idx) *. 16.0)
    let _ = Container.addChildText(networkContainer, connText)
  })

  // ============================================
  // System Log Section (Y: 365)
  // ============================================
  let logY = 365.0
  let logHeader = Text.make({"text": "SYSTEM LOG", "style": headerStyle})
  Text.setX(logHeader, 10.0)
  Text.setY(logHeader, logY)
  let _ = Container.addChildText(content, logHeader)

  // Container for log entries (will be updated)
  let logContainer = Container.make()
  Container.setY(logContainer, logY +. 20.0)
  let _ = Container.addChild(content, logContainer)

  // ============================================
  // Terminal Section (Y: 420)
  // ============================================
  let terminalY = 420.0
  let terminalHeader = Text.make({"text": "TERMINAL", "style": headerStyle})
  Text.setX(terminalHeader, 10.0)
  Text.setY(terminalHeader, terminalY)
  let _ = Container.addChildText(content, terminalHeader)

  // Create terminal
  let terminal = Terminal.make(
    ~width=580.0,
    ~height=220.0,
    ~prompt=`root@${device.name}:~# `,
    ~ipAddress=device.ipAddress,
    ~deviceState=state,
    ()
  )
  Container.setY(terminal.container, terminalY +. 25.0)
  let _ = Container.addChild(content, terminal.container)

  // ============================================
  // Power Button (Y: 660)
  // ============================================
  let powerBtnY = 660.0
  let powerBtn = Graphics.make()
  let isShutdown = PowerManager.isDeviceShutdown(device.ipAddress)
  let powerBtnColor = if isShutdown { 0x00aa00 } else { 0xaa0000 }
  let _ = powerBtn
    ->Graphics.rect(490.0, powerBtnY, 100.0, 30.0)
    ->Graphics.fill({"color": powerBtnColor})
    ->Graphics.stroke({"width": 1, "color": 0x000000})
  Graphics.setEventMode(powerBtn, "static")
  Graphics.setCursor(powerBtn, "pointer")
  let _ = Container.addChildGraphics(content, powerBtn)

  let powerText = Text.make({
    "text": if isShutdown { "POWER ON" } else { "POWER OFF" },
    "style": {"fontSize": 10, "fill": 0xffffff, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(powerText), 0.5, ~y=0.5)
  Text.setX(powerText, 540.0)
  Text.setY(powerText, powerBtnY +. 15.0)
  let _ = Container.addChildText(content, powerText)

  Graphics.on(powerBtn, "pointertap", _ => {
    let currentlyShutdown = PowerManager.isDeviceShutdown(device.ipAddress)
    if currentlyShutdown {
      // Boot the device
      if PowerManager.deviceHasPower(device.ipAddress) {
        PowerManager.bootDevice(device.ipAddress)
        state.bootTime = getCurrentTime()
        SystemLogs.addLog(device.ipAddress, "System booted", #Info)
        Text.setText(powerText, "POWER OFF")
        Graphics.clear(powerBtn)->ignore
        let _ = powerBtn
          ->Graphics.rect(490.0, powerBtnY, 100.0, 30.0)
          ->Graphics.fill({"color": 0xaa0000})
          ->Graphics.stroke({"width": 1, "color": 0x000000})
      }
    } else {
      // Shutdown the device
      PowerManager.manualShutdownDevice(device.ipAddress)
      SystemLogs.addLog(device.ipAddress, "System shutdown", #Warning)
      Text.setText(powerText, "POWER ON")
      Graphics.clear(powerBtn)->ignore
      let _ = powerBtn
        ->Graphics.rect(490.0, powerBtnY, 100.0, 30.0)
        ->Graphics.fill({"color": 0x00aa00})
        ->Graphics.stroke({"width": 1, "color": 0x000000})
    }
  })

  // ============================================
  // Update Functions
  // ============================================

  let updateStats = (): unit => {
    // Update CPU
    let cpu = LaptopState.getCpuUsage(state.processManager)
    Text.setText(cpuText, `${Float.toFixed(cpu, ~digits=1)}%`)

    // Update Storage
    let (used, total) = LaptopState.getTotalStorageUsage(state.processManager, state.ipAddress)
    Text.setText(storageText, `${Int.toString(used)}/${Int.toString(total)} Gq`)

    // Update Uptime
    let uptimeMs = getCurrentTime() -. state.bootTime
    let uptimeSeconds = uptimeMs /. 1000.0
    let days = Int.fromFloat(uptimeSeconds /. 86400.0)
    @warning("-3")
    let hours = Int.fromFloat(mod_float(uptimeSeconds /. 3600.0, 24.0))
    @warning("-3")
    let minutes = Int.fromFloat(mod_float(uptimeSeconds /. 60.0, 60.0))
    Text.setText(uptimeText, `${Int.toString(days)}d ${Int.toString(hours)}h ${Int.toString(minutes)}m`)
  }

  let updateProcesses = (): unit => {
    // Sync running services with process list
    LaptopState.syncServicesWithProcesses(state.processManager, state.ipAddress)

    // Clear existing process list
    Container.removeChildren(processContainer)

    // Get processes sorted by CPU
    let processes = LaptopState.getProcesses(state.processManager)
    let sortedProcs = Array.toSorted(processes, (a, b) => {
      if a.cpuPercent > b.cpuPercent { -1.0 }
      else if a.cpuPercent < b.cpuPercent { 1.0 }
      else { 0.0 }
    })

    // Display top 8 processes
    let displayProcs = Array.slice(sortedProcs, ~start=0, ~end=8)
    Array.forEachWithIndex(displayProcs, (proc, idx) => {
      let pidStr = String.padEnd(Int.toString(proc.pid), 8, " ")
      let nameStr = String.padEnd(proc.name, 21, " ")
      let cpuStr = String.padStart(Float.toFixed(proc.cpuPercent, ~digits=1), 6, " ")
      let sizeStr = String.padStart(Int.toString(proc.sizeGq), 4, " ")

      let procText = Text.make({
        "text": `${pidStr}${nameStr}${cpuStr}  ${sizeStr}`,
        "style": {"fontSize": 10, "fill": 0xaaaaaa, "fontFamily": "monospace"},
      })
      Text.setX(procText, 10.0)
      Text.setY(procText, Int.toFloat(idx) *. 16.0)
      let _ = Container.addChildText(processContainer, procText)
    })
  }

  let updateLogs = (): unit => {
    // Clear existing log entries
    Container.removeChildren(logContainer)

    // Get last 3 log entries
    let logs = SystemLogs.getLogs(device.ipAddress, 3)
    Array.forEachWithIndex(logs, (log, idx) => {
      let levelColor = switch log.level {
      | #Info => 0x00ff00
      | #Warning => 0xffaa00
      | #Error => 0xff0000
      }

      let logText = Text.make({
        "text": `[${log.timestamp}] ${log.message}`,
        "style": {"fontSize": 10, "fill": levelColor, "fontFamily": "monospace"},
      })
      Text.setX(logText, 10.0)
      Text.setY(logText, Int.toFloat(idx) *. 16.0)
      let _ = Container.addChildText(logContainer, logText)
    })
  }

  // Initial updates
  updateStats()
  updateProcesses()
  updateLogs()

  // Start update interval (1 second)
  let intervalId = setInterval(() => {
    updateStats()
    updateProcesses()
    updateLogs()
  }, 1000)

  // Register cleanup callback
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
