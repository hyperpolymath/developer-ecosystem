// SPDX-License-Identifier: PMPL-1.0-or-later
// World Screen - Physical world view with hacker character
// Sidescrolling platformer with mouse-aimed jumping

open Pixi
open PixiUI

// Asset bundles required by this screen
let assetBundles = ["main"]

// World device - a device placed in the world
type worldDevice = {
  container: Container.t,
  device: DeviceTypes.device,
  x: float,
  y: float,
  powerIndicator: option<Graphics.t>,
  ipAddress: string,
}

// World constants
let groundY = 500.0  // Y position of the ground
let interactionDistance = 100.0  // Max distance to interact with a device

// World device icon - devices sit on the ground
module WorldDeviceIcon = {
  let make = (device: DeviceTypes.device, x: float): worldDevice => {
    let info = device.getInfo()
    let container = Container.make()
    Container.setEventMode(container, "static")
    Container.setCursor(container, "pointer")
    Container.setX(container, x)
    Container.setY(container, groundY)  // All devices on ground level

    // Device graphic based on type
    let deviceGraphic = Graphics.make()
    let deviceColor = DeviceTypes.getDeviceColor(info.deviceType)

    switch info.deviceType {
    | Laptop =>
      // Laptop on a small desk
      // Desk
      let _ = deviceGraphic
        ->Graphics.rect(-35.0, -20.0, 70.0, 20.0)
        ->Graphics.fill({"color": 0x4a3728})
      // Desk legs
      let _ = deviceGraphic
        ->Graphics.rect(-30.0, 0.0, 8.0, 20.0)
        ->Graphics.fill({"color": 0x4a3728})
      let _ = deviceGraphic
        ->Graphics.rect(22.0, 0.0, 8.0, 20.0)
        ->Graphics.fill({"color": 0x4a3728})
      // Laptop screen
      let _ = deviceGraphic
        ->Graphics.rect(-25.0, -55.0, 50.0, 35.0)
        ->Graphics.fill({"color": 0x333333})
      let _ = deviceGraphic
        ->Graphics.rect(-22.0, -52.0, 44.0, 29.0)
        ->Graphics.fill({"color": deviceColor})
      // Laptop base
      let _ = deviceGraphic
        ->Graphics.rect(-28.0, -20.0, 56.0, 8.0)
        ->Graphics.fill({"color": 0x444444})
    | Server =>
      // Tall server rack
      let _ = deviceGraphic
        ->Graphics.rect(-25.0, -120.0, 50.0, 120.0)
        ->Graphics.fill({"color": 0x333333})
      // Server units
      for i in 0 to 5 {
        let yPos = -115.0 +. Int.toFloat(i) *. 18.0
        let _ = deviceGraphic
          ->Graphics.rect(-22.0, yPos, 44.0, 16.0)
          ->Graphics.fill({"color": deviceColor})
        // LED
        let _ = deviceGraphic
          ->Graphics.circle(17.0, yPos +. 8.0, 3.0)
          ->Graphics.fill({"color": 0x00ff00})
      }
    | Router =>
      // Router on a small shelf
      // Shelf
      let _ = deviceGraphic
        ->Graphics.rect(-30.0, -40.0, 60.0, 8.0)
        ->Graphics.fill({"color": 0x4a3728})
      // Shelf support
      let _ = deviceGraphic
        ->Graphics.rect(-5.0, -40.0, 10.0, 40.0)
        ->Graphics.fill({"color": 0x4a3728})
      // Router box
      let _ = deviceGraphic
        ->Graphics.rect(-25.0, -60.0, 50.0, 20.0)
        ->Graphics.fill({"color": deviceColor})
      // Antennas
      let _ = deviceGraphic
        ->Graphics.rect(-18.0, -85.0, 4.0, 25.0)
        ->Graphics.fill({"color": 0x333333})
      let _ = deviceGraphic
        ->Graphics.rect(14.0, -85.0, 4.0, 25.0)
        ->Graphics.fill({"color": 0x333333})
      // LEDs
      for i in 0 to 3 {
        let _ = deviceGraphic
          ->Graphics.circle(-15.0 +. Int.toFloat(i) *. 10.0, -50.0, 3.0)
          ->Graphics.fill({"color": 0x00ff00})
      }
    | Firewall =>
      // Hardened rack-mount appliance with brick-wall motif
      // Main chassis
      let _ = deviceGraphic
        ->Graphics.rect(-30.0, -80.0, 60.0, 40.0)
        ->Graphics.fill({"color": 0x2a1a1a})
        ->Graphics.stroke({"width": 2, "color": deviceColor})
      // Brick pattern (3 rows of offset bricks)
      for row in 0 to 2 {
        let yPos = -75.0 +. Int.toFloat(row) *. 12.0
        let offset = if mod(row, 2) == 0 { 0.0 } else { 10.0 }
        for col in 0 to 2 {
          let xPos = -25.0 +. offset +. Int.toFloat(col) *. 18.0
          let _ = deviceGraphic
            ->Graphics.rect(xPos, yPos, 16.0, 10.0)
            ->Graphics.fill({"color": deviceColor})
        }
      }
      // Status LED row
      for i in 0 to 3 {
        let _ = deviceGraphic
          ->Graphics.circle(-18.0 +. Int.toFloat(i) *. 12.0, -45.0, 3.0)
          ->Graphics.fill({"color": 0x00ff00})
      }
      // Wall-mount bracket
      let _ = deviceGraphic
        ->Graphics.rect(-5.0, -40.0, 10.0, 40.0)
        ->Graphics.fill({"color": 0x444444})

    | IotCamera =>
      // Camera on a tall pole
      // Pole
      let _ = deviceGraphic
        ->Graphics.rect(-4.0, -100.0, 8.0, 100.0)
        ->Graphics.fill({"color": 0x666666})
      // Camera mount
      let _ = deviceGraphic
        ->Graphics.rect(-15.0, -110.0, 30.0, 10.0)
        ->Graphics.fill({"color": 0x444444})
      // Camera body
      let _ = deviceGraphic
        ->Graphics.circle(0.0, -125.0, 18.0)
        ->Graphics.fill({"color": deviceColor})
      // Lens
      let _ = deviceGraphic
        ->Graphics.circle(0.0, -125.0, 10.0)
        ->Graphics.fill({"color": 0x222222})

    | Terminal =>
      // Computer terminal on desk
      // Desk
      let _ = deviceGraphic
        ->Graphics.rect(-40.0, -30.0, 80.0, 30.0)
        ->Graphics.fill({"color": 0x4a3728})
      // Desk legs
      let _ = deviceGraphic
        ->Graphics.rect(-35.0, 0.0, 8.0, 25.0)
        ->Graphics.fill({"color": 0x4a3728})
      let _ = deviceGraphic
        ->Graphics.rect(27.0, 0.0, 8.0, 25.0)
        ->Graphics.fill({"color": 0x4a3728})
      // Monitor
      let _ = deviceGraphic
        ->Graphics.rect(-30.0, -80.0, 60.0, 50.0)
        ->Graphics.fill({"color": 0x333333})
      let _ = deviceGraphic
        ->Graphics.rect(-27.0, -77.0, 54.0, 44.0)
        ->Graphics.fill({"color": 0x000000})
      // Terminal text
      let termText = Text.make({
        "text": ">_",
        "style": {"fill": 0x00ff00, "fontSize": 16},
      })
      Text.setX(termText, -20.0)
      Text.setY(termText, -70.0)
      let _ = Graphics.addChild(deviceGraphic, termText)
      // Monitor stand
      let _ = deviceGraphic
        ->Graphics.rect(-8.0, -30.0, 16.0, 10.0)
        ->Graphics.fill({"color": 0x333333})
      // Keyboard
      let _ = deviceGraphic
        ->Graphics.rect(-25.0, -28.0, 50.0, 8.0)
        ->Graphics.fill({"color": 0x222222})

    | PowerStation =>
      // Large industrial power station unit
      // Main cabinet
      let _ = deviceGraphic
        ->Graphics.rect(-40.0, -150.0, 80.0, 150.0)
        ->Graphics.fill({"color": 0x2a2a2a})
      // Cabinet door
      let _ = deviceGraphic
        ->Graphics.rect(-35.0, -145.0, 70.0, 140.0)
        ->Graphics.fill({"color": 0x333333})
        ->Graphics.stroke({"width": 2, "color": 0x444444})
      // Ventilation grille
      for i in 0 to 5 {
        let yPos = -140.0 +. Int.toFloat(i) *. 12.0
        let _ = deviceGraphic
          ->Graphics.rect(-30.0, yPos, 60.0, 8.0)
          ->Graphics.fill({"color": 0x1a1a1a})
      }
      // Power meter display
      let _ = deviceGraphic
        ->Graphics.rect(-25.0, -60.0, 50.0, 30.0)
        ->Graphics.fill({"color": 0x000000})
        ->Graphics.stroke({"width": 1, "color": deviceColor})
      // Power bars
      for i in 0 to 4 {
        let _ = deviceGraphic
          ->Graphics.rect(-20.0 +. Int.toFloat(i) *. 10.0, -55.0, 6.0, 20.0)
          ->Graphics.fill({"color": deviceColor})
      }
      // Warning stripe at bottom
      let _ = deviceGraphic
        ->Graphics.rect(-40.0, -20.0, 80.0, 20.0)
        ->Graphics.fill({"color": 0xffcc00})
      for i in 0 to 7 {
        let _ = deviceGraphic
          ->Graphics.rect(-40.0 +. Int.toFloat(i) *. 20.0, -20.0, 10.0, 20.0)
          ->Graphics.fill({"color": 0x222222})
      }
      // Status light
      let _ = deviceGraphic
        ->Graphics.circle(0.0, -130.0, 8.0)
        ->Graphics.fill({"color": 0x00ff00})

    | UPS =>
      // UPS unit (smaller than power station)
      // Main box
      let _ = deviceGraphic
        ->Graphics.rect(-30.0, -80.0, 60.0, 80.0)
        ->Graphics.fill({"color": 0x3d3d3d})
        ->Graphics.stroke({"width": 2, "color": 0x505050})
      // Front panel
      let _ = deviceGraphic
        ->Graphics.rect(-25.0, -75.0, 50.0, 70.0)
        ->Graphics.fill({"color": deviceColor})
      // LCD display
      let _ = deviceGraphic
        ->Graphics.rect(-20.0, -70.0, 40.0, 20.0)
        ->Graphics.fill({"color": 0x1a3a1a})
        ->Graphics.stroke({"width": 1, "color": 0x00ff00})
      // Battery icon on display
      let _ = deviceGraphic
        ->Graphics.rect(-15.0, -65.0, 20.0, 10.0)
        ->Graphics.fill({"color": 0x00ff00})
      let _ = deviceGraphic
        ->Graphics.rect(5.0, -63.0, 3.0, 6.0)
        ->Graphics.fill({"color": 0x00ff00})
      // Status LEDs
      let _ = deviceGraphic
        ->Graphics.circle(-10.0, -40.0, 4.0)
        ->Graphics.fill({"color": 0x00ff00})  // Power
      let _ = deviceGraphic
        ->Graphics.circle(0.0, -40.0, 4.0)
        ->Graphics.fill({"color": 0x00ff00})  // Battery
      let _ = deviceGraphic
        ->Graphics.circle(10.0, -40.0, 4.0)
        ->Graphics.fill({"color": 0x00ff00})  // Line
      // Outlets at bottom
      for i in 0 to 2 {
        let _ = deviceGraphic
          ->Graphics.rect(-18.0 +. Int.toFloat(i) *. 14.0, -25.0, 10.0, 12.0)
          ->Graphics.fill({"color": 0x222222})
      }
    }

    let _ = Container.addChildGraphics(container, deviceGraphic)

    // Add camera indicator light on top of device graphic (for cameras only)
    switch info.deviceType {
    | IotCamera =>
      let cameraIndicator = Graphics.make()
      let _ = cameraIndicator
        ->Graphics.circle(0.0, -125.0, 5.0)
        ->Graphics.fill({"color": 0x0066cc})  // Blue when idle
      let _ = Container.addChildGraphics(container, cameraIndicator)

      // Register camera position for background motion checking
      // Use same view width as CameraDevice (300.0)
      CameraFeed.registerCameraPosition(info.ipAddress, x, 300.0)

      // Register callback to change indicator color on motion detection
      // None = disabled/grey, Some(false) = no motion/blue, Some(true) = motion/orange
      CameraFeed.registerMotionCallback(info.ipAddress, (status) => {
        let _ = Graphics.clear(cameraIndicator)
        let indicatorColor = switch status {
        | None => 0x666666  // Grey when disabled
        | Some(false) => 0x0066cc  // Blue when idle
        | Some(true) => 0xff6600  // Orange when motion detected
        }
        let _ = cameraIndicator
          ->Graphics.circle(0.0, -125.0, 5.0)
          ->Graphics.fill({"color": indicatorColor})
      })
    | _ => ()
    }

    // Device name label
    let nameText = Text.make({
      "text": info.name,
      "style": {"fontSize": 12, "fill": 0xffffff, "fontWeight": "bold"},
    })
    ObservablePoint.set(Text.anchor(nameText), 0.5, ~y=0.0)
    Text.setX(nameText, 0.0)
    Text.setY(nameText, 10.0)
    let _ = Container.addChildText(container, nameText)

    // Power indicator (small LED at top-left of device)
    // Skip for power station and UPS (they provide power, not consume it visually)
    let powerIndicator = switch info.deviceType {
    | PowerStation | UPS => None
    | _ =>
      // Use a separate container for the indicator to handle events independently
      let indicatorContainer = Container.make()
      Container.setX(indicatorContainer, -40.0)
      Container.setY(indicatorContainer, -60.0)
      Container.setEventMode(indicatorContainer, "static")
      Container.setCursor(indicatorContainer, "pointer")
      // Set hit area as a circle centered at (0,0) with radius 10 (slightly larger than visual)
      Container.setHitAreaCircle(indicatorContainer, Circle.make(~x=0.0, ~y=0.0, ~radius=10.0))

      // Draw indicator at origin since container handles positioning
      let indicator = Graphics.make()
      let hasPower = PowerManager.deviceHasPower(info.ipAddress)
      let _ = indicator
        ->Graphics.circle(0.0, 0.0, 8.0)
        ->Graphics.fill({"color": if hasPower { 0x00ff00 } else { 0xff0000 }})
      let _ = Container.addChildGraphics(indicatorContainer, indicator)

      // Make container clickable to toggle power
      // Use pointertap to match the device container's event type
      let ip = info.ipAddress
      let deviceX = x  // Store device X position for proximity check
      Container.on(indicatorContainer, "pointertap", e => {
        // Stop event from bubbling to device container
        Pixi.stopPropagation(e)

        // Check proximity - player must be close to the device
        let isNearby = switch CameraFeed.getFeedData() {
        | Some(feedData) =>
          let (hackerX, _) = feedData.getHackerPosition()
          let distance = Math.abs(hackerX -. deviceX)
          distance <= interactionDistance
        | None => false
        }

        if !isNearby {
          ()
        } else {
          let isShutdown = PowerManager.isDeviceShutdown(ip)
          if isShutdown {
            // Boot the device if it has power available
            if PowerManager.deviceHasPower(ip) {
              PowerManager.bootDevice(ip)
            } else {
              ()
            }
          } else {
            // Manually shutdown the device (won't auto-boot)
            PowerManager.manualShutdownDevice(ip)
          }
        }
      })

      let _ = Container.addChild(container, indicatorContainer)
      Some(indicator)
    }

    {container, device, x, y: groundY, powerIndicator, ipAddress: info.ipAddress}
  }

  // Update power indicator for a device
  let updatePowerIndicator = (wd: worldDevice): unit => {
    switch wd.powerIndicator {
    | Some(indicator) =>
      let hasPower = PowerManager.deviceHasPower(wd.ipAddress)
      let isShutdown = PowerManager.isDeviceShutdown(wd.ipAddress)
      Graphics.clear(indicator)->ignore
      let color = if isShutdown {
        0x444444  // Dark grey when shutdown
      } else if hasPower {
        0x00ff00  // Green when powered
      } else {
        0xff0000  // Red when no power (shouldn't happen if shutdown is tracked)
      }
      // Draw at origin since indicator is positioned via setX/setY
      let _ = indicator
        ->Graphics.circle(0.0, 0.0, 8.0)
        ->Graphics.fill({"color": color})
    | None => ()
    }
  }
}

// Key state tracking
type keyState = {
  mutable up: bool,
  mutable down: bool,
  mutable left: bool,
  mutable right: bool,
  mutable sprint: bool,
  mutable crouch: bool,
}

let globalKeyState: keyState = {
  up: false,
  down: false,
  left: false,
  right: false,
  sprint: false,
  crouch: false,
}

// Mouse state tracking
type mouseState = {
  mutable x: float,
  mutable y: float,
}

let globalMouseState: mouseState = {
  x: 0.0,
  y: 0.0,
}

// Setup keyboard handlers - tracks key state globally
// Uses e.shiftKey for reliable shift detection since e.key === 'Shift' can be unreliable
let setupKeyboard: (keyState => unit) => unit = %raw(`
  function(updateCallback) {
    // Remove old handlers if they exist (for hot-reload support)
    if (window.__worldKeydownHandler) {
      window.removeEventListener('keydown', window.__worldKeydownHandler);
      window.removeEventListener('keyup', window.__worldKeyupHandler);
      window.removeEventListener('blur', window.__worldBlurHandler);
    }
    console.log('Setting up keyboard handlers (fresh)');

    const keyState = { up: false, down: false, left: false, right: false, sprint: false, crouch: false };

    window.__worldKeydownHandler = (e) => {
      if (e.key === 'w' || e.key === 'W' || e.key === 'ArrowUp' || e.key === ' ') { keyState.up = true; }
      if (e.key === 's' || e.key === 'S' || e.key === 'ArrowDown') { keyState.down = true; }
      if (e.key === 'a' || e.key === 'A' || e.key === 'ArrowLeft') { keyState.left = true; }
      if (e.key === 'd' || e.key === 'D' || e.key === 'ArrowRight') { keyState.right = true; }
      if (e.key === 'Control' || e.key === 'c' || e.key === 'C') { keyState.crouch = true; }
      // Use shiftKey property - always reflects current shift state
      keyState.sprint = e.shiftKey;
      updateCallback(keyState);
    };

    window.__worldKeyupHandler = (e) => {
      if (e.key === 'w' || e.key === 'W' || e.key === 'ArrowUp' || e.key === ' ') { keyState.up = false; }
      if (e.key === 's' || e.key === 'S' || e.key === 'ArrowDown') { keyState.down = false; }
      if (e.key === 'a' || e.key === 'A' || e.key === 'ArrowLeft') { keyState.left = false; }
      if (e.key === 'd' || e.key === 'D' || e.key === 'ArrowRight') { keyState.right = false; }
      if (e.key === 'Control' || e.key === 'c' || e.key === 'C') { keyState.crouch = false; }
      // Use shiftKey property - always reflects current shift state
      keyState.sprint = e.shiftKey;
      updateCallback(keyState);
    };

    // Also handle blur to reset all keys when window loses focus
    window.__worldBlurHandler = () => {
      keyState.up = false;
      keyState.down = false;
      keyState.left = false;
      keyState.right = false;
      keyState.sprint = false;
      keyState.crouch = false;
      updateCallback(keyState);
    };

    window.addEventListener('keydown', window.__worldKeydownHandler);
    window.addEventListener('keyup', window.__worldKeyupHandler);
    window.addEventListener('blur', window.__worldBlurHandler);
  }
`)

// Mouse screen position (raw, not converted to world coords yet)
type mouseScreenPos = {
  mutable screenX: float,
  mutable screenY: float,
}

let globalMouseScreenPos: mouseScreenPos = {
  screenX: 0.0,
  screenY: 0.0,
}

// Setup mouse tracking using PixiJS stage events for proper coordinate conversion
// This handles devicePixelRatio and canvas positioning automatically
let setupMouseTrackingOnStage: (Container.t, mouseScreenPos => unit) => unit = %raw(`
  function(container, updateCallback) {
    console.log('Setting up mouse tracking on PixiJS container');

    // Container should already have eventMode='static' and interactiveChildren=true set
    // We just need to listen for pointer events on the stage/app level
    const mousePos = { screenX: 0, screenY: 0 };

    // Listen on globalThis to capture all pointer moves regardless of hitArea
    container.on('globalpointermove', (e) => {
      // e.global contains properly converted stage coordinates
      mousePos.screenX = e.global.x;
      mousePos.screenY = e.global.y;
      updateCallback(mousePos);
    });
  }
`)

// Create button animations config
let buttonAnimations = {
  "hover": {
    "props": {"scale": {"x": 1.1, "y": 1.1}},
    "duration": 100,
  },
  "pressed": {
    "props": {"scale": {"x": 0.9, "y": 0.9}},
    "duration": 100,
  },
}

type t = {
  container: Container.t,
  worldContainer: Container.t,
  dimOverlay: Graphics.t,
  player: Player.t,
  devices: array<worldDevice>,
  networkManager: NetworkManager.t,
  debugButton: FancyButton.t,
  powerButton: FancyButton.t,
  mutable paused: bool,
  mutable currentDeviceWindow: option<DeviceWindow.t>,
  mutable controlsDisabled: bool,
}

// Create the world screen
let make = (): Navigation.appScreen => {
  let container = Container.make()
  Container.setEventMode(container, "static")
  Container.setInteractiveChildren(container, true)
  let worldContainer = Container.make()
  let _ = Container.addChild(container, worldContainer)

  // Use global network manager (shared with NetworkDesktop)
  let networkManager = GlobalNetworkManager.get()

  // Set up network interface setter for devices
  DesktopDevice.setGlobalNetworkInterfaceSetter((state: LaptopState.laptopState) => {
    let ni = NetworkManager.createNetworkInterfaceFor(networkManager, state.ipAddress)
    LaptopState.setNetworkInterface(state, ni)
  })

  // Set up global state getter so devices use shared state from NetworkManager
  DesktopDevice.setGlobalStateGetter((ipAddress: string) => {
    NetworkManager.getDeviceState(networkManager, ipAddress)
  })

  // Set up router's network manager reference
  RouterDevice.setGlobalNetworkManager({
    getConnectedDevices: () => NetworkManager.getConnectedDevices(networkManager),
    getConfiguredDns: () => NetworkManager.getConfiguredDns(networkManager),
    setConfiguredDns: (dnsIp) => NetworkManager.setConfiguredDns(networkManager, dnsIp),
  })

  // Create player first so we can reference it in camera feed
  let player = Player.make(~startX=150.0, ~startY=groundY, ~groundY)

  // Set up camera feed system so cameras can track the player
  CameraFeed.setFeedData({
    worldContainer,
    getHackerPosition: () => Player.getPosition(player),
  })

  // Sky/background (behind everything)
  let sky = Graphics.make()
  let _ = sky
    ->Graphics.rect(0.0, 0.0, 3000.0, groundY +. 200.0)
    ->Graphics.fill({"color": 0x1a1a2e})
  let _ = Container.addChildGraphics(worldContainer, sky)

  // Background buildings (behind ground)
  let buildings = Graphics.make()
  for i in 0 to 15 {
    let bx = Int.toFloat(i) *. 200.0
    let bh = 100.0 +. Math.random() *. 150.0
    let _ = buildings
      ->Graphics.rect(bx, groundY -. bh, 150.0, bh)
      ->Graphics.fill({"color": 0x252540})
    // Windows
    for wy in 0 to Float.toInt(bh /. 30.0) {
      for wx in 0 to 3 {
        let windowLit = Math.random() > 0.5
        let _ = buildings
          ->Graphics.rect(
            bx +. 15.0 +. Int.toFloat(wx) *. 35.0,
            groundY -. bh +. 15.0 +. Int.toFloat(wy) *. 30.0,
            20.0, 15.0
          )
          ->Graphics.fill({"color": windowLit ? 0xffffaa : 0x1a1a30})
      }
    }
  }
  let _ = Container.addChildGraphics(worldContainer, buildings)

  // Ground (in front of background buildings)
  let ground = Graphics.make()
  let _ = ground
    ->Graphics.rect(0.0, groundY, 3000.0, 200.0)
    ->Graphics.fill({"color": 0x2d4a3e})
  // Ground surface line
  let _ = ground
    ->Graphics.rect(0.0, groundY, 3000.0, 4.0)
    ->Graphics.fill({"color": 0x4a7a5e})
  let _ = Container.addChildGraphics(worldContainer, ground)

  // Place devices in a line on the ground
  // Spread them out horizontally for sidescrolling
  let devicePositions = [
    ("192.168.1.102", 300.0),   // Player's laptop
    ("192.168.1.103", 550.0),   // Another laptop
    ("192.168.1.1", 800.0),     // Router
    ("192.168.1.105", 1050.0),  // Camera
    ("192.168.1.200", 1300.0),  // Admin panel server
    ("10.0.0.25", 1550.0),      // Mail server
    ("10.0.0.50", 1800.0),      // DB server
    ("10.0.0.77", 2050.0),      // Dev terminal
    ("192.168.1.250", 2300.0),  // Power Station
    ("192.168.1.251", 2550.0),  // UPS
  ]

  let devices = Array.filterMap(devicePositions, ((ip, x)) => {
    switch NetworkManager.getDevice(networkManager, ip) {
    | Some(device) => Some(WorldDeviceIcon.make(device, x))
    | None => None
    }
  })

  // Add devices to world
  Array.forEach(devices, wd => {
    let _ = Container.addChild(worldContainer, wd.container)
  })

  // Add trajectory preview (behind player, uses world coordinates)
  let _ = Container.addChild(worldContainer, Player.getTrajectoryContainer(player))

  // Add player on top
  let _ = Container.addChild(worldContainer, Player.getContainer(player))

  // Debug button to open network view
  let debugButton = Button.make(~options={text: "Network View (Debug)", width: 180.0, height: 40.0}, ())
  Signal.connect(FancyButton.onPress(debugButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.presentPopup(engine.navigation, NetworkDesktop.constructor)
    | None => ()
    }
  })
  Signal.connect(FancyButton.onDown(debugButton), () => {
    ()
  })
  let _ = Container.addChild(container, FancyButton.toContainer(debugButton))

  // Power View debug button
  let powerButton = Button.make(~options={text: "Power View (Debug)", width: 180.0, height: 40.0}, ())
  Signal.connect(FancyButton.onPress(powerButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.presentPopup(engine.navigation, PowerView.constructor)
    | None => ()
    }
  })
  let _ = Container.addChild(container, FancyButton.toContainer(powerButton))

  // Dim overlay (covers world when device window is open)
  // IMPORTANT: Set eventMode to "none" so it doesn't block clicks on device windows above it
  let dimOverlay = Graphics.make()
  Graphics.setEventMode(dimOverlay, "none")
  Container.setVisible(Graphics.toContainer(dimOverlay), false)
  let _ = Container.addChildGraphics(container, dimOverlay)

  // Instructions text
  let instructions = Text.make({
    "text": "A/D to move | Shift to sprint | C/Ctrl to crouch | W/Space + Mouse to aim jump | Click nearby device",
    "style": {"fontSize": 14, "fill": 0x888888},
  })
  let _ = Container.addChildText(container, instructions)

  let screenState = {
    container,
    worldContainer,
    dimOverlay,
    player,
    devices,
    networkManager,
    debugButton,
    powerButton,
    paused: false,
    currentDeviceWindow: None,
    controlsDisabled: false,
  }

  // Helper to close device window
  let closeDeviceWindow = () => {
    switch screenState.currentDeviceWindow {
    | Some(win) =>
      let _ = Container.removeChild(container, win.container)
      Container.destroy(win.container)
      screenState.currentDeviceWindow = None
      screenState.controlsDisabled = false
      // Hide dim overlay
      Container.setVisible(Graphics.toContainer(dimOverlay), false)
    | None => ()
    }
  }

  // Setup keyboard
  setupKeyboard(ks => {
    globalKeyState.up = ks.up
    globalKeyState.down = ks.down
    globalKeyState.left = ks.left
    globalKeyState.right = ks.right
    globalKeyState.sprint = ks.sprint
    globalKeyState.crouch = ks.crouch
  })

  // Setup mouse tracking using PixiJS stage events for proper coordinate conversion
  // Use the main container which is added to the stage
  setupMouseTrackingOnStage(container, ms => {
    globalMouseScreenPos.screenX = ms.screenX
    globalMouseScreenPos.screenY = ms.screenY
  })

  // Setup ESC key to close windows (only once)
  let setupEscKey: unit => unit = %raw(`
    function() {
      if (!window.__escKeySetup) {
        window.__escKeySetup = true;
        window.addEventListener('keydown', (e) => {
          if (e.key === 'Escape') {
            if (window.__closeDeviceWindow) window.__closeDeviceWindow();
          }
        });
      }
      window.__closeDeviceWindow = function() {};
    }
  `)
  setupEscKey()

  // Set up the close callback
  let setCloseCallback: (unit => unit) => unit = %raw(`
    function(callback) {
      window.__closeDeviceWindow = callback;
    }
  `)
  setCloseCallback(closeDeviceWindow)

  // Setup device click handlers with proximity check
  Array.forEach(devices, wd => {
    Container.on(wd.container, "pointertap", _ => {
      // Check if player is close enough to interact
      let distance = Math.abs(Player.getX(player) -. wd.x)
      if distance <= interactionDistance {
        // Check if device is operational (has power and not shutdown)
        let info = wd.device.getInfo()
        // Power devices always work, other devices need power
        let canOpen = switch info.deviceType {
        | DeviceTypes.PowerStation | DeviceTypes.UPS => true
        | _ => PowerManager.isDeviceOperational(wd.ipAddress)
        }

        if !canOpen {
          // Device is shutdown - don't open, just log
          ()
        } else {
          // Close existing window if any
          closeDeviceWindow()

          // Open device GUI
          let window = wd.device.openGUI()

          // Set close callback so X button re-enables movement
          DeviceWindow.setOnClose(window, () => {
            screenState.currentDeviceWindow = None
            screenState.controlsDisabled = false
            // Hide dim overlay
            Container.setVisible(Graphics.toContainer(dimOverlay), false)
          })

          let _ = Container.addChild(container, window.container)
          Container.setX(window.container, 100.0)
          Container.setY(window.container, 50.0)
          screenState.currentDeviceWindow = Some(window)
          screenState.controlsDisabled = true

          // Show dim overlay
          Container.setVisible(Graphics.toContainer(dimOverlay), true)
        }
      }
      // Note: if not close enough, do nothing (don't disable controls)
    })
  })

  // Store screen dimensions for camera
  let screenWidth = ref(800.0)
  let screenHeight = ref(600.0)

  {
    container,
    prepare: Some(() => ()),
    show: Some(async () => {
      Container.setAlpha(container, 0.0)
      await Motion.animateAsync(container, {"alpha": 1.0}, {duration: 0.5, ease: "easeOut"})
    }),
    hide: Some(async () => {
      await Motion.animateAsync(container, {"alpha": 0.0}, {duration: 0.3})
    }),
    pause: Some(async () => {
      screenState.paused = true
    }),
    resume: Some(async () => {
      screenState.paused = false
    }),
    reset: Some(() => ()),
    update: Some(ticker => {
      // deltaTime is in frames at 60fps, convert to seconds
      let dt = Ticker.deltaTime(ticker) /. 60.0

      // Update network transfers (bandwidth simulation)
      NetworkTransfer.updateTransfers(dt)

      // Convert mouse viewport coordinates to world coordinates
      // The player appears on screen at: (playerWorldX + worldContainer.x, playerWorldY)
      // So to convert screen to world: worldX = screenX - worldContainer.x
      let worldContainerX = Container.x(worldContainer)
      let mouseWorldX = globalMouseScreenPos.screenX -. worldContainerX
      let mouseWorldY = globalMouseScreenPos.screenY



      // Build input state for player
      let input: Player.inputState = if !screenState.paused && !screenState.controlsDisabled {
        {
          left: globalKeyState.left,
          right: globalKeyState.right,
          up: globalKeyState.up,
          crouch: globalKeyState.crouch || globalKeyState.down,  // S/Down also crouches
          sprint: globalKeyState.sprint,
          mouseX: mouseWorldX,
          mouseY: mouseWorldY,
        }
      } else {
        // No input when controls disabled
        {
          left: false,
          right: false,
          up: false,
          crouch: false,
          sprint: false,
          mouseX: mouseWorldX,
          mouseY: mouseWorldY,
        }
      }

      // Update player if not paused
      if !screenState.paused {
        Player.update(player, ~input, ~deltaTime=dt)

        // Keep player in world bounds
        let playerX = Player.getX(player)
        if playerX < 50.0 { Player.setX(player, 50.0) }
        if playerX > 2950.0 { Player.setX(player, 2950.0) }

        // Camera follow - keep player roughly centered horizontally
        let targetCameraX = -. Player.getX(player) +. screenWidth.contents /. 2.0
        // Clamp camera to world bounds
        let maxCameraX = 0.0
        let minCameraX = -. 3000.0 +. screenWidth.contents
        let clampedCameraX = Math.max(minCameraX, Math.min(maxCameraX, targetCameraX))
        Container.setX(worldContainer, clampedCameraX)

        // Update camera motion detection in background
        CameraFeed.updateAllCameraMotion()

        // Update UPS batteries
        PowerManager.updateUPSBatteries(dt)

        // Update device power states and indicators
        let deviceIps = Array.map(devices, wd => wd.ipAddress)
        let _ = PowerManager.updateAllDevicePowerStates(deviceIps)
        Array.forEach(devices, WorldDeviceIcon.updatePowerIndicator)
      }
    }),
    resize: Some((width, height) => {
      screenWidth := width
      screenHeight := height

      // Position debug buttons
      FancyButton.setX(debugButton, width -. 100.0)
      FancyButton.setY(debugButton, 30.0)
      FancyButton.setX(powerButton, width -. 100.0)
      FancyButton.setY(powerButton, 80.0)

      // Update dim overlay size
      let _ = Graphics.clear(dimOverlay)
      let _ = dimOverlay
        ->Graphics.rect(0.0, 0.0, width, height)
        ->Graphics.fill({"color": 0x000000, "alpha": 0.6})

      // Position instructions
      Text.setX(instructions, 20.0)
      Text.setY(instructions, height -. 30.0)
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
