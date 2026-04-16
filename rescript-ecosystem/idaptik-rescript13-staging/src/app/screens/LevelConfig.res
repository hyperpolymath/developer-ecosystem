// SPDX-License-Identifier: PMPL-1.0-or-later
// LevelConfig  per-location configuration for gameplay
//
// Maps each location to its mission, item placements, guard spawn points,
// per-device defence flags (ADR-0013), and environmental properties.
// Used by GameLoop when starting a mission.
//
// Defence flag escalation across levels (ADR-0013):
//   city      — No defences (tutorial zone, guards patrol only)
//   dmz       — Canary monitoring + one decoy honeypot
//   security  — Canary traps + cascade alerts + undo immunity on LDAP
//   scada     — Instruction whitelist + tamper-proof UPS + time bomb
//   backbone  — Full defence suite: whitelist, undo immunity, kill switch,
//                time bomb, mirror target, failover chains

open Inventory

//  World Item Placement

// Items that can be found in the world (supply rooms, desks, racks)
type worldItem = {
  item: Inventory.item,
  x: float, // World X position
  container: string, // "supply_room" | "desk" | "server_rack" | "toolbox"
  mutable collected: bool,
}

//  Guard Placement

// A guard spawn point configured per-location.
// These replace the difficulty-only guard spawning from GameLoop.spawnGuards
// and allow level designers to position and rank guards explicitly.
type guardPlacement = {
  x: float, // World X spawn position
  zone: string, // Zone the guard patrols (must match a zone in zoneTransitions)
  rank: string, // "Enforcer" | "AntiHacker" | "Sentinel" | "Assassin"
  patrolRadius: float, // Half-width of patrol range around x (pixels)
}

//  Device Defence Configuration (ADR-0013)

// Per-device defence flag assignment for a level.
// Devices not listed in deviceDefences use DeviceType.defaultDefenceFlags
// (all flags false/None).  Only devices relevant to the mission's difficulty
// and puzzle design should have non-default flags.
type deviceDefenceConfig = {
  ipAddress: string, // Target device IP address
  flags: DeviceType.defenceFlags, // Defence flags to apply at level load
}

//  Zone & Level Structure

type zoneTransition = {
  x: float,
  fromZone: string,
  toZone: string,
}

type levelConfig = {
  locationId: string,
  missionId: string,
  worldItems: array<worldItem>,
  // Location-specific guard layout. GameLoop reads these instead of using
  // difficulty-only random spawning so level designers control threat flow.
  guardPlacements: array<guardPlacement>,
  // Per-device defence flags for this level (ADR-0013).
  // Empty array = all devices use defaultDefenceFlags.
  deviceDefences: array<deviceDefenceConfig>,
  // Environmental
  hasPowerSystem: bool, // UPS and power stations present
  hasSecurityCameras: bool,
  numberOfCovertLinks: int, // Hidden connections to discover
  hasPBX: bool, // PBX telephone system present (social engineering)
  pbxIpAddress: string, // PBX device IP (empty if no PBX)
  pbxWorldX: float, // Where the PBX device sits in the world
  // Zone boundaries
  zoneTransitions: array<zoneTransition>,
}

//  Level Database

let getConfig = (locationId: string): option<levelConfig> => {
  switch locationId {

  // ─────────────────────────────────────────────────────────────────────────
  // M01 — Downtown Office (Tutorial / Entry point)
  //   Threat level: Minimal. One patrol guard. No device defences.
  //   Learning objective: basic movement, E-key interaction, first SSH.
  // ─────────────────────────────────────────────────────────────────────────
  | "downtown" | "city" =>
    Some({
      locationId: "city",
      missionId: "m01_downtown",
      worldItems: [
        {
          item: {
            id: "w_eth1",
            kind: Cable(Ethernet),
            name: "Cat5e Cable (3m)",
            weight: 0.2,
            condition: Inventory.Good,
            usesRemaining: None,
            cableLength: Some(3.0),
            description: "Found in supply closet",
          },
          x: 450.0,
          container: "supply_room",
          collected: false,
        },
        {
          item: {
            id: "w_usb1",
            kind: Storage(USBDrive(2048)),
            name: "2GB USB Drive",
            weight: 0.02,
            condition: Inventory.Good,
            usesRemaining: None,
            cableLength: None,
            description: "Left on a desk",
          },
          x: 850.0,
          container: "desk",
          collected: false,
        },
      ],
      // One relaxed Enforcer guard who patrols the ground floor.
      // Introduced here so the player learns guard-avoidance basics.
      guardPlacements: [
        {
          x: 600.0,
          zone: "downtown_lan",
          rank: "Enforcer",
          patrolRadius: 300.0,
        },
      ],
      // No device defences in the tutorial zone — everything is openable.
      deviceDefences: [],
      hasPowerSystem: false,
      hasSecurityCameras: false,
      numberOfCovertLinks: 0,
      hasPBX: false,
      pbxIpAddress: "",
      pbxWorldX: 0.0,
      zoneTransitions: [{x: 0.0, fromZone: "outside", toZone: "downtown_lan"}],
    })

  // ─────────────────────────────────────────────────────────────────────────
  // M02 — DMZ (Easy)
  //   Threat level: Low. Two guards. Canary on mail server, decoy VPN trap.
  //   Learning objective: port scanning, discovering honeypots, covert link.
  // ─────────────────────────────────────────────────────────────────────────
  | "dmz" =>
    Some({
      locationId: "dmz",
      missionId: "m02_dmz",
      worldItems: [
        {
          item: {
            id: "w_eth2",
            kind: Cable(Ethernet),
            name: "Cat6 Cable (1m)",
            weight: 0.1,
            condition: Inventory.Good,
            usesRemaining: None,
            cableLength: Some(1.0),
            description: "Short patch cable from rack",
          },
          x: 300.0,
          container: "server_rack",
          collected: false,
        },
        {
          item: {
            id: "w_serial1",
            kind: Cable(Serial),
            name: "Console Cable",
            weight: 0.1,
            condition: Inventory.Good,
            usesRemaining: None,
            cableLength: Some(1.5),
            description: "Console management cable",
          },
          x: 700.0,
          container: "server_rack",
          collected: false,
        },
        {
          item: {
            id: "w_sfp1",
            kind: Module(SFP1G),
            name: "1G SFP Module",
            weight: 0.03,
            condition: Inventory.Pristine,
            usesRemaining: None,
            cableLength: None,
            description: "Spare SFP from parts drawer",
          },
          x: 1100.0,
          container: "supply_room",
          collected: false,
        },
      ],
      // An Enforcer patrols the perimeter; an AntiHacker covers the server room.
      // The AntiHacker will attempt to reverse VM changes if they detect hacking.
      guardPlacements: [
        {
          x: 400.0,
          zone: "dmz",
          rank: "Enforcer",
          patrolRadius: 350.0,
        },
        {
          x: 900.0,
          zone: "internal",
          rank: "AntiHacker",
          patrolRadius: 200.0,
        },
      ],
      // Mail server has a canary: it silently reports any port scan to the SIEM.
      // The VPN server is a decoy honeypot: connecting to it raises alert level.
      deviceDefences: [
        {
          ipAddress: "10.0.0.20", // MAIL-SERVER
          flags: {
            ...DeviceType.defaultDefenceFlags,
            canary: true, // Detects scans, reports to SecurityAI without player seeing
          },
        },
        {
          ipAddress: "10.0.0.30", // VPN-SERVER (honeypot)
          flags: {
            ...DeviceType.defaultDefenceFlags,
            decoy: true, // Looks normal; triggers alert on scan/crack/ssh
          },
        },
      ],
      hasPowerSystem: false,
      hasSecurityCameras: true,
      numberOfCovertLinks: 1,
      hasPBX: false,
      pbxIpAddress: "",
      pbxWorldX: 0.0,
      zoneTransitions: [
        {x: 0.0, fromZone: "outside", toZone: "dmz"},
        {x: 900.0, fromZone: "dmz", toZone: "internal"},
      ],
    })

  // ─────────────────────────────────────────────────────────────────────────
  // M03 — Security Office (Normal)
  //   Threat level: Medium. Three guards including a Sentinel.
  //   Learning objective: cascade traps, undo immunity, timing attacks.
  // ─────────────────────────────────────────────────────────────────────────
  | "security" =>
    Some({
      locationId: "security",
      missionId: "m03_security",
      worldItems: [
        {
          item: {
            id: "w_fibre1",
            kind: Cable(FibreLC),
            name: "LC Fibre Patch (2m)",
            weight: 0.05,
            condition: Inventory.Good,
            usesRemaining: None,
            cableLength: Some(2.0),
            description: "Single-mode fibre patch",
          },
          x: 600.0,
          container: "server_rack",
          collected: false,
        },
        {
          item: {
            id: "w_crimper",
            kind: Tool(Crimper),
            name: "RJ45 Crimper",
            weight: 0.3,
            condition: Inventory.Good,
            usesRemaining: Some(10),
            cableLength: None,
            description: "Make your own Ethernet cables",
          },
          x: 1400.0,
          container: "toolbox",
          collected: false,
        },
        {
          item: {
            id: "w_keycard1",
            kind: Keycard("SECURITY"),
            name: "Security Keycard",
            weight: 0.01,
            condition: Inventory.Pristine,
            usesRemaining: None,
            cableLength: None,
            description: "Access to security zone doors",
          },
          x: 1000.0,
          container: "desk",
          collected: false,
        },
      ],
      // Three guards: an Enforcer at the entrance, AntiHacker near the servers,
      // and a Sentinel who watches the inner security zone and never panics.
      guardPlacements: [
        {
          x: 200.0,
          zone: "security",
          rank: "Enforcer",
          patrolRadius: 250.0,
        },
        {
          x: 800.0,
          zone: "security",
          rank: "AntiHacker",
          patrolRadius: 180.0,
        },
        {
          x: 1400.0,
          zone: "security_inner",
          rank: "Sentinel",
          patrolRadius: 120.0,
        },
      ],
      // DB-SERVER: canary (detects scans silently) + cascades alert to SIEM.
      // LDAP-SERVER: last 5 VM instructions are undo-immune — committing to LDAP
      //   means the player must plan their approach carefully before executing.
      // SIEM-SERVER: tamperProof (cannot power off the monitoring system).
      deviceDefences: [
        {
          ipAddress: "10.0.1.51", // DB-SERVER-01
          flags: {
            ...DeviceType.defaultDefenceFlags,
            canary: true, // Silent scan monitor
            cascadeTrap: Some("10.0.3.20"), // Alert SIEM-SERVER on access
          },
        },
        {
          ipAddress: "10.0.1.10", // LDAP-SERVER
          flags: {
            ...DeviceType.defaultDefenceFlags,
            undoImmunity: Some(5), // Last 5 VM ops locked in — no backing out
          },
        },
        {
          ipAddress: "10.0.3.20", // SIEM-SERVER
          flags: {
            ...DeviceType.defaultDefenceFlags,
            tamperProof: true, // SecurityAI's eyes — cannot be powered off
          },
        },
      ],
      hasPowerSystem: true,
      hasSecurityCameras: true,
      numberOfCovertLinks: 2,
      hasPBX: true,
      pbxIpAddress: "10.0.1.50",
      pbxWorldX: 1200.0,
      zoneTransitions: [
        {x: 0.0, fromZone: "internal", toZone: "security"},
        {x: 1500.0, fromZone: "security", toZone: "security_inner"},
      ],
    })

  // ─────────────────────────────────────────────────────────────────────────
  // M04 — SCADA Control (Hard)
  //   Threat level: High. Four guards including an Assassin at the core.
  //   Learning objective: instruction whitelists, time bombs, failover chains.
  // ─────────────────────────────────────────────────────────────────────────
  | "scada" =>
    Some({
      locationId: "scada",
      missionId: "m04_scada",
      worldItems: [
        {
          item: {
            id: "w_fibre2",
            kind: Cable(FibreSC),
            name: "SC Fibre Patch (5m)",
            weight: 0.08,
            condition: Inventory.Good,
            usesRemaining: None,
            cableLength: Some(5.0),
            description: "Long fibre run for SCADA link",
          },
          x: 500.0,
          container: "supply_room",
          collected: false,
        },
        {
          item: {
            id: "w_otdr",
            kind: Tool(OTDR),
            name: "OTDR Unit",
            weight: 0.8,
            condition: Inventory.Good,
            usesRemaining: Some(5),
            cableLength: None,
            description: "Diagnose fibre faults",
          },
          x: 1200.0,
          container: "toolbox",
          collected: false,
        },
        {
          item: {
            id: "w_splicer",
            kind: Tool(FibreSplicer),
            name: "Fibre Splicer",
            weight: 0.5,
            condition: Inventory.Good,
            usesRemaining: Some(8),
            cableLength: None,
            description: "Join fibre strands",
          },
          x: 1800.0,
          container: "toolbox",
          collected: false,
        },
        {
          item: {
            id: "w_radio",
            kind: Radio,
            name: "Guard Radio",
            weight: 0.15,
            condition: Inventory.Worn,
            usesRemaining: None,
            cableLength: None,
            description: "Stolen radio — listen to guard comms",
          },
          x: 2200.0,
          container: "desk",
          collected: false,
        },
      ],
      // Four guards: perimeter Enforcer, inner AntiHacker, power-room Sentinel,
      // and a covert Assassin at the SCADA core (immune to charge knockdown).
      guardPlacements: [
        {
          x: 300.0,
          zone: "scada_perimeter",
          rank: "Enforcer",
          patrolRadius: 400.0,
        },
        {
          x: 900.0,
          zone: "scada_perimeter",
          rank: "AntiHacker",
          patrolRadius: 200.0,
        },
        {
          x: 1400.0,
          zone: "scada_core",
          rank: "Sentinel",
          patrolRadius: 150.0,
        },
        {
          x: 2000.0,
          zone: "scada_core",
          rank: "Assassin",
          patrolRadius: 100.0,
        },
      ],
      // SCADA controller only allows safe industrial instructions — no arbitrary
      //   register manipulation that could trigger physical process failures.
      // UPS-CRITICAL is tamper-proof and fails over to the main power station
      //   (cutting power to SCADA arms the emergency lockdown sequence).
      // Main power station: VM instructions are mirrored to the SCADA controller
      //   so the security team sees everything the hacker does there.
      // SCADA controller also has a 120-tick time bomb: if the player does not
      //   deactivate it within 120 game ticks, all VM changes auto-undo.
      deviceDefences: [
        {
          ipAddress: "10.10.1.100", // SCADA-CONTROLLER
          flags: {
            ...DeviceType.defaultDefenceFlags,
            instructionWhitelist: Some(["ADD", "SUB", "LOAD", "STORE"]), // Industrial ops only
            timeBomb: Some(120), // 120 ticks until auto-undo if not deactivated
          },
        },
        {
          ipAddress: "192.168.1.251", // UPS-CRITICAL
          flags: {
            ...DeviceType.defaultDefenceFlags,
            tamperProof: true, // Cannot power off UPS
            failoverTarget: Some("10.10.1.200"), // Backup: MAIN-PWR-STATION
          },
        },
        {
          ipAddress: "10.10.1.200", // MAIN-PWR-STATION
          flags: {
            ...DeviceType.defaultDefenceFlags,
            mirrorTarget: Some("10.10.1.100"), // All VM ops mirrored to SCADA-CONTROLLER
          },
        },
      ],
      hasPowerSystem: true,
      hasSecurityCameras: true,
      numberOfCovertLinks: 3,
      hasPBX: true,
      pbxIpAddress: "10.0.2.50",
      pbxWorldX: 1600.0,
      zoneTransitions: [
        {x: 0.0, fromZone: "internal", toZone: "scada_perimeter"},
        {x: 800.0, fromZone: "scada_perimeter", toZone: "scada_core"},
      ],
    })

  // ─────────────────────────────────────────────────────────────────────────
  // M05 — Tier 1 Internet Backbone (Expert)
  //   Threat level: Maximum. Five guards. Full defence suite on core routers.
  //   Learning objective: all ADR-0013 mechanics active simultaneously.
  //   The player must plan each instruction carefully before committing.
  // ─────────────────────────────────────────────────────────────────────────
  | "backbone" =>
    Some({
      locationId: "backbone",
      missionId: "m05_backbone",
      worldItems: [
        {
          item: {
            id: "w_fibre3",
            kind: Cable(FibreLC),
            name: "LC Fibre (10m)",
            weight: 0.12,
            condition: Inventory.Pristine,
            usesRemaining: None,
            cableLength: Some(10.0),
            description: "Long-haul fibre patch",
          },
          x: 800.0,
          container: "server_rack",
          collected: false,
        },
        {
          item: {
            id: "w_sfp10g",
            kind: Module(SFP10G),
            name: "10G SFP+ Module",
            weight: 0.04,
            condition: Inventory.Pristine,
            usesRemaining: None,
            cableLength: None,
            description: "High-speed transceiver",
          },
          x: 1500.0,
          container: "server_rack",
          collected: false,
        },
        {
          item: {
            id: "w_multi",
            kind: Tool(Multimeter),
            name: "Multimeter",
            weight: 0.2,
            condition: Inventory.Good,
            usesRemaining: None,
            cableLength: None,
            description: "Test electrical connections",
          },
          x: 2100.0,
          container: "toolbox",
          collected: false,
        },
        {
          item: {
            id: "w_usb2",
            kind: Storage(USBDrive(16384)),
            name: "16GB USB Drive",
            weight: 0.02,
            condition: Inventory.Pristine,
            usesRemaining: None,
            cableLength: None,
            description: "Large storage for evidence",
          },
          x: 2500.0,
          container: "desk",
          collected: false,
        },
      ],
      // Five guards: two Enforcers at edges, two AntiHackers, one elite Assassin
      // who never panics and can chase the player across zone boundaries.
      guardPlacements: [
        {
          x: 200.0,
          zone: "backbone_edge",
          rank: "Enforcer",
          patrolRadius: 300.0,
        },
        {
          x: 700.0,
          zone: "backbone_edge",
          rank: "AntiHacker",
          patrolRadius: 200.0,
        },
        {
          x: 1300.0,
          zone: "backbone_core",
          rank: "Enforcer",
          patrolRadius: 300.0,
        },
        {
          x: 1800.0,
          zone: "backbone_core",
          rank: "AntiHacker",
          patrolRadius: 200.0,
        },
        {
          x: 2300.0,
          zone: "backbone_deep",
          rank: "Assassin",
          patrolRadius: 400.0, // Elite: wide patrol coverage
        },
      ],
      // NA-BACKBONE: whitelist (only routing ops allowed) + 60-tick time bomb
      //   + undo immunity on last 8 instructions + kills entire backbone subnet.
      // EU-BACKBONE: mirror of NA-BACKBONE — every op the hacker executes is
      //   replicated, revealing the attack pattern to the security team.
      // ATLAS-ROUTER (external): canary + cascade trap to SIEM.
      deviceDefences: [
        {
          ipAddress: "10.100.0.1", // NA-BACKBONE router
          flags: {
            tamperProof: false,
            decoy: false,
            canary: true, // Monitor all scans
            oneWayMirror: false,
            killSwitch: true, // Admin can take this subnet offline
            failoverTarget: Some("10.100.1.1"), // EU-BACKBONE failover
            cascadeTrap: Some("172.16.0.1"), // Alert ADMIN-PANEL
            instructionWhitelist: Some(["ADD", "SUB", "LOAD", "STORE", "SWAP"]),
            timeBomb: Some(60), // 60 ticks — very short, forces fast play
            mirrorTarget: None,
            undoImmunity: Some(8), // Deep commitment required
          },
        },
        {
          ipAddress: "10.100.1.1", // EU-BACKBONE router
          flags: {
            ...DeviceType.defaultDefenceFlags,
            mirrorTarget: Some("10.100.0.1"), // All ops mirrored back to NA-BACKBONE
            undoImmunity: Some(5),
          },
        },
        {
          ipAddress: "10.200.0.1", // ATLAS-ROUTER (external peering)
          flags: {
            ...DeviceType.defaultDefenceFlags,
            canary: true,
            cascadeTrap: Some("172.16.0.1"), // Any access triggers ADMIN-PANEL alert
          },
        },
      ],
      hasPowerSystem: true,
      hasSecurityCameras: true,
      numberOfCovertLinks: 7,
      hasPBX: true,
      pbxIpAddress: "10.0.3.50",
      pbxWorldX: 1000.0,
      zoneTransitions: [
        {x: 0.0, fromZone: "tier2_isp", toZone: "backbone_edge"},
        {x: 800.0, fromZone: "backbone_edge", toZone: "backbone_core"},
        {x: 2000.0, fromZone: "backbone_core", toZone: "backbone_deep"},
      ],
    })

  | _ => None
  }
}

// Get guard count for a level by location ID (used by GameLoop as fallback).
// When guardPlacements is non-empty the count comes from Array.length(config.guardPlacements).
// This function is kept for backward compatibility with callers that only need the count.
let getGuardCountForDifficulty = (difficulty: MissionBriefing.difficulty): int => {
  switch difficulty {
  | MissionBriefing.Tutorial => 1
  | MissionBriefing.Easy => 3
  | MissionBriefing.Normal => 5
  | MissionBriefing.Hard => 8
  | MissionBriefing.Expert => 13
  }
}

// Look up the defence flags for a specific device IP in a given level config.
// Returns DeviceType.defaultDefenceFlags if the device has no custom flags.
let getDeviceDefenceFlags = (config: levelConfig, ipAddress: string): DeviceType.defenceFlags => {
  let found = config.deviceDefences-> Array.find(dc => dc.ipAddress == ipAddress)
  switch found {
  | Some(dc) => dc.flags
  | None => DeviceType.defaultDefenceFlags
  }
}
