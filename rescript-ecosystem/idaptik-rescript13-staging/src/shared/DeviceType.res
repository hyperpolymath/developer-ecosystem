// SPDX-License-Identifier: PMPL-1.0-or-later
// DeviceType.res  Shared device type definitions
//
// Every network device in the game world has a type. This is shared between
// the game client (rendering, interaction), the VM (I/O port routing), and
// the level editor (device placement, configuration).

type securityLevel =
  | Open     // No authentication needed
  | Weak     // Simple password (brute-forceable)
  | Medium   // Multi-factor or encrypted
  | Strong   // Hardware token or biometric required

type t =
  | Laptop
  | Desktop
  | Server
  | Router
  | Switch
  | Firewall
  | Camera
  | AccessPoint
  | PatchPanel
  | PowerSupply
  | PhoneSystem   // PBX
  | FibreHub

// The VM port name convention for each device type
let portName = (device: t): string => {
  switch device {
  | Laptop => "laptop"
  | Desktop => "desktop"
  | Server => "server"
  | Router => "router"
  | Switch => "switch"
  | Firewall => "firewall"
  | Camera => "camera"
  | AccessPoint => "ap"
  | PatchPanel => "patch"
  | PowerSupply => "power"
  | PhoneSystem => "pbx"
  | FibreHub => "fibre"
  }
}

// Defence flags - level-designer-configurable properties per device (ADR-0013)
// All flags default to false/None so existing levels are unaffected.
type defenceFlags = {
  mutable tamperProof: bool,               // Cannot be powered off by hacker
  mutable decoy: bool,                     // Fake device - triggers alert on scan/crack/ssh
  mutable canary: bool,                    // Silent monitor - detects scans, reports to security
  mutable oneWayMirror: bool,              // Can observe but cannot be accessed from hacker's zone
  mutable killSwitch: bool,                // Admin can remotely brick (takes subnet offline)
  mutable failoverTarget: option<string>,  // Device ID of backup that activates on power loss
  mutable cascadeTrap: option<string>,     // Device ID to alert when this device is accessed
  mutable instructionWhitelist: option<array<string>>,  // Allowed VM instructions (None = all)
  mutable timeBomb: option<int>,           // Ticks until auto-UNDO if not deactivated
  mutable mirrorTarget: option<string>,    // Device ID to replicate VM instructions to
  mutable undoImmunity: option<int>,       // Last N instructions cannot be undone
}

let defaultDefenceFlags: defenceFlags = {
  tamperProof: false,
  decoy: false,
  canary: false,
  oneWayMirror: false,
  killSwitch: false,
  failoverTarget: None,
  cascadeTrap: None,
  instructionWhitelist: None,
  timeBomb: None,
  mirrorTarget: None,
  undoImmunity: None,
}

// Device metadata for the level editor and game UI
type deviceInfo = {
  deviceType: t,
  id: string,
  label: string,
  security: securityLevel,
  zone: string,          // Network zone (LAN, VLAN, DMZ, External)
  position: (float, float),
  vmPort: string,        // Which VM I/O port this device uses
  defence: defenceFlags, // Level-designer defence mechanics (ADR-0013)
}

let fromString = (s: string): option<t> => {
  switch String.toLowerCase(s) {
  | "laptop" => Some(Laptop)
  | "desktop" => Some(Desktop)
  | "server" => Some(Server)
  | "router" => Some(Router)
  | "switch" => Some(Switch)
  | "firewall" => Some(Firewall)
  | "camera" => Some(Camera)
  | "access_point" | "accesspoint" | "ap" => Some(AccessPoint)
  | "patch_panel" | "patchpanel" | "patch" => Some(PatchPanel)
  | "power_supply" | "powersupply" | "power" => Some(PowerSupply)
  | "phone_system" | "phonesystem" | "pbx" => Some(PhoneSystem)
  | "fibre_hub" | "fibrehub" | "fibre" => Some(FibreHub)
  | _ => None
  }
}
