// SPDX-License-Identifier: PMPL-1.0-or-later
// PBX Device  telephone exchange system for social engineering
//
// Physical device in the world that must be hacked before `pbx call`
// commands become available. Once compromised, the player can place
// distraction calls from ANY terminal on the network.
//
// The PBX GUI shows call logs, extension directory, and system status.

open Pixi
open DeviceTypes

type t = {
  name: string,
  ipAddress: string,
  securityLevel: securityLevel,
  mutable pbxState: Distraction.pbxState,
}

let make = (
  ~name: string,
  ~ipAddress: string,
  ~securityLevel: securityLevel,
  ~entranceX: float=100.0,
  ~exitX: float=50.0,
  ~lobbyX: float=400.0,
  ~dockX: float=200.0,
  (),
): t => {
  let state = Distraction.make(~ipAddress)
  state.entranceX = entranceX
  state.exitX = exitX
  state.lobbyX = lobbyX
  state.dockX = dockX
  {
    name,
    ipAddress,
    securityLevel,
    pbxState: state,
  }
}

let getInfo = (device: t): deviceInfo => {
  name: device.name,
  deviceType: Server, // PBX/PhoneSystem treated as specialized server
  ipAddress: device.ipAddress,
  securityLevel: device.securityLevel,
}

let openGUI = (device: t): DeviceWindow.t => {
  let pbx = device.pbxState
  let win = DeviceWindow.make(
    ~title=`PBX - ${device.name} [${device.ipAddress}]`,
    ~width=480.0,
    ~height=400.0,
    ~titleBarColor=getDeviceColor(Server), // PBX treated as specialized server
    ~backgroundColor=0x0a1a2a,
    (),
  )

  let content = DeviceWindow.getContent(win)

  // Status header
  let statusColor = if pbx.hacked {
    "#ff4444"
  } else {
    "#44ff44"
  }
  let statusLabel = if pbx.hacked {
    "COMPROMISED"
  } else {
    "SECURED"
  }
  let statusText = Text.make({
    "text": `System: ${statusLabel}  |  Extensions: 24  |  Active Lines: 3`,
    "style": {"fontSize": 11.0, "fill": statusColor, "fontFamily": "monospace"},
  })
  Text.setX(statusText, 10.0)
  Text.setY(statusText, 8.0)
  let _ = Container.addChildText(content, statusText)

  // PBX ASCII art header
  let artText = Text.make({
    "text": `
  MERIDIAN PBX-4000  Telephone Exchange  
  Firmware: v4.2.1   Lines: 24/48 used   
`,
    "style": {"fontSize": 10.0, "fill": "#00bcd4", "fontFamily": "monospace"},
  })
  Text.setX(artText, 10.0)
  Text.setY(artText, 30.0)
  let _ = Container.addChildText(content, artText)

  // Extension directory
  let dirHeader = Text.make({
    "text": "EXT   LOCATION            STATUS",
    "style": {"fontSize": 10.0, "fill": "#888888", "fontFamily": "monospace"},
  })
  Text.setX(dirHeader, 10.0)
  Text.setY(dirHeader, 100.0)
  let _ = Container.addChildText(content, dirHeader)

  let extensions = [
    ("100", "Front Desk", "IDLE"),
    ("101", "Guard Station", "ACTIVE"),
    ("102", "Server Room", "IDLE"),
    ("103", "Loading Dock", "IDLE"),
    ("104", "Security Office", "ACTIVE"),
    ("105", "Manager Office", "DND"),
    ("110", "External Line 1", "IDLE"),
    ("111", "External Line 2", "IDLE"),
  ]

  extensions->Array.forEachWithIndex(((ext, loc, status), idx) => {
    let color = switch status {
    | "ACTIVE" => "#44ff44"
    | "DND" => "#ffaa00"
    | _ => "#666666"
    }
    let line = `${ext}   ${loc->String.padEnd(20, " ")}${status}`
    let lineText = Text.make({
      "text": line,
      "style": {"fontSize": 10.0, "fill": color, "fontFamily": "monospace"},
    })
    Text.setX(lineText, 10.0)
    Text.setY(lineText, 116.0 +. Int.toFloat(idx) *. 14.0)
    let _ = Container.addChildText(content, lineText)
  })

  // Bottom info
  let infoY = 116.0 +. Int.toFloat(Array.length(extensions)) *. 14.0 +. 16.0
  let secStr = switch device.securityLevel {
  | Open => "OPEN"
  | Weak => "WEAK"
  | Medium => "MEDIUM"
  | Strong => "STRONG"
  }

  let callInfo = if pbx.hacked {
    let cooldown = if pbx.cooldownSec > 0.0 {
      `Cooldown: ${Int.toString(Float.toInt(pbx.cooldownSec))}s`
    } else {
      "Ready for calls"
    }
    `Calls made: ${Int.toString(pbx.totalCalls)}  |  ${cooldown}`
  } else {
    "Hack this device to unlock PBX commands"
  }

  let infoText = Text.make({
    "text": `Security: ${secStr}  |  ${callInfo}`,
    "style": {"fontSize": 10.0, "fill": "#aaaaaa", "fontFamily": "monospace"},
  })
  Text.setX(infoText, 10.0)
  Text.setY(infoText, infoY)
  let _ = Container.addChildText(content, infoText)

  win
}

let toDevice = (t: t): device => {
  getInfo: () => getInfo(t),
  openGUI: () => openGUI(t),
}
