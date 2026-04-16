// SPDX-License-Identifier: PMPL-1.0-or-later
// Firewall Device  ACL rules, packet filtering, bypass challenge mechanics

open Pixi
open DeviceTypes

// ACL rule types
type aclAction = Allow | Deny | Log

type aclRule = {
  id: int,
  sourceSubnet: string,
  destSubnet: string,
  port: int,
  protocol: string,
  action: aclAction,
  description: string,
}

type t = {
  name: string,
  ipAddress: string,
  securityLevel: securityLevel,
  mutable rules: array<aclRule>,
  mutable blockedAttempts: int,
  mutable passedPackets: int,
  mutable bypassed: bool,
}

// Default ACL rules for a corporate firewall
let defaultRules = (): array<aclRule> => [
  {
    id: 1,
    sourceSubnet: "192.168.1.0/24",
    destSubnet: "10.0.0.0/8",
    port: 443,
    protocol: "TCP",
    action: Allow,
    description: "LAN to DMZ HTTPS",
  },
  {
    id: 2,
    sourceSubnet: "192.168.1.0/24",
    destSubnet: "10.0.0.0/8",
    port: 80,
    protocol: "TCP",
    action: Allow,
    description: "LAN to DMZ HTTP",
  },
  {
    id: 3,
    sourceSubnet: "0.0.0.0/0",
    destSubnet: "10.0.0.25",
    port: 25,
    protocol: "TCP",
    action: Allow,
    description: "External SMTP to mail server",
  },
  {
    id: 4,
    sourceSubnet: "0.0.0.0/0",
    destSubnet: "10.0.0.100",
    port: 1194,
    protocol: "UDP",
    action: Allow,
    description: "External VPN access",
  },
  {
    id: 5,
    sourceSubnet: "10.0.0.0/8",
    destSubnet: "10.0.1.0/24",
    port: 389,
    protocol: "TCP",
    action: Allow,
    description: "DMZ to internal LDAP",
  },
  {
    id: 6,
    sourceSubnet: "0.0.0.0/0",
    destSubnet: "10.0.1.0/24",
    port: 0,
    protocol: "ANY",
    action: Deny,
    description: "Block all external to internal",
  },
  {
    id: 7,
    sourceSubnet: "0.0.0.0/0",
    destSubnet: "0.0.0.0/0",
    port: 22,
    protocol: "TCP",
    action: Log,
    description: "Log all SSH attempts",
  },
]

let make = (~name: string, ~ipAddress: string, ~securityLevel: securityLevel, ()): t => {
  name,
  ipAddress,
  securityLevel,
  rules: defaultRules(),
  blockedAttempts: 0,
  passedPackets: 0,
  bypassed: false,
}

let getInfo = (device: t): deviceInfo => {
  name: device.name,
  deviceType: Firewall,
  ipAddress: device.ipAddress,
  securityLevel: device.securityLevel,
}

// Check if a packet passes the firewall rules
let checkPacket = (
  device: t,
  ~source: string,
  ~dest: string,
  ~port: int,
  ~protocol: string,
): aclAction => {
  let matchedRule = device.rules-> Array.find(rule => {
    // Simplified subnet matching  check prefix
    let sourceMatch =
      rule.sourceSubnet == "0.0.0.0/0" ||
        String.startsWith(
          source,
          String.slice(rule.sourceSubnet, ~start=0, ~end=String.indexOf(rule.sourceSubnet, "/")),
        )
    let destMatch =
      rule.destSubnet == "0.0.0.0/0" ||
        String.startsWith(
          dest,
          String.slice(rule.destSubnet, ~start=0, ~end=String.indexOf(rule.destSubnet, "/")),
        )
    let portMatch = rule.port == 0 || rule.port == port
    let protoMatch = rule.protocol == "ANY" || rule.protocol == protocol

    sourceMatch && destMatch && portMatch && protoMatch
  })

  switch matchedRule {
  | Some(rule) => {
      switch rule.action {
      | Allow => device.passedPackets = device.passedPackets + 1
      | Deny => device.blockedAttempts = device.blockedAttempts + 1
      | Log => device.passedPackets = device.passedPackets + 1
      }
      rule.action
    }
  | None => {
      // Default deny
      device.blockedAttempts = device.blockedAttempts + 1
      Deny
    }
  }
}

// Format action for display
let actionToString = (action: aclAction): string => {
  switch action {
  | Allow => "ALLOW"
  | Deny => "DENY"
  | Log => "LOG"
  }
}

let actionToColor = (action: aclAction): int => {
  switch action {
  | Allow => 0x4CAF50
  | Deny => 0xF44336
  | Log => 0xFFEB3B
  }
}

let openGUI = (device: t): DeviceWindow.t => {
  let win = DeviceWindow.make(
    ~title=`FIREWALL - ${device.name} [${device.ipAddress}]`,
    ~width=520.0,
    ~height=440.0,
    ~titleBarColor=getDeviceColor(Firewall),
    ~backgroundColor=0x1a1a1a,
    (),
  )

  let content = DeviceWindow.getContent(win)

  // Status header
  let statusColor = if device.bypassed {
    "#ff4444"
  } else {
    "#44ff44"
  }
  let statusLabel = if device.bypassed {
    "BYPASSED"
  } else {
    "ACTIVE"
  }
  let statusText = Text.make({
    "text": `Status: ${statusLabel}  |  Blocked: ${Int.toString(
        device.blockedAttempts,
      )}  |  Passed: ${Int.toString(device.passedPackets)}`,
    "style": {"fontSize": 11.0, "fill": statusColor, "fontFamily": "monospace"},
  })
  Text.setX(statusText, 10.0)
  Text.setY(statusText, 8.0)
  let _ = Container.addChildText(content, statusText)

  // ACL rules table header
  let headerText = Text.make({
    "text": "ID  ACTION  PROTO  PORT   SOURCE            DEST              DESC",
    "style": {"fontSize": 10.0, "fill": "#888888", "fontFamily": "monospace"},
  })
  Text.setX(headerText, 10.0)
  Text.setY(headerText, 32.0)
  let _ = Container.addChildText(content, headerText)

  // Separator line
  let separator = Graphics.make()
  let _ =
    separator
    ->Graphics.moveTo(10.0, 48.0)
    ->Graphics.lineTo(510.0, 48.0)
    ->Graphics.stroke({"width": 1, "color": 0x444444})
  let _ = Container.addChildGraphics(content, separator)

  // ACL rules
  device.rules->Array.forEachWithIndex((rule, idx) => {
    let actionStr = actionToString(rule.action)
    let portStr = if rule.port == 0 {
      "*"
    } else {
      Int.toString(rule.port)
    }
    let line = `${Int.toString(rule.id)->String.padStart(2, " ")}  ${actionStr->String.padEnd(
        6,
        " ",
      )}  ${rule.protocol->String.padEnd(5, " ")}  ${portStr->String.padEnd(
        5,
        " ",
      )}  ${rule.sourceSubnet->String.padEnd(16, " ")}  ${rule.destSubnet->String.padEnd(
        16,
        " ",
      )}  ${rule.description}`

    let fillColor = switch rule.action {
    | Allow => "#66ff66"
    | Deny => "#ff6666"
    | Log => "#ffff66"
    }
    let ruleText = Text.make({
      "text": line,
      "style": {"fontSize": 10.0, "fill": fillColor, "fontFamily": "monospace"},
    })
    Text.setX(ruleText, 10.0)
    Text.setY(ruleText, 54.0 +. Int.toFloat(idx) *. 16.0)
    let _ = Container.addChildText(content, ruleText)
  })

  // Bottom info
  let infoY = 54.0 +. Int.toFloat(Array.length(device.rules)) *. 16.0 +. 16.0
  let secLevel = switch device.securityLevel {
  | Open => "OPEN"
  | Weak => "WEAK"
  | Medium => "MEDIUM"
  | Strong => "STRONG"
  }
  let infoText = Text.make({
    "text": `Security Level: ${secLevel}  |  Default Policy: DENY ALL`,
    "style": {"fontSize": 10.0, "fill": "#aaaaaa", "fontFamily": "monospace"},
  })
  Text.setX(infoText, 10.0)
  Text.setY(infoText, infoY)
  let _ = Container.addChildText(content, infoText)

  win
}

// Create device interface
let toDevice = (t: t): device => {
  getInfo: () => getInfo(t),
  openGUI: () => openGUI(t),
}
