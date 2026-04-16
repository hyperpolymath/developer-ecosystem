// SPDX-License-Identifier: PMPL-1.0-or-later
// Network Desktop - Main hacking interface (Debug View)

open Pixi
open PixiUI
open DeviceTypes

// Math bindings for layout
@val external sqrt: float => float = "Math.sqrt"

// Asset bundles for this popup
let assetBundles = ["desktop"]

// Network zone types for layout
type networkZone =
  | LAN
  | Rural
  | DMZ
  | Internal
  | Dev
  | Security
  | Management
  | IoT
  | SCADA
  | ISP
  | Atlas
  | Nexus
  | DevHub
  | External

// Get zone from IP address
let getZone = (ip: string): networkZone => {
  // Edge Networks
  if String.startsWith(ip, "192.168.1.") {
    LAN // Downtown Corporate LAN
  } else if String.startsWith(ip, "192.168.2.") {
    Rural // Rural Home LAN
    // Downtown Office Zones
  } else if String.startsWith(ip, "10.0.0.") {
    DMZ // Internet-facing services (Mail, VPN)
  } else if String.startsWith(ip, "10.0.1.") {
    Internal // Protected business services (DB, Intranet, LDAP, File Server)
  } else if String.startsWith(ip, "10.0.2.") {
    Dev // Development/test environment
  } else if String.startsWith(ip, "10.0.3.") {
    Security // IDS/IPS, SIEM, Backup
  } else if String.startsWith(ip, "172.16.0.") {
    Management // Network administration (Admin Panel)
  } else if String.startsWith(ip, "192.168.100.") {
    IoT // IoT devices (Cameras, sensors)
  } else if String.startsWith(ip, "10.10.1.") {
    SCADA // Industrial control (air-gapped)
    // ISP Infrastructure
  } else if (
    String.startsWith(ip, "100.64.") ||
    String.startsWith(ip, "198.51.100.") ||
    String.startsWith(ip, "203.0.113.")
  ) {
    ISP // ISP infrastructure (Tier 3, Tier 2, Tier 1)
    // Public Services
  } else if String.startsWith(ip, "8.8.8.") || String.startsWith(ip, "142.250.") {
    Atlas // Atlas router (8.8.8.x) and web services (142.250.x.x)
  } else if String.startsWith(ip, "1.1.1.") || String.startsWith(ip, "104.16.") {
    Nexus // Nexus router (1.1.1.x) and web services (104.16.x.x)
  } else if String.startsWith(ip, "140.82.") {
    DevHub // DevHub code repository
  } else {
    External // Unknown/public internet
  }
}

// Zone configuration type for auto-grid layout
type zoneConfig = {
  x: float,
  y: float,
  maxDevicesPerRow: int,
  deviceSpacing: float,
  connectToX: float,
  connectToY: float,
  lineColor: int,
}

// Network Device Icon on the desktop
module DeviceIcon = {
  type t = {
    container: Container.t,
    ipAddress: string,
    zone: networkZone,
  }

  let createDeviceGraphic = (
    deviceType: deviceType,
    ipAddress: string,
    iconBg: Graphics.t,
  ): unit => {
    let indicator = Graphics.make()

    switch deviceType {
    | Laptop =>
      let _ =
        indicator
        ->Graphics.rect(20.0, 30.0, 40.0, 25.0)
        ->Graphics.fill({"color": 0xffffff})
      let _ =
        indicator
        ->Graphics.rect(30.0, 55.0, 20.0, 3.0)
        ->Graphics.fill({"color": 0xffffff})
    | Firewall =>
      // Brick wall icon (white silhouette on dark red background)
      let _ =
        indicator
        ->Graphics.rect(25.0, 25.0, 30.0, 8.0)
        ->Graphics.fill({"color": 0xffffff})
      let _ =
        indicator
        ->Graphics.rect(25.0, 35.0, 12.0, 8.0)
        ->Graphics.fill({"color": 0xffffff})
      let _ =
        indicator
        ->Graphics.rect(40.0, 35.0, 15.0, 8.0)
        ->Graphics.fill({"color": 0xffffff})
      let _ =
        indicator
        ->Graphics.rect(25.0, 45.0, 30.0, 8.0)
        ->Graphics.fill({"color": 0xffffff})
      // Mortar lines (darker to show brick separation)
      let _ =
        indicator
        ->Graphics.rect(25.0, 33.0, 30.0, 2.0)
        ->Graphics.fill({"color": 0x999999})
      let _ =
        indicator
        ->Graphics.rect(25.0, 43.0, 30.0, 2.0)
        ->Graphics.fill({"color": 0x999999})
      let _ =
        indicator
        ->Graphics.rect(37.0, 35.0, 3.0, 8.0)
        ->Graphics.fill({"color": 0x999999})
    | Router =>
      if (
        String.startsWith(ipAddress, "100.64.") ||
        String.startsWith(ipAddress, "198.51.100.") ||
        String.startsWith(ipAddress, "203.0.113.")
      ) {
        // ISP ROUTER - cloud symbol (white silhouette on blue background)
        // Cloud shape using circles
        let _ =
          indicator
          ->Graphics.circle(35.0, 42.0, 8.0)
          ->Graphics.fill({"color": 0xffffff})
        let _ =
          indicator
          ->Graphics.circle(45.0, 42.0, 8.0)
          ->Graphics.fill({"color": 0xffffff})
        let _ =
          indicator
          ->Graphics.circle(40.0, 36.0, 10.0)
          ->Graphics.fill({"color": 0xffffff})
        // Cloud base
        let _ =
          indicator
          ->Graphics.rect(28.0, 42.0, 25.0, 8.0)
          ->Graphics.fill({"color": 0xffffff})
      } else {
        // Regular edge router - standard icon
        let _ =
          indicator
          ->Graphics.circle(40.0, 40.0, 15.0)
          ->Graphics.fill({"color": 0xffffff})
        let _ =
          indicator
          ->Graphics.rect(38.0, 25.0, 4.0, 15.0)
          ->Graphics.fill({"color": 0xffffff})
      }
    | Server =>
      let _ =
        indicator
        ->Graphics.rect(20.0, 25.0, 40.0, 8.0)
        ->Graphics.fill({"color": 0xffffff})
      let _ =
        indicator
        ->Graphics.rect(20.0, 37.0, 40.0, 8.0)
        ->Graphics.fill({"color": 0xffffff})
      let _ =
        indicator
        ->Graphics.rect(20.0, 49.0, 40.0, 8.0)
        ->Graphics.fill({"color": 0xffffff})
    | IotCamera =>
      let _ =
        indicator
        ->Graphics.circle(40.0, 35.0, 12.0)
        ->Graphics.fill({"color": 0xffffff})
      let _ =
        indicator
        ->Graphics.rect(35.0, 47.0, 10.0, 8.0)
        ->Graphics.fill({"color": 0xffffff})
    | Terminal =>
      let _ =
        indicator
        ->Graphics.rect(15.0, 25.0, 50.0, 30.0)
        ->Graphics.fill({"color": 0x000000})
      let termText = Text.make({
        "text": ">_",
        "style": {"fill": 0x00ff00, "fontSize": 16},
      })
      Text.setX(termText, 20.0)
      Text.setY(termText, 30.0)
      let _ = Graphics.addChild(indicator, termText)
    | PowerStation =>
      // Power station icon - lightning bolt
      let _ =
        indicator
        ->Graphics.rect(25.0, 25.0, 30.0, 35.0)
        ->Graphics.fill({"color": 0xffffff})
      let _ =
        indicator
        ->Graphics.rect(30.0, 35.0, 20.0, 5.0)
        ->Graphics.fill({"color": 0xFFEB3B})
      let _ =
        indicator
        ->Graphics.rect(30.0, 42.0, 20.0, 5.0)
        ->Graphics.fill({"color": 0xFFEB3B})
      let _ =
        indicator
        ->Graphics.rect(30.0, 49.0, 20.0, 5.0)
        ->Graphics.fill({"color": 0xFFEB3B})
    | UPS =>
      // UPS icon - battery
      let _ =
        indicator
        ->Graphics.rect(20.0, 30.0, 35.0, 25.0)
        ->Graphics.fill({"color": 0xffffff})
      let _ =
        indicator
        ->Graphics.rect(55.0, 37.0, 5.0, 10.0)
        ->Graphics.fill({"color": 0xffffff})
      let _ =
        indicator
        ->Graphics.rect(25.0, 35.0, 10.0, 15.0)
        ->Graphics.fill({"color": 0x00ff00})
      let _ =
        indicator
        ->Graphics.rect(37.0, 35.0, 10.0, 15.0)
        ->Graphics.fill({"color": 0x00ff00})
    }

    let _ = Graphics.addChild(iconBg, indicator)
  }

  let make = (
    networkManager: NetworkManager.t,
    ipAddress: string,
    ~screenContainer: option<Container.t>=?,
    (),
  ): option<t> => {
    switch NetworkManager.getDevice(networkManager, ipAddress) {
    | None => None
    | Some(device) =>
      let info = device.getInfo()
      let container = Container.make()
      Container.setEventMode(container, "static")
      Container.setCursor(container, "pointer")

      // Device icon background (color based on device type and IP for routers)
      let iconBg = Graphics.make()
      let bgColor = if info.deviceType == Router {
        // Different colors for different router types
        if String.startsWith(ipAddress, "10.0.0.1") || String.startsWith(ipAddress, "10.0.1.1") {
          0xD32F2F // Dark red for firewalls
        } else if (
          String.startsWith(ipAddress, "100.64.") ||
          String.startsWith(ipAddress, "198.51.100.") ||
          String.startsWith(ipAddress, "203.0.113.")
        ) {
          0x1976D2 // Blue for ISP routers
        } else {
          getDeviceColor(info.deviceType) // Orange for edge routers
        }
      } else {
        getDeviceColor(info.deviceType)
      }
      let _ =
        iconBg
        ->Graphics.rect(0.0, 0.0, 80.0, 80.0)
        ->Graphics.fill({"color": bgColor})
      let _ =
        iconBg
        ->Graphics.rect(2.0, 2.0, 76.0, 76.0)
        ->Graphics.stroke({"width": 2, "color": 0x000000})
      let _ = Container.addChildGraphics(container, iconBg)

      // Device type indicator (pass IP to differentiate router types)
      createDeviceGraphic(info.deviceType, ipAddress, iconBg)

      // Security indicator
      let securityDot = Graphics.make()
      let _ =
        securityDot
        ->Graphics.circle(70.0, 10.0, 5.0)
        ->Graphics.fill({"color": getSecurityColor(info.securityLevel)})
      let _ = Container.addChildGraphics(container, securityDot)

      // Device name label
      let nameText = Text.make({
        "text": info.name,
        "style": {"fontSize": 11, "fill": 0xffffff, "align": "center", "fontWeight": "bold"},
      })
      ObservablePoint.set(Text.anchor(nameText), 0.5, ~y=0.0)
      Text.setX(nameText, 40.0)
      Text.setY(nameText, 85.0)
      let _ = Container.addChildText(container, nameText)

      // IP Address
      let ipText = Text.make({
        "text": info.ipAddress,
        "style": {"fontSize": 9, "fill": 0xaaaaaa, "align": "center"},
      })
      ObservablePoint.set(Text.anchor(ipText), 0.5, ~y=0.0)
      Text.setX(ipText, 40.0)
      Text.setY(ipText, 100.0)
      let _ = Container.addChildText(container, ipText)

      // Click to open device
      Container.on(container, "pointertap", _ => {
        switch NetworkManager.getDevice(networkManager, ipAddress) {
        | None => ()
        | Some(d) =>
          let window = d.openGUI()
          // Always add windows to the top-level screen container if provided,
          // otherwise fallback to the icon's parent (topologyContainer)
          let targetParent = switch screenContainer {
          | Some(sc) => sc
          | None =>
            switch Container.parent(container)->Nullable.toOption {
            | Some(p) => p
            | None => container // Last resort (unlikely to work well but avoids crash)
            }
          }
          let _ = Container.addChild(targetParent, window.container)
        }
      })

      Some({container, ipAddress, zone: getZone(ipAddress)})
    }
  }
}

// ========================================
// GENERIC TREE LAYOUT SYSTEM (Module Level)
// ========================================

// Node storage (simple x/y positions)
type layoutNode = {
  ip: string,
  mutable x: float,
  mutable y: float,
}

type layoutEdge = {
  source: string,
  target: string,
  strength: float,
}

// Tree structure for generic layout
type rec treeNode = {
  ip: string,
  mutable children: array<treeNode>,
  mutable x: float,
  mutable y: float,
  mutable subtreeHeight: float,
}

// Layout parameters
let levelSpacing = 240.0 // Horizontal distance between hierarchy levels
let baseDeviceSpacing = 100.0 // Base vertical spacing between devices
let minBranchSpacing = 120.0 // Minimum vertical space between branches

// Calculate spacing per device
let calculateDeviceSpacing = (deviceCount: int): float => {
  if deviceCount <= 3 {
    baseDeviceSpacing
  } else if deviceCount <= 6 {
    baseDeviceSpacing *. 1.15
  } else if deviceCount <= 10 {
    baseDeviceSpacing *. 1.3
  } else {
    baseDeviceSpacing *. 1.4 // Cap at 1.4x for very large groups
  }
}

// Calculate total vertical space needed for devices
let calculateTotalHeight = (deviceCount: int): float => {
  if deviceCount <= 1 {
    0.0 // Single device or none takes no vertical space
  } else {
    let spacing = calculateDeviceSpacing(deviceCount)
    Int.toFloat(deviceCount - 1) *. spacing
  }
}

// Build tree from edges (parent-child relationships)
let buildTree = (rootIP: string, allEdges: array<layoutEdge>): treeNode => {
  let rec buildNode = (ip: string, visited: dict<bool>): treeNode => {
    // Mark as visited to avoid cycles
    Dict.set(visited, ip, true)

    // Find all children of this node
    let childIPs = Array.filterMap(allEdges, edge =>
      if edge.source == ip && !(Dict.get(visited, edge.target)->Option.getOr(false)) {
        Some(edge.target)
      } else {
        None
      }
    )

    // Recursively build child nodes
    let children = Array.map(childIPs, childIP => buildNode(childIP, visited))

    {
      ip,
      children,
      x: 0.0,
      y: 0.0,
      subtreeHeight: 0.0,
    }
  }

  buildNode(rootIP, Dict.make())
}

// Calculate subtree heights bottom-up
let rec calculateSubtreeHeights = (node: treeNode): float => {
  let childCount = Array.length(node.children)

  if childCount == 0 {
    // Leaf node - no height
    node.subtreeHeight = 0.0
    0.0
  } else {
    // Calculate heights of all children first
    let childHeights = Array.map(node.children, calculateSubtreeHeights)

    // Total height needed is sum of child subtree heights plus spacing
    let totalChildHeight = Array.reduce(childHeights, 0.0, (acc, h) => acc +. h)
    let spacingBetweenChildren = Int.toFloat(childCount - 1) *. minBranchSpacing
    let height = totalChildHeight +. spacingBetweenChildren

    node.subtreeHeight = height
    height
  }
}

// Backbone layout info (for dynamic spacing)
type backboneLayout = {
  ip: string,
  leftHeight: float,
  rightHeight: float,
  totalHeight: float,
}

// Layout tree nodes recursively (left-to-right or right-to-left)
let rec layoutNode = (
  node: treeNode,
  x: float,
  y: float,
  direction: [#Left | #Right], // Which way to extend children
  nodes: dict<layoutNode>,
): unit => {
  // Position this node
  node.x = x
  node.y = y
  Dict.set(nodes, node.ip, {ip: node.ip, x, y})

  let childCount = Array.length(node.children)

  if childCount > 0 {
    // Determine child X position based on direction
    let childX = switch direction {
    | #Left => x -. levelSpacing
    | #Right => x +. levelSpacing
    }

    // Position children vertically centered around this node
    let startY = y -. node.subtreeHeight /. 2.0
    let currentY = ref(startY)

    Array.forEach(node.children, child => {
      // Center the child on its own subtree
      let childCenterY = currentY.contents +. child.subtreeHeight /. 2.0

      // Recursively layout this child
      layoutNode(child, childX, childCenterY, direction, nodes)

      // Move Y position for next sibling
      currentY := currentY.contents +. child.subtreeHeight +. minBranchSpacing
    })
  }
}

// Create the network desktop
let make = (): Navigation.appScreen => {
  let container = Container.make()
  Container.setSortableChildren(container, true)
  Container.setEventMode(container, "static")
  Container.setInteractiveChildren(container, true)

  // Use global network manager (shared with WorldScreen)
  let networkManager = GlobalNetworkManager.get()

  // Set up the network interface setter for laptops
  // Each device gets its own network interface based on its IP address
  // This enables proper routing - devices see the network from their perspective
  DesktopDevice.setGlobalNetworkInterfaceSetter((state: LaptopState.laptopState) => {
    // Create network interface from this device's perspective
    let ni = NetworkManager.createNetworkInterfaceFor(networkManager, state.ipAddress)
    LaptopState.setNetworkInterface(state, ni)
  })

  // Set up global state getter so devices use shared state from NetworkManager
  DesktopDevice.setGlobalStateGetter((ipAddress: string) => {
    NetworkManager.getDeviceState(networkManager, ipAddress)
  })

  // Set up the router's network manager reference
  // This allows the router GUI to show connected devices and configure DNS
  RouterDevice.setGlobalNetworkManager({
    getConnectedDevices: () => NetworkManager.getConnectedDevices(networkManager),
    getConfiguredDns: () => NetworkManager.getConfiguredDns(networkManager),
    setConfiguredDns: dnsIp => NetworkManager.setConfiguredDns(networkManager, dnsIp),
  })

  // Desktop background
  let desktopBg = Graphics.make()
  Graphics.setEventMode(desktopBg, "static")
  let _ = Container.addChildGraphics(container, desktopBg)

  // Close button to return to world view
  let closeButton = Button.make(~options={text: "Back to World", width: 140.0, height: 40.0}, ())
  Signal.connect(FancyButton.onPress(closeButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.dismissPopup(engine.navigation)
    | None => ()
    }
  })
  let _ = Container.addChild(container, FancyButton.toContainer(closeButton))

  // Create a container for all topology content (lines + icons) that can be panned and zoomed
  let topologyContainer = Container.make()
  let _ = Container.addChild(container, topologyContainer)

  // Topology lines container (drawn behind icons)
  let topologyLines = Graphics.make()
  let _ = Container.addChildGraphics(topologyContainer, topologyLines)

  // Legend container (stays on top, doesn't pan/zoom)
  let legendContainer = Container.make()
  let _ = Container.addChild(container, legendContainer)

  // Pan and zoom state
  let scale = ref(1.0)
  let dragStartX = ref(0.0)
  let dragStartY = ref(0.0)
  let isDragging = ref(false)

  // Store totalRingHeight for infinite scrolling wrapping
  let totalRingHeightRef = ref(1000.0) // Default value, updated on resize

  // Create device icons and organize by zone
  let lanIcons = ref([])
  let ruralIcons = ref([])
  let dmzIcons = ref([])
  let internalIcons = ref([])
  let devIcons = ref([])
  let securityIcons = ref([])
  let managementIcons = ref([])
  let iotIcons = ref([])
  let scadaIcons = ref([])
  let atlasIcons = ref([])
  let nexusIcons = ref([])
  let devhubIcons = ref([])
  let externalIcons = ref([])

  // Edge routers (local networks)
  let mainRouterIcon = ref(None)
  let ruralRouterIcon = ref(None)
  let iotRouterIcon = ref(None)

  // ISP routers (tiered infrastructure)
  let ruralIspIcon = ref(None)
  let businessIspIcon = ref(None)
  let regionalIspIcon = ref(None)
  // Backbone servers (ring topology)
  let naBackboneIcon = ref(None)
  let euBackboneIcon = ref(None)
  let asiaBackboneIcon = ref(None)
  let saBackboneIcon = ref(None)
  let afBackboneIcon = ref(None)

  // Service provider routers
  let atlasRouterIcon = ref(None)
  let nexusRouterIcon = ref(None)
  let devhubRouterIcon = ref(None)

  // Store all created icons for later duplication
  let allCreatedIcons: ref<array<(string, DeviceIcon.t)>> = ref([])

  // Store duplicate icons for infinite scrolling across resizes
  let iconsAbove1: ref<array<DeviceIcon.t>> = ref([])
  let iconsAbove2: ref<array<DeviceIcon.t>> = ref([])
  let iconsBelow1: ref<array<DeviceIcon.t>> = ref([])
  let iconsBelow2: ref<array<DeviceIcon.t>> = ref([])

  let devices = NetworkManager.getAllDevices(networkManager)
  Array.forEach(devices, device => {
    let info = device.getInfo()
    // Pass screen container so windows open at root level
    switch DeviceIcon.make(networkManager, info.ipAddress, ~screenContainer=container, ()) {
    | Some(icon) =>
      let _ = Container.addChild(topologyContainer, icon.container)
      let _ = Array.push(allCreatedIcons.contents, (info.ipAddress, icon))

      // Categorize routers by their role in the hierarchy
      if info.ipAddress == "192.168.1.1" {
        mainRouterIcon := Some(icon)
      } else if info.ipAddress == "192.168.2.1" {
        ruralRouterIcon := Some(icon)
      } else if info.ipAddress == "192.168.100.1" {
        iotRouterIcon := Some(icon)
      } else if info.ipAddress == "100.64.1.1" {
        ruralIspIcon := Some(icon)
      } else if info.ipAddress == "100.64.2.1" {
        businessIspIcon := Some(icon)
      } else if info.ipAddress == "198.51.100.1" {
        regionalIspIcon := Some(icon)
      } else if info.ipAddress == "203.0.113.1" {
        naBackboneIcon := Some(icon)
      } else if info.ipAddress == "203.0.113.2" {
        euBackboneIcon := Some(icon)
      } else if info.ipAddress == "203.0.113.3" {
        asiaBackboneIcon := Some(icon)
      } else if info.ipAddress == "203.0.113.4" {
        saBackboneIcon := Some(icon)
      } else if info.ipAddress == "203.0.113.5" {
        afBackboneIcon := Some(icon)
      } else if info.ipAddress == "8.8.8.1" {
        atlasRouterIcon := Some(icon)
      } else if info.ipAddress == "1.1.1.254" {
        nexusRouterIcon := Some(icon)
      } else if info.ipAddress == "140.82.121.1" {
        devhubRouterIcon := Some(icon)
      } else {
        switch icon.zone {
        | LAN => lanIcons := Array.concat(lanIcons.contents, [icon])
        | Rural => ruralIcons := Array.concat(ruralIcons.contents, [icon])
        | DMZ => dmzIcons := Array.concat(dmzIcons.contents, [icon])
        | Internal => internalIcons := Array.concat(internalIcons.contents, [icon])
        | Dev => devIcons := Array.concat(devIcons.contents, [icon])
        | Security => securityIcons := Array.concat(securityIcons.contents, [icon])
        | Management => managementIcons := Array.concat(managementIcons.contents, [icon])
        | IoT => iotIcons := Array.concat(iotIcons.contents, [icon])
        | SCADA => scadaIcons := Array.concat(scadaIcons.contents, [icon])
        | ISP => () // ISP devices handled as routers above
        | Atlas => atlasIcons := Array.concat(atlasIcons.contents, [icon])
        | Nexus => nexusIcons := Array.concat(nexusIcons.contents, [icon])
        | DevHub => devhubIcons := Array.concat(devhubIcons.contents, [icon])
        | External => externalIcons := Array.concat(externalIcons.contents, [icon])
        }
      }
    | None => ()
    }
  })

  // Instructions text (created once)
  let instructions = Text.make({
    "text": "Mouse wheel: Zoom | Drag: Pan",
    "style": {"fontSize": 11, "fill": 0x888888},
  })
  let _ = Container.addChildText(container, instructions)

  {
    container,
    prepare: None,
    show: Some(
      async () => {
        Container.setAlpha(container, 0.0)
        await Motion.animateAsync(container, {"alpha": 1.0}, {duration: 0.5, ease: "easeOut"})
      },
    ),
    hide: Some(
      async () => {
        await Motion.animateAsync(container, {"alpha": 0.0}, {duration: 0.3})
      },
    ),
    pause: None,
    resume: None,
    reset: None,
    update: Some(_time => ()),
    resize: Some(
      (width, height) => {
        let _ = Graphics.clear(desktopBg)
        let _ =
          desktopBg
          ->Graphics.rect(0.0, 0.0, width, height)
          ->Graphics.fill({"color": 0x0a0a0a, "alpha": 1.0})

        // Position close button in top-right corner
        FancyButton.setX(closeButton, width -. 80.0)
        FancyButton.setY(closeButton, 30.0)

        // Grid pattern
        let gridGraphics = Graphics.make()
        let x = ref(0.0)
        while x.contents < width {
          let _ =
            gridGraphics
            ->Graphics.moveTo(x.contents, 0.0)
            ->Graphics.lineTo(x.contents, height)
            ->Graphics.stroke({"width": 1, "color": 0x1a1a1a, "alpha": 0.3})
          x := x.contents +. 50.0
        }
        let y = ref(0.0)
        while y.contents < height {
          let _ =
            gridGraphics
            ->Graphics.moveTo(0.0, y.contents)
            ->Graphics.lineTo(width, y.contents)
            ->Graphics.stroke({"width": 1, "color": 0x1a1a1a, "alpha": 0.3})
          y := y.contents +. 50.0
        }
        // IMPORTANT: Clear old grid
        Container.removeChildren(Graphics.toContainer(desktopBg))
        let _ = Graphics.addChild(desktopBg, gridGraphics)

        // Clear topology content except topologyLines
        Container.removeChildren(topologyContainer)
        let _ = Container.addChildGraphics(topologyContainer, topologyLines)
        let _ = Graphics.clear(topologyLines)

        // Clear legend children
        Container.removeChildren(legendContainer)

        // Layout constants
        let iconWidth = 80.0
        let iconHeight = 80.0
        let iconCenterX = iconWidth /. 2.0
        let iconCenterY = iconHeight /. 2.0
        let _iconSpacingX = 110.0
        let _iconSpacingY = 130.0

        // Helper to draw a curved line between two points to avoid overlaps
        // Uses quadratic Bzier curve with perpendicular offset
        let drawCurvedLine = (
          fromX: float,
          fromY: float,
          toX: float,
          toY: float,
          color: int,
          width: float,
          curveOffset: float,
        ) => {
          let startX = fromX +. iconCenterX
          let startY = fromY +. iconCenterY
          let endX = toX +. iconCenterX
          let endY = toY +. iconCenterY

          // Calculate midpoint
          let midX = (startX +. endX) /. 2.0
          let midY = (startY +. endY) /. 2.0

          // Calculate perpendicular vector for curve offset
          let dx = endX -. startX
          let dy = endY -. startY
          let dist = sqrt(dx *. dx +. dy *. dy)

          // Perpendicular vector (normalized)
          let perpX = if dist > 0.0 {
            -.dy /. dist
          } else {
            0.0
          }
          let perpY = if dist > 0.0 {
            dx /. dist
          } else {
            0.0
          }

          // Control point offset perpendicular to the line
          let controlX = midX +. perpX *. curveOffset
          let controlY = midY +. perpY *. curveOffset

          let _ =
            topologyLines
            ->Graphics.moveTo(startX, startY)
            ->Graphics.quadraticCurveTo(controlX, controlY, endX, endY)
            ->Graphics.stroke({"width": width, "color": color, "alpha": 0.6})
        }

        // Track edges to avoid overlaps
        let edgeCounter: dict<int> = Dict.make()

        let drawLine = (
          fromX: float,
          fromY: float,
          toX: float,
          toY: float,
          color: int,
          width: float,
        ) => {
          // Create edge key (bidirectional)
          let key1 = `${Float.toString(fromX)},${Float.toString(fromY)}-${Float.toString(
              toX,
            )},${Float.toString(toY)}`
          let key2 = `${Float.toString(toX)},${Float.toString(toY)}-${Float.toString(
              fromX,
            )},${Float.toString(fromY)}`

          // Check if we've drawn this edge before (in either direction)
          let count = switch (Dict.get(edgeCounter, key1), Dict.get(edgeCounter, key2)) {
          | (Some(c), _) => c
          | (_, Some(c)) => c
          | _ => 0
          }

          // Increment counter
          Dict.set(edgeCounter, key1, count + 1)

          // Calculate curve offset based on count
          // First edge: slight curve (30px)
          // Subsequent edges: alternate left/right with increasing offset
          let baseOffset = 30.0
          let curveOffset = if count == 0 {
            baseOffset
          } else {
            // Alternate direction: even = positive, odd = negative
            let direction = if mod(count, 2) == 0 {
              1.0
            } else {
              -1.0
            }
            let magnitude = Int.toFloat(count / 2 + 1)
            direction *. baseOffset *. magnitude
          }

          drawCurvedLine(fromX, fromY, toX, toY, color, width, curveOffset)
        }

        // ========================================
        // BUILD NETWORK TOPOLOGY
        // ========================================

        // Instance-specific storage (created each resize)
        let nodes: dict<layoutNode> = Dict.make()
        let edges: array<layoutEdge> = []

        let addNode = (ip: string, x: float, y: float): unit => {
          Dict.set(nodes, ip, {ip, x, y})
        }

        let addEdge = (parent: string, child: string, ~strength: float=1.0, ()): unit => {
          let _ = Array.push(edges, {source: parent, target: child, strength})
        }

        // ========================================
        // BUILD NETWORK TOPOLOGY EDGES
        // ========================================

        let centerX = width *. 0.5
        let centerY = height *. 0.5

        // ========================================
        // BACKBONE RING TOPOLOGY
        // ========================================
        // 5 continental backbone servers in a ring
        // Ring connections (each backbone connects to next, forming a loop)
        let backboneRing = [
          ("203.0.113.1", "NA-BACKBONE"), // North America
          ("203.0.113.2", "EU-BACKBONE"), // Europe
          ("203.0.113.3", "ASIA-BACKBONE"), // Asia
          ("203.0.113.4", "SA-BACKBONE"), // South America
          ("203.0.113.5", "AF-BACKBONE"), // Africa
        ]

        // Store backbone IPs for special layout handling
        let backboneIPs = Array.map(backboneRing, ((ip, _)) => ip)

        // Ring edges (each connects to next)
        // All backbones connect sequentially: NAEUAsiaSAAF
        // But NAAF connection wraps vertically through duplicates
        Array.forEachWithIndex(backboneIPs, (ip, i) => {
          if i < Array.length(backboneIPs) - 1 {
            // Sequential connections within the ring (NAEU, EUAsia, etc.)
            // Bounds-checked: i+1 < length is guaranteed by the outer guard.
            switch backboneIPs[i + 1] {
            | Some(nextIP) => addEdge(ip, nextIP, ~strength=5.0, ())
            | None => ()
            }
          }
          // Note: AFNA connection handled separately for vertical wrapping
        })

        // ========================================
        // REGIONAL ISP CONNECTIONS TO BACKBONES
        // ========================================
        // North America backbone  Regional ISP (existing network)
        addEdge("203.0.113.1", "198.51.100.1", ~strength=4.0, ()) // NA Backbone  Regional ISP

        // Regional ISP  Tier 3 ISPs (existing network)
        addEdge("198.51.100.1", "100.64.2.1", ~strength=3.0, ()) // Regional  Business ISP
        addEdge("198.51.100.1", "100.64.1.1", ~strength=3.0, ()) // Regional  Rural ISP
        addEdge("100.64.2.1", "192.168.1.1", ~strength=3.0, ()) // Business ISP  Downtown Router
        addEdge("100.64.1.1", "192.168.2.1", ~strength=3.0, ()) // Rural ISP  Rural Router

        // Downtown Router branches - medium strength
        addEdge("192.168.1.1", "10.0.0.1", ~strength=2.0, ()) // Downtown  DMZ Firewall
        addEdge("192.168.1.1", "192.168.100.1", ~strength=2.0, ()) // Downtown  IoT Router
        Array.forEach(lanIcons.contents, icon => {
          addEdge("192.168.1.1", icon.ipAddress, ()) // Downtown  LAN devices
        })

        // DMZ Firewall branches - medium strength
        addEdge("10.0.0.1", "10.0.1.1", ~strength=2.0, ()) // DMZ  Internal Firewall
        Array.forEach(dmzIcons.contents, icon => {
          if icon.ipAddress != "10.0.0.1" {
            addEdge("10.0.0.1", icon.ipAddress, ()) // DMZ  DMZ devices
          }
        })

        // Internal Firewall branches (all internal zones)
        Array.forEach(internalIcons.contents, icon => {
          if icon.ipAddress != "10.0.1.1" {
            addEdge("10.0.1.1", icon.ipAddress, ()) // Internal Firewall  Internal devices
          }
        })
        Array.forEach(devIcons.contents, icon => {
          addEdge("10.0.1.1", icon.ipAddress, ()) // Internal Firewall  Dev devices
        })
        Array.forEach(securityIcons.contents, icon => {
          addEdge("10.0.1.1", icon.ipAddress, ()) // Internal Firewall  Security devices
        })
        Array.forEach(managementIcons.contents, icon => {
          addEdge("10.0.1.1", icon.ipAddress, ()) // Internal Firewall  Management devices
        })

        // IoT Router branch
        Array.forEach(iotIcons.contents, icon => {
          addEdge("192.168.100.1", icon.ipAddress, ()) // IoT Router  IoT devices
        })

        // Rural Router branch
        Array.forEach(ruralIcons.contents, icon => {
          addEdge("192.168.2.1", icon.ipAddress, ()) // Rural Router  Rural devices
        })

        // ========================================
        // SERVICE PROVIDER CONNECTIONS
        // ========================================
        // Distribute service providers across different backbone servers
        addEdge("203.0.113.1", "8.8.8.1", ~strength=3.0, ()) // NA Backbone  Atlas
        addEdge("203.0.113.2", "1.1.1.254", ~strength=3.0, ()) // EU Backbone  Nexus
        addEdge("203.0.113.3", "140.82.121.1", ~strength=3.0, ()) // Asia Backbone  DevHub

        Array.forEach(atlasIcons.contents, icon => {
          addEdge("8.8.8.1", icon.ipAddress, ()) // Atlas  Atlas devices
        })
        Array.forEach(nexusIcons.contents, icon => {
          addEdge("1.1.1.254", icon.ipAddress, ()) // Nexus  Nexus devices
        })
        Array.forEach(devhubIcons.contents, icon => {
          addEdge("140.82.121.1", icon.ipAddress, ()) // DevHub  DevHub devices
        })
        Array.forEach(externalIcons.contents, icon => {
          addEdge("203.0.113.1", icon.ipAddress, ()) // External devices directly to Tier 1
        })

        // ========================================
        // BACKBONE RING LAYOUT (Dynamic Spacing)
        // ========================================
        // Position backbone servers in a vertical line at center
        // Spacing adapts to each backbone's subnet sizes

        let _backboneCount = Array.length(backboneIPs)

        // Filter out ring edges for tree building (avoid circular dependencies)
        let treeEdges = Array.filter(edges, edge => {
          // Exclude backbone-to-backbone edges (ring connections)
          !(Array.some(backboneIPs, x => x == edge.source) && Array.some(backboneIPs, x => x == edge.target))
        })

        // First pass: Calculate required height for each backbone's children
        let backboneLayouts = Array.map(backboneIPs, backboneIP => {
          // Build tree for this backbone's children
          let backboneTree = buildTree(backboneIP, treeEdges)

          // Separate left (ISPs) and right (services) children
          let leftChildren = Array.filter(backboneTree.children, child =>
            String.startsWith(child.ip, "198.51.100.") ||
            // Regional ISPs
            String.startsWith(child.ip, "100.64.")
          ) // Tier 3 ISPs

          let rightChildren = Array.filter(backboneTree.children, child =>
            String.startsWith(child.ip, "8.8.8.") ||
            // Atlas
            String.startsWith(child.ip, "1.1.1.") ||
            // Nexus
            String.startsWith(child.ip, "140.82.") ||
            // DevHub
            String.startsWith(child.ip, "104.16.") ||
            // Nexus CDN
            String.startsWith(child.ip, "142.250.") ||
            // Atlas services
            Array.some(externalIcons.contents, icon => icon.ipAddress == child.ip)
          )

          // Calculate heights
          let leftHeight = if Array.length(leftChildren) > 0 {
            let heights = Array.map(leftChildren, calculateSubtreeHeights)
            Array.reduce(heights, 0.0, (acc, h) => acc +. h) +.
            Int.toFloat(Array.length(leftChildren) - 1) *. minBranchSpacing
          } else {
            0.0
          }

          let rightHeight = if Array.length(rightChildren) > 0 {
            let heights = Array.map(rightChildren, calculateSubtreeHeights)
            Array.reduce(heights, 0.0, (acc, h) => acc +. h) +.
            Int.toFloat(Array.length(rightChildren) - 1) *. minBranchSpacing
          } else {
            0.0
          }

          let totalHeight = Math.max(leftHeight, rightHeight)

          {ip: backboneIP, leftHeight, rightHeight, totalHeight}
        })

        // Calculate cumulative Y positions with dynamic spacing
        let minBackboneSpacing = 200.0 // Minimum spacing between backbones
        let backbonePositions = []
        let currentY = ref(0.0)

        Array.forEachWithIndex(backboneLayouts, (layout, i) => {
          let _ = Array.push(backbonePositions, currentY.contents)

          // Spacing to next backbone = max of (this backbone's height, min spacing)
          if i < Array.length(backboneLayouts) - 1 {
            let nextSpacing = Math.max(layout.totalHeight, minBackboneSpacing)
            currentY := currentY.contents +. nextSpacing
          }
        })

        // Total ring height (for infinite scrolling)
        // Total ring height (last backbone's totalHeight, or minBackboneSpacing).
        // Bounds-checked: backboneLayouts is populated by the loop above so
        // the last element should always exist, but we guard defensively.
        let lastLayoutHeight = switch backboneLayouts[Array.length(backboneLayouts) - 1] {
        | Some(layout) => layout.totalHeight
        | None => minBackboneSpacing
        }
        let totalRingHeight = currentY.contents +. Math.max(lastLayoutHeight, minBackboneSpacing)

        // Store in ref for use by event handlers
        totalRingHeightRef := totalRingHeight

        // Center the entire ring vertically
        let verticalOffset = centerY -. totalRingHeight /. 2.0

        // Second pass: Position backbone servers and layout their children
        // Second pass: position each backbone and its children.
        // Bounds-checked: backbonePositions and backboneLayouts were populated
        // in lock-step with backboneIPs, so indices should always align.
        Array.forEachWithIndex(backboneIPs, (backboneIP, i) => {
          let backboneY = switch backbonePositions[i] {
          | Some(pos) => pos +. verticalOffset
          | None => verticalOffset
          }
          let layout = switch backboneLayouts[i] {
          | Some(l) => l
          | None => {ip: backboneIP, leftHeight: 0.0, rightHeight: 0.0, totalHeight: 0.0}
          }

          // Position this backbone server
          addNode(backboneIP, centerX, backboneY)

          // Build tree (reuse from first pass calculations)
          let backboneTree = buildTree(backboneIP, treeEdges)

          // Separate left (ISPs) and right (services) children
          let leftChildren = Array.filter(backboneTree.children, child =>
            String.startsWith(child.ip, "198.51.100.") || String.startsWith(child.ip, "100.64.")
          )

          let rightChildren = Array.filter(backboneTree.children, child =>
            String.startsWith(child.ip, "8.8.8.") ||
            String.startsWith(child.ip, "1.1.1.") ||
            String.startsWith(child.ip, "140.82.") ||
            String.startsWith(child.ip, "104.16.") ||
            String.startsWith(child.ip, "142.250.") ||
            Array.some(externalIcons.contents, icon => icon.ipAddress == child.ip)
          )

          // Layout left children (ISP hierarchies) - centered on backbone
          if Array.length(leftChildren) > 0 {
            let leftStartY = backboneY -. layout.leftHeight /. 2.0
            let currentY = ref(leftStartY)

            Array.forEach(leftChildren, child => {
              let _ = calculateSubtreeHeights(child)
              let childCenterY = currentY.contents +. child.subtreeHeight /. 2.0
              layoutNode(child, centerX -. levelSpacing, childCenterY, #Left, nodes)
              currentY := currentY.contents +. child.subtreeHeight +. minBranchSpacing
            })
          }

          // Layout right children (service providers) - centered on backbone
          if Array.length(rightChildren) > 0 {
            let rightStartY = backboneY -. layout.rightHeight /. 2.0
            let currentY = ref(rightStartY)

            Array.forEach(rightChildren, child => {
              let _ = calculateSubtreeHeights(child)
              let childCenterY = currentY.contents +. child.subtreeHeight /. 2.0
              layoutNode(child, centerX +. levelSpacing, childCenterY, #Right, nodes)
              currentY := currentY.contents +. child.subtreeHeight +. minBranchSpacing
            })
          }
        })

        // ========================================
        // INFINITE SCROLLING SETUP
        // ========================================
        // Create two buffer copies in each direction (5 total copies)
        // Wrapping logic will create the illusion of infinite scrolling

        // Store original nodes
        let originalNodes = Dict.toArray(nodes)

        // Add two duplicates above
        Array.forEach(originalNodes, ((ip, node)) => {
          Dict.set(
            nodes,
            `${ip}_above1`,
            {
              ip: `${ip}_above1`,
              x: node.x,
              y: node.y -. totalRingHeight,
            },
          )
          Dict.set(
            nodes,
            `${ip}_above2`,
            {
              ip: `${ip}_above2`,
              x: node.x,
              y: node.y -. totalRingHeight *. 2.0,
            },
          )
        })

        // Add two duplicates below
        Array.forEach(originalNodes, ((ip, node)) => {
          Dict.set(
            nodes,
            `${ip}_below1`,
            {
              ip: `${ip}_below1`,
              x: node.x,
              y: node.y +. totalRingHeight,
            },
          )
          Dict.set(
            nodes,
            `${ip}_below2`,
            {
              ip: `${ip}_below2`,
              x: node.x,
              y: node.y +. totalRingHeight *. 2.0,
            },
          )
        })

        // SCADA devices (air-gapped, positioned separately on the left)
        let scadaDeviceIPs = Array.map(scadaIcons.contents, icon => icon.ipAddress)
        Array.forEachWithIndex(scadaDeviceIPs, (ip, i) => {
          let scadaX = -400.0 // Position to the left of the main network
          let scadaY = centerY +. Int.toFloat(i - Array.length(scadaDeviceIPs) / 2) *. 150.0
          addNode(ip, scadaX, scadaY)

          // Duplicate SCADA for infinite scrolling (two buffers each direction)
          Dict.set(
            nodes,
            `${ip}_above1`,
            {ip: `${ip}_above1`, x: scadaX, y: scadaY -. totalRingHeight},
          )
          Dict.set(
            nodes,
            `${ip}_above2`,
            {ip: `${ip}_above2`, x: scadaX, y: scadaY -. totalRingHeight *. 2.0},
          )
          Dict.set(
            nodes,
            `${ip}_below1`,
            {ip: `${ip}_below1`, x: scadaX, y: scadaY +. totalRingHeight},
          )
          Dict.set(
            nodes,
            `${ip}_below2`,
            {ip: `${ip}_below2`, x: scadaX, y: scadaY +. totalRingHeight *. 2.0},
          )
        })

        // ========================================
        // DUPLICATE EDGES FOR INFINITE SCROLLING
        // ========================================
        let originalEdges = Array.copy(edges)

        // Add edges for above copies
        Array.forEach(originalEdges, edge => {
          let _ = Array.push(
            edges,
            {
              source: `${edge.source}_above1`,
              target: `${edge.target}_above1`,
              strength: edge.strength,
            },
          )
          let _ = Array.push(
            edges,
            {
              source: `${edge.source}_above2`,
              target: `${edge.target}_above2`,
              strength: edge.strength,
            },
          )
        })

        // Add edges for below copies
        Array.forEach(originalEdges, edge => {
          let _ = Array.push(
            edges,
            {
              source: `${edge.source}_below1`,
              target: `${edge.target}_below1`,
              strength: edge.strength,
            },
          )
          let _ = Array.push(
            edges,
            {
              source: `${edge.source}_below2`,
              target: `${edge.target}_below2`,
              strength: edge.strength,
            },
          )
        })

        // ========================================
        // BACKBONE RING VERTICAL WRAPPING
        // ========================================
        // Special case: NA-BACKBONE and AF-BACKBONE ring closure
        // Instead of connecting horizontally within same copy,
        // connect vertically to nearest copy above/below
        let naBackboneIP = "203.0.113.1" // Top of ring
        let afBackboneIP = "203.0.113.5" // Bottom of ring

        // Create vertical wrapping connections between layers
        addEdge(afBackboneIP, `${naBackboneIP}_below1`, ~strength=5.0, ())
        addEdge(naBackboneIP, `${afBackboneIP}_above1`, ~strength=5.0, ())
        addEdge(`${afBackboneIP}_above1`, naBackboneIP, ~strength=5.0, ())
        addEdge(`${naBackboneIP}_below1`, afBackboneIP, ~strength=5.0, ())
        addEdge(`${afBackboneIP}_above2`, `${naBackboneIP}_above1`, ~strength=5.0, ())
        addEdge(`${naBackboneIP}_below2`, `${afBackboneIP}_below1`, ~strength=5.0, ())

        // ========================================
        // APPLY POSITIONS TO VISUAL ICONS
        // ========================================

        // Helper to apply node position to icon container
        let applyPosition = (ip: string, icons: array<DeviceIcon.t>): unit => {
          switch Dict.get(nodes, ip) {
          | Some(node) =>
            switch Array.find(icons, icon => icon.ipAddress == ip) {
            | Some(icon) =>
              Container.setX(icon.container, node.x)
              Container.setY(icon.container, node.y)
            | None => ()
            }
          | None => ()
          }
        }

        // ========================================
        // INFINITE SCROLLING: Create full visual duplicates
        // ========================================
        // Duplicate all device icons (2 above, 2 below = 5 total copies)

        // Clear existing duplicates from previous resize
        iconsAbove1.contents = []
        iconsAbove2.contents = []
        iconsBelow1.contents = []
        iconsBelow2.contents = []

        // Create duplicates for each device
        Array.forEach(allCreatedIcons.contents, ((ipAddress, _originalIcon)) => {
          // Create icons for above positions
          switch DeviceIcon.make(networkManager, ipAddress, ~screenContainer=container, ()) {
          | Some(icon) =>
            Container.addChild(topologyContainer, icon.container)->ignore
            let _ = Array.push(iconsAbove1.contents, icon)
          | None => ()
          }
          switch DeviceIcon.make(networkManager, ipAddress, ~screenContainer=container, ()) {
          | Some(icon) =>
            Container.addChild(topologyContainer, icon.container)->ignore
            let _ = Array.push(iconsAbove2.contents, icon)
          | None => ()
          }

          // Create icons for below positions
          switch DeviceIcon.make(networkManager, ipAddress, ~screenContainer=container, ()) {
          | Some(icon) =>
            Container.addChild(topologyContainer, icon.container)->ignore
            let _ = Array.push(iconsBelow1.contents, icon)
          | None => ()
          }
          switch DeviceIcon.make(networkManager, ipAddress, ~screenContainer=container, ()) {
          | Some(icon) =>
            Container.addChild(topologyContainer, icon.container)->ignore
            let _ = Array.push(iconsBelow2.contents, icon)
          | None => ()
          }
        })

        // Re-add original icons to topologyContainer (they were cleared above)
        Array.forEach(allCreatedIcons.contents, ((_, icon)) => {
          let _ = Container.addChild(topologyContainer, icon.container)
        })

        // Apply positions to routers (stored separately)
        switch (mainRouterIcon.contents, Dict.get(nodes, "192.168.1.1")) {
        | (Some(icon), Some(node)) =>
          Container.setX(icon.container, node.x)
          Container.setY(icon.container, node.y)
        | _ => ()
        }

        switch (ruralRouterIcon.contents, Dict.get(nodes, "192.168.2.1")) {
        | (Some(icon), Some(node)) =>
          Container.setX(icon.container, node.x)
          Container.setY(icon.container, node.y)
        | _ => ()
        }

        switch (iotRouterIcon.contents, Dict.get(nodes, "192.168.100.1")) {
        | (Some(icon), Some(node)) =>
          Container.setX(icon.container, node.x)
          Container.setY(icon.container, node.y)
        | _ => ()
        }

        // Function to apply all positions from simulation
        let applyAllPositions = () => {
          // Get router positions from simulation
          let mainRouterPos = Dict.get(nodes, "192.168.1.1")
          let ruralRouterPos = Dict.get(nodes, "192.168.2.1")
          let iotRouterPos = Dict.get(nodes, "192.168.100.1")

          // Apply positions to routers
          switch (mainRouterIcon.contents, mainRouterPos) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }
          switch (ruralRouterIcon.contents, ruralRouterPos) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }
          switch (iotRouterIcon.contents, iotRouterPos) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }

          // Apply positions to all device arrays
          Array.forEach(lanIcons.contents, icon => applyPosition(icon.ipAddress, lanIcons.contents))
          Array.forEach(dmzIcons.contents, icon => applyPosition(icon.ipAddress, dmzIcons.contents))
          Array.forEach(internalIcons.contents, icon =>
            applyPosition(icon.ipAddress, internalIcons.contents)
          )
          Array.forEach(devIcons.contents, icon => applyPosition(icon.ipAddress, devIcons.contents))
          Array.forEach(securityIcons.contents, icon =>
            applyPosition(icon.ipAddress, securityIcons.contents)
          )
          Array.forEach(managementIcons.contents, icon =>
            applyPosition(icon.ipAddress, managementIcons.contents)
          )
          Array.forEach(iotIcons.contents, icon => applyPosition(icon.ipAddress, iotIcons.contents))
          Array.forEach(ruralIcons.contents, icon =>
            applyPosition(icon.ipAddress, ruralIcons.contents)
          )
          Array.forEach(scadaIcons.contents, icon =>
            applyPosition(icon.ipAddress, scadaIcons.contents)
          )

          // Apply positions to ISP routers
          switch (ruralIspIcon.contents, Dict.get(nodes, "100.64.1.1")) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }
          switch (businessIspIcon.contents, Dict.get(nodes, "100.64.2.1")) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }
          switch (regionalIspIcon.contents, Dict.get(nodes, "198.51.100.1")) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }
          // Backbone servers (ring topology)
          switch (naBackboneIcon.contents, Dict.get(nodes, "203.0.113.1")) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }
          switch (euBackboneIcon.contents, Dict.get(nodes, "203.0.113.2")) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }
          switch (asiaBackboneIcon.contents, Dict.get(nodes, "203.0.113.3")) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }
          switch (saBackboneIcon.contents, Dict.get(nodes, "203.0.113.4")) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }
          switch (afBackboneIcon.contents, Dict.get(nodes, "203.0.113.5")) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }

          // Apply positions to service routers
          switch (atlasRouterIcon.contents, Dict.get(nodes, "8.8.8.1")) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }
          switch (nexusRouterIcon.contents, Dict.get(nodes, "1.1.1.254")) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }
          switch (devhubRouterIcon.contents, Dict.get(nodes, "140.82.121.1")) {
          | (Some(icon), Some(node)) =>
            Container.setX(icon.container, node.x)
            Container.setY(icon.container, node.y)
          | _ => ()
          }

          // Apply positions to service devices
          Array.forEach(atlasIcons.contents, icon =>
            applyPosition(icon.ipAddress, atlasIcons.contents)
          )
          Array.forEach(nexusIcons.contents, icon =>
            applyPosition(icon.ipAddress, nexusIcons.contents)
          )
          Array.forEach(devhubIcons.contents, icon =>
            applyPosition(icon.ipAddress, devhubIcons.contents)
          )
          Array.forEach(externalIcons.contents, icon =>
            applyPosition(icon.ipAddress, externalIcons.contents)
          )

          // ========================================
          // POSITION DUPLICATE ICONS FOR INFINITE SCROLLING
          // ========================================
          let duplicateIndex = ref(0)
          Array.forEach(allCreatedIcons.contents, ((ipAddress, _)) => {
            let idx = duplicateIndex.contents

            // Position duplicate icons for infinite scrolling.
            // Bounds-checked via Array.get  idx is guaranteed < length by the
            // outer guard, but we use safe access to prevent OOB crashes from
            // any desync between allCreatedIcons and the duplicate icon arrays.
            if idx < Array.length(iconsAbove1.contents) {
              Dict.get(nodes, `${ipAddress}_above1`)->Option.forEach(node => {
                iconsAbove1.contents[idx]->Option.forEach(
                  icon => {
                    Container.setX(icon.container, node.x)
                    Container.setY(icon.container, node.y)
                  },
                )
              })
              Dict.get(nodes, `${ipAddress}_above2`)->Option.forEach(node => {
                iconsAbove2.contents[idx]->Option.forEach(
                  icon => {
                    Container.setX(icon.container, node.x)
                    Container.setY(icon.container, node.y)
                  },
                )
              })
            }

            // Position icons below
            if idx < Array.length(iconsBelow1.contents) {
              Dict.get(nodes, `${ipAddress}_below1`)->Option.forEach(node => {
                iconsBelow1.contents[idx]->Option.forEach(
                  icon => {
                    Container.setX(icon.container, node.x)
                    Container.setY(icon.container, node.y)
                  },
                )
              })
              Dict.get(nodes, `${ipAddress}_below2`)->Option.forEach(node => {
                iconsBelow2.contents[idx]->Option.forEach(
                  icon => {
                    Container.setX(icon.container, node.x)
                    Container.setY(icon.container, node.y)
                  },
                )
              })
            }

            duplicateIndex := duplicateIndex.contents + 1
          })

          // Redraw all connection lines from force simulation
          let _ = Graphics.clear(topologyLines)

          // Reset edge counter for consistent curve patterns
          Dict.toArray(edgeCounter)->Array.forEach(((key, _)) => {
            Dict.delete(edgeCounter, key)->ignore
          })

          // Draw all edges from network topology
          Array.forEach(edges, edge => {
            switch (Dict.get(nodes, edge.source), Dict.get(nodes, edge.target)) {
            | (Some(sourceNode), Some(targetNode)) =>
              // Color based on edge strength
              let lineColor = if edge.strength >= 5.0 {
                0xFF00FF // Magenta for backbone ring (strongest)
              } else if edge.strength >= 4.0 {
                0xFF0000 // Red for Tier 1 connections
              } else if edge.strength >= 3.0 {
                0xFF9800 // Orange for strong (ISP tier connections)
              } else if edge.strength >= 2.0 {
                0xFFFF00 // Yellow for medium (firewall/router connections)
              } else {
                0x4CAF50 // Green for normal (device connections)
              }
              let lineWidth = if edge.strength >= 5.0 {
                5.0
              } else if edge.strength >= 3.0 {
                4.0
              } else if edge.strength >= 2.0 {
                3.0
              } else {
                2.0
              }
              drawLine(sourceNode.x, sourceNode.y, targetNode.x, targetNode.y, lineColor, lineWidth)
            | _ => ()
            }
          })
        }

        // Apply positions initially
        applyAllPositions()

        // SCADA devices are air-gapped (no connections) positioned on the left

        // Legend - Connection Types
        // IMPORTANT: Clear old legend children
        Container.removeChildren(legendContainer)

        let legendX = width -. 420.0
        let legendY = height -. 180.0
        let legendTitle = Text.make({
          "text": "Connection Types",
          "style": {"fontSize": 14, "fill": 0xffffff, "fontWeight": "bold"},
        })
        let _ = Container.addChildText(legendContainer, legendTitle)

        // Legend entries (2-column layout)
        let legendEntries = [
          ("LAN", 0x4CAF50, 2.0),
          ("DMZ", 0xFF9800, 2.0),
          ("Internal Apps", 0x2196F3, 2.0),
          ("Dev/Test", 0x9C27B0, 2.0),
          ("Security", 0xF44336, 2.0),
          ("Management", 0x00BCD4, 2.0),
          ("IoT", 0xE91E63, 2.0),
          ("Tier 3 ISP", 0xFFFF00, 3.0),
          ("Tier 2 ISP", 0xFF9800, 4.0),
          ("Tier 1 Backbone", 0xFF0000, 5.0),
          ("Services", 0xFFFFFF, 3.0),
        ]

        Array.forEachWithIndex(legendEntries, ((color, lineWidth, label), i) => {
          let column = i >= 6 ? 1 : 0 // Split at entry 6
          let row = if column == 0 {
            i
          } else {
            i - 6
          }
          let xPos = 10.0 +. Int.toFloat(column) *. 200.0
          let yPos = 35.0 +. Int.toFloat(row) *. 20.0

          // Draw line sample
          let line = Graphics.make()
          let _ = line->Graphics.moveTo(xPos, yPos +. 5.0)
          let _ = line->Graphics.lineTo(xPos +. 30.0, yPos +. 5.0)
          let _ = line->Graphics.stroke({"color": color, "width": lineWidth})
          let _ = Container.addChildGraphics(legendContainer, line)

          // Draw label text
          let labelText = Text.make({"text": label, "style": {"fontSize": 10, "fill": 0xCCCCCC}})
          Text.setX(labelText, xPos +. 40.0)
          Text.setY(labelText, yPos)
          let _ = Container.addChildText(legendContainer, labelText)
        })

        // Position legend in bottom-right
        Container.setX(legendContainer, legendX)
        Container.setY(legendContainer, legendY)

        // ========== PAN AND ZOOM CONTROLS ==========

        // Enable interactive mode on desktop background
        Graphics.setEventMode(desktopBg, "static")

        // Mouse wheel zoom (zooms toward cursor position)
        Graphics.on(desktopBg, "wheel", (_evt: 'a) => {
          let deltaY: float = %raw(`_evt.deltaY`)
          let zoomFactor = if deltaY < 0.0 {
            1.1
          } else {
            0.9
          }
          let newScale = scale.contents *. zoomFactor

          // Clamp scale between 0.3x and 3x
          if newScale >= 0.3 && newScale <= 3.0 {
            // Get mouse position
            let mouseX: float = %raw(`_evt.global.x`)
            let mouseY: float = %raw(`_evt.global.y`)

            // Get current position and scale
            let oldScale = scale.contents
            let oldX = Container.x(topologyContainer)
            let oldY = Container.y(topologyContainer)

            // Calculate world position under cursor.
            // SafeFloat.divOr guards against oldScale=0 (which would produce
            // Infinity, breaking all subsequent position calculations).
            let worldX = SafeFloat.divOr(mouseX -. oldX, oldScale, ~default=0.0)
            let worldY = SafeFloat.divOr(mouseY -. oldY, oldScale, ~default=0.0)

            // Apply new scale
            scale := newScale
            let scalePoint = Container.scale(topologyContainer)
            ObservablePoint.set(scalePoint, newScale, ~y=newScale)

            // Adjust position so world point under cursor stays in place
            let newX = mouseX -. worldX *. newScale
            let newY = mouseY -. worldY *. newScale

            // Infinite scrolling: wrap at 1.0*totalRingHeight (scaled)
            // Wrap when we've scrolled exactly one full ring height
            let scaledRingHeight = totalRingHeightRef.contents *. newScale

            let wrappedY = if newY > scaledRingHeight {
              newY -. scaledRingHeight
            } else if newY < -.scaledRingHeight {
              newY +. scaledRingHeight
            } else {
              newY
            }

            Container.setX(topologyContainer, newX)
            Container.setY(topologyContainer, wrappedY)
          }

          %raw(`_evt.preventDefault()`)
        })

        // Pan with mouse drag
        Graphics.on(desktopBg, "pointerdown", (_evt: 'a) => {
          isDragging := true
          dragStartX := %raw(`_evt.global.x`) -. Container.x(topologyContainer)
          dragStartY := %raw(`_evt.global.y`) -. Container.y(topologyContainer)
        })

        Graphics.on(desktopBg, "pointerup", (_evt: 'a) => {
          isDragging := false
        })

        Graphics.on(desktopBg, "pointerupoutside", (_evt: 'a) => {
          isDragging := false
        })

        Graphics.on(desktopBg, "pointermove", (_evt: 'a) => {
          if isDragging.contents {
            let globalX: float = %raw(`_evt.global.x`)
            let globalY: float = %raw(`_evt.global.y`)
            let newX = globalX -. dragStartX.contents
            let newY = globalY -. dragStartY.contents

            // Infinite scrolling: wrap at 1.0*totalRingHeight (scaled)
            // Wrap when we've scrolled exactly one full ring height
            let currentScale = scale.contents
            let scaledRingHeight = totalRingHeightRef.contents *. currentScale

            let wrappedY = if newY > scaledRingHeight {
              // Wrap and adjust drag anchor
              dragStartY := dragStartY.contents +. scaledRingHeight
              newY -. scaledRingHeight
            } else if newY < -.scaledRingHeight {
              // Wrap and adjust drag anchor
              dragStartY := dragStartY.contents -. scaledRingHeight
              newY +. scaledRingHeight
            } else {
              newY
            }

            Container.setX(topologyContainer, newX)
            Container.setY(topologyContainer, wrappedY)
          }
        })

        // Position instructions text (created once in 'make')
        Text.setX(instructions, 10.0)
        Text.setY(instructions, height -. 25.0)
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
