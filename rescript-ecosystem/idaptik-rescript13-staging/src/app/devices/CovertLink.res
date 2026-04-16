// SPDX-License-Identifier: PMPL-1.0-or-later
// CovertLink.res  Hidden high-speed network pathways (ADR-0014)
//
// Covert links are discoverable, activatable links between devices
// that bypass normal network routing. They serve as:
//   1. Network shortcut (skip hops, reduce latency)
//   2. Stealth channel (bypass IDS/firewall monitoring)
//   3. Power-up / collectible (exploration reward)
//   4. Strategic objective (level design tool)

// Connection substrate type  affects bandwidth, stealth, durability
type connectionType =
  | DarkFibre // Best: high bandwidth, low latency, very stealthy, durable
  | LegacyTrunk // Good: decent bandwidth, may be flaky, admin might notice
  | OOBManagement // Low bandwidth but very stealthy (iLO/IPMI/BMC)
  | WirelessBridge // High bandwidth, detectable by RF scan, weather-affected
  | CrossConnect // Colo facility link, requires physical access to both ends
  | MaintenanceVLAN // Firmware-level, can't be physically cut, vendor may monitor
  | ImprovisedLink // Player's own cable from inventory  slow, fragile

// Discovery method  how the player finds this connection
type discoveryMethod =
  | CableTrace // Follow a cable in the platformer world
  | ConfigFile // Find trunk port reference in router config
  | PortScan // Notice an unexpected open port
  | TrafficAnomaly // Monitor switch counters, see traffic on "down" interface
  | NPCTip // Janitor/sysadmin reveals hidden infrastructure
  | PhysicalAccess // Open a patch panel, find unlabelled cable
  | SignalAnalysis // OTDR to find fibre splice point

// Lifecycle state
type connectionState =
  | Unknown // Not yet discovered  invisible on map
  | Discovered // Found but not activated  shows on overlay
  | Active // Working  usable for transfers and VM I/O
  | Dead // Cut by guard, expired TTL, or broken  cannot reuse

// Connection stats (derived from type, can be overridden per-instance)
type connectionStats = {
  bandwidth: int, // 1-5 scale
  latency: int, // 1-5 scale (5 = fastest)
  stealth: int, // 1-5 scale (5 = most hidden)
  durability: int, // 1-5 scale (5 = hardest to break)
}

// A single covert link instance
type t = {
  id: string,
  connectionType: connectionType,
  endpointA: string, // IP address of device A
  endpointB: string, // IP address of device B
  mutable state: connectionState,
  discoveryMethod: discoveryMethod,
  discoveryHint: string, // Flavour text shown on discovery
  activationItems: array<string>, // Inventory items needed (e.g., "sfp_transceiver")
  stats: connectionStats,
  ttl: option<float>, // Time-to-live in seconds (None = permanent)
  mutable timeRemaining: option<float>,
  coopRequired: bool, // Needs both players to activate?
  requiredForCompletion: bool, // Must use to complete level?
  guardPatrolNearby: bool, // Guard patrols near an endpoint?
}

// Get default stats for a connection type
let defaultStats = (ct: connectionType): connectionStats => {
  switch ct {
  | DarkFibre => {bandwidth: 5, latency: 5, stealth: 5, durability: 5}
  | LegacyTrunk => {bandwidth: 4, latency: 4, stealth: 3, durability: 2}
  | OOBManagement => {bandwidth: 2, latency: 3, stealth: 4, durability: 4}
  | WirelessBridge => {bandwidth: 3, latency: 2, stealth: 1, durability: 3}
  | CrossConnect => {bandwidth: 4, latency: 4, stealth: 3, durability: 3}
  | MaintenanceVLAN => {bandwidth: 3, latency: 3, stealth: 2, durability: 5}
  | ImprovisedLink => {bandwidth: 1, latency: 1, stealth: 3, durability: 1}
  }
}

// Connection type display names
let connectionTypeName = (ct: connectionType): string => {
  switch ct {
  | DarkFibre => "Dark Fibre"
  | LegacyTrunk => "Legacy Trunk"
  | OOBManagement => "OOB Management"
  | WirelessBridge => "Wireless Bridge"
  | CrossConnect => "Cross-Connect"
  | MaintenanceVLAN => "Maintenance VLAN"
  | ImprovisedLink => "Improvised Link"
  }
}

// Discovery method display
let discoveryMethodName = (dm: discoveryMethod): string => {
  switch dm {
  | CableTrace => "Cable Trace"
  | ConfigFile => "Config File"
  | PortScan => "Port Scan"
  | TrafficAnomaly => "Traffic Anomaly"
  | NPCTip => "NPC Tip"
  | PhysicalAccess => "Physical Access"
  | SignalAnalysis => "Signal Analysis"
  }
}

// State display
let stateToString = (s: connectionState): string => {
  switch s {
  | Unknown => "UNKNOWN"
  | Discovered => "DISCOVERED"
  | Active => "ACTIVE"
  | Dead => "DEAD"
  }
}

let stateToColor = (s: connectionState): int => {
  switch s {
  | Unknown => 0x444444 // Dark gray
  | Discovered => 0xFFAA00 // Amber
  | Active => 0x00FF88 // Bright green
  | Dead => 0xFF2222 // Red
  }
}

// Create a new covert link
let make = (
  ~id: string,
  ~connectionType: connectionType,
  ~endpointA: string,
  ~endpointB: string,
  ~discoveryMethod: discoveryMethod,
  ~discoveryHint: string,
  ~activationItems: array<string>=[],
  ~stats: option<connectionStats>=?,
  ~ttl: option<float>=?,
  ~coopRequired: bool=false,
  ~requiredForCompletion: bool=false,
  ~guardPatrolNearby: bool=false,
  (),
): t => {
  id,
  connectionType,
  endpointA,
  endpointB,
  state: Unknown,
  discoveryMethod,
  discoveryHint,
  activationItems,
  stats: switch stats {
  | Some(s) => s
  | None => defaultStats(connectionType)
  },
  ttl,
  timeRemaining: ttl,
  coopRequired,
  requiredForCompletion,
  guardPatrolNearby,
}

// Discover a connection (Unknown  Discovered)
let discover = (conn: t): bool => {
  switch conn.state {
  | Unknown => {
      conn.state = Discovered
      true
    }
  | _ => false
  }
}

// Activate a connection (Discovered  Active)
let activate = (conn: t): bool => {
  switch conn.state {
  | Discovered => {
      conn.state = Active
      conn.timeRemaining = conn.ttl
      true
    }
  | _ => false
  }
}

// Kill a connection (any state  Dead)
let cut = (conn: t): unit => {
  conn.state = Dead
}

// Check if connection links two specific IPs
let connects = (conn: t, ipA: string, ipB: string): bool => {
  (conn.endpointA == ipA && conn.endpointB == ipB) ||
    (conn.endpointA == ipB && conn.endpointB == ipA)
}

// Check if an IP is an endpoint of this connection
let hasEndpoint = (conn: t, ip: string): bool => {
  conn.endpointA == ip || conn.endpointB == ip
}

// Get the other endpoint given one IP
let otherEndpoint = (conn: t, ip: string): option<string> => {
  if conn.endpointA == ip {
    Some(conn.endpointB)
  } else if conn.endpointB == ip {
    Some(conn.endpointA)
  } else {
    None
  }
}

// Update TTL (call each frame with delta time)
let update = (conn: t, deltaSeconds: float): unit => {
  switch (conn.state, conn.timeRemaining) {
  | (Active, Some(remaining)) => {
      let newRemaining = remaining -. deltaSeconds
      if newRemaining <= 0.0 {
        conn.state = Dead
        conn.timeRemaining = Some(0.0)
      } else {
        conn.timeRemaining = Some(newRemaining)
      }
    }
  | _ => ()
  }
}

// Get effective latency for a transfer through this connection (in ticks)
// Normal routing: 1 tick per hop. Covert link: always 1 tick.
let getLatencyTicks = (_conn: t): int => 1

// Check if traffic through this connection is visible to IDS/firewall
let isMonitored = (conn: t): bool => {
  switch conn.connectionType {
  | DarkFibre | OOBManagement => false
  | LegacyTrunk | CrossConnect | ImprovisedLink => false
  | WirelessBridge => true // RF detectable
  | MaintenanceVLAN => true // Vendor may have telemetry
  }
}

// VM port name for this connection (used with SEND/RECV)
let portName = (conn: t): string => {
  `covert:${conn.id}`
}

// Format connection info for terminal display
let formatInfo = (conn: t): string => {
  let typeName = connectionTypeName(conn.connectionType)
  let stateName = stateToString(conn.state)
  let ttlStr = switch conn.timeRemaining {
  | Some(remaining) => ` TTL: ${Int.toString(Float.toInt(remaining))}s`
  | None => " TTL: permanent"
  }
  let monitoredStr = if isMonitored(conn) {
    " [MONITORED]"
  } else {
    " [STEALTH]"
  }
  let coopStr = if conn.coopRequired {
    " [CO-OP]"
  } else {
    ""
  }

  `COVERT LINK: ${conn.id}\n` ++
  `  Type:      ${typeName}\n` ++
  `  State:     ${stateName}\n` ++
  `  Endpoints: ${conn.endpointA} <===> ${conn.endpointB}\n` ++
  `  Stats:     BW:${Int.toString(conn.stats.bandwidth)} LAT:${Int.toString(
      conn.stats.latency,
    )} STL:${Int.toString(conn.stats.stealth)} DUR:${Int.toString(conn.stats.durability)}\n` ++
  `  Port:      ${portName(conn)}${ttlStr}${monitoredStr}${coopStr}`
}

// Format a short one-line summary for the overlay map
let formatShort = (conn: t): string => {
  let typeName = connectionTypeName(conn.connectionType)
  let stateName = stateToString(conn.state)
  `${conn.id}: ${typeName} [${stateName}] ${conn.endpointA}${conn.endpointB}`
}

// ================================================================
// Registry  global state tracking all covert links in a level
// ================================================================

module Registry = {
  // All connections in the current level
  let connections: dict<t> = Dict.make()

  // Register a connection
  let add = (conn: t): unit => {
    Dict.set(connections, conn.id, conn)
  }

  // Get a connection by ID
  let get = (id: string): option<t> => {
    Dict.get(connections, id)
  }

  // Get all connections
  let getAll = (): array<t> => {
    Dict.valuesToArray(connections)
  }

  // Get connections by state
  let getByState = (state: connectionState): array<t> => {
    Dict.valuesToArray(connections)->Array.filter(c => c.state == state)
  }

  // Get active connections for a specific IP
  let getActiveForIp = (ip: string): array<t> => {
    Dict.valuesToArray(connections)->Array.filter(c => c.state == Active && hasEndpoint(c, ip))
  }

  // Get all discovered-or-active connections (for overlay map)
  let getVisible = (): array<t> => {
    Dict.valuesToArray(connections)->Array.filter(c => c.state == Discovered || c.state == Active)
  }

  // Find an active covert route between two IPs
  let findRoute = (sourceIp: string, destIp: string): option<t> => {
    Array.find(Dict.valuesToArray(connections), c =>
      c.state == Active && connects(c, sourceIp, destIp)
    )
  }

  // Check if a covert route exists (for NetworkZones integration)
  let hasCovertRoute = (sourceIp: string, destIp: string): bool => {
    Option.isSome(findRoute(sourceIp, destIp))
  }

  // Update all connections (call each frame)
  let updateAll = (deltaSeconds: float): unit => {
    Dict.valuesToArray(connections)->Array.forEach(conn => {
      update(conn, deltaSeconds)
    })
  }

  // Reset all connections (new level)
  let clear = (): unit => {
    Dict.keysToArray(connections)->Array.forEach(key => {
      Dict.delete(connections, key)
    })
  }

  // Count connections by state
  let countByState = (state: connectionState): int => {
    getByState(state)->Array.length
  }

  // Format all visible connections for terminal display
  let formatOverlay = (): string => {
    let visible = getVisible()
    if Array.length(visible) == 0 {
      "No covert links discovered yet."
    } else {
      let header = `COVERT LINK NETWORK OVERLAY (${Int.toString(
          Array.length(visible),
        )} connections)\n`
      let lines = visible->Array.map(formatShort)->Array.join("\n")
      header ++ lines
    }
  }
}

// ================================================================
// Level presets  standard covert links for the default level
// ================================================================

let initializeDefaultLevel = (): unit => {
  Registry.clear()

  // Dark fibre: Laptop (192.168.1.10) directly to Database Server (10.0.1.50)
  // Bypasses both firewalls entirely
  Registry.add(
    make(
      ~id="darkfibre_01",
      ~connectionType=DarkFibre,
      ~endpointA="192.168.1.10",
      ~endpointB="10.0.1.50",
      ~discoveryMethod=CableTrace,
      ~discoveryHint="An unmarked orange cable runs behind server rack 3, disappearing into the floor void",
      ~activationItems=["sfp_transceiver", "sfp_transceiver"],
      ~coopRequired=true,
      (),
    ),
  )

  // OOB management: Router (192.168.1.1) to Security Server (10.0.3.10)
  // Low bandwidth but completely invisible to IDS
  Registry.add(
    make(
      ~id="oob_mgmt_01",
      ~connectionType=OOBManagement,
      ~endpointA="192.168.1.1",
      ~endpointB="10.0.3.10",
      ~discoveryMethod=ConfigFile,
      ~discoveryHint="Router config mentions an iLO port on the security server: 10.0.3.10:623",
      (),
    ),
  )

  // Legacy trunk: Downtown LAN switch to DMZ switch
  // Decent bandwidth but flaky and admin might remember it
  Registry.add(
    make(
      ~id="legacy_trunk_01",
      ~connectionType=LegacyTrunk,
      ~endpointA="192.168.1.1",
      ~endpointB="10.0.0.1",
      ~discoveryMethod=TrafficAnomaly,
      ~discoveryHint="Interface Gi0/24 shows 12 packets/sec on a port marked 'DECOMMISSIONED' in the switch config",
      ~ttl=300.0, // 5 minutes before port sweep catches it
      ~guardPatrolNearby=true,
      (),
    ),
  )

  // Maintenance VLAN: Built into the core switch firmware
  // Reaches the SCADA network (normally air-gapped!)
  Registry.add(
    make(
      ~id="maint_vlan_01",
      ~connectionType=MaintenanceVLAN,
      ~endpointA="172.16.0.5",
      ~endpointB="10.10.1.1",
      ~discoveryMethod=NPCTip,
      ~discoveryHint="The night janitor mentions: 'The vendor tech always plugs into that weird port on the management switch...'",
      ~activationItems=["vendor_magic_packet"],
      ~requiredForCompletion=false,
      (),
    ),
  )

  // Wireless bridge: IoT camera to an external device
  // Detectable but high bandwidth for exfiltration
  Registry.add(
    make(
      ~id="wireless_bridge_01",
      ~connectionType=WirelessBridge,
      ~endpointA="192.168.100.5",
      ~endpointB="192.168.2.10",
      ~discoveryMethod=SignalAnalysis,
      ~discoveryHint="RF scanner detects a 5GHz signal from the parking lot camera aimed at a building across the street",
      ~ttl=600.0, // Weather degrades signal over 10 minutes
      (),
    ),
  )
}
