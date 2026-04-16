// SPDX-License-Identifier: PMPL-1.0-or-later
// Power Management System
// Tracks power state for all devices in the network

// Power source types
type powerSource =
  | MainsPower // From power station
  | UPSBattery // From UPS when mains is down
  | NoPower // No power available

// UPS state
type upsState = {
  mutable batteryLevel: float, // 0.0 to 100.0
  mutable isCharging: bool,
  mutable connectedDevices: array<string>, // IP addresses of devices powered by this UPS
}

// Power station state
type powerStationState = {
  mutable isOnline: bool,
  mutable outputPower: float, // Watts being output
  mutable connectedUPS: array<string>, // IP addresses of connected UPS units
}

// Global power states
let powerStationStates: dict<powerStationState> = Dict.make()
let upsStates: dict<upsState> = Dict.make()

// Track which devices are shutdown due to power loss
let shutdownDevices: ref<Set.t<string>> = ref(Set.make())

// Track which devices were manually shutdown by user (these don't auto-boot)
let manuallyShutdownDevices: ref<Set.t<string>> = ref(Set.make())

// Main power station IP (there's typically one main station)
let mainPowerStationIp = ref("192.168.1.250")

// Get or create power station state
let getPowerStationState = (ip: string): powerStationState => {
  switch Dict.get(powerStationStates, ip) {
  | Some(state) => state
  | None =>
    let state = {
      isOnline: true,
      outputPower: 5000.0, // 5kW default
      connectedUPS: [],
    }
    Dict.set(powerStationStates, ip, state)
    state
  }
}

// Get or create UPS state
let getUPSState = (ip: string): upsState => {
  switch Dict.get(upsStates, ip) {
  | Some(state) => state
  | None =>
    let state = {
      batteryLevel: 100.0,
      isCharging: true,
      connectedDevices: [],
    }
    Dict.set(upsStates, ip, state)
    state
  }
}

// Set main power station
let setMainPowerStation = (ip: string): unit => {
  mainPowerStationIp := ip
}

// Connect UPS to power station
let connectUPSToPowerStation = (upsIp: string, stationIp: string): unit => {
  let station = getPowerStationState(stationIp)
  if !Array.some(station.connectedUPS, ip => ip == upsIp) {
    station.connectedUPS = Array.concat(station.connectedUPS, [upsIp])
  }
}

// Connect device to UPS
let connectDeviceToUPS = (deviceIp: string, upsIp: string): unit => {
  let ups = getUPSState(upsIp)
  if !Array.some(ups.connectedDevices, ip => ip == deviceIp) {
    ups.connectedDevices = Array.concat(ups.connectedDevices, [deviceIp])
  }
}

// Check if main power station is online
let isMainPowerOnline = (): bool => {
  let state = getPowerStationState(mainPowerStationIp.contents)
  state.isOnline
}

// Toggle power station
let setPowerStationOnline = (ip: string, online: bool): unit => {
  let state = getPowerStationState(ip)
  state.isOnline = online

  // Update all connected UPS charging state
  Array.forEach(state.connectedUPS, upsIp => {
    let ups = getUPSState(upsIp)
    ups.isCharging = online
  })
}

// Get power source for a device
let getDevicePowerSource = (deviceIp: string): powerSource => {
  // Check if device is connected to any UPS
  let connectedUps =
    Dict.toArray(upsStates)->Array.find(((_, ups)) =>
      Array.some(ups.connectedDevices, ip => ip == deviceIp)
    )

  switch connectedUps {
  | Some((upsIp, ups)) =>
    // Device is on UPS - check if main power is on
    // Find which power station this UPS is connected to
    let connectedStation =
      Dict.toArray(powerStationStates)->Array.find(((_, station)) =>
        Array.some(station.connectedUPS, ip => ip == upsIp)
      )

    switch connectedStation {
    | Some((_, station)) =>
      if station.isOnline {
        MainsPower
      } else if ups.batteryLevel > 0.0 {
        UPSBattery
      } else {
        NoPower
      }
    | None =>
      // UPS not connected to any station - running on battery only
      if ups.batteryLevel > 0.0 {
        UPSBattery
      } else {
        NoPower
      }
    }
  | None =>
    // Device not on UPS - check main power directly
    if isMainPowerOnline() {
      MainsPower
    } else {
      NoPower
    }
  }
}

// Check if a device has power (either mains or UPS)
let deviceHasPower = (deviceIp: string): bool => {
  getDevicePowerSource(deviceIp) != NoPower
}

// Update UPS battery levels (called from game loop)
// Drains battery when on battery power, charges when on mains
let updateUPSBatteries = (deltaSeconds: float): unit => {
  Dict.valuesToArray(upsStates)->Array.forEach(ups => {
    if ups.isCharging {
      // Charging at 10% per minute when on mains
      let newLevel = ups.batteryLevel +. deltaSeconds *. (10.0 /. 60.0)
      ups.batteryLevel = if newLevel > 100.0 {
        100.0
      } else {
        newLevel
      }
    } else {
      // Draining based on connected devices (roughly 1% per 30 seconds per device)
      let drainRate = Int.toFloat(Array.length(ups.connectedDevices)) *. (1.0 /. 30.0)
      let newLevel = ups.batteryLevel -. deltaSeconds *. drainRate
      ups.batteryLevel = if newLevel < 0.0 {
        0.0
      } else {
        newLevel
      }
    }
  })
}

// Get UPS battery level
let getUPSBatteryLevel = (upsIp: string): float => {
  let ups = getUPSState(upsIp)
  ups.batteryLevel
}

// Check if UPS is charging
let isUPSCharging = (upsIp: string): bool => {
  let ups = getUPSState(upsIp)
  ups.isCharging
}

// Get devices connected to UPS
let getUPSConnectedDevices = (upsIp: string): array<string> => {
  let ups = getUPSState(upsIp)
  ups.connectedDevices
}

// Get UPS units connected to power station
let getPowerStationConnectedUPS = (stationIp: string): array<string> => {
  let station = getPowerStationState(stationIp)
  station.connectedUPS
}

// Callbacks for power state changes
let powerChangeCallbacks: dict<bool => unit> = Dict.make()

let registerPowerChangeCallback = (deviceIp: string, callback: bool => unit): unit => {
  Dict.set(powerChangeCallbacks, deviceIp, callback)
}

let unregisterPowerChangeCallback = (deviceIp: string): unit => {
  Dict.delete(powerChangeCallbacks, deviceIp)
}

// Notify all devices of power state change
let notifyPowerChange = (): unit => {
  Dict.toArray(powerChangeCallbacks)->Array.forEach(((deviceIp, callback)) => {
    callback(deviceHasPower(deviceIp))
  })
}

// Check if a device is shutdown (due to power loss)
let isDeviceShutdown = (deviceIp: string): bool => {
  Set.has(shutdownDevices.contents, deviceIp)
}

// Shutdown a device (called when power is lost)
let shutdownDevice = (deviceIp: string): unit => {
  Set.add(shutdownDevices.contents, deviceIp)
}

// Manually shutdown a device (user clicked the power indicator)
let manualShutdownDevice = (deviceIp: string): unit => {
  Set.add(shutdownDevices.contents, deviceIp)
  Set.add(manuallyShutdownDevices.contents, deviceIp)
}

// Check if device was manually shutdown
let isManuallyShutdown = (deviceIp: string): bool => {
  Set.has(manuallyShutdownDevices.contents, deviceIp)
}

// Boot a device (called when power is restored or user manually boots)
let bootDevice = (deviceIp: string): unit => {
  Set.delete(shutdownDevices.contents, deviceIp)->ignore
  Set.delete(manuallyShutdownDevices.contents, deviceIp)->ignore
}

// Check if device is operational (has power AND not shutdown)
let isDeviceOperational = (deviceIp: string): bool => {
  deviceHasPower(deviceIp) && !isDeviceShutdown(deviceIp)
}

// Update all device power states - shutdown devices without power, boot devices with power
// Returns array of (ip, wasShutdown, isNowShutdown) for devices that changed state
// Note: Does NOT auto-boot manually shutdown devices - user must boot them manually
let updateAllDevicePowerStates = (allDeviceIps: array<string>): array<(string, bool, bool)> => {
  let changes = ref([])

  Array.forEach(allDeviceIps, ip => {
    let hasPower = deviceHasPower(ip)
    let wasShutdown = isDeviceShutdown(ip)
    let wasManuallyShutdown = isManuallyShutdown(ip)

    if !hasPower && !wasShutdown {
      // Lost power - shutdown
      shutdownDevice(ip)
      changes := Array.concat(changes.contents, [(ip, false, true)])
    } else if hasPower && wasShutdown && !wasManuallyShutdown {
      // Power restored after power loss - auto-boot
      // (but NOT if device was manually shutdown by user)
      bootDevice(ip)
      changes := Array.concat(changes.contents, [(ip, true, false)])
    }
  })

  changes.contents
}
