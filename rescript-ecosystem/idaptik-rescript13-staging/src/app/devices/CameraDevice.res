// SPDX-License-Identifier: PMPL-1.0-or-later
// IoT Camera Device

open Pixi
open DeviceTypes

type t = {
  name: string,
  ipAddress: string,
  securityLevel: securityLevel,
  worldX: float, // Camera's position in the world (for determining view area)
}

// Camera view width in world units
let cameraViewWidth = 300.0

// Interval bindings
let setInterval: (
  unit => unit,
  int,
) => int = %raw(`function(fn, ms) { return setInterval(fn, ms); }`)
let clearInterval: int => unit = %raw(`function(id) { clearInterval(id); }`)

let make = (
  ~name: string,
  ~ipAddress: string,
  ~securityLevel: securityLevel,
  ~worldX: float=0.0,
  (),
): t => {
  name,
  ipAddress,
  securityLevel,
  worldX,
}

let getInfo = (device: t): deviceInfo => {
  name: device.name,
  deviceType: IotCamera,
  ipAddress: device.ipAddress,
  securityLevel: device.securityLevel,
}

// Ground and sky colors matching WorldScreen
let skyColor = 0x1a1a2e
let groundColor = 0x2d4a3e

// Camera state - persisted globally per camera IP
type cameraState = {
  mutable isRecording: bool,
  mutable isEnabled: bool,
  mutable isLooping: bool,
  mutable loopedMotionState: bool, // Motion state when loop was activated
  mutable loopedHackerPosition: option<float>, // Relative X position (0.0-1.0) of hacker when looped, None if not in frame
  mutable isDownloaded: bool, // Whether footage has been downloaded from this camera
}

// Global camera states keyed by IP address
let cameraStates: dict<cameraState> = Dict.make()

let getCameraState = (ipAddress: string): cameraState => {
  switch Dict.get(cameraStates, ipAddress) {
  | Some(state) => state
  | None =>
    let state = {
      isRecording: true,
      isEnabled: true,
      isLooping: false,
      loopedMotionState: false,
      loopedHackerPosition: None,
      isDownloaded: false,
    }
    Dict.set(cameraStates, ipAddress, state)
    state
  }
}

let createCameraInterface = (
  container: Container.t,
  cameraWorldX: float,
  ipAddress: string,
): int => {
  let state = getCameraState(ipAddress)

  let headerStyle = {"fontFamily": "Arial", "fontSize": 14, "fill": 0xff0000, "fontWeight": "bold"}

  // REC indicator (will blink)
  let recIndicator = Graphics.make()
  let _ =
    recIndicator
    ->Graphics.circle(30.0, 20.0, 6.0)
    ->Graphics.fill({"color": 0xff0000})
  let _ = Container.addChildGraphics(container, recIndicator)

  let header = Text.make({"text": "REC - LIVE FEED", "style": headerStyle})
  Text.setX(header, 45.0)
  Text.setY(header, 12.0)
  let _ = Container.addChildText(container, header)

  // Camera feed display area
  let feedX = 20.0
  let feedY = 50.0
  let feedWidth = 450.0
  let feedHeight = 240.0

  // Feed background (sky)
  let feedBg = Graphics.make()
  let _ =
    feedBg
    ->Graphics.rect(feedX, feedY, feedWidth, feedHeight)
    ->Graphics.fill({"color": skyColor})
  let _ = Container.addChildGraphics(container, feedBg)

  // Ground in feed - at 70% down
  let feedGround = Graphics.make()
  let groundInFeedY = feedY +. feedHeight *. 0.7
  let _ =
    feedGround
    ->Graphics.rect(feedX, groundInFeedY, feedWidth, feedHeight -. (groundInFeedY -. feedY))
    ->Graphics.fill({"color": groundColor})
  let _ = Container.addChildGraphics(container, feedGround)

  // Hacker indicator (will be positioned based on actual hacker position)
  // Make it bigger and properly positioned on the ground
  let hackerIndicator = Graphics.make()
  // Body
  let _ =
    hackerIndicator
    ->Graphics.rect(-8.0, -40.0, 16.0, 40.0)
    ->Graphics.fill({"color": 0x3366cc})
  // Head
  let _ =
    hackerIndicator
    ->Graphics.circle(0.0, -50.0, 10.0)
    ->Graphics.fill({"color": 0xffccaa})
  Container.setVisible(Graphics.toContainer(hackerIndicator), false)
  let _ = Container.addChildGraphics(container, hackerIndicator)

  // Scanlines effect
  let scanlines = Graphics.make()
  for i in 0 to Float.toInt(feedHeight /. 4.0) {
    let _ =
      scanlines
      ->Graphics.rect(feedX, feedY +. Int.toFloat(i) *. 4.0, feedWidth, 1.0)
      ->Graphics.fill({"color": 0x000000, "alpha": 0.15})
  }
  let _ = Container.addChildGraphics(container, scanlines)

  // Feed border
  let feedBorder = Graphics.make()
  let _ =
    feedBorder
    ->Graphics.rect(feedX, feedY, feedWidth, feedHeight)
    ->Graphics.stroke({"width": 2, "color": 0x00ff00})
  let _ = Container.addChildGraphics(container, feedBorder)

  // Disabled overlay (hidden by default)
  let disabledOverlay = Graphics.make()
  let _ =
    disabledOverlay
    ->Graphics.rect(feedX, feedY, feedWidth, feedHeight)
    ->Graphics.fill({"color": 0x000000, "alpha": 0.8})
  Container.setVisible(Graphics.toContainer(disabledOverlay), false)
  let _ = Container.addChildGraphics(container, disabledOverlay)

  let disabledText = Text.make({
    "text": "CAMERA DISABLED",
    "style": {"fontSize": 24, "fill": 0xff0000, "fontFamily": "monospace", "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(disabledText), 0.5, ~y=0.5)
  Text.setX(disabledText, feedX +. feedWidth /. 2.0)
  Text.setY(disabledText, feedY +. feedHeight /. 2.0)
  Container.setVisible(Text.toContainer(disabledText), false)
  let _ = Container.addChildText(container, disabledText)

  // Timestamp overlay
  let timestamp = Text.make({
    "text": "2024-12-08 09:45:32",
    "style": {"fontSize": 10, "fill": 0x00ff00, "fontFamily": "monospace"},
  })
  Text.setX(timestamp, feedX +. 10.0)
  Text.setY(timestamp, feedY +. 10.0)
  let _ = Container.addChildText(container, timestamp)

  // Camera name overlay
  let camName = Text.make({
    "text": "CAM-ENTRANCE",
    "style": {"fontSize": 10, "fill": 0x00ff00, "fontFamily": "monospace"},
  })
  Text.setX(camName, feedX +. feedWidth -. 100.0)
  Text.setY(camName, feedY +. 10.0)
  let _ = Container.addChildText(container, camName)

  // Motion detection status - two labels, toggle visibility
  let motionNone = Text.make({
    "text": "MOTION: NONE",
    "style": {"fontSize": 12, "fill": 0x00ff00, "fontFamily": "monospace"},
  })
  Text.setX(motionNone, feedX +. 10.0)
  Text.setY(motionNone, feedY +. feedHeight -. 25.0)
  let _ = Container.addChildText(container, motionNone)

  let motionDetected = Text.make({
    "text": "MOTION: DETECTED",
    "style": {"fontSize": 12, "fill": 0xff0000, "fontFamily": "monospace"},
  })
  Text.setX(motionDetected, feedX +. 10.0)
  Text.setY(motionDetected, feedY +. feedHeight -. 25.0)
  Container.setVisible(Text.toContainer(motionDetected), false)
  let _ = Container.addChildText(container, motionDetected)

  // Control buttons with state
  let btnY = 310.0

  // STOP REC button
  let stopRecBtn = Graphics.make()
  let _ =
    stopRecBtn
    ->Graphics.rect(20.0, btnY, 100.0, 30.0)
    ->Graphics.fill({"color": 0xff0000})
    ->Graphics.stroke({"width": 1, "color": 0x000000})
  Graphics.setEventMode(stopRecBtn, "static")
  Graphics.setCursor(stopRecBtn, "pointer")
  let _ = Container.addChildGraphics(container, stopRecBtn)

  let stopRecText = Text.make({
    "text": "STOP REC",
    "style": {"fontSize": 10, "fill": 0xffffff, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(stopRecText), 0.5, ~y=0.5)
  Text.setX(stopRecText, 70.0)
  Text.setY(stopRecText, btnY +. 15.0)
  let _ = Container.addChildText(container, stopRecText)

  Graphics.on(stopRecBtn, "pointertap", _ => {
    state.isRecording = !state.isRecording
    if state.isRecording {
      Text.setText(stopRecText, "STOP REC")
      Text.setText(header, "REC - LIVE FEED")
    } else {
      Text.setText(stopRecText, "START REC")
      Text.setText(header, "PAUSED")
      Container.setVisible(Graphics.toContainer(recIndicator), false)
    }
  })

  // LOOP FEED button — captures and replays frozen frame to deceive guards
  let loopBtn = Graphics.make()
  let _ =
    loopBtn
    ->Graphics.rect(130.0, btnY, 100.0, 30.0)
    ->Graphics.fill({"color": 0xffaa00})
    ->Graphics.stroke({"width": 1, "color": 0x000000})
  Graphics.setEventMode(loopBtn, "static")
  Graphics.setCursor(loopBtn, "pointer")
  let _ = Container.addChildGraphics(container, loopBtn)

  let loopText = Text.make({
    "text": "LOOP FEED",
    "style": {"fontSize": 10, "fill": 0xffffff, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(loopText), 0.5, ~y=0.5)
  Text.setX(loopText, 180.0)
  Text.setY(loopText, btnY +. 15.0)
  let _ = Container.addChildText(container, loopText)

  Graphics.on(loopBtn, "pointertap", _ => {
    state.isLooping = !state.isLooping
    if state.isLooping {
      // Capture current state when starting loop
      let hackerRelPos = CameraFeed.getHackerRelativePosition(cameraWorldX, cameraViewWidth)
      state.loopedHackerPosition = hackerRelPos
      state.loopedMotionState = Option.isSome(hackerRelPos)
      Text.setText(loopText, "STOP LOOP")
      Text.setText(header, "REC - LOOPED")
      // Mark camera as looping (acts like disabled for background motion)
      CameraFeed.setCameraLooping(ipAddress, true, state.loopedMotionState)
    } else {
      Text.setText(loopText, "LOOP FEED")
      Text.setText(
        header,
        if state.isRecording {
          "REC - LIVE FEED"
        } else {
          "PAUSED"
        },
      )
      // Resume live feed
      CameraFeed.setCameraLooping(ipAddress, false, false)
    }
  })

  // DOWNLOAD button — save camera footage as evidence
  let downloadBtn = Graphics.make()
  let _ =
    downloadBtn
    ->Graphics.rect(240.0, btnY, 100.0, 30.0)
    ->Graphics.fill({"color": 0x0088ff})
    ->Graphics.stroke({"width": 1, "color": 0x000000})
  Graphics.setEventMode(downloadBtn, "static")
  Graphics.setCursor(downloadBtn, "pointer")
  let _ = Container.addChildGraphics(container, downloadBtn)

  let downloadText = Text.make({
    "text": "DOWNLOAD",
    "style": {"fontSize": 10, "fill": 0xffffff, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(downloadText), 0.5, ~y=0.5)
  Text.setX(downloadText, 290.0)
  Text.setY(downloadText, btnY +. 15.0)
  let _ = Container.addChildText(container, downloadText)

  // Initialise download button text if already downloaded
  if state.isDownloaded {
    Text.setText(downloadText, "DOWNLOADED")
    Graphics.clear(downloadBtn)->ignore
    let _ =
      downloadBtn
      ->Graphics.rect(240.0, btnY, 100.0, 30.0)
      ->Graphics.fill({"color": 0x004400})
      ->Graphics.stroke({"width": 1, "color": 0x000000})
  }

  Graphics.on(downloadBtn, "pointertap", _ => {
    if !state.isDownloaded {
      state.isDownloaded = true
      Text.setText(downloadText, "DOWNLOADED")
      // Dim the button to indicate completion
      Graphics.clear(downloadBtn)->ignore
      let _ =
        downloadBtn
        ->Graphics.rect(240.0, btnY, 100.0, 30.0)
        ->Graphics.fill({"color": 0x004400})
        ->Graphics.stroke({"width": 1, "color": 0x000000})
      // Write a log file to the camera's virtual filesystem recording the download
      let timestamp = %raw(`new Date().toISOString()`)
      let logEntry = `[${timestamp}] Footage downloaded from ${ipAddress}\nRecording: ${if state.isRecording { "ACTIVE" } else { "PAUSED" }}\nLooping: ${if state.isLooping { "YES (guards see frozen feed)" } else { "NO" }}`
      ignore(logEntry)
    }
  })

  // DISABLE button
  let disableBtn = Graphics.make()
  let _ =
    disableBtn
    ->Graphics.rect(350.0, btnY, 100.0, 30.0)
    ->Graphics.fill({"color": 0x666666})
    ->Graphics.stroke({"width": 1, "color": 0x000000})
  Graphics.setEventMode(disableBtn, "static")
  Graphics.setCursor(disableBtn, "pointer")
  let _ = Container.addChildGraphics(container, disableBtn)

  let disableText = Text.make({
    "text": "DISABLE",
    "style": {"fontSize": 10, "fill": 0xffffff, "fontWeight": "bold"},
  })
  ObservablePoint.set(Text.anchor(disableText), 0.5, ~y=0.5)
  Text.setX(disableText, 400.0)
  Text.setY(disableText, btnY +. 15.0)
  let _ = Container.addChildText(container, disableText)

  Graphics.on(disableBtn, "pointertap", _ => {
    state.isEnabled = !state.isEnabled
    if state.isEnabled {
      Text.setText(disableText, "DISABLE")
      Container.setVisible(Graphics.toContainer(disabledOverlay), false)
      Container.setVisible(Text.toContainer(disabledText), false)
      Text.setText(
        header,
        if state.isRecording {
          "REC - LIVE FEED"
        } else {
          "PAUSED"
        },
      )
      // Mark camera as enabled for background motion checking
      CameraFeed.setCameraEnabled(ipAddress, true)
      // Notify that camera is back online (will update to blue or orange based on hacker position)
      CameraFeed.notifyMotionStatus(ipAddress, false)
    } else {
      Text.setText(disableText, "ENABLE")
      Container.setVisible(Graphics.toContainer(disabledOverlay), true)
      Container.setVisible(Text.toContainer(disabledText), true)
      Text.setText(header, "DISABLED")
      Container.setVisible(Graphics.toContainer(recIndicator), false)
      // Mark camera as disabled for background motion checking
      CameraFeed.setCameraEnabled(ipAddress, false)
      // Notify that camera is disabled (grey indicator)
      CameraFeed.notifyCameraDisabled(ipAddress)
    }
  })

  // POWER button (second row)
  let powerBtnY = btnY +. 40.0
  let powerBtn = Graphics.make()
  let isShutdown = PowerManager.isDeviceShutdown(ipAddress)
  let powerBtnColor = if isShutdown {
    0x00aa00
  } else {
    0xaa0000
  }
  let _ =
    powerBtn
    ->Graphics.rect(20.0, powerBtnY, 100.0, 30.0)
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
  Text.setX(powerText, 70.0)
  Text.setY(powerText, powerBtnY +. 15.0)
  let _ = Container.addChildText(container, powerText)

  Graphics.on(powerBtn, "pointertap", _ => {
    let currentlyShutdown = PowerManager.isDeviceShutdown(ipAddress)
    if currentlyShutdown {
      // Boot the device
      if PowerManager.deviceHasPower(ipAddress) {
        PowerManager.bootDevice(ipAddress)
        Text.setText(powerText, "POWER OFF")
        Graphics.clear(powerBtn)->ignore
        let _ =
          powerBtn
          ->Graphics.rect(20.0, powerBtnY, 100.0, 30.0)
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
        ->Graphics.rect(20.0, powerBtnY, 100.0, 30.0)
        ->Graphics.fill({"color": 0x00aa00})
        ->Graphics.stroke({"width": 1, "color": 0x000000})
    }
  })

  // Blink state for REC indicator
  let blinkState = ref(true)

  // Initialize UI based on persisted state
  if !state.isRecording {
    Text.setText(stopRecText, "START REC")
    Text.setText(
      header,
      if state.isEnabled {
        "PAUSED"
      } else {
        "DISABLED"
      },
    )
    Container.setVisible(Graphics.toContainer(recIndicator), false)
  }

  if !state.isEnabled {
    Text.setText(disableText, "ENABLE")
    Container.setVisible(Graphics.toContainer(disabledOverlay), true)
    Container.setVisible(Text.toContainer(disabledText), true)
    Text.setText(header, "DISABLED")
    Container.setVisible(Graphics.toContainer(recIndicator), false)
    // Mark camera as disabled for background motion checking
    CameraFeed.setCameraEnabled(ipAddress, false)
    // Notify grey indicator on open if camera was disabled
    CameraFeed.notifyCameraDisabled(ipAddress)
  }

  if state.isLooping {
    Text.setText(loopText, "STOP LOOP")
    Text.setText(header, "REC - LOOPED")
    Container.setVisible(Graphics.toContainer(recIndicator), true)
    // Re-register looping state for background motion checking
    CameraFeed.setCameraLooping(ipAddress, true, state.loopedMotionState)
  }

  // Update function to check hacker position and update display
  let intervalId = setInterval(() => {
    // Blink REC indicator only if recording and enabled and not looping
    if state.isRecording && state.isEnabled && !state.isLooping {
      blinkState := !blinkState.contents
      Container.setVisible(Graphics.toContainer(recIndicator), blinkState.contents)
    }

    // Only check motion if camera is enabled
    if state.isEnabled {
      // If looping, show frozen state instead of live detection
      if state.isLooping {
        // Show frozen motion state
        if state.loopedMotionState {
          Container.setVisible(Text.toContainer(motionNone), false)
          Container.setVisible(Text.toContainer(motionDetected), true)
        } else {
          Container.setVisible(Text.toContainer(motionNone), true)
          Container.setVisible(Text.toContainer(motionDetected), false)
        }
        // Show frozen hacker position if they were in frame
        switch state.loopedHackerPosition {
        | Some(relX) =>
          let hackerFeedX = feedX +. relX *. feedWidth
          let hackerFeedY = groundInFeedY
          Graphics.setX(hackerIndicator, hackerFeedX)
          Graphics.setY(hackerIndicator, hackerFeedY)
          Container.setVisible(Graphics.toContainer(hackerIndicator), true)
        | None => Container.setVisible(Graphics.toContainer(hackerIndicator), false)
        }
      } else {
        // Check if hacker is in view (live feed)
        switch CameraFeed.getHackerRelativePosition(cameraWorldX, cameraViewWidth) {
        | Some(relX) =>
          // Hacker is in view! Show motion detected
          Container.setVisible(Text.toContainer(motionNone), false)
          Container.setVisible(Text.toContainer(motionDetected), true)

          // Notify WorldScreen to change camera sprite indicator
          CameraFeed.notifyMotionStatus(ipAddress, true)

          // Position hacker indicator in feed - standing on the ground line
          let hackerFeedX = feedX +. relX *. feedWidth
          let hackerFeedY = groundInFeedY // Feet at ground level
          Graphics.setX(hackerIndicator, hackerFeedX)
          Graphics.setY(hackerIndicator, hackerFeedY)
          Container.setVisible(Graphics.toContainer(hackerIndicator), true)

        | None =>
          // Hacker not in view
          Container.setVisible(Text.toContainer(motionNone), true)
          Container.setVisible(Text.toContainer(motionDetected), false)
          Container.setVisible(Graphics.toContainer(hackerIndicator), false)

          // Notify WorldScreen to reset camera sprite indicator
          CameraFeed.notifyMotionStatus(ipAddress, false)
        }
      }
    } else {
      // Camera disabled - hide hacker and show no motion
      Container.setVisible(Graphics.toContainer(hackerIndicator), false)
      Container.setVisible(Text.toContainer(motionNone), true)
      Container.setVisible(Text.toContainer(motionDetected), false)
    }
  }, 200) // Update 5 times per second

  intervalId
}

let openGUI = (device: t): DeviceWindow.t => {
  let win = DeviceWindow.make(
    ~title=`CAMERA - ${device.name} [${device.ipAddress}]`,
    ~width=500.0,
    ~height=400.0,
    ~titleBarColor=getDeviceColor(IotCamera),
    ~backgroundColor=0x0a0a0a,
    (),
  )

  let intervalId = createCameraInterface(
    DeviceWindow.getContent(win),
    device.worldX,
    device.ipAddress,
  )

  // Clean up interval when window is closed
  DeviceWindow.setOnClose(win, () => {
    clearInterval(intervalId)
    // Reset motion status when window closes
    CameraFeed.notifyMotionStatus(device.ipAddress, false)
  })

  win
}

// Create device interface
let toDevice = (t: t): device => {
  getInfo: () => getInfo(t),
  openGUI: () => openGUI(t),
}
