// SPDX-License-Identifier: PMPL-1.0-or-later
// Network Zone Configuration System
// Defines network zones and their properties for scalable network management

type zoneCategory =
  | LAN // Local Area Network - employee workstations
  | DMZ // Demilitarized Zone - public-facing services
  | Internal // Internal applications - protected business services
  | IoT // Internet of Things - cameras, sensors, smart devices
  | Management // Network management and monitoring
  | SCADA // Industrial control systems - power, HVAC, physical security
  | ISP // Internet Service Provider infrastructure
  | Service // Public internet services (Atlas, Nexus, DevHub)

type networkZone = {
  id: string, // Unique identifier
  name: string, // Display name
  subnet: string, // IP prefix (e.g., "192.168.1.")
  category: zoneCategory,
  color: int, // Visualization color
  securityLevel: string, // "Low", "Medium", "High", "Critical"
  description: string,
  // Access control - which zones can this zone reach?
  canAccessZones: array<string>, // Zone IDs this zone can reach
}

// Define all network zones in the game
let allZones: array<networkZone> = [
  // ========== EDGE NETWORKS (Local networks at different locations) ==========
  {
    id: "downtown-lan",
    name: "Downtown Corporate LAN",
    subnet: "192.168.1.",
    category: LAN,
    color: 0x4CAF50, // Green
    securityLevel: "Medium",
    description: "Corporate employee workstations and office equipment",
    canAccessZones: [
      "downtown-dmz",
      "downtown-internal",
      "downtown-dev",
      "downtown-iot",
      "downtown-mgmt",
      "isp-tier3-business",
      "public",
    ],
  },
  {
    id: "rural-lan",
    name: "Rural Home LAN",
    subnet: "192.168.2.",
    category: LAN,
    color: 0x4CAF50, // Green
    securityLevel: "Low",
    description: "Home network at rural outpost",
    canAccessZones: ["downtown-dmz", "isp-tier3-rural", "public"], // Can't access internal corporate directly
  },
  // ========== DOWNTOWN OFFICE ZONES ==========
  {
    id: "downtown-dmz",
    name: "Downtown DMZ",
    subnet: "10.0.0.",
    category: DMZ,
    color: 0xFF9800, // Orange
    securityLevel: "High",
    description: "Public-facing services - mail, web, VPN",
    canAccessZones: ["downtown-internal", "downtown-security", "isp-tier3-business", "public"],
  },
  {
    id: "downtown-internal",
    name: "Downtown Internal Apps",
    subnet: "10.0.1.",
    category: Internal,
    color: 0x2196F3, // Blue
    securityLevel: "High",
    description: "Protected business applications - database, intranet, file server",
    canAccessZones: ["downtown-dmz", "downtown-dev", "downtown-security", "downtown-mgmt"],
  },
  {
    id: "downtown-dev",
    name: "Downtown Development",
    subnet: "10.0.2.",
    category: Internal,
    color: 0x9C27B0, // Purple
    securityLevel: "Medium",
    description: "Development and testing environment",
    canAccessZones: ["downtown-internal", "downtown-security", "public"],
  },
  {
    id: "downtown-security",
    name: "Downtown Security/Monitoring",
    subnet: "10.0.3.",
    category: Internal,
    color: 0xF44336, // Red
    securityLevel: "High",
    description: "IDS/IPS, SIEM, backup systems",
    canAccessZones: [
      "downtown-lan",
      "downtown-dmz",
      "downtown-internal",
      "downtown-dev",
      "downtown-iot",
      "downtown-mgmt",
      "downtown-scada",
    ],
  },
  {
    id: "downtown-iot",
    name: "Downtown IoT",
    subnet: "192.168.100.",
    category: IoT,
    color: 0xE91E63, // Pink
    securityLevel: "Low",
    description: "IoT devices - cameras, locks, sensors",
    canAccessZones: ["downtown-security"], // IoT can only report to security
  },
  {
    id: "downtown-mgmt",
    name: "Downtown Management",
    subnet: "172.16.0.",
    category: Management,
    color: 0x00BCD4, // Cyan
    securityLevel: "High",
    description: "Network management and administration tools",
    canAccessZones: [
      "downtown-lan",
      "downtown-dmz",
      "downtown-internal",
      "downtown-dev",
      "downtown-security",
      "downtown-iot",
      "downtown-scada",
    ],
  },
  {
    id: "downtown-scada",
    name: "Downtown SCADA",
    subnet: "10.10.1.",
    category: SCADA,
    color: 0xFF5722, // Deep Orange
    securityLevel: "Critical",
    description: "Industrial control - power distribution, HVAC, physical access",
    canAccessZones: [], // Air-gapped - no outbound access
  },
  // ========== ISP INFRASTRUCTURE ==========
  {
    id: "isp-tier3-rural",
    name: "Rural ISP (Tier 3)",
    subnet: "100.64.1.",
    category: ISP,
    color: 0xFFFF00, // Yellow
    securityLevel: "Medium",
    description: "Local ISP serving rural areas",
    canAccessZones: ["isp-tier2-regional"],
  },
  {
    id: "isp-tier3-business",
    name: "Business ISP (Tier 3)",
    subnet: "100.64.2.",
    category: ISP,
    color: 0xFFFF00, // Yellow
    securityLevel: "Medium",
    description: "Local ISP serving business customers",
    canAccessZones: ["isp-tier2-regional"],
  },
  {
    id: "isp-tier2-regional",
    name: "Regional ISP (Tier 2)",
    subnet: "198.51.100.",
    category: ISP,
    color: 0xFF9800, // Orange
    securityLevel: "High",
    description: "Regional ISP aggregating local providers",
    canAccessZones: ["isp-tier1-backbone"],
  },
  {
    id: "isp-tier1-backbone",
    name: "Internet Backbone (Tier 1)",
    subnet: "203.0.113.",
    category: ISP,
    color: 0xFF0000, // Red
    securityLevel: "High",
    description: "Core internet routing infrastructure",
    canAccessZones: ["service-atlas", "service-nexus", "service-devhub"],
  },
  // ========== PUBLIC SERVICES ==========
  {
    id: "service-atlas",
    name: "Atlas Network",
    subnet: "8.8.8.", // Also includes 142.250.x.x
    category: Service,
    color: 0x4285F4, // Blue
    securityLevel: "High",
    description: "Atlas DNS and web services",
    canAccessZones: ["isp-tier1-backbone", "public"],
  },
  {
    id: "service-nexus",
    name: "Nexus Network",
    subnet: "1.1.1.", // Also includes 104.16.x.x
    category: Service,
    color: 0xF38020, // Orange
    securityLevel: "High",
    description: "Nexus CDN and DNS services",
    canAccessZones: ["isp-tier1-backbone", "public"],
  },
  {
    id: "service-devhub",
    name: "DevHub Network",
    subnet: "140.82.",
    category: Service,
    color: 0x24292e, // Dark gray
    securityLevel: "High",
    description: "DevHub code repository",
    canAccessZones: ["isp-tier1-backbone", "public"],
  },
  // ========== SPECIAL ==========
  {
    id: "public",
    name: "Public Internet",
    subnet: "", // No specific subnet
    category: Service,
    color: 0xFFFFFF, // White
    securityLevel: "Low",
    description: "General internet access",
    canAccessZones: [],
  },
]

// Get zone by IP address
let getZoneByIp = (ip: string): option<networkZone> => {
  // Special handling for multi-subnet zones
  if String.startsWith(ip, "142.250.") {
    Array.find(allZones, zone => zone.id == "service-atlas")
  } else if String.startsWith(ip, "104.16.") {
    Array.find(allZones, zone => zone.id == "service-nexus")
  } else {
    // Standard subnet matching
    Array.find(allZones, zone => {
      zone.subnet != "" && String.startsWith(ip, zone.subnet)
    })
  }
}

// Get zone by ID
let getZoneById = (id: string): option<networkZone> => {
  Array.find(allZones, zone => zone.id == id)
}

// Check if source zone can access destination zone
let canZoneAccessZone = (sourceZoneId: string, destZoneId: string): bool => {
  // Same zone = always accessible
  if sourceZoneId == destZoneId {
    true
  } else {
    switch getZoneById(sourceZoneId) {
    | Some(sourceZone) => Array.some(sourceZone.canAccessZones, x => x == destZoneId)
    | None => false
    }
  }
}

// Check if source can reach destination via ISP tier routing
// LAN  Tier3 ISP  Tier2 ISP  Tier1 Backbone  Public Services
let canRouteViaISP = (sourceZone: networkZone, destZone: networkZone): bool => {
  // If destination is a public service (Atlas, Nexus, DevHub), check ISP routing
  if destZone.category == Service {
    // Can source reach any ISP tier?
    let canReachISP =
      Array.some(sourceZone.canAccessZones, x => x == "isp-tier3-business") ||
      Array.some(sourceZone.canAccessZones, x => x == "isp-tier3-rural") ||
      Array.some(sourceZone.canAccessZones, x => x == "isp-tier2-regional") ||
      Array.some(sourceZone.canAccessZones, x => x == "isp-tier1-backbone")

    // If source can reach ISP infrastructure, it can reach public services
    canReachISP || Array.some(sourceZone.canAccessZones, x => x == "public")
  } else if destZone.category == ISP {
    // ISP zones are accessible if you can reach the tier hierarchy
    // Check if source can reach this ISP or a lower tier that routes to it
    Array.some(sourceZone.canAccessZones, x => x == destZone.id) ||
    Array.some(sourceZone.canAccessZones, x => x == "isp-tier3-business") ||
    Array.some(sourceZone.canAccessZones, x => x == "isp-tier3-rural") ||
    Array.some(sourceZone.canAccessZones, x => x == "public")
  } else {
    false // Not ISP routing
  }
}

// Check if source IP can access destination IP based on zones
let canIpAccessIp = (sourceIp: string, destIp: string): bool => {
  // Same IP = always accessible
  if sourceIp == destIp {
    true
  } else {
    let sourceZone = getZoneByIp(sourceIp)
    let destZone = getZoneByIp(destIp)

    switch (sourceZone, destZone) {
    | (Some(sZone), Some(dZone)) =>
      // First check direct access
      if canZoneAccessZone(sZone.id, dZone.id) {
        true
      } else {
        // If no direct access, check if we can route via ISP tiers
        canRouteViaISP(sZone, dZone)
      }
    | (Some(sZone), None) =>
      // Destination not in defined zone - check if source can access public
      Array.some(sZone.canAccessZones, x => x == "public") ||
      Array.some(sZone.canAccessZones, x => x == "isp-tier3-business") ||
      Array.some(sZone.canAccessZones, x => x == "isp-tier3-rural")
    | _ => false // Source zone unknown = no access
    }
  }
}

// Get all zones by category
let getZonesByCategory = (category: zoneCategory): array<networkZone> => {
  Array.filter(allZones, zone => zone.category == category)
}

// Get zone color for visualization
let getZoneColor = (ip: string): int => {
  switch getZoneByIp(ip) {
  | Some(zone) => zone.color
  | None => 0x666666 // Gray for unknown
  }
}

// Get zone name for display
let getZoneName = (ip: string): string => {
  switch getZoneByIp(ip) {
  | Some(zone) => zone.name
  | None => "Unknown Zone"
  }
}

// Get all zone IDs (for lookups)
let getAllZoneIds = (): array<string> => {
  Array.map(allZones, zone => zone.id)
}
