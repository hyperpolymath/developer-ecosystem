// SPDX-License-Identifier: PMPL-1.0-or-later
// Camera Feed System - provides live world view to camera devices

open Pixi

// Camera feed data
type cameraFeedData = {
  worldContainer: Container.t,
  getHackerPosition: unit => (float, float), // Returns (x, y) of hacker
}

// Global camera feed provider (set by WorldScreen)
let globalFeedData: ref<option<cameraFeedData>> = ref(None)

let setFeedData = (data: cameraFeedData): unit => {
  globalFeedData := Some(data)
}

let getFeedData = (): option<cameraFeedData> => {
  globalFeedData.contents
}

// Motion detection callbacks - keyed by camera IP address
// WorldScreen registers callbacks to update camera sprite indicators
// Callback receives: None = disabled/grey, Some(false) = no motion/blue, Some(true) = motion/orange
let motionCallbacks: dict<option<bool> => unit> = Dict.make()

let registerMotionCallback = (cameraIp: string, callback: option<bool> => unit): unit => {
  Dict.set(motionCallbacks, cameraIp, callback)
}

let unregisterMotionCallback = (cameraIp: string): unit => {
  Dict.delete(motionCallbacks, cameraIp)
}

// Motion status: None = disabled/grey, Some(false) = no motion/blue, Some(true) = motion/orange
let notifyMotionStatus = (cameraIp: string, motionDetected: bool): unit => {
  switch Dict.get(motionCallbacks, cameraIp) {
  | Some(callback) => callback(Some(motionDetected))
  | None => ()
  }
}

// Notify camera is disabled (grey indicator)
let notifyCameraDisabled = (cameraIp: string): unit => {
  switch Dict.get(motionCallbacks, cameraIp) {
  | Some(callback) => callback(None)
  | None => ()
  }
}

// Check if hacker is within camera view range
// cameraX: world X position of the camera
// viewWidth: how wide the camera can see
let isHackerInView = (cameraX: float, viewWidth: float): bool => {
  switch globalFeedData.contents {
  | None => false
  | Some(data) =>
    let (hackerX, _) = data.getHackerPosition()
    let leftBound = cameraX -. viewWidth /. 2.0
    let rightBound = cameraX +. viewWidth /. 2.0
    hackerX >= leftBound && hackerX <= rightBound
  }
}

// Get hacker position relative to camera view (0.0 to 1.0, or None if not in view)
let getHackerRelativePosition = (cameraX: float, viewWidth: float): option<float> => {
  switch globalFeedData.contents {
  | None => None
  | Some(data) =>
    let (hackerX, _) = data.getHackerPosition()
    let leftBound = cameraX -. viewWidth /. 2.0
    let rightBound = cameraX +. viewWidth /. 2.0
    if hackerX >= leftBound && hackerX <= rightBound {
      Some((hackerX -. leftBound) /. viewWidth)
    } else {
      None
    }
  }
}

// Camera positions in world - used for background motion checking
// Maps IP address to (worldX, viewWidth)
let cameraPositions: dict<(float, float)> = Dict.make()

// Track which cameras are disabled (to skip in background motion check)
let disabledCameras: Set.t<string> = Set.make()

// Track which cameras are looping and their frozen motion state
// Maps IP to frozen motion state (true = motion detected, false = no motion)
let loopingCameras: dict<bool> = Dict.make()

let registerCameraPosition = (cameraIp: string, worldX: float, viewWidth: float): unit => {
  Dict.set(cameraPositions, cameraIp, (worldX, viewWidth))
}

let setCameraEnabled = (cameraIp: string, enabled: bool): unit => {
  if enabled {
    Set.delete(disabledCameras, cameraIp)->ignore
  } else {
    Set.add(disabledCameras, cameraIp)
  }
}

let setCameraLooping = (cameraIp: string, looping: bool, frozenMotionState: bool): unit => {
  if looping {
    Dict.set(loopingCameras, cameraIp, frozenMotionState)
  } else {
    Dict.delete(loopingCameras, cameraIp)
  }
}

// Update all camera motion statuses based on hacker position
// Called from WorldScreen update loop
let updateAllCameraMotion = (): unit => {
  Dict.toArray(cameraPositions)->Array.forEach(((ip, position)) => {
    let (worldX, viewWidth) = position

    // Skip disabled cameras
    if Set.has(disabledCameras, ip) {
      ()
    } else {
      // Check if camera has power - if not, show as disabled (grey)
      let hasPower = PowerManager.isDeviceOperational(ip)
      if !hasPower {
        // No power - show grey indicator
        switch Dict.get(motionCallbacks, ip) {
        | Some(callback) => callback(None)
        | None => ()
        }
      } else {
        // Check if this camera has a motion callback registered
        switch Dict.get(motionCallbacks, ip) {
        | Some(callback) =>
          // Check if camera is looping - use frozen state instead of live detection
          switch Dict.get(loopingCameras, ip) {
          | Some(frozenMotion) =>
            // Camera is looping - show the frozen motion state
            callback(Some(frozenMotion))
          | None =>
            // Camera is live - check actual hacker position
            let motionDetected = isHackerInView(worldX, viewWidth)
            callback(Some(motionDetected))
          }
        | None => ()
        }
      }
    }
  })
}
