// SPDX-License-Identifier: PMPL-1.0-or-later
// Detection System  unified alert level from all detection sources
//
// Aggregates detection events from guards, cameras, canaries, port scans,
// and failed cracks into a global alert level (0-5) that drives the HUD
// and triggers SecurityAI response.

//  Detection Sources 

type detectionSource =
  | GuardSight(string) // Guard ID spotted player
  | GuardHearing(string) // Guard ID heard player
  | DogDetection(string) // Dog ID detected player (scent/visual)
  | DogHearing(string) // Dog ID heard player sprinting
  | CameraMotion(string) // Camera IP detected motion
  | CanaryTripped(string) // Canary device IP was accessed
  | PortScanDetected(string) // Target IP detected scan attempt
  | CrackFailed(string) // Target IP logged failed crack
  | FirewallBlock(string) // Firewall blocked suspicious packet
  | CovertLinkProbe(string) // Hidden connection probed (risky)
  | DistractionExpired(string) // Distraction type name  guards realised it was fake
  | ContactDamage // Player took contact damage from alert enemy
  | ManualAlert // Admin manually raised alert

// How much each source contributes to the alert score
let sourceWeight = (source: detectionSource): float => {
  switch source {
  | GuardSight(_) => 40.0 // Major  direct visual confirmation
  | GuardHearing(_) => 15.0 // Moderate  could be ambient noise
  | DogDetection(_) => 30.0 // Significant  dog confirmed intruder
  | DogHearing(_) => 10.0 // Minor  dogs hear many things
  | CameraMotion(_) => 25.0 // Significant  logged and reviewed
  | CanaryTripped(_) => 50.0 // Critical  honeypot confirms intruder
  | PortScanDetected(_) => 10.0 // Minor  could be routine scan
  | CrackFailed(_) => 20.0 // Moderate  deliberate attack attempt
  | FirewallBlock(_) => 5.0 // Minimal  firewalls block noise constantly
  | CovertLinkProbe(_) => 8.0 // Minor  subtle but logged
  | DistractionExpired(_) => 0.0 // Handled externally with per-type suspicion values
  | ContactDamage => 20.0 // Moderate  physical confrontation detected
  | ManualAlert => 60.0 // Critical  admin intervention
  }
}

let sourceToString = (source: detectionSource): string => {
  switch source {
  | GuardSight(id) => `Guard ${id} visual contact`
  | GuardHearing(id) => `Guard ${id} heard noise`
  | DogDetection(id) => `Dog ${id} detected intruder`
  | DogHearing(id) => `Dog ${id} heard movement`
  | CameraMotion(ip) => `Camera ${ip} motion detected`
  | CanaryTripped(ip) => `CANARY ${ip} accessed  intruder confirmed`
  | PortScanDetected(ip) => `Port scan on ${ip} detected`
  | CrackFailed(ip) => `Failed authentication on ${ip}`
  | FirewallBlock(ip) => `Firewall ${ip} blocked packet`
  | CovertLinkProbe(id) => `Hidden channel ${id} probed`
  | DistractionExpired(kind) => `False ${kind}  guards suspicious`
  | ContactDamage => `Physical confrontation detected`
  | ManualAlert => `Admin raised manual alert`
  }
}

//  Alert State 

// Alert score thresholds
let clearThreshold = 0.0
let noticedThreshold = 15.0
let cautionThreshold = 35.0
let alertThreshold = 60.0
let dangerThreshold = 85.0
let lockdownThreshold = 100.0

type detectionEvent = {
  source: detectionSource,
  timestamp: float,
  weight: float,
}

type t = {
  mutable alertScore: float, // 0.0 to 120.0 (clamped)
  mutable decayRate: float, // Points per second of natural decay
  mutable events: array<detectionEvent>,
  mutable maxEventHistory: int,
  mutable suppressionActive: bool, // Hacker using stealth tool
  mutable totalDetections: int, // Lifetime counter for stats
}

let make = (): t => {
  alertScore: 0.0,
  decayRate: 2.0, // Slow natural decay  security relaxes over time
  events: [],
  maxEventHistory: 50,
  suppressionActive: false,
  totalDetections: 0,
}

//  Alert Level Mapping 

let getAlertLevel = (system: t): HUD.alertLevel => {
  let score = system.alertScore
  if score >= lockdownThreshold {
    HUD.Lockdown
  } else if score >= dangerThreshold {
    HUD.Danger
  } else if score >= alertThreshold {
    HUD.Alert
  } else if score >= cautionThreshold {
    HUD.Caution
  } else if score >= noticedThreshold {
    HUD.Noticed
  } else {
    HUD.Clear
  }
}

let getAlertInt = (system: t): int => {
  HUD.alertToInt(getAlertLevel(system))
}

//  Event Reporting 

let reportDetection = (system: t, ~source: detectionSource, ~gameTime: float): unit => {
  // Calm mode: no alert escalation  explore freely without pressure
  if AccessibilitySettings.isCalmModeEnabled() {
    // Still record the event for the log, but don't raise the score
    let event = {source, timestamp: gameTime, weight: 0.0}
    let _ = Array.push(system.events, event)
    if Array.length(system.events) > system.maxEventHistory {
      system.events = Array.sliceToEnd(system.events, ~start=1)
    }
  } else {
    let weight = if system.suppressionActive {
      sourceWeight(source) *. 0.3 // Stealth tool reduces detection weight
    } else {
      sourceWeight(source)
    }

    system.alertScore = Math.min(120.0, system.alertScore +. weight)
    system.totalDetections = system.totalDetections + 1

    let event = {source, timestamp: gameTime, weight}
    let _ = Array.push(system.events, event)

    // Trim history
    if Array.length(system.events) > system.maxEventHistory {
      system.events = Array.sliceToEnd(system.events, ~start=1)
    }
  } // end else (not calm mode)
}

//  Per-Frame Update 

let update = (system: t, ~dt: float): unit => {
  // Natural decay  security relaxes over time if nothing happens
  if system.alertScore > 0.0 {
    let decay = system.decayRate *. dt
    system.alertScore = Math.max(0.0, system.alertScore -. decay)
  }
}

//  Stealth Suppression 

let activateSuppression = (system: t): unit => {
  system.suppressionActive = true
}

let deactivateSuppression = (system: t): unit => {
  system.suppressionActive = false
}

//  Queries 

// Is the security system in active pursuit?
let isActivelyHunting = (system: t): bool => {
  system.alertScore >= alertThreshold
}

// Has lockdown been triggered?
let isLockdown = (system: t): bool => {
  system.alertScore >= lockdownThreshold
}

// Get recent events for terminal `security log` display
let getRecentEvents = (system: t, ~count: int): array<string> => {
  let len = Array.length(system.events)
  let start = Math.Int.max(0, len - count)
  let recent = Array.slice(system.events, ~start, ~end=len)
  recent->Array.map(e => {
    let timeStr = Float.toFixed(e.timestamp, ~digits=1)
    `[${timeStr}s] ${sourceToString(e.source)} (+${Int.toString(Float.toInt(e.weight))})`
  })
}

// Format status for terminal display
let formatStatus = (system: t): string => {
  let level = getAlertLevel(system)
  let levelStr = HUD.alertToString(level)
  let score = Float.toFixed(system.alertScore, ~digits=1)
  let suppressed = if system.suppressionActive {
    " [SUPPRESSED]"
  } else {
    ""
  }
  `Alert: ${levelStr} (${score}/120)${suppressed}\nTotal detections: ${Int.toString(
      system.totalDetections,
    )}`
}

// Reset alert (e.g. after level restart)
let reset = (system: t): unit => {
  system.alertScore = 0.0
  system.events = []
  system.suppressionActive = false
  system.totalDetections = 0
}
