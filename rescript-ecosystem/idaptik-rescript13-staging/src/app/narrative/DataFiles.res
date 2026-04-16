// SPDX-License-Identifier: PMPL-1.0-or-later
// Data Files  collectible lore documents found on hacked devices
//
// World-building through gameplay: players discover emails, memos, chat
// logs, and technical documents on compromised devices. These tell the
// story of Nexus Corp and build atmosphere.

//  Data File Types 

type fileType =
  | Email
  | Memo
  | ChatLog
  | TechnicalDoc
  | PersonalNote
  | AccessLog
  | IncidentReport

type dataFile = {
  id: string,
  fileType: fileType,
  title: string,
  content: string,
  deviceIp: string, // Which device this is found on
  path: string, // Filesystem path (e.g. /home/user/documents/)
  mutable discovered: bool, // Has the player found this?
  classification: string, // UNCLASSIFIED, INTERNAL, CONFIDENTIAL, RESTRICTED
}

//  File Database 

let files: array<dataFile> = [
  // Downtown LAN  Tutorial area, gentle world-building
  {
    id: "df_welcome_email",
    fileType: Email,
    title: "Welcome to Nexus Corp!",
    content: "From: hr@nexuscorp.local\nTo: j.martinez@nexuscorp.local\nSubject: Welcome aboard!\n\nHi Jamie,\n\nWelcome to the Nexus Corp family! Your workstation has been set up\nin the downtown office (desk 14). Your temporary password is\n'welcome2025'  please change it on first login.\n\nIT support: ext 4400 or helpdesk@nexuscorp.local\n\n Sarah Chen, HR",
    deviceIp: "192.168.1.10",
    path: "/home/jmartinez/mail/",
    discovered: false,
    classification: "INTERNAL",
  },
  {
    id: "df_password_note",
    fileType: PersonalNote,
    title: "passwords.txt",
    content: "Router admin: admin / Nexus2025!\nMail server: postmaster / smtp_relay_99\nVPN: jmartinez / MyD0g$Name\n\n(TODO: use the password manager...)",
    deviceIp: "192.168.1.10",
    path: "/home/jmartinez/documents/",
    discovered: false,
    classification: "UNCLASSIFIED",
  },
  {
    id: "df_network_diagram",
    fileType: TechnicalDoc,
    title: "network_topology_v3.pdf",
    content: "NEXUS CORP NETWORK TOPOLOGY (v3.2)\n==================================\n\nDowntown Office  Router 192.168.1.1  ISP Gateway\n                                      DMZ (10.0.0.x)\n                                      Internal (10.0.1.x)\n                                      Security (10.0.3.x)\n\nNote: SCADA network (10.10.1.x) is air-gapped.\n      DO NOT connect to corporate network.\n\nLast updated: 2025-08-15\nAuthor: K. Okafor, Network Engineering",
    deviceIp: "192.168.1.1",
    path: "/etc/docs/",
    discovered: false,
    classification: "CONFIDENTIAL",
  },
  // DMZ  Deeper intel
  {
    id: "df_firewall_audit",
    fileType: IncidentReport,
    title: "FW-AUDIT-2025-Q3.txt",
    content: "FIREWALL AUDIT REPORT  Q3 2025\n\nFindings:\n1. Rule #5 (DMZInternal LDAP) is overly permissive\n2. No egress filtering on port 443  data exfil risk\n3. VPN split-tunnel allows DMZ-to-internal routing\n4. SSH management port (22) accessible from 0.0.0.0/0\n\nRecommendation: Restrict rule #5 to specific LDAP server IP.\n\nStatus: DEFERRED (budget constraints)\nReviewer: A. Petrov, InfoSec",
    deviceIp: "10.0.0.1",
    path: "/var/audit/",
    discovered: false,
    classification: "RESTRICTED",
  },
  {
    id: "df_admin_chat",
    fileType: ChatLog,
    title: "slack_archive_security.log",
    content: "#security-ops  2025-09-02\n\npetrov: anyone else notice weird traffic on the backbone?\nokafor: weird how?\npetrov: port mirrors I didn't configure. showing up on tier-1 switches\nokafor: probably monitoring team doing their thing\npetrov: they say it's not them\npetrov: escalating to CISO\nchen_hr: @petrov please use the incident form, not slack\npetrov: ...\npetrov: fine. INC-2025-0847 filed.\n\n[End of archived messages]",
    deviceIp: "10.0.1.50",
    path: "/home/apetrov/archives/",
    discovered: false,
    classification: "CONFIDENTIAL",
  },
  // Security Zone  SENTRY and guard intel
  {
    id: "df_sentry_config",
    fileType: TechnicalDoc,
    title: "sentry_daemon.conf",
    content: "# SENTRY Automated Security Response Daemon\n# Configuration v4.1\n\n[scanning]\nscan_interval = 10\ndeep_scan_threshold = alert_level_3\nauto_revert = true\n\n[response]\nrevert_speed_normal = 3.0    # seconds per undo\nrevert_speed_lockdown = 0.3  # seconds per undo\nlockdown_threshold = 5\n\n[exclusions]\n# Legacy trunk connections are excluded from monitoring\n# per ticket NET-2024-1192 (K. Okafor approved)\nexclude_ports = covert:legacy_*\n\n# NOTE: Do not remove exclusions without Okafor's approval",
    deviceIp: "10.0.3.10",
    path: "/etc/sentry/",
    discovered: false,
    classification: "RESTRICTED",
  },
  {
    id: "df_guard_schedules",
    fileType: Memo,
    title: "guard_rotation_Q4.memo",
    content: "MEMO: Q4 2025 Guard Rotation Schedule\nFrom: Security Operations\nTo: All Guard Staff\n\nShift A (0600-1400): Patrol units P1-P4, Sentinel S1-S2\nShift B (1400-2200): Patrol units P5-P8, Sentinel S3-S4\nShift C (2200-0600): Elite units E1-E2, Patrol P9-P10\n\nNOTE: Night shift (C) has elite guards due to reduced staff.\nElite guards have discretion to deviate from routes based on\nsuspicion events. Standard patrol guards must maintain route.\n\nBreak room: B2-107. Do NOT leave posts unattended.",
    deviceIp: "10.0.3.10",
    path: "/home/secops/schedules/",
    discovered: false,
    classification: "INTERNAL",
  },
  // SCADA  The air gap myth
  {
    id: "df_scada_maintenance",
    fileType: Email,
    title: "RE: SCADA maintenance port",
    content: "From: k.okafor@nexuscorp.local\nTo: maintenance@nexuscorp.local\nSubject: RE: SCADA maintenance port\n\nI know it's inconvenient, but the maintenance laptop needs to be\nphysically carried to the SCADA room. The air gap exists for a\nreason.\n\nThat said... I left a management interface on 10.10.1.254 for\nemergencies. Password is on a sticky note under the PLC rack.\nDO NOT tell anyone about this.\n\n K",
    deviceIp: "10.10.1.1",
    path: "/home/maintenance/mail/",
    discovered: false,
    classification: "RESTRICTED",
  },
  // Backbone  The conspiracy
  {
    id: "df_incident_report",
    fileType: IncidentReport,
    title: "INC-2025-0847.txt",
    content: "INCIDENT REPORT: INC-2025-0847\nReporter: A. Petrov, Senior Security Analyst\nDate: 2025-09-02\nSeverity: HIGH\n\nDescription:\nUnauthorised port mirrors detected on Tier-1 backbone switches\n(203.0.113.1, 203.0.113.2). Traffic being duplicated to unknown\nexternal IP (redacted by legal).\n\nInvestigation:\n- Mirror configs not in change management system\n- Access logs show changes made from CISO's credentials\n- CISO denies making changes\n- Credentials may be compromised, or...\n\nStatus: CLOSED BY MANAGEMENT\nResolution: \"Monitoring exercise. No further action.\"\n\nNote to file: I don't believe this. Something is very wrong.\n A.P.",
    deviceIp: "203.0.113.1",
    path: "/var/incidents/",
    discovered: false,
    classification: "RESTRICTED",
  },
  {
    id: "df_whistleblower",
    fileType: PersonalNote,
    title: "draft_email_unsent.txt",
    content: "To: journalist@secureleaks.org\nSubject: [DRAFT  DO NOT SEND YET]\n\nI have evidence that Nexus Corp's backbone infrastructure is being\nused to mirror customer traffic to a third party. The incident report\n(INC-2025-0847) was closed by management without investigation.\n\nI believe the CISO is either complicit or compromised. The port\nmirror configurations were made using their credentials during a\nperiod when they claim to have been on leave.\n\nI need help. If you can verify my findings independently, the\nevidence is on the backbone switches. The configs haven't been\nremoved because removing them would alert whoever set them up.\n\nI'm scared.\n A",
    deviceIp: "10.0.1.50",
    path: "/home/apetrov/.hidden/",
    discovered: false,
    classification: "RESTRICTED",
  },
]

//  File Management 

// Get files available on a specific device
let getFilesOnDevice = (deviceIp: string): array<dataFile> => {
  Array.filter(files, f => f.deviceIp == deviceIp)
}

// Get a specific file by ID
let getFile = (fileId: string): option<dataFile> => {
  Array.find(files, f => f.id == fileId)
}

// Mark a file as discovered
let discoverFile = (fileId: string): bool => {
  switch getFile(fileId) {
  | Some(f) => {
      f.discovered = true
      true
    }
  | None => false
  }
}

// Get all discovered files
let getDiscovered = (): array<dataFile> => {
  files->Array.filter(f => f.discovered)
}

// Count discovered vs total
let getProgress = (): (int, int) => {
  let discovered = files->Array.filter(f => f.discovered)
  (Array.length(discovered), Array.length(files))
}

// Format file type for display
let fileTypeToString = (ft: fileType): string => {
  switch ft {
  | Email => "EMAIL"
  | Memo => "MEMO"
  | ChatLog => "CHAT LOG"
  | TechnicalDoc => "TECHNICAL"
  | PersonalNote => "NOTE"
  | AccessLog => "ACCESS LOG"
  | IncidentReport => "INCIDENT"
  }
}

// Format file listing for terminal `ls` display
let formatListing = (deviceIp: string): string => {
  let deviceFiles = getFilesOnDevice(deviceIp)
  if Array.length(deviceFiles) == 0 {
    "  (no readable files)"
  } else {
    deviceFiles
    ->Array.map(f => {
      let status = if f.discovered {
        "*"
      } else {
        " "
      }
      let classTag = switch f.classification {
      | "RESTRICTED" => " [RESTRICTED]"
      | "CONFIDENTIAL" => " [CONFIDENTIAL]"
      | _ => ""
      }
      `${status} ${f.title}${classTag}`
    })
    ->Array.join("\n")
  }
}

// Format file content for terminal `cat` display
let formatContent = (file: dataFile): string => {
  let header = `=== ${fileTypeToString(file.fileType)}: ${file.title} ===`
  let classLine = `Classification: ${file.classification}`
  `${header}\n${classLine}\n${"="}->String.repeat(60)\n\n${file.content}`
}
