// SPDX-License-Identifier: PMPL-1.0-or-later
// Distraction System  social engineering via PBX phone calls
//
// Players hack a physical PBX device to unlock `pbx call <type>` commands.
// Once hacked, the `pbx` command works from ANY terminal on the network.
// Distractions lure guards, dogs, and drones to a target location for
// a limited duration. Each type has limited uses, a cooldown, and a
// suspicion cost if guards realise it's fake.
//
// Distraction types:

//   PizzaDelivery      low risk, pulls 1-2 guards to entrance, 30s
//   FakeMaintenance    medium risk, pulls guards to loading dock, 45s
//   FireAlarm          high impact, pulls ALL guards to exits, raises alert
//   PrankCall          confuses station guards for 15s
//   FakePoliceCall     empties lobby for 60s, very suspicious if caught

let absFloat = (x: float): float =>
  if x < 0.0 {
    -.x
  } else {
    x
  }

//  Distraction Types 

type distractionKind =
  | PizzaDelivery
  | FakeMaintenance
  | FireAlarm
  | PrankCall
  | FakePoliceCall

// Properties for each distraction type (duration, radius, etc.)
type distractionSpec = {
  kind: distractionKind,
  label: string, // Human-readable name for terminal output
  durationSec: float, // How long the distraction lasts
  radius: float, // How far away entities are affected (px)
  targetX: float, // Where in the level the distraction occurs
  maxGuards: int, // Max guards pulled (-1 = ALL)
  alertPenalty: float, // Immediate alert score added on trigger
  suspicionOnExpiry: float, // Alert added when guards realise it's fake
  maxUsesPerMission: int, // How many times this type can be used
  affectsDogs: bool, // Do guard dogs respond?
  affectsDrones: bool, // Do drones respond?
}

let getSpec = (
  kind: distractionKind,
  ~entranceX: float,
  ~exitX: float,
  ~lobbyX: float,
  ~dockX: float,
): distractionSpec => {
  switch kind {
  | PizzaDelivery => {
      kind: PizzaDelivery,
      label: "Pizza Delivery",
      durationSec: 30.0,
      radius: 300.0,
      targetX: entranceX,
      maxGuards: 2,
      alertPenalty: 0.0, // No alert  completely innocuous
      suspicionOnExpiry: 5.0, // Mild suspicion when nobody ordered pizza
      maxUsesPerMission: 2,
      affectsDogs: true, // Dogs go check the pizza smell
      affectsDrones: false, // Drones don't care about pizza
    }
  | FakeMaintenance => {
      kind: FakeMaintenance,
      label: "Fake Maintenance Visit",
      durationSec: 45.0,
      radius: 400.0,
      targetX: dockX,
      maxGuards: 3,
      alertPenalty: 5.0, // Slight suspicion  unscheduled visit
      suspicionOnExpiry: 15.0, // Guards realise nobody called maintenance
      maxUsesPerMission: 1,
      affectsDogs: false, // Dogs stay on patrol
      affectsDrones: false,
    }
  | FireAlarm => {
      kind: FireAlarm,
      label: "Fire Alarm",
      durationSec: 25.0,
      radius: 9999.0, // Entire level
      targetX: exitX,
      maxGuards: -1, // ALL guards
      alertPenalty: 20.0, // Immediate alert spike
      suspicionOnExpiry: 30.0, // Big penalty  false alarm is very suspicious
      maxUsesPerMission: 1,
      affectsDogs: true, // Dogs panic and follow handlers
      affectsDrones: true, // Drones reroute to exits
    }
  | PrankCall => {
      kind: PrankCall,
      label: "Prank Call to Guard Station",
      durationSec: 15.0,
      radius: 250.0,
      targetX: lobbyX,
      maxGuards: 2,
      alertPenalty: 0.0,
      suspicionOnExpiry: 3.0, // Barely noticed
      maxUsesPerMission: 2,
      affectsDogs: false,
      affectsDrones: false,
    }
  | FakePoliceCall => {
      kind: FakePoliceCall,
      label: "Fake Police Call",
      durationSec: 60.0,
      radius: 500.0,
      targetX: lobbyX,
      maxGuards: 4,
      alertPenalty: 10.0, // Security takes it seriously
      suspicionOnExpiry: 40.0, // Very suspicious when police don't show
      maxUsesPerMission: 1,
      affectsDogs: true,
      affectsDrones: true,
    }
  }
}

let kindToString = (kind: distractionKind): string => {
  switch kind {
  | PizzaDelivery => "pizza"
  | FakeMaintenance => "maintenance"
  | FireAlarm => "fire"
  | PrankCall => "prank"
  | FakePoliceCall => "police"
  }
}

let kindFromString = (s: string): option<distractionKind> => {
  switch String.toLowerCase(s) {
  | "pizza" | "pizzadelivery" | "pizza_delivery" => Some(PizzaDelivery)
  | "maintenance" | "maint" => Some(FakeMaintenance)
  | "fire" | "firealarm" | "fire_alarm" => Some(FireAlarm)
  | "prank" | "prankcall" | "prank_call" => Some(PrankCall)
  | "police" | "fakepolice" | "police_call" => Some(FakePoliceCall)
  | _ => None
  }
}

//  Active Distraction 

type activeDistraction = {
  id: string,
  spec: distractionSpec,
  mutable elapsedSec: float,
  mutable expired: bool,
  mutable guardsResponding: int, // How many guards are currently responding
}

let makeActive = (~id: string, ~spec: distractionSpec): activeDistraction => {
  id,
  spec,
  elapsedSec: 0.0,
  expired: false,
  guardsResponding: 0,
}

//  PBX State 

type pbxState = {
  mutable hacked: bool, // Must hack the physical PBX first
  mutable usesRemaining: dict<int>,
  mutable cooldownSec: float, // Time until next call allowed
  mutable activeDistractions: array<activeDistraction>,
  mutable totalCalls: int,
  mutable nextId: int,
  ipAddress: string, // PBX device IP
  // Level layout anchors (set per level)
  mutable entranceX: float,
  mutable exitX: float,
  mutable lobbyX: float,
  mutable dockX: float,
}

let cooldownBetweenCalls = 60.0 // Seconds between PBX calls

let make = (~ipAddress: string): pbxState => {
  let uses = Dict.make()
  Dict.set(uses, "pizza", 2)
  Dict.set(uses, "maintenance", 1)
  Dict.set(uses, "fire", 1)
  Dict.set(uses, "prank", 2)
  Dict.set(uses, "police", 1)

  {
    hacked: false,
    usesRemaining: uses,
    cooldownSec: 0.0,
    activeDistractions: [],
    totalCalls: 0,
    nextId: 1,
    ipAddress,
    entranceX: 100.0,
    exitX: 50.0,
    lobbyX: 400.0,
    dockX: 200.0,
  }
}

//  PBX Operations 

type callResult =
  | Success(activeDistraction)
  | NotHacked
  | OnCooldown(float) // Seconds remaining
  | NoUsesLeft
  | UnknownType

// Attempt to make a PBX call
let call = (pbx: pbxState, ~kind: distractionKind): callResult => {
  if !pbx.hacked {
    NotHacked
  } else if pbx.cooldownSec > 0.0 {
    OnCooldown(pbx.cooldownSec)
  } else {
    let key = kindToString(kind)
    let remaining = Dict.get(pbx.usesRemaining, key)->Option.getOr(0)
    if remaining <= 0 {
      NoUsesLeft
    } else {
      let spec = getSpec(
        kind,
        ~entranceX=pbx.entranceX,
        ~exitX=pbx.exitX,
        ~lobbyX=pbx.lobbyX,
        ~dockX=pbx.dockX,
      )
      let id = `distraction_${Int.toString(pbx.nextId)}`
      let distraction = makeActive(~id, ~spec)
      pbx.nextId = pbx.nextId + 1
      pbx.totalCalls = pbx.totalCalls + 1
      pbx.cooldownSec = cooldownBetweenCalls
      Dict.set(pbx.usesRemaining, key, remaining - 1)
      let _ = Array.push(pbx.activeDistractions, distraction)
      Success(distraction)
    }
  }
}

// Hack the PBX (called when player successfully hacks the PBX device)
let hackPBX = (pbx: pbxState): unit => {
  pbx.hacked = true
}

//  Per-Frame Update 

type distractionEvent =
  | DistractionStarted(activeDistraction)
  | DistractionExpired(activeDistraction)

let update = (pbx: pbxState, ~dt: float): array<distractionEvent> => {
  // Tick cooldown
  if pbx.cooldownSec > 0.0 {
    pbx.cooldownSec = Math.max(0.0, pbx.cooldownSec -. dt)
  }

  // Tick active distractions, collect events
  let events: array<distractionEvent> = []
  pbx.activeDistractions->Array.forEach(d => {
    if !d.expired {
      d.elapsedSec = d.elapsedSec +. dt
      if d.elapsedSec >= d.spec.durationSec {
        d.expired = true
        let _ = Array.push(events, DistractionExpired(d))
      }
    }
  })

  // Remove expired distractions (keep for 2s after expiry for cleanup)
  pbx.activeDistractions =
    pbx.activeDistractions->Array.filter(d =>
      !d.expired || d.elapsedSec < d.spec.durationSec +. 2.0
    )

  events
}

//  Guard AI Queries 

// Check if a guard at position guardX should respond to any active distraction.
// Returns the target X position and distraction ID if they should respond.
type distractionOrder = {
  targetX: float,
  distractionId: string,
  kind: distractionKind,
}

let getDistractionForGuard = (pbx: pbxState, ~guardX: float): option<distractionOrder> => {
  // Find the nearest active, non-expired distraction within radius
  let best = ref(None)
  let bestDist = ref(99999.0)
  pbx.activeDistractions->Array.forEach(d => {
    if !d.expired {
      let dist = absFloat(guardX -. d.spec.targetX)
      if dist < d.spec.radius && dist < bestDist.contents {
        // Check if this distraction still wants more guards
        if d.spec.maxGuards == -1 || d.guardsResponding < d.spec.maxGuards {
          best :=
            Some({
              targetX: d.spec.targetX,
              distractionId: d.id,
              kind: d.spec.kind,
            })
          bestDist := dist
        }
      }
    }
  })
  best.contents
}

// Same for dogs  only responds if spec.affectsDogs
let getDistractionForDog = (pbx: pbxState, ~dogX: float): option<distractionOrder> => {
  let best = ref(None)
  let bestDist = ref(99999.0)
  pbx.activeDistractions->Array.forEach(d => {
    if !d.expired && d.spec.affectsDogs {
      let dist = absFloat(dogX -. d.spec.targetX)
      if dist < d.spec.radius && dist < bestDist.contents {
        best :=
          Some({
            targetX: d.spec.targetX,
            distractionId: d.id,
            kind: d.spec.kind,
          })
        bestDist := dist
      }
    }
  })
  best.contents
}

// Same for drones
let getDistractionForDrone = (pbx: pbxState, ~droneX: float): option<distractionOrder> => {
  let best = ref(None)
  let bestDist = ref(99999.0)
  pbx.activeDistractions->Array.forEach(d => {
    if !d.expired && d.spec.affectsDrones {
      let dist = absFloat(droneX -. d.spec.targetX)
      if dist < d.spec.radius && dist < bestDist.contents {
        best :=
          Some({
            targetX: d.spec.targetX,
            distractionId: d.id,
            kind: d.spec.kind,
          })
        bestDist := dist
      }
    }
  })
  best.contents
}

// Register that a guard is responding to a distraction
let registerResponder = (pbx: pbxState, ~distractionId: string): unit => {
  pbx.activeDistractions->Array.forEach(d => {
    if d.id == distractionId {
      d.guardsResponding = d.guardsResponding + 1
    }
  })
}

// Unregister when guard stops responding (distraction expired, guard reassigned)
let unregisterResponder = (pbx: pbxState, ~distractionId: string): unit => {
  pbx.activeDistractions->Array.forEach(d => {
    if d.id == distractionId {
      d.guardsResponding = Math.Int.max(0, d.guardsResponding - 1)
    }
  })
}

//  Difficulty Scaling 

// On higher difficulties, distractions are less effective
let applyDifficultyScaling = (pbx: pbxState, ~difficulty: int): unit => {
  // difficulty: 0=Tutorial, 1=Easy, 2=Normal, 3=Hard, 4=Expert
  // Reduce uses on harder difficulties
  if difficulty >= 3 {
    Dict.set(pbx.usesRemaining, "pizza", 1)
    Dict.set(pbx.usesRemaining, "prank", 1)
  }
  if difficulty >= 4 {
    Dict.set(pbx.usesRemaining, "maintenance", 0)
    Dict.set(pbx.usesRemaining, "police", 0)
  }
}

//  Terminal Output Formatting 

let formatCallSuccess = (d: activeDistraction): string => {
  let kind = d.spec.label
  let duration = Int.toString(Float.toInt(d.spec.durationSec))
  let target = Int.toString(Float.toInt(d.spec.targetX))
  `[PBX] Calling ${kind}...
  
    CALL PLACED SUCCESSFULLY       
    Type: ${kind}
    Duration: ${duration}s
    Target area: sector ${target}
  
Guards within range will investigate.`
}

let formatStatus = (pbx: pbxState): string => {
  let hacked = if pbx.hacked {
    "COMPROMISED"
  } else {
    "LOCKED"
  }
  let cooldown = if pbx.cooldownSec > 0.0 {
    `\nCooldown: ${Int.toString(Float.toInt(pbx.cooldownSec))}s`
  } else {
    "\nCooldown: READY"
  }
  let active = Array.length(pbx.activeDistractions->Array.filter(d => !d.expired))
  let uses =
    [
      ("pizza", "Pizza Delivery"),
      ("maintenance", "Fake Maintenance"),
      ("fire", "Fire Alarm"),
      ("prank", "Prank Call"),
      ("police", "Fake Police"),
    ]
    ->Array.map(((key, label)) => {
      let remaining = Dict.get(pbx.usesRemaining, key)->Option.getOr(0)
      `  ${label}: ${Int.toString(remaining)} remaining`
    })
    ->Array.join("\n")

  `PBX System Status: ${hacked}
IP: ${pbx.ipAddress}${cooldown}
Active distractions: ${Int.toString(active)}
Total calls made: ${Int.toString(pbx.totalCalls)}

Available calls:
${uses}`
}

let formatHelp = (): string => {
  `PBX  social engineering distraction system
  pbx status            Show PBX status and available calls
  pbx call pizza        Order pizza delivery to entrance (lures 1-2 guards)
  pbx call maintenance  Fake maintenance visit to loading dock (lures 3 guards)
  pbx call fire         Trigger fire alarm (pulls ALL guards to exits, +alert)
  pbx call prank        Prank call to guard station (confuses 2 guards)
  pbx call police       Fake police call (empties lobby, very suspicious)
  pbx help              Show this help

NOTE: Must hack the PBX device first. 60s cooldown between calls.
      Each call type has limited uses per mission.`
}
