// SPDX-License-Identifier: PMPL-1.0-or-later
// Mission Briefing  objectives per location with briefing text
//
// Each location in the game has a mission with objectives, briefing text,
// and completion tracking. Displayed in the IntroScreen before each level
// and tracked via the HUD objective display.

//  Objective Types 

type objectiveState = Pending | InProgress | Completed | Failed

type objective = {
  id: string,
  description: string,
  mutable state: objectiveState,
  optional: bool, // Optional objectives for bonus grade
  hidden: bool, // Revealed only when conditions met
  mutable revealedText: option<string>, // Replaces description when revealed
}

//  Mission 

type difficulty = Tutorial | Easy | Normal | Hard | Expert

type mission = {
  id: string,
  locationId: string,
  title: string,
  briefingText: string, // Shown before mission starts
  debriefText: string, // Shown on completion
  difficulty: difficulty,
  objectives: array<objective>,
  parTimeSec: float, // Target time for grade calculation
  maxAlertForS: int, // Max alert level for S grade
}

//  Mission Database 

let missions: array<mission> = [
  // Tutorial  Downtown LAN
  {
    id: "m01_downtown",
    locationId: "city",
    title: "First Contact",
    briefingText: "Welcome to Nexus Corp, Jessica. Your client suspects their downtown office network has vulnerabilities. Standard penetration test  assess the LAN, document what you find, and get out clean.\n\nThis is a tutorial mission. Take your time, learn the systems.",
    debriefText: "Good work. The downtown LAN is wide open  you've documented the basics. But the real work starts deeper in the network.",
    difficulty: Tutorial,
    objectives: [
      {
        id: "scan_router",
        description: "Scan the downtown router",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "access_laptop",
        description: "Access a workstation via SSH",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "read_passwords",
        description: "Find the passwords file",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "exit_clean",
        description: "Disconnect without raising alert",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "find_note",
        description: "Find the admin's personal note",
        state: Pending,
        optional: true,
        hidden: false,
        revealedText: None,
      },
    ],
    parTimeSec: 300.0,
    maxAlertForS: 0,
  },
  // Easy  DMZ
  {
    id: "m02_dmz",
    locationId: "dmz",
    title: "Behind the Firewall",
    briefingText: "The DMZ hosts their public-facing services  web servers, mail, VPN. Your client wants to know if an external attacker could pivot from the DMZ into the internal network.\n\nWatch the firewall rules. There's a path through, but it's narrow.",
    debriefText: "You found the LDAP pivot  that's a critical finding. The DMZ-to-internal boundary is weaker than it looks.",
    difficulty: Easy,
    objectives: [
      {
        id: "map_dmz",
        description: "Map all DMZ services",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "bypass_firewall",
        description: "Find a path through the firewall",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "access_internal",
        description: "Reach an internal network device",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "exfil_data",
        description: "Exfiltrate the target document",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "no_alerts",
        description: "Complete without triggering CAUTION",
        state: Pending,
        optional: true,
        hidden: false,
        revealedText: None,
      },
    ],
    parTimeSec: 480.0,
    maxAlertForS: 1,
  },
  // Normal  Security Zone
  {
    id: "m03_security",
    locationId: "security",
    title: "The Watchers",
    briefingText: "The security zone runs their CCTV, access control, and guard dispatch systems. Nexus Corp's CISO is paranoid  the network here is monitored 24/7 by SENTRY, their automated security daemon.\n\nSENTRY will undo your changes if it detects them. Work fast, or find a way to suppress it.",
    debriefText: "You went head-to-head with SENTRY and survived. The security zone's own monitoring was turned against it.",
    difficulty: Normal,
    objectives: [
      {
        id: "disable_cameras",
        description: "Disable at least 2 security cameras",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "access_guard_routes",
        description: "Extract guard patrol schedules",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "plant_backdoor",
        description: "Plant a persistent backdoor on the security server",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "survive_sentry",
        description: "Complete objectives before SENTRY reverts your changes",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "find_covert_link",
        description: "Discover a hidden covert link",
        state: Pending,
        optional: true,
        hidden: true,
        revealedText: Some("Use the legacy trunk to bypass SENTRY monitoring"),
      },
    ],
    parTimeSec: 600.0,
    maxAlertForS: 2,
  },
  // Hard  SCADA Zone
  {
    id: "m04_scada",
    locationId: "scada",
    title: "Air Gap",
    briefingText: "The SCADA network controls building infrastructure  HVAC, power, elevators. It's supposed to be air-gapped from the corporate network. Your client wants proof it isn't.\n\nPhysical access required. The covert links are your only way in. This is a co-op mission  your partner needs to find the physical endpoint while you prepare the exploit.",
    debriefText: "Air gap breached. The SCADA network was reachable via a forgotten management interface. This finding will make headlines.",
    difficulty: Hard,
    objectives: [
      {
        id: "locate_bridge",
        description: "Find the network bridge to SCADA",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "activate_covert_link",
        description: "Activate the covert link to SCADA",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "read_plc",
        description: "Read PLC registers on a SCADA device",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "document_gap",
        description: "Prove the air gap is broken",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "no_power_disruption",
        description: "Complete without disrupting power",
        state: Pending,
        optional: true,
        hidden: false,
        revealedText: None,
      },
      {
        id: "elite_guard_evade",
        description: "Avoid detection by elite guards",
        state: Pending,
        optional: true,
        hidden: false,
        revealedText: None,
      },
    ],
    parTimeSec: 900.0,
    maxAlertForS: 1,
  },
  // Expert  Backbone
  {
    id: "m05_backbone",
    locationId: "backbone",
    title: "Deep Infrastructure",
    briefingText: "The ISP backbone. Tier 1 infrastructure connecting Nexus Corp to the outside world. Your client suspects their traffic is being mirrored to an unknown third party.\n\nThis is the deepest you've ever gone. Elite guards, SENTRY on maximum, instruction-restricted VMs. Every device has defence flags. Find the mirror, document it, and get out alive.",
    debriefText: "The traffic mirror was real. Someone inside Nexus Corp has been exfiltrating data through the backbone for months. Your evidence is irrefutable.",
    difficulty: Expert,
    objectives: [
      {
        id: "reach_backbone",
        description: "Navigate to the backbone infrastructure",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "find_mirror",
        description: "Locate the traffic mirror device",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "capture_evidence",
        description: "Capture evidence of data exfiltration",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "trace_destination",
        description: "Trace where mirrored traffic is sent",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "escape",
        description: "Disconnect from all devices cleanly",
        state: Pending,
        optional: false,
        hidden: false,
        revealedText: None,
      },
      {
        id: "ghost_run",
        description: "Complete at CLEAR alert level",
        state: Pending,
        optional: true,
        hidden: false,
        revealedText: None,
      },
      {
        id: "all_covert_links",
        description: "Discover all covert links",
        state: Pending,
        optional: true,
        hidden: true,
        revealedText: Some("7 hidden paths exist in the backbone"),
      },
    ],
    parTimeSec: 1200.0,
    maxAlertForS: 0,
  },
]

//  Mission Management 

let getMission = (locationId: string): option<mission> => {
  Array.find(missions, m => m.locationId == locationId)
}

let getMissionById = (missionId: string): option<mission> => {
  Array.find(missions, m => m.id == missionId)
}

// Complete an objective
let completeObjective = (mission: mission, ~objectiveId: string): bool => {
  let found = Array.find(mission.objectives, o => o.id == objectiveId)
  switch found {
  | Some(obj) => {
      obj.state = Completed
      true
    }
  | None => false
  }
}

// Check if all required objectives are complete
let isComplete = (mission: mission): bool => {
  mission.objectives
  ->Array.filter(o => !o.optional)
  ->Array.every(o => o.state == Completed)
}

// Get the current active objective (first non-completed required objective)
let getCurrentObjective = (mission: mission): option<string> => {
  let active = Array.find(mission.objectives, o => {
    !o.optional && o.state != Completed && !o.hidden
  })
  switch active {
  | Some(obj) => Some(obj.description)
  | None => if isComplete(mission) {
      Some("All objectives complete  exfiltrate")
    } else {
      None
    }
  }
}

// Count completed vs total objectives
let getProgress = (mission: mission): (int, int) => {
  let required = mission.objectives->Array.filter(o => !o.optional)
  let completed = required->Array.filter(o => o.state == Completed)
  (Array.length(completed), Array.length(required))
}

// Format for HUD/terminal display
let formatObjectives = (mission: mission): string => {
  let lines = mission.objectives->Array.filterMap(obj => {
    if obj.hidden && obj.state == Pending {
      None // Hidden objectives not shown until revealed
    } else {
      let marker = switch obj.state {
      | Completed => "[x]"
      | Failed => "[!]"
      | InProgress => "[>]"
      | Pending => "[ ]"
      }
      let opt = if obj.optional {
        " (optional)"
      } else {
        ""
      }
      let desc = switch obj.revealedText {
      | Some(text) if obj.state != Pending => text
      | _ => obj.description
      }
      Some(`${marker} ${desc}${opt}`)
    }
  })
  lines->Array.join("\n")
}

let difficultyToString = (d: difficulty): string => {
  switch d {
  | Tutorial => "TUTORIAL"
  | Easy => "EASY"
  | Normal => "NORMAL"
  | Hard => "HARD"
  | Expert => "EXPERT"
  }
}
