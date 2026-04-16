// SPDX-License-Identifier: PMPL-1.0-or-later
// Security AI  SENTRY system that coordinates anti-hacker response
//
// ADR-0011: "Undo IS the defence mechanic."
// ADR-0013: Only Anti-Hacker Specialist NPCs can perform VM reversions.
//
// SENTRY is the corporate security daemon. It monitors the network and
// DETECTS compromised devices, but it CANNOT undo changes itself.
// Instead, it dispatches Anti-Hacker Specialists to perform reversions.
// If no anti-hackers are available (fled, panicking, or dead), SENTRY
// is helpless  it can only raise the alert level and hope guards
// find the intruder.
//
// This creates a strategic dynamic: the player can scare off anti-hackers
// to buy time, but doing so raises the alert level further.

//  AI Personality 

let sentryName = "SENTRY"

let sentryMessages = {
  "detected": "[SENTRY] Anomalous state change detected on device %s",
  "dispatching": "[SENTRY] Dispatching anti-hacker specialist to %s",
  "no_specialists": "[SENTRY] WARNING: No anti-hacker specialists available  cannot revert %s",
  "specialist_fled": "[SENTRY] Anti-hacker specialist fled before completing reversion on %s",
  "reverted": "[SENTRY] Device %s restored to baseline state by specialist",
  "lockdown": "[SENTRY] LOCKDOWN ENGAGED  all available specialists dispatched",
  "scanning": "[SENTRY] Scanning network for unauthorized modifications...",
  "clear": "[SENTRY] Scan complete  no anomalies detected",
  "rival_detected": "[SENTRY] Unidentified hacker signature detected on network",
}

//  AI State 

type aiPhase =
  | Dormant // Alert 0-1: not active, passive monitoring
  | Scanning // Alert 2: actively scanning for changes
  | Targeting // Alert 3: identified compromised devices, dispatching
  | Active // Alert 4: all available specialists deployed
  | Lockdown // Alert 5: maximum response, all resources mobilised

// Track devices that need anti-hacker attention
type compromisedDevice = {
  deviceId: string,
  mutable undosNeeded: int, // How many UNDO operations needed
  mutable assignedSpecialist: option<string>, // Anti-hacker NPC ID
  mutable dispatched: bool, // Has a specialist been sent?
  mutable completed: bool, // Device fully reverted?
}

type t = {
  mutable phase: aiPhase,
  mutable scanTimer: float,
  mutable scanInterval: float,
  mutable compromisedDevices: array<compromisedDevice>,
  mutable messageLog: array<string>,
  mutable maxMessages: int,
  mutable totalReversions: int, // Lifetime counter (by specialists)
  mutable failedDispatches: int, // Times no specialist was available
}

let make = (): t => {
  phase: Dormant,
  scanTimer: 0.0,
  scanInterval: 10.0,
  compromisedDevices: [],
  messageLog: [],
  maxMessages: 20,
  totalReversions: 0,
  failedDispatches: 0,
}

//  Phase Transitions 

let updatePhase = (ai: t, ~alertLevel: int): unit => {
  let newPhase = switch alertLevel {
  | 0 | 1 => Dormant
  | 2 => Scanning
  | 3 => Targeting
  | 4 => Active
  | _ => Lockdown
  }

  if ai.phase != newPhase {
    ai.phase = newPhase

    switch newPhase {
    | Dormant => {
        ai.scanInterval = 10.0
        ai.compromisedDevices = []
      }
    | Scanning => ai.scanInterval = 5.0
    | Targeting => ai.scanInterval = 3.0
    | Active => ai.scanInterval = 2.0
    | Lockdown => ai.scanInterval = 1.0
    }
  }
}

//  Logging 

let log = (ai: t, ~message: string): unit => {
  let _ = Array.push(ai.messageLog, message)
  if Array.length(ai.messageLog) > ai.maxMessages {
    ai.messageLog = Array.sliceToEnd(ai.messageLog, ~start=1)
  }
}

//  Network Scanning 

let scanForCompromised = (_ai: t): array<string> => {
  if !FeaturePacks.isInvertibleProgrammingEnabled() {
    []
  } else {
    let allDevices = VMNetwork.getAllDeviceIds()
    let compromised = allDevices->Array.filter(deviceId => {
      let history = VMNetwork.getDeviceHistory(deviceId)
      Array.length(history) > 0
    })
    compromised
  }
}

//  Specialist Dispatch 

// Request type for the game loop to process
type dispatchRequest = {
  deviceId: string,
  undosNeeded: int,
}

// Track a compromised device
let trackDevice = (ai: t, ~deviceId: string): unit => {
  let alreadyTracked = ai.compromisedDevices->Array.some(d => d.deviceId == deviceId)
  if !alreadyTracked {
    let history = VMNetwork.getDeviceHistory(deviceId)
    let undoCount = Array.length(history)
    if undoCount > 0 {
      let device: compromisedDevice = {
        deviceId,
        undosNeeded: undoCount,
        assignedSpecialist: None,
        dispatched: false,
        completed: false,
      }
      let _ = Array.push(ai.compromisedDevices, device)
      log(
        ai,
        ~message=`[SENTRY] Targeting ${deviceId}  ${Int.toString(
            undoCount,
          )} operations to revert`,
      )
    }
  }
}

// Get list of devices that need specialists dispatched
let getPendingDispatches = (ai: t): array<dispatchRequest> => {
  ai.compromisedDevices
  ->Array.filter(d => !d.dispatched && !d.completed)
  ->Array.map(d => {
    {deviceId: d.deviceId, undosNeeded: d.undosNeeded}
  })
}

// Record that a specialist has been assigned to a device
let assignSpecialist = (ai: t, ~deviceId: string, ~specialistId: string): unit => {
  ai.compromisedDevices->Array.forEach(d => {
    if d.deviceId == deviceId {
      d.assignedSpecialist = Some(specialistId)
      d.dispatched = true
    }
  })
  log(ai, ~message=`[SENTRY] Specialist ${specialistId} dispatched to ${deviceId}`)
}

// Record that no specialist is available
let recordDispatchFailure = (ai: t, ~deviceId: string): unit => {
  ai.failedDispatches = ai.failedDispatches + 1
  log(ai, ~message=`[SENTRY] WARNING: No specialists available for ${deviceId}`)
}

// Record that a specialist completed reversion
let recordReversion = (ai: t, ~deviceId: string): unit => {
  ai.compromisedDevices->Array.forEach(d => {
    if d.deviceId == deviceId {
      d.completed = true
    }
  })
  ai.totalReversions = ai.totalReversions + 1
  log(ai, ~message=`[SENTRY] Device ${deviceId} restored to baseline`)
}

// Record that a specialist fled (device still compromised)
let recordSpecialistFled = (ai: t, ~deviceId: string): unit => {
  ai.compromisedDevices->Array.forEach(d => {
    if d.deviceId == deviceId {
      d.assignedSpecialist = None
      d.dispatched = false // Needs re-dispatch
    }
  })
  log(ai, ~message=`[SENTRY] Specialist fled  ${deviceId} still compromised`)
}

//  Per-Frame Update 

// Returns dispatch requests for the game loop to process.
// The game loop is responsible for finding available anti-hacker NPCs
// and calling GuardNPC.assignReverseTarget on them.
let update = (ai: t, ~dt: float, ~alertLevel: int): array<dispatchRequest> => {
  updatePhase(ai, ~alertLevel)

  let dispatches = ref([])

  switch ai.phase {
  | Dormant => ()

  | Scanning => {
      ai.scanTimer = ai.scanTimer +. dt
      if ai.scanTimer >= ai.scanInterval {
        ai.scanTimer = 0.0
        let compromised = scanForCompromised(ai)
        if Array.length(compromised) > 0 {
          log(
            ai,
            ~message=`[SENTRY] Scan detected ${Int.toString(
                Array.length(compromised),
              )} modified devices`,
          )
        }
      }
    }

  | Targeting => {
      ai.scanTimer = ai.scanTimer +. dt
      if ai.scanTimer >= ai.scanInterval {
        ai.scanTimer = 0.0
        let compromised = scanForCompromised(ai)
        // Target the most recently modified device
        switch compromised[0] {
        | Some(deviceId) => {
            trackDevice(ai, ~deviceId)
            dispatches := getPendingDispatches(ai)
          }
        | None => ()
        }
      }
    }

  | Active => {
      ai.scanTimer = ai.scanTimer +. dt
      if ai.scanTimer >= ai.scanInterval {
        ai.scanTimer = 0.0
        let compromised = scanForCompromised(ai)
        compromised->Array.forEach(deviceId => trackDevice(ai, ~deviceId))
        dispatches := getPendingDispatches(ai)
      }
    }

  | Lockdown => {
      // Continuous scanning  dispatch everything
      let compromised = scanForCompromised(ai)
      compromised->Array.forEach(deviceId => trackDevice(ai, ~deviceId))
      dispatches := getPendingDispatches(ai)

      if Array.length(dispatches.contents) > 0 {
        log(ai, ~message="[SENTRY] LOCKDOWN  dispatching all available specialists")
      }
    }
  }

  // Clean up completed devices
  ai.compromisedDevices = ai.compromisedDevices->Array.filter(d => !d.completed)

  dispatches.contents
}

//  Queries 

let phaseToString = (phase: aiPhase): string => {
  switch phase {
  | Dormant => "DORMANT"
  | Scanning => "SCANNING"
  | Targeting => "TARGETING"
  | Active => "ACTIVE"
  | Lockdown => "LOCKDOWN"
  }
}

let formatStatus = (ai: t): string => {
  let phase = phaseToString(ai.phase)
  let tracked = Int.toString(Array.length(ai.compromisedDevices))
  let dispatched = Int.toString(
    ai.compromisedDevices->Array.filter(d => d.dispatched && !d.completed)->Array.length,
  )
  let reversions = Int.toString(ai.totalReversions)
  let failed = Int.toString(ai.failedDispatches)
  `SENTRY Status: ${phase}\nTracked devices: ${tracked}\nSpecialists deployed: ${dispatched}\nTotal reversions: ${reversions}\nFailed dispatches: ${failed}`
}

let getRecentMessages = (ai: t, ~count: int): array<string> => {
  let len = Array.length(ai.messageLog)
  let start = Math.Int.max(0, len - count)
  Array.slice(ai.messageLog, ~start, ~end=len)
}

let isActive = (ai: t): bool => {
  ai.phase != Dormant
}

let reset = (ai: t): unit => {
  ai.phase = Dormant
  ai.scanTimer = 0.0
  ai.compromisedDevices = []
  ai.totalReversions = 0
  ai.failedDispatches = 0
  ai.messageLog = []
}
