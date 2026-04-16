// SPDX-License-Identifier: PMPL-1.0-or-later
// World Screen - Physical world view with hacker character
// Sidescrolling platformer with mouse-aimed jumping

open Pixi
open PixiUI

// World Builder - Reusable location screen builder
// This module provides buildLocationScreen() to create platformer scenes from location data

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
let groundY = 500.0 // Y position of the ground
let interactionDistance = 120.0 // Max distance to interact with a device (slightly increased)

// World device icon - devices sit on the ground
module WorldDeviceIcon = {
  let make = (device: DeviceTypes.device, x: float): worldDevice => {
    let info = device.getInfo()
    let container = Container.make()
    Container.setEventMode(container, "static")
    Container.setCursor(container, "pointer")
    Container.setX(container, x)
    Container.setY(container, groundY) // All devices on ground level

    // Device graphic based on type
    let deviceGraphic = Graphics.make()
    let deviceColor = DeviceTypes.getDeviceColor(info.deviceType)

    switch info.deviceType {
    | Laptop =>
      // Laptop on a small desk
      // Desk
      let _ =
        deviceGraphic
        ->Graphics.rect(-35.0, -20.0, 70.0, 20.0)
        ->Graphics.fill({"color": 0x4a3728})
      // Desk legs
      let _ =
        deviceGraphic
        ->Graphics.rect(-30.0, 0.0, 8.0, 20.0)
        ->Graphics.fill({"color": 0x4a3728})
      let _ =
        deviceGraphic
        ->Graphics.rect(22.0, 0.0, 8.0, 20.0)
        ->Graphics.fill({"color": 0x4a3728})
      // Laptop screen
      let _ =
        deviceGraphic
        ->Graphics.rect(-25.0, -55.0, 50.0, 35.0)
        ->Graphics.fill({"color": 0x333333})
      let _ =
        deviceGraphic
        ->Graphics.rect(-22.0, -52.0, 44.0, 29.0)
        ->Graphics.fill({"color": deviceColor})
      // Laptop base
      let _ =
        deviceGraphic
        ->Graphics.rect(-28.0, -20.0, 56.0, 8.0)
        ->Graphics.fill({"color": 0x444444})
    | Server =>
      // Tall server rack
      let _ =
        deviceGraphic
        ->Graphics.rect(-25.0, -120.0, 50.0, 120.0)
        ->Graphics.fill({"color": 0x333333})
      // Server units
      for i in 0 to 5 {
        let yPos = -115.0 +. Int.toFloat(i) *. 18.0
        let _ =
          deviceGraphic
          ->Graphics.rect(-22.0, yPos, 44.0, 16.0)
          ->Graphics.fill({"color": deviceColor})
        // LED
        let _ =
          deviceGraphic
          ->Graphics.circle(17.0, yPos +. 8.0, 3.0)
          ->Graphics.fill({"color": 0x00ff00})
      }
    | Router =>
      // Router on a small shelf
      // Shelf
      let _ =
        deviceGraphic
        ->Graphics.rect(-30.0, -40.0, 60.0, 8.0)
        ->Graphics.fill({"color": 0x4a3728})
      // Shelf support
      let _ =
        deviceGraphic
        ->Graphics.rect(-5.0, -40.0, 10.0, 40.0)
        ->Graphics.fill({"color": 0x4a3728})
      // Router box
      let _ =
        deviceGraphic
        ->Graphics.rect(-25.0, -60.0, 50.0, 20.0)
        ->Graphics.fill({"color": deviceColor})
      // Antennas
      let _ =
        deviceGraphic
        ->Graphics.rect(-18.0, -85.0, 4.0, 25.0)
        ->Graphics.fill({"color": 0x333333})
      let _ =
        deviceGraphic
        ->Graphics.rect(14.0, -85.0, 4.0, 25.0)
        ->Graphics.fill({"color": 0x333333})
      // LEDs
      for i in 0 to 3 {
        let _ =
          deviceGraphic
          ->Graphics.circle(-15.0 +. Int.toFloat(i) *. 10.0, -50.0, 3.0)
          ->Graphics.fill({"color": 0x00ff00})
      }
    | Firewall =>
      // Hardened rack-mount appliance with brick-wall motif
      // Main chassis
      let _ =
        deviceGraphic
        ->Graphics.rect(-30.0, -80.0, 60.0, 40.0)
        ->Graphics.fill({"color": 0x2a1a1a})
        ->Graphics.stroke({"width": 2, "color": deviceColor})
      // Brick pattern (3 rows of offset bricks)
      for row in 0 to 2 {
        let yPos = -75.0 +. Int.toFloat(row) *. 12.0
        let offset = if mod(row, 2) == 0 { 0.0 } else { 10.0 }
        for col in 0 to 2 {
          let xPos = -25.0 +. offset +. Int.toFloat(col) *. 18.0
          let _ =
            deviceGraphic
            ->Graphics.rect(xPos, yPos, 16.0, 10.0)
            ->Graphics.fill({"color": deviceColor})
        }
      }
      // Status LED row
      for i in 0 to 3 {
        let _ =
          deviceGraphic
          ->Graphics.circle(-18.0 +. Int.toFloat(i) *. 12.0, -45.0, 3.0)
          ->Graphics.fill({"color": 0x00ff00})
      }
      // Wall-mount bracket
      let _ =
        deviceGraphic
        ->Graphics.rect(-5.0, -40.0, 10.0, 40.0)
        ->Graphics.fill({"color": 0x444444})

    | IotCamera =>
      // Camera on a tall pole
      // Pole
      let _ =
        deviceGraphic
        ->Graphics.rect(-4.0, -100.0, 8.0, 100.0)
        ->Graphics.fill({"color": 0x666666})
      // Camera mount
      let _ =
        deviceGraphic
        ->Graphics.rect(-15.0, -110.0, 30.0, 10.0)
        ->Graphics.fill({"color": 0x444444})
      // Camera body
      let _ =
        deviceGraphic
        ->Graphics.circle(0.0, -125.0, 18.0)
        ->Graphics.fill({"color": deviceColor})
      // Lens
      let _ =
        deviceGraphic
        ->Graphics.circle(0.0, -125.0, 10.0)
        ->Graphics.fill({"color": 0x222222})

    | Terminal =>
      // Computer terminal on desk
      // Desk
      let _ =
        deviceGraphic
        ->Graphics.rect(-40.0, -30.0, 80.0, 30.0)
        ->Graphics.fill({"color": 0x4a3728})
      // Desk legs
      let _ =
        deviceGraphic
        ->Graphics.rect(-35.0, 0.0, 8.0, 25.0)
        ->Graphics.fill({"color": 0x4a3728})
      let _ =
        deviceGraphic
        ->Graphics.rect(27.0, 0.0, 8.0, 25.0)
        ->Graphics.fill({"color": 0x4a3728})
      // Monitor
      let _ =
        deviceGraphic
        ->Graphics.rect(-30.0, -80.0, 60.0, 50.0)
        ->Graphics.fill({"color": 0x333333})
      let _ =
        deviceGraphic
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
      let _ =
        deviceGraphic
        ->Graphics.rect(-8.0, -30.0, 16.0, 10.0)
        ->Graphics.fill({"color": 0x333333})
      // Keyboard
      let _ =
        deviceGraphic
        ->Graphics.rect(-25.0, -28.0, 50.0, 8.0)
        ->Graphics.fill({"color": 0x222222})

    | PowerStation =>
      // Large industrial power station unit
      // Main cabinet
      let _ =
        deviceGraphic
        ->Graphics.rect(-40.0, -150.0, 80.0, 150.0)
        ->Graphics.fill({"color": 0x2a2a2a})
      // Cabinet door
      let _ =
        deviceGraphic
        ->Graphics.rect(-35.0, -145.0, 70.0, 140.0)
        ->Graphics.fill({"color": 0x333333})
        ->Graphics.stroke({"width": 2, "color": 0x444444})
      // Ventilation grille
      for i in 0 to 5 {
        let yPos = -140.0 +. Int.toFloat(i) *. 12.0
        let _ =
          deviceGraphic
          ->Graphics.rect(-30.0, yPos, 60.0, 8.0)
          ->Graphics.fill({"color": 0x1a1a1a})
      }
      // Power meter display
      let _ =
        deviceGraphic
        ->Graphics.rect(-25.0, -60.0, 50.0, 30.0)
        ->Graphics.fill({"color": 0x000000})
        ->Graphics.stroke({"width": 1, "color": deviceColor})
      // Power bars
      for i in 0 to 4 {
        let _ =
          deviceGraphic
          ->Graphics.rect(-20.0 +. Int.toFloat(i) *. 10.0, -55.0, 6.0, 20.0)
          ->Graphics.fill({"color": deviceColor})
      }
      // Warning stripe at bottom
      let _ =
        deviceGraphic
        ->Graphics.rect(-40.0, -20.0, 80.0, 20.0)
        ->Graphics.fill({"color": 0xffcc00})
      for i in 0 to 7 {
        let _ =
          deviceGraphic
          ->Graphics.rect(-40.0 +. Int.toFloat(i) *. 20.0, -20.0, 10.0, 20.0)
          ->Graphics.fill({"color": 0x222222})
      }
      // Status light
      let _ =
        deviceGraphic
        ->Graphics.circle(0.0, -130.0, 8.0)
        ->Graphics.fill({"color": 0x00ff00})

    | UPS =>
      // UPS unit (smaller than power station)
      // Main box
      let _ =
        deviceGraphic
        ->Graphics.rect(-30.0, -80.0, 60.0, 80.0)
        ->Graphics.fill({"color": 0x3d3d3d})
        ->Graphics.stroke({"width": 2, "color": 0x505050})
      // Front panel
      let _ =
        deviceGraphic
        ->Graphics.rect(-25.0, -75.0, 50.0, 70.0)
        ->Graphics.fill({"color": deviceColor})
      // LCD display
      let _ =
        deviceGraphic
        ->Graphics.rect(-20.0, -70.0, 40.0, 20.0)
        ->Graphics.fill({"color": 0x1a3a1a})
        ->Graphics.stroke({"width": 1, "color": 0x00ff00})
      // Battery icon on display
      let _ =
        deviceGraphic
        ->Graphics.rect(-15.0, -65.0, 20.0, 10.0)
        ->Graphics.fill({"color": 0x00ff00})
      let _ =
        deviceGraphic
        ->Graphics.rect(5.0, -63.0, 3.0, 6.0)
        ->Graphics.fill({"color": 0x00ff00})
      // Status LEDs
      let _ =
        deviceGraphic
        ->Graphics.circle(-10.0, -40.0, 4.0)
        ->Graphics.fill({"color": 0x00ff00}) // Power
      let _ =
        deviceGraphic
        ->Graphics.circle(0.0, -40.0, 4.0)
        ->Graphics.fill({"color": 0x00ff00}) // Battery
      let _ =
        deviceGraphic
        ->Graphics.circle(10.0, -40.0, 4.0)
        ->Graphics.fill({"color": 0x00ff00}) // Line
      // Outlets at bottom
      for i in 0 to 2 {
        let _ =
          deviceGraphic
          ->Graphics.rect(-18.0 +. Int.toFloat(i) *. 14.0, -25.0, 10.0, 12.0)
          ->Graphics.fill({"color": 0x222222})
      }
    }

    let _ = Container.addChildGraphics(container, deviceGraphic)

    // Add camera indicator light on top of device graphic (for cameras only)
    switch info.deviceType {
    | IotCamera =>
      let cameraIndicator = Graphics.make()
      let _ =
        cameraIndicator
        ->Graphics.circle(0.0, -125.0, 5.0)
        ->Graphics.fill({"color": 0x0066cc}) // Blue when idle
      let _ = Container.addChildGraphics(container, cameraIndicator)

      // Register camera position for background motion checking
      // Use same view width as CameraDevice (300.0)
      CameraFeed.registerCameraPosition(info.ipAddress, x, 300.0)

      // Register callback to change indicator color on motion detection
      // None = disabled/grey, Some(false) = no motion/blue, Some(true) = motion/orange
      CameraFeed.registerMotionCallback(info.ipAddress, status => {
        let _ = Graphics.clear(cameraIndicator)
        let indicatorColor = switch status {
        | None => 0x666666 // Grey when disabled
        | Some(false) => 0x0066cc // Blue when idle
        | Some(true) => 0xff6600 // Orange when motion detected
        }
        let _ =
          cameraIndicator
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
      let _ =
        indicator
        ->Graphics.circle(0.0, 0.0, 8.0)
        ->Graphics.fill({
          "color": if hasPower {
            0x00ff00
          } else {
            0xff0000
          },
        })
      let _ = Container.addChildGraphics(indicatorContainer, indicator)

      // Make container clickable to toggle power
      // Use pointertap to match the device container's event type
      let ip = info.ipAddress
      let deviceX = x // Store device X position for proximity check
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
        0x444444 // Dark grey when shutdown
      } else if hasPower {
        0x00ff00 // Green when powered
      } else {
        0xff0000 // Red when no power (shouldn't happen if shutdown is tracked)
      }
      // Draw at origin since indicator is positioned via setX/setY
      let _ =
        indicator
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
  mutable interact: bool,
  mutable aimLeft: bool, // Q key  keyboard aiming: rotate counter-clockwise
  mutable aimRight: bool, // E key (when keyboard-only)  rotate clockwise
  // Moletaire keys
  mutable moleLeft: bool,   // J
  mutable moleRight: bool,  // K
  mutable moleToggle: bool, // M
  mutable moleTrap: bool,   // N
  mutable moleItem: bool,   // B
  // Highway Crossing Mole keys (vertical movement)
  mutable moleForward: bool,  // Y — hop toward finish (up on screen)
  mutable moleBackward: bool, // H — hop toward start (down on screen)
  mutable hardware: bool, // H key — open hardware wiring patch panel (also moleBackward)
}

let globalKeyState: keyState = {
  up: false,
  down: false,
  left: false,
  right: false,
  sprint: false,
  crouch: false,
  interact: false,
  aimLeft: false,
  aimRight: false,
  moleLeft: false,
  moleRight: false,
  moleToggle: false,
  moleTrap: false,
  moleItem: false,
  moleForward: false,
  moleBackward: false,
  hardware: false,
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
    const keyState = { up: false, down: false, left: false, right: false, sprint: false, crouch: false, interact: false, aimLeft: false, aimRight: false, moleLeft: false, moleRight: false, moleToggle: false, moleTrap: false, moleItem: false, moleForward: false, moleBackward: false, hardware: false };

    window.__worldKeydownHandler = (e) => {
      if (e.key === 'w' || e.key === 'W' || e.key === 'ArrowUp' || e.key === ' ') { keyState.up = true; }
      if (e.key === 's' || e.key === 'S' || e.key === 'ArrowDown') { keyState.down = true; }
      if (e.key === 'a' || e.key === 'A' || e.key === 'ArrowLeft') { keyState.left = true; }
      if (e.key === 'd' || e.key === 'D' || e.key === 'ArrowRight') { keyState.right = true; }
      if (e.key === 'Control' || e.key === 'c' || e.key === 'C') { keyState.crouch = true; }
      if (e.key === 'e' || e.key === 'E') { keyState.interact = true; }
      if (e.key === 'q' || e.key === 'Q') { keyState.aimLeft = true; }
      if (e.key === 'j' || e.key === 'J') { keyState.moleLeft = true; }
      if (e.key === 'k' || e.key === 'K') { keyState.moleRight = true; }
      if (e.key === 'm' || e.key === 'M') { keyState.moleToggle = true; }
      if (e.key === 'n' || e.key === 'N') { keyState.moleTrap = true; }
      if (e.key === 'b' || e.key === 'B') { keyState.moleItem = true; }
      if (e.key === 'y' || e.key === 'Y') { keyState.moleForward = true; }
      if (e.key === 'h' || e.key === 'H') { keyState.moleBackward = true; keyState.hardware = true; }
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
      if (e.key === 'e' || e.key === 'E') { keyState.interact = false; }
      if (e.key === 'q' || e.key === 'Q') { keyState.aimLeft = false; }
      if (e.key === 'j' || e.key === 'J') { keyState.moleLeft = false; }
      if (e.key === 'k' || e.key === 'K') { keyState.moleRight = false; }
      if (e.key === 'm' || e.key === 'M') { keyState.moleToggle = false; }
      if (e.key === 'n' || e.key === 'N') { keyState.moleTrap = false; }
      if (e.key === 'b' || e.key === 'B') { keyState.moleItem = false; }
      if (e.key === 'y' || e.key === 'Y') { keyState.moleForward = false; }
      if (e.key === 'h' || e.key === 'H') { keyState.moleBackward = false; keyState.hardware = false; }
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
      keyState.interact = false;
      keyState.aimLeft = false;
      keyState.aimRight = false;
      keyState.moleLeft = false;
      keyState.moleRight = false;
      keyState.moleToggle = false;
      keyState.moleTrap = false;
      keyState.moleItem = false;
      keyState.moleForward = false;
      keyState.moleBackward = false;
      keyState.hardware = false;
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
  pickups: array<WorldPickup.t>,
  networkManager: NetworkManager.t,
  debugButton: FancyButton.t,
  powerButton: FancyButton.t,
  mutable paused: bool,
  mutable currentDeviceWindow: option<DeviceWindow.t>,
  mutable controlsDisabled: bool,
}

// Create a world/location screen from location data
let buildLocationScreen = (location: LocationData.location): Navigation.appScreen => {
  let container = Container.make()
  Container.setEventMode(container, "static")
  Container.setInteractiveChildren(container, true)
  let worldContainer = Container.make()
  let _ = Container.addChild(container, worldContainer)

  // Exit button overlay (UI layer, not in worldContainer)
  let exitBtn = Graphics.make()
  let _ =
    exitBtn
    ->Graphics.rect(0.0, 0.0, 120.0, 40.0)
    ->Graphics.fill({"color": 0xaa0000})
    ->Graphics.stroke({"width": 2, "color": 0x000000})
  Graphics.setEventMode(exitBtn, "static")
  Graphics.setCursor(exitBtn, "pointer")
  Graphics.setX(exitBtn, 20.0)
  Graphics.setY(exitBtn, 20.0)
  let _ = Container.addChildGraphics(container, exitBtn)

  let exitText = Text.make({
    "text": "Exit to Map",
    "style": {
      "fontFamily": "Arial",
      "fontSize": 14,
      "fill": 0xffffff,
      "fontWeight": "bold",
    },
  })
  ObservablePoint.set(Text.anchor(exitText), 0.5, ~y=0.5)
  Text.setX(exitText, 60.0)
  Text.setY(exitText, 20.0)
  let _ = Container.addChildText(container, exitText)

  Graphics.on(exitBtn, "pointertap", _ => {
    switch GetEngine.get() {
    | Some(engine) => Navigation.showScreen(engine.navigation, WorldMapScreen.constructor)->ignore
    | None => ()
    }
  })

  // ESC key handler
  let escKeyHandler = ref(None)

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
    setConfiguredDns: dnsIp => NetworkManager.setConfiguredDns(networkManager, dnsIp),
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
  let _ =
    sky
    ->Graphics.rect(0.0, 0.0, location.worldWidth, groundY +. 200.0)
    ->Graphics.fill({"color": location.backgroundColor})
  let _ = Container.addChildGraphics(worldContainer, sky)

  // Background buildings (behind ground)
  let buildings = Graphics.make()
  let buildingCount = Float.toInt(location.worldWidth /. 200.0)
  for i in 0 to buildingCount {
    let bx = Int.toFloat(i) *. 200.0
    let bh = 100.0 +. Math.random() *. 150.0
    let _ =
      buildings
      ->Graphics.rect(bx, groundY -. bh, 150.0, bh)
      ->Graphics.fill({"color": 0x252540})
    // Windows
    for wy in 0 to Float.toInt(bh /. 30.0) {
      for wx in 0 to 3 {
        let windowLit = Math.random() > 0.5
        let _ =
          buildings
          ->Graphics.rect(
            bx +. 15.0 +. Int.toFloat(wx) *. 35.0,
            groundY -. bh +. 15.0 +. Int.toFloat(wy) *. 30.0,
            20.0,
            15.0,
          )
          ->Graphics.fill({"color": windowLit ? 0xffffaa : 0x1a1a30})
      }
    }
  }
  let _ = Container.addChildGraphics(worldContainer, buildings)

  // Ground (in front of background buildings)
  let ground = Graphics.make()
  let _ =
    ground
    ->Graphics.rect(0.0, groundY, location.worldWidth, 200.0)
    ->Graphics.fill({"color": 0x2d4a3e})
  // Ground surface line
  let _ =
    ground
    ->Graphics.rect(0.0, groundY, location.worldWidth, 4.0)
    ->Graphics.fill({"color": 0x4a7a5e})
  let _ = Container.addChildGraphics(worldContainer, ground)

  // Use device positions from location data
  let devicePositions = location.devicePositions

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
  let debugButton = Button.make(
    ~options={text: "Network View (Debug)", width: 180.0, height: 40.0},
    (),
  )
  Signal.connect(FancyButton.onPress(debugButton), () => {
    switch GetEngine.get() {
    | Some(engine) =>
      let _ = Navigation.presentPopup(engine.navigation, NetworkDesktop.constructor)
    | None => ()
    }
  })
  let _ = Container.addChild(container, FancyButton.toContainer(debugButton))

  // Power View debug button
  let powerButton = Button.make(
    ~options={text: "Power View (Debug)", width: 180.0, height: 40.0},
    (),
  )
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

  //  Game Systems 
  // GameLoop manages guards, detection, AI, missions, inventory, and game over/victory
  let gameState = GameLoop.make(~tier=Inventory.Accessible)
  GameLoop.startMission(gameState, ~locationId=location.id)

  // HUD overlay (UI layer on top of world)
  let hud = HUD.make()
  let _ = Container.addChild(container, hud.container)

  // KernelMonitor HUD — resource-usage bars for the active coprocessor device.
  // Sits above the HUD layer, hidden until a device with coprocessor activity is
  // opened.  Only meaningful when the Invertible Programming feature pack is on.
  let kernelMonitor = KernelMonitor.make()
  let _ = Container.addChild(container, kernelMonitor.container)

  // Guard containers  add to worldContainer so they scroll with camera
  let guardContainer = Container.make()
  let _ = Container.addChild(worldContainer, guardContainer)
  Array.forEach(gameState.guards, guard => {
    let _ = Container.addChild(guardContainer, guard.container)
  })

  // Dog containers  also in worldContainer
  let dogContainer = Container.make()
  let _ = Container.addChild(worldContainer, dogContainer)
  Array.forEach(gameState.dogs, dog => {
    let _ = Container.addChild(dogContainer, dog.container)
  })

  // Instructions text
  let instructions = Text.make({
    "text": "A/D to move | Shift to sprint | C/Ctrl to crouch | E to interact | H for wiring panel | F1 to pause",
    "style": {"fontSize": 14, "fill": 0x888888},
  })
  let _ = Container.addChildText(container, instructions)

  // Create visual pickups for items in the level
  let pickups = Array.map(gameState.worldItems, (wi: LevelConfig.worldItem) => {
    WorldPickup.makeCollectible(~item=wi.item, ~x=wi.x, ~groundY)
  })

  // Add pickups to world
  Array.forEach(pickups, p => {
    let _ = Container.addChild(worldContainer, p.container)
  })

  let screenState = {
    container,
    worldContainer,
    dimOverlay,
    player,
    devices,
    pickups,
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
    globalKeyState.aimLeft = ks.aimLeft
    globalKeyState.aimRight = ks.aimRight
    globalKeyState.hardware = ks.hardware
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
          // Device is shutdown - can't open
          ()
        } else {
          // Close existing window if any
          closeDeviceWindow()

          // Open device GUI
          let window = wd.device.openGUI()

          // Set close callback so X button re-enables movement
          DeviceWindow.setOnClose(
            window,
            () => {
              screenState.currentDeviceWindow = None
              screenState.controlsDisabled = false
              // Hide dim overlay
              Container.setVisible(Graphics.toContainer(dimOverlay), false)
              // Detach KernelMonitor from device — hides the overlay
              if FeaturePacks.isInvertibleProgrammingEnabled() {
                KernelMonitor.setDevice(kernelMonitor, "")
              }
            },
          )

          let _ = Container.addChild(container, window.container)
          Container.setX(window.container, 100.0)
          Container.setY(window.container, 50.0)
          screenState.currentDeviceWindow = Some(window)
          screenState.controlsDisabled = true

          // Show dim overlay
          Container.setVisible(Graphics.toContainer(dimOverlay), true)

          // Enrol device with the coprocessor framework and attach KernelMonitor.
          // CoprocessorManager.setup is idempotent — safe to call on every open.
          if FeaturePacks.isInvertibleProgrammingEnabled() {
            CoprocessorManager.setup(wd.ipAddress)
            KernelMonitor.setDevice(kernelMonitor, wd.ipAddress)
          }
        }
      }
      // Note: if not close enough, do nothing (don't disable controls)
    })
  })

  // Guard against per-frame navigation (game-over/victory fire every frame while true)
  let navigated = ref(false)

  // Position sync timer for multiplayer
  let positionTimer = ref(0.0)

  // Store screen dimensions for camera
  let screenWidth = ref(800.0)
  let screenHeight = ref(600.0)

  {
    container,
    prepare: Some(() => ()),
    show: Some(
      async () => {
        Container.setAlpha(container, 0.0)

        // Add key listener  navigate to pause menu
        let escNavigating = ref(false)
        let rec escHandler = (_e: {..}) => {
          let key: string = %raw(`_e.key`)
          if (key == "Escape" || key == "F1" || key == "Tab" || key == "p" || key == "P") && !escNavigating.contents {
            escNavigating := true
            let _: unit = %raw(`_e.preventDefault()`)
            // Remove listener immediately to prevent stacking
            switch escKeyHandler.contents {
            | Some(_handler) => %raw(`window.removeEventListener("keydown", _handler)`)
            | None => ()
            }
            switch GetEngine.get() {
            | Some(engine) =>
              let _ = Navigation.presentPopup(
                engine.navigation,
                PausePopup.constructor,
              )->Promise.thenResolve(_ => {
                escNavigating := false
                // Re-add listener for next time if we resume
                escKeyHandler := Some(
                  %raw(`function(fn) { var h = function(e) { fn(e); }; window.addEventListener("keydown", h); return h; }`)(
                    escHandler,
                  ),
                )
              })->Promise.catch(e => {
                escNavigating := false
                PanicHandler.handleException(e)
              })
            | None => ()
            }
          }
        }
        let handler = %raw(`function(fn) { var h = function(e) { fn(e); }; window.addEventListener('keydown', h); return h; }`)(
          escHandler,
        )
        escKeyHandler := Some(handler)

        await Motion.animateAsync(container, {"alpha": 1.0}, {duration: 0.5, ease: "easeOut"})
      },
    ),
    hide: Some(
      async () => {
        // Remove ESC key listener
        switch escKeyHandler.contents {
        | Some(_handler) => %raw(`window.removeEventListener('keydown', _handler)`)
        | None => ()
        }

        await Motion.animateAsync(container, {"alpha": 0.0}, {duration: 0.3})
      },
    ),
    pause: Some(
      async () => {
        screenState.paused = true
      },
    ),
    resume: Some(
      async () => {
        screenState.paused = false
      },
    ),
    reset: Some(
      () => {
        // Cleanup ESC key listener
        switch escKeyHandler.contents {
        | Some(_handler) => %raw(`window.removeEventListener('keydown', _handler)`)
        | None => ()
        }
      },
    ),
    update: Some(
      ticker => {
        try {
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

          // Keyboard-only aiming: when enabled and charging jump, Q/E adjust angle, W/S adjust power
          // E key serves double duty: interact when not charging, aim-right when charging in keyboard-only mode
          let aimRightKey = if globalKeyState.up {
            // During jump charge, E becomes aim-right instead of interact
            globalKeyState.interact
          } else {
            globalKeyState.aimRight
          }
          let _keyboardAimActive = KeyboardAiming.update(
            ~qKey=globalKeyState.aimLeft,
            ~eKey=aimRightKey,
            ~wKey=globalKeyState.up,
            ~sKey=globalKeyState.down,
          )

          // Use keyboard aim coords when keyboard-only mode is active
          let (finalMouseX, finalMouseY) = if AccessibilitySettings.isKeyboardOnlyEnabled() {
            let playerScreenX = Player.getX(player) +. worldContainerX
            let playerScreenY = Player.getY(player)
            let (kbX, kbY) = KeyboardAiming.getMouseEquivalent(~playerScreenX, ~playerScreenY)
            // Convert back to world coords
            (kbX -. worldContainerX, kbY)
          } else {
            (mouseWorldX, mouseWorldY)
          }

          // Build input state for player
          let input: Player.inputState = if !screenState.paused && !screenState.controlsDisabled {
            {
              left: globalKeyState.left,
              right: globalKeyState.right,
              up: globalKeyState.up,
              crouch: globalKeyState.crouch || globalKeyState.down, // S/Down also crouches
              sprint: globalKeyState.sprint,
              mouseX: finalMouseX,
              mouseY: finalMouseY,
            }
          } else {
            // No input when controls disabled
            {
              left: false,
              right: false,
              up: false,
              crouch: false,
              sprint: false,
              mouseX: finalMouseX,
              mouseY: finalMouseY,
            }
          }

          // Update player if not paused
          if !screenState.paused {
            Player.update(player, ~input, ~deltaTime=dt)

            // Keep player in world bounds
            let playerX = Player.getX(player)
            if playerX < 50.0 {
              Player.setX(player, 50.0)
            }
            if playerX > location.worldWidth -. 50.0 {
              Player.setX(player, location.worldWidth -. 50.0)
            }

            // Camera follow - keep player roughly centered horizontally
            let targetCameraX = -.Player.getX(player) +. screenWidth.contents /. 2.0
            // Clamp camera to world bounds
            let maxCameraX = 0.0
            let minCameraX = -.location.worldWidth +. screenWidth.contents
            let clampedCameraX = Math.max(minCameraX, Math.min(maxCameraX, targetCameraX))
            Container.setX(worldContainer, clampedCameraX)

            // Update camera motion detection in background
            CameraFeed.updateAllCameraMotion()

            // Update UPS batteries
            PowerManager.updateUPSBatteries(dt)

            // E-key device/item interaction
            if globalKeyState.interact && !screenState.controlsDisabled {
              globalKeyState.interact = false // Consume the keypress
              let playerX = Player.getX(player)

              // 1. Try item pickup first
              let pickedUp = GameLoop.attemptItemPickup(
                gameState,
                ~playerX,
                ~interactionDistance,
              )

              if pickedUp {
                // Find which visual pickup was just collected and animate it
                Array.forEach(screenState.pickups, p => {
                  if !p.collected {
                    // Match visual pickup to game state item
                    let itemId = switch p.kind {
                    | Collectible(i) => i.id
                    | Trap(id) => id
                    }
                    let isCollected = Array.some(gameState.worldItems, wi => 
                      wi.item.id == itemId && wi.collected
                    )
                    if isCollected {
                      WorldPickup.animateCollect(p)
                    }
                  }
                })
              }

              if !pickedUp {
                // 2. Try device interaction if no item was picked up
                let nearestDevice = ref(None)
                let nearestDist = ref(interactionDistance +. 1.0)
                Array.forEach(devices, wd => {
                  let dist = Math.abs(playerX -. wd.x)
                  if dist <= interactionDistance && dist < nearestDist.contents {
                    nearestDevice := Some(wd)
                    nearestDist := dist
                  }
                })
                switch nearestDevice.contents {
                | Some(wd) =>
                  let info = wd.device.getInfo()
                  let canOpen = switch info.deviceType {
                  | DeviceTypes.PowerStation | DeviceTypes.UPS => true
                  | _ => PowerManager.isDeviceOperational(wd.ipAddress)
                  }
                  if canOpen {
                    closeDeviceWindow()
                    let window = wd.device.openGUI()
                    DeviceWindow.setOnClose(window, () => {
                      screenState.currentDeviceWindow = None
                      screenState.controlsDisabled = false
                      Container.setVisible(Graphics.toContainer(dimOverlay), false)
                      // Detach KernelMonitor from device — hides the overlay
                      if FeaturePacks.isInvertibleProgrammingEnabled() {
                        KernelMonitor.setDevice(kernelMonitor, "")
                      }
                    })
                    let _ = Container.addChild(container, window.container)
                    Container.setX(window.container, 100.0)
                    Container.setY(window.container, 50.0)
                    screenState.currentDeviceWindow = Some(window)
                    screenState.controlsDisabled = true
                    Container.setVisible(Graphics.toContainer(dimOverlay), true)
                    // Enrol device with the coprocessor framework and attach KernelMonitor.
                    // CoprocessorManager.setup is idempotent — safe to call on every open.
                    if FeaturePacks.isInvertibleProgrammingEnabled() {
                      CoprocessorManager.setup(wd.ipAddress)
                      KernelMonitor.setDevice(kernelMonitor, wd.ipAddress)
                    }
                  }
                | None => ()
                }
              }
            }

            // H-key — open hardware wiring patch panel for nearest Router/Firewall/Server
            if globalKeyState.hardware && !screenState.controlsDisabled {
              globalKeyState.hardware = false // Consume the keypress
              let playerX = Player.getX(player)

              // Only Router, Firewall, and Server have physical patch panels worth wiring
              let nearestWirable = ref(None)
              let nearestDist = ref(interactionDistance +. 1.0)
              Array.forEach(devices, wd => {
                let info = wd.device.getInfo()
                let isWirable = switch info.deviceType {
                | DeviceTypes.Router | DeviceTypes.Firewall | DeviceTypes.Server => true
                | _ => false
                }
                if isWirable {
                  let dist = Math.abs(playerX -. wd.x)
                  if dist <= interactionDistance && dist < nearestDist.contents {
                    nearestWirable := Some(wd)
                    nearestDist := dist
                  }
                }
              })

              switch nearestWirable.contents {
              | Some(wd) =>
                closeDeviceWindow()

                // Build a 2×8 patch panel for this device (16 ports, 4 VLAN groups)
                let ports = HardwareWiring.makeStandardPorts(
                  ~config={
                    rows: 2,
                    cols: 8,
                    startX: 16.0,
                    startY: 44.0,
                    xSpacing: 44.0,
                    ySpacing: 44.0,
                    vlanGroups: [0, 0, 1, 1, 2, 2, 3, 3],
                  },
                )
                let wiringPanel = HardwareWiring.make(~width=400.0, ~height=200.0, ~ports, ())

                // Raise a port-scan detection event when an unsanctioned patch is made
                wiringPanel.onAlarmTriggered = Some(reason => {
                  DetectionSystem.reportDetection(
                    gameState.detection,
                    ~source=DetectionSystem.PortScanDetected(reason),
                    ~gameTime=gameState.gameTime,
                  )
                })

                // Build a portId → deviceIp lookup for the 16 panel slots.
                // Peers (all network devices except the patched device itself) are sorted
                // alphabetically by IP and assigned to ports A01-A08, B01-B08 in order.
                // Ports whose slot index exceeds the peer count remain unmapped.
                let portDeviceMap: dict<string> = Dict.make()
                let panelPortIds = [
                  "A01", "A02", "A03", "A04", "A05", "A06", "A07", "A08",
                  "B01", "B02", "B03", "B04", "B05", "B06", "B07", "B08",
                ]
                let sortedPeers =
                  NetworkManager.getAllDevices(screenState.networkManager)
                  ->Array.filter(d => d.getInfo().ipAddress != wd.ipAddress)
                  ->Array.toSorted((a, b) =>
                    String.compare(a.getInfo().ipAddress, b.getInfo().ipAddress)
                  )
                let slotIndex = ref(0)
                Array.forEach(panelPortIds, portId => {
                  switch Array.get(sortedPeers, slotIndex.contents) {
                  | Some(device) =>
                    Dict.set(portDeviceMap, portId, device.getInfo().ipAddress)
                  | None => ()
                  }
                  slotIndex := slotIndex.contents + 1
                })

                // onConnectionMade — create an ImprovisedLink CovertLink between the two
                // device IPs mapped to the connected ports. This immediately activates the
                // link so it is usable for SSH and VM I/O transfers, bypassing zone isolation.
                // Ports with no mapped device (slotIndex > peer count) are ignored silently.
                wiringPanel.onConnectionMade = Some((portA, portB) => {
                  switch (Dict.get(portDeviceMap, portA), Dict.get(portDeviceMap, portB)) {
                  | (Some(ipA), Some(ipB)) => {
                      let linkId = `patch_${portA}_${portB}`
                      let link: CovertLink.t = {
                        id: linkId,
                        connectionType: ImprovisedLink,
                        endpointA: ipA,
                        endpointB: ipB,
                        state: Active,
                        discoveryMethod: PhysicalAccess,
                        discoveryHint: `Patch cable ${portA}↔${portB} via ${wd.ipAddress}`,
                        activationItems: [],
                        stats: CovertLink.defaultStats(ImprovisedLink),
                        ttl: None,
                        timeRemaining: None,
                        coopRequired: false,
                        requiredForCompletion: false,
                        guardPatrolNearby: false,
                      }
                      CovertLink.Registry.add(link)
                    }
                  | _ =>
                    // One or both ports unmapped — no covert link, just log
                    ()
                  }
                })

                // onConnectionBroken — mark any ImprovisedLink that was created for the
                // pulled port as Dead, removing the covert route from the active graph.
                // Link IDs use format `patch_<portA>_<portB>` so splitting on "_" and
                // comparing port segments unambiguously identifies affected links.
                wiringPanel.onConnectionBroken = Some(brokenPortId => {
                  CovertLink.Registry.getAll()
                  ->Array.filter(link => {
                    link.connectionType == ImprovisedLink &&
                      Array.some(String.split(link.id, "_"), seg => seg == brokenPortId)
                  })
                  ->Array.forEach(link => {
                    link.state = Dead
                  })
                })

                // Wrap the patch panel in a device window for chrome and draggability
                let winTitle = `Patch Panel — ${wd.ipAddress}`
                let window = DeviceWindow.make(
                  ~title=winTitle,
                  ~width=440.0,
                  ~height=270.0,
                  ~titleBarColor=0x2d5f1e, // Dark green — physical layer
                  ~backgroundColor=0x111111,
                  (),
                )
                let _ = Container.addChild(window.content, wiringPanel.container)
                DeviceWindow.setOnClose(window, () => {
                  screenState.currentDeviceWindow = None
                  screenState.controlsDisabled = false
                  Container.setVisible(Graphics.toContainer(dimOverlay), false)
                })
                let _ = Container.addChild(container, window.container)
                Container.setX(window.container, 80.0)
                Container.setY(window.container, 40.0)
                screenState.currentDeviceWindow = Some(window)
                screenState.controlsDisabled = true
                Container.setVisible(Graphics.toContainer(dimOverlay), true)
              | None => ()
              }
            }

            // Update device power states and indicators
            let deviceIps = Array.map(devices, wd => wd.ipAddress)
            let _ = PowerManager.updateAllDevicePowerStates(deviceIps)
            Array.forEach(devices, WorldDeviceIcon.updatePowerIndicator)

            // Update pickups
            Array.forEach(screenState.pickups, p => {
              WorldPickup.updateAnimation(p, ~gameTime=gameState.gameTime)
            })

            //  Combat system 
            let combatEvents = Combat.update(
              ~player,
              ~dogs=gameState.dogs,
              ~guards=gameState.guards,
              ~_deltaTime=dt,
            )

            // Report contact damage to detection system
            if combatEvents.contactDamageDealt {
              DetectionSystem.reportDetection(
                gameState.detection,
                ~source=ContactDamage,
                ~gameTime=gameState.gameTime,
              )
            }

            //  Game systems update 
            let playerX = Player.getX(player)
            let playerY = Player.getY(player)
            let frameResult = GameLoop.update(
              gameState,
              ~dt,
              ~playerX,
              ~playerY,
              ~playerCrouching=globalKeyState.crouch,
              ~playerSprinting=globalKeyState.sprint,
            )

            // Render all guards
            Array.forEach(gameState.guards, guard => {
              GuardNPC.renderGuard(guard)
            })

            // Sync HUD
            GameLoop.syncHUD(gameState, ~hud)

            // Check player death
            if !navigated.contents && !Player.isAlive(player) {
              navigated := true
              GameOverScreen.setFailure(
                ~reason=SecurityDetected,
                ~stats=GameLoop.getRunStats(gameState),
              )
              switch GetEngine.get() {
              | Some(engine) =>
                Navigation.showScreen(engine.navigation, GameOverScreen.constructor)->ignore
              | None => ()
              }
            }

            // Check game-over / victory conditions (guard prevents per-frame re-navigation)
            if !navigated.contents && frameResult.gameOver {
              navigated := true
              switch frameResult.gameOverReason {
              | Some(reason) =>
                GameOverScreen.setFailure(~reason, ~stats=GameLoop.getRunStats(gameState))
              | None =>
                GameOverScreen.setFailure(
                  ~reason=SecurityDetected,
                  ~stats=GameLoop.getRunStats(gameState),
                )
              }
              switch GetEngine.get() {
              | Some(engine) =>
                Navigation.showScreen(engine.navigation, GameOverScreen.constructor)->ignore
              | None => ()
              }
            } else if !navigated.contents && frameResult.missionComplete {
              navigated := true
              VictoryScreen.setStats(GameLoop.getVictoryStats(gameState))
              switch GetEngine.get() {
              | Some(engine) =>
                Navigation.showScreen(engine.navigation, VictoryScreen.constructor)->ignore
              | None => ()
              }
            }

            // Co-op: flush VM message bus outbox
            if FeaturePacks.isInvertibleProgrammingEnabled() {
              VMMessageBus.update(dt)
              // Refresh KernelMonitor resource bars for the active device.
              // No-op when no device is attached (monitor.deviceId is empty).
              KernelMonitor.update(kernelMonitor)
            }

            // Co-op: throttled position sync (~5 Hz)
            if MultiplayerGlobal.enabled.contents {
              positionTimer := positionTimer.contents +. dt
              if positionTimer.contents > 0.2 {
                positionTimer := 0.0
                MultiplayerClient.sendPosition(MultiplayerGlobal.client, ~x=playerX, ~y=playerY)
              }
            }
          }
        } catch {
        | exn => Console.error2("WorldBuilder update error:", exn)
        }
      },
    ),
    resize: Some(
      (width, height) => {
        screenWidth := width
        screenHeight := height

        // Position debug buttons (bottom right)
        FancyButton.setX(debugButton, width -. 100.0)
        FancyButton.setY(debugButton, height -. 100.0)
        FancyButton.setX(powerButton, width -. 100.0)
        FancyButton.setY(powerButton, height -. 50.0)

        // Position exit button (bottom left)
        Graphics.setX(exitBtn, 20.0)
        Graphics.setY(exitBtn, height -. 60.0)
        Text.setX(exitText, 80.0)
        Text.setY(exitText, height -. 60.0)

        // Update dim overlay size
        let _ = Graphics.clear(dimOverlay)
        let _ =
          dimOverlay
          ->Graphics.rect(0.0, 0.0, width, height)
          ->Graphics.fill({"color": 0x000000, "alpha": 0.6})

        // HUD resize
        HUD.resize(hud, ~width, ~height)

        // KernelMonitor resize — anchors to bottom-left corner
        KernelMonitor.resize(kernelMonitor, ~screenWidth=width, ~screenHeight=height)

        // Position instructions
        Text.setX(instructions, 20.0)
        Text.setY(instructions, height -. 30.0)
      },
    ),
    blur: None,
    focus: None,
    onLoad: None,
  }
}

// No constructor exported - use buildLocationScreen() directly
