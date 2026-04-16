// SPDX-License-Identifier: PMPL-1.0-or-later
// Central network manager for all devices
// Implements zone-based network segmentation with proper isolation

open DeviceTypes

// Network topology: Segmented zones with firewalls
// Edge Networks:
//   - 192.168.1.x (Downtown LAN) - Corporate employee workstations
//   - 192.168.2.x (Rural LAN) - Home network at rural outpost
// Downtown Office Zones:
//   - 10.0.0.x (DMZ) - Internet-facing services (Mail, VPN)
//   - 10.0.1.x (Internal Apps) - Protected business services (DB, Intranet, LDAP)
//   - 10.0.2.x (Development) - Dev/test environment
//   - 10.0.3.x (Security) - IDS/IPS, SIEM, Backup
//   - 172.16.0.x (Management) - Network administration
//   - 192.168.100.x (IoT) - Cameras, sensors, smart devices
//   - 10.10.1.x (SCADA) - Industrial control (air-gapped)
// ISP Infrastructure:
//   - 100.64.x.x (Tier 3 ISPs) - Local access providers
//   - 198.51.100.x (Tier 2 ISP) - Regional aggregation
//   - 203.0.113.x (Tier 1 Backbone) - Core internet routing
// Public Services:
//   - 8.8.8.x, 142.250.x.x (Atlas Network)
//   - 1.1.1.x, 104.16.x.x (Nexus Network)
//   - 140.82.x.x (DevHub Network)

// DNS record type
type dnsRecord = {
  hostname: string,
  ip: string,
}

// DNS server configuration
type dnsServer = {
  ip: string,
  records: array<dnsRecord>,
  isOnline: bool,
}

type t = {
  devices: Dict.t<device>,
  // Device states for SSH connections (keyed by IP)
  deviceStates: Dict.t<LaptopState.laptopState>,
  // Router IP (center of star)
  routerIp: string,
  // DNS server IP configured on router (can be changed)
  mutable configuredDnsIp: string,
  // DNS servers on the network (keyed by IP)
  dnsServers: Dict.t<dnsServer>,
}

// Get subnet from IP address (e.g., "192.168.1" from "192.168.1.102")
let getSubnet = (ip: string): string => {
  let parts = String.split(ip, ".")
  if Array.length(parts) >= 3 {
    let first3 = Array.slice(parts, ~start=0, ~end=3)
    Array.join(first3, ".")
  } else {
    ip
  }
}

// Check if two IPs are on the same subnet
let sameSubnet = (ip1: string, ip2: string): bool => {
  getSubnet(ip1) == getSubnet(ip2)
}

// Check if device is the router
let isRouter = (ip: string, routerIp: string): bool => {
  ip == routerIp
}

// Initialize DNS servers
let initializeDnsServers = (manager: t): unit => {
  // Atlas DNS server at 8.8.8.8 (external, always reachable via router)
  Dict.set(manager.dnsServers, "8.8.8.8", {
    ip: "8.8.8.8",
    isOnline: true,
    records: [
      // Public internet services
      {hostname: "atlas.com", ip: "142.250.80.46"},
      {hostname: "www.atlas.com", ip: "142.250.80.46"},
      {hostname: "devhub.com", ip: "140.82.121.4"},
      {hostname: "www.devhub.com", ip: "140.82.121.4"},
      {hostname: "nexus.com", ip: "104.16.132.229"},
      {hostname: "www.nexus.com", ip: "104.16.132.229"},
      // Corporate DMZ services (public-facing)
      {hostname: "mail.corp.local", ip: "10.0.0.25"},
      {hostname: "vpn.corp.local", ip: "10.0.0.100"},
      // Corporate Internal services (protected)
      {hostname: "ldap.corp.local", ip: "10.0.1.10"},
      {hostname: "files.corp.local", ip: "10.0.1.50"},
      {hostname: "corp-intranet.local", ip: "10.0.1.100"},
      {hostname: "secret-server.local", ip: "10.0.1.99"},
      {hostname: "fileserver.corp.local", ip: "10.0.1.200"},
      // Development
      {hostname: "dev.corp.local", ip: "10.0.2.77"},
      // Management
      {hostname: "admin-panel.local", ip: "172.16.0.200"},
    ],
  })
  // Secondary DNS (Nexus) - also external
  Dict.set(manager.dnsServers, "1.1.1.1", {
    ip: "1.1.1.1",
    isOnline: true,
    records: [
      {hostname: "atlas.com", ip: "142.250.80.46"},
      {hostname: "devhub.com", ip: "140.82.121.4"},
      {hostname: "nexus.com", ip: "104.16.132.229"},
    ],
  })
}

// Initialize the network with default devices
let initializeNetwork = (manager: t): unit => {
  // ========================================
  // INITIALIZE GLOBAL NETWORK STATE
  // ========================================

  // Initialize global content store (hash-based deduplication)
  GlobalNetworkData.initializeDefaultContent()

  // Initialize device filesystems (trees with content references)
  DeviceView.initializeDefaultFilesystems()

  // ========================================
  // DOWNTOWN OFFICE (192.168.1.x) - Main Corporate LAN
  // ========================================

  // Downtown Router (corporate office, gateway to internet and DMZ)
  Dict.set(manager.devices, "192.168.1.1", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="DOWNTOWN-ROUTER",
    ~ipAddress="192.168.1.1",
    ~securityLevel=Medium,
  ))
  // Corp laptop 1
  Dict.set(manager.devices, "192.168.1.102", DeviceFactory.createDevice(
    ~deviceType=Laptop,
    ~name="CORP-LAPTOP-42",
    ~ipAddress="192.168.1.102",
    ~securityLevel=Medium,
  ))
  // Corp laptop 2
  Dict.set(manager.devices, "192.168.1.103", DeviceFactory.createDevice(
    ~deviceType=Laptop,
    ~name="CORP-LAPTOP-17",
    ~ipAddress="192.168.1.103",
    ~securityLevel=Weak,
  ))

  // ========================================
  // RURAL OUTPOST (192.168.2.x) - Remote Home Network
  // ========================================

  // Rural router
  Dict.set(manager.devices, "192.168.2.1", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="RURAL-ROUTER",
    ~ipAddress="192.168.2.1",
    ~securityLevel=Weak,
  ))
  // Rural laptop (player start location)
  Dict.set(manager.devices, "192.168.2.100", DeviceFactory.createDevice(
    ~deviceType=Laptop,
    ~name="HOME-LAPTOP",
    ~ipAddress="192.168.2.100",
    ~securityLevel=Weak,
  ))

  // ========================================
  // IoT NETWORK (192.168.100.x) - Isolated IoT devices
  // ========================================

  // IoT Router (gateway for IoT network)
  Dict.set(manager.devices, "192.168.100.1", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="IOT-ROUTER",
    ~ipAddress="192.168.100.1",
    ~securityLevel=Weak,
  ))
  // Security camera (moved from LAN to IoT network)
  Dict.set(manager.devices, "192.168.100.10", DeviceFactory.createDevice(
    ~deviceType=IotCamera,
    ~name="CAM-ENTRANCE",
    ~ipAddress="192.168.100.10",
    ~securityLevel=Open,
  ))

  // ========================================
  // DMZ (10.0.0.x) - Internet-facing services ONLY
  // ========================================

  // External Firewall (boundary between internet and DMZ)
  Dict.set(manager.devices, "10.0.0.1", DeviceFactory.createDevice(
    ~deviceType=Firewall,
    ~name="FIREWALL-EXT",
    ~ipAddress="10.0.0.1",
    ~securityLevel=Strong,
  ))
  // Mail server (internet-facing, receives external email)
  Dict.set(manager.devices, "10.0.0.25", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="MAIL-SERVER",
    ~ipAddress="10.0.0.25",
    ~securityLevel=Strong,
  ))
  // VPN server (remote access gateway)
  Dict.set(manager.devices, "10.0.0.100", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="VPN-SERVER",
    ~ipAddress="10.0.0.100",
    ~securityLevel=Strong,
  ))

  // ========================================
  // INTERNAL APPS (10.0.1.x) - Protected business services
  // ========================================

  // Internal Firewall (boundary between DMZ and Internal)
  Dict.set(manager.devices, "10.0.1.1", DeviceFactory.createDevice(
    ~deviceType=Firewall,
    ~name="FIREWALL-INT",
    ~ipAddress="10.0.1.1",
    ~securityLevel=Strong,
  ))
  // LDAP/Active Directory (central authentication)
  Dict.set(manager.devices, "10.0.1.10", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="LDAP-SERVER",
    ~ipAddress="10.0.1.10",
    ~securityLevel=Strong,
  ))
  // Database server (files.corp.local)
  Dict.set(manager.devices, "10.0.1.50", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="DB-SERVER-01",
    ~ipAddress="10.0.1.50",
    ~securityLevel=Strong,
  ))
  // Secret server (hidden, high-value target)
  Dict.set(manager.devices, "10.0.1.99", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="SECRET-SERVER",
    ~ipAddress="10.0.1.99",
    ~securityLevel=Strong,
  ))
  // Corporate intranet (internal web portal)
  Dict.set(manager.devices, "10.0.1.100", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="CORP-INTRANET",
    ~ipAddress="10.0.1.100",
    ~securityLevel=Medium,
  ))
  // File server (shared storage)
  Dict.set(manager.devices, "10.0.1.200", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="FILE-SERVER",
    ~ipAddress="10.0.1.200",
    ~securityLevel=Medium,
  ))

  // ========================================
  // DEVELOPMENT (10.0.2.x) - Dev/test environment
  // ========================================

  // Development terminal (dev.corp.local)
  Dict.set(manager.devices, "10.0.2.77", DeviceFactory.createDevice(
    ~deviceType=Terminal,
    ~name="DEV-TERMINAL",
    ~ipAddress="10.0.2.77",
    ~securityLevel=Weak,
  ))

  // ========================================
  // SECURITY/MONITORING (10.0.3.x) - IDS/IPS, SIEM, Backup
  // ========================================

  // IDS/IPS (intrusion detection/prevention)
  Dict.set(manager.devices, "10.0.3.10", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="IDS-IPS",
    ~ipAddress="10.0.3.10",
    ~securityLevel=Strong,
  ))
  // SIEM/Log Server (security information and event management)
  Dict.set(manager.devices, "10.0.3.20", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="SIEM-SERVER",
    ~ipAddress="10.0.3.20",
    ~securityLevel=Strong,
  ))
  // Backup Server (data backup and recovery)
  Dict.set(manager.devices, "10.0.3.30", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="BACKUP-SERVER",
    ~ipAddress="10.0.3.30",
    ~securityLevel=Strong,
  ))

  // ========================================
  // MANAGEMENT VLAN (172.16.0.x) - Network management tools
  // ========================================

  // Admin panel (network administration interface)
  Dict.set(manager.devices, "172.16.0.200", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="ADMIN-PANEL",
    ~ipAddress="172.16.0.200",
    ~securityLevel=Medium,
  ))

  // ========================================
  // SCADA (10.10.1.x) - Industrial control (air-gapped)
  // ========================================

  // SCADA Controller (power distribution control)
  Dict.set(manager.devices, "10.10.1.1", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="SCADA-CONTROLLER",
    ~ipAddress="10.10.1.1",
    ~securityLevel=Strong,
  ))
  // Main Power Station (moved from LAN to SCADA network)
  Dict.set(manager.devices, "10.10.1.100", DeviceFactory.createDevice(
    ~deviceType=PowerStation,
    ~name="MAIN-PWR-STATION",
    ~ipAddress="10.10.1.100",
    ~securityLevel=Medium,
  ))

  // UPS Unit (downtown office, protects critical business systems)
  Dict.set(manager.devices, "192.168.1.251", DeviceFactory.createDevice(
    ~deviceType=UPS,
    ~name="UPS-CRITICAL",
    ~ipAddress="192.168.1.251",
    ~securityLevel=Open,
    ~connectedStationIp="10.10.1.100", // Updated to new power station IP
  ))

  // Connect critical downtown devices to UPS
  PowerManager.connectDeviceToUPS("192.168.1.1", "192.168.1.251")    // Main router
  PowerManager.connectDeviceToUPS("10.0.0.25", "192.168.1.251")      // Mail server (DMZ)
  PowerManager.connectDeviceToUPS("10.0.1.50", "192.168.1.251")      // DB server (Internal)
  PowerManager.connectDeviceToUPS("172.16.0.200", "192.168.1.251")   // Admin panel (Management)

  // ========================================
  // ISP INFRASTRUCTURE - Tiered Routing
  // ========================================

  // Tier 3: Local/Access ISPs (connect end users)
  Dict.set(manager.devices, "100.64.1.1", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="RURAL-ISP",
    ~ipAddress="100.64.1.1",
    ~securityLevel=Medium,
  ))
  Dict.set(manager.devices, "100.64.2.1", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="BUSINESS-ISP",
    ~ipAddress="100.64.2.1",
    ~securityLevel=Medium,
  ))

  // Tier 2: Regional ISP (aggregates local ISPs)
  Dict.set(manager.devices, "198.51.100.1", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="REGIONAL-ISP",
    ~ipAddress="198.51.100.1",
    ~securityLevel=Strong,
  ))

  // ========================================
  // TIER 1: INTERNET BACKBONE RING (Global routing)
  // ========================================
  // 5 continental backbone servers in a ring topology
  // Each connects to 2 neighbors to form a redundant ring

  // North America Backbone
  Dict.set(manager.devices, "203.0.113.1", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="NA-BACKBONE",
    ~ipAddress="203.0.113.1",
    ~securityLevel=Strong,
  ))

  // Europe Backbone
  Dict.set(manager.devices, "203.0.113.2", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="EU-BACKBONE",
    ~ipAddress="203.0.113.2",
    ~securityLevel=Strong,
  ))

  // Asia Backbone
  Dict.set(manager.devices, "203.0.113.3", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="ASIA-BACKBONE",
    ~ipAddress="203.0.113.3",
    ~securityLevel=Strong,
  ))

  // South America Backbone
  Dict.set(manager.devices, "203.0.113.4", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="SA-BACKBONE",
    ~ipAddress="203.0.113.4",
    ~securityLevel=Strong,
  ))

  // Africa Backbone
  Dict.set(manager.devices, "203.0.113.5", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="AF-BACKBONE",
    ~ipAddress="203.0.113.5",
    ~securityLevel=Strong,
  ))

  // ========================================
  // EXTERNAL INTERNET (Public IPs)
  // ========================================

  // Atlas Data Center (8.8.8.x)
  Dict.set(manager.devices, "8.8.8.1", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="ATLAS-ROUTER",
    ~ipAddress="8.8.8.1",
    ~securityLevel=Strong,
  ))
  Dict.set(manager.devices, "8.8.8.8", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="ATLAS-DNS",
    ~ipAddress="8.8.8.8",
    ~securityLevel=Strong,
  ))
  Dict.set(manager.devices, "142.250.80.46", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="ATLAS-WEB",
    ~ipAddress="142.250.80.46",
    ~securityLevel=Strong,
  ))

  // Nexus CDN (1.1.1.x / 104.16.x.x)
  Dict.set(manager.devices, "1.1.1.254", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="NEXUS-ROUTER",
    ~ipAddress="1.1.1.254",
    ~securityLevel=Strong,
  ))
  Dict.set(manager.devices, "1.1.1.1", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="NEXUS-DNS",
    ~ipAddress="1.1.1.1",
    ~securityLevel=Strong,
  ))
  Dict.set(manager.devices, "104.16.132.229", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="NEXUS-WEB",
    ~ipAddress="104.16.132.229",
    ~securityLevel=Strong,
  ))

  // DevHub Repository (140.82.121.x)
  Dict.set(manager.devices, "140.82.121.1", DeviceFactory.createDevice(
    ~deviceType=Router,
    ~name="DEVHUB-ROUTER",
    ~ipAddress="140.82.121.1",
    ~securityLevel=Strong,
  ))
  Dict.set(manager.devices, "140.82.121.4", DeviceFactory.createDevice(
    ~deviceType=Server,
    ~name="DEVHUB-WEB",
    ~ipAddress="140.82.121.4",
    ~securityLevel=Strong,
  ))

  // Initialize DNS servers (records for hostname resolution)
  initializeDnsServers(manager)

  // ========================================
  // INITIALIZE SERVICES FOR ALL DEVICES
  // ========================================
  // Initialize services for servers and laptops so they're ready for SSH/network access
  Dict.toArray(manager.devices)->Array.forEach(((ip, device)) => {
    let info = device.getInfo()
    switch info.deviceType {
    | Server =>
      // Servers auto-start SSH, HTTP, Security services
      LaptopState.ServiceManager.initializeServices(ip, ~isServer=true)
    | Laptop | Terminal =>
      // Laptops/Terminals auto-start Desktop, Security services
      LaptopState.ServiceManager.initializeServices(ip, ~isServer=false)
    | Router | Firewall | IotCamera | PowerStation | UPS => ()  // No services for these
    }
  })
}

// Create a new network manager
let make = (): t => {
  let manager = {
    devices: Dict.make(),
    deviceStates: Dict.make(),
    routerIp: "192.168.1.1",
    configuredDnsIp: "8.8.8.8",
    dnsServers: Dict.make(),
  }
  initializeNetwork(manager)
  manager
}

// Get configured DNS server IP
let getConfiguredDns = (manager: t): string => manager.configuredDnsIp

// Set configured DNS server IP (called from router config)
let setConfiguredDns = (manager: t, dnsIp: string): unit => {
  manager.configuredDnsIp = dnsIp
}

// Resolve hostname to IP using configured DNS
// Returns None if DNS server is unreachable or hostname not found
let resolveHostname = (manager: t, hostname: string): option<string> => {
  // First check if it's already an IP address
  let parts = String.split(hostname, ".")
  let isIp = Array.length(parts) == 4 && Array.every(parts, part => {
    switch Int.fromString(part) {
    | Some(n) => n >= 0 && n <= 255
    | None => false
    }
  })

  if isIp {
    Some(hostname) // Already an IP
  } else {
    // Need to query DNS server
    // Check if DNS server is reachable (router must be up for external DNS)
    switch Dict.get(manager.devices, manager.routerIp) {
    | None => None // Router down, can't reach DNS
    | Some(_) =>
      // Check if configured DNS server exists and is online
      switch Dict.get(manager.dnsServers, manager.configuredDnsIp) {
      | None => None // DNS server not found
      | Some(dns) =>
        if !dns.isOnline {
          None // DNS server offline
        } else {
          // Look up the hostname
          Array.find(dns.records, r => r.hostname == hostname)
          ->Option.map(r => r.ip)
        }
      }
    }
  }
}

// Get all connected devices (for router display)
let getConnectedDevices = (manager: t): array<(string, string, string)> => {
  // Returns array of (name, ip, mac) for all devices except the router itself
  Dict.toArray(manager.devices)
  ->Array.filter(((ip, _)) => ip != manager.routerIp)
  ->Array.map(((ip, device)) => {
    let info = device.getInfo()
    // Generate a fake MAC based on IP for consistency
    let ipParts = String.split(ip, ".")
    let lastOctet = Array.get(ipParts, 3)->Option.getOr("0")
    let mac = `AA:BB:CC:DD:EE:${String.padStart(lastOctet, 2, "0")}`
    (info.name, ip, mac)
  })
  ->Array.toSorted(((_, ip1, _), (_, ip2, _)) => String.compare(ip1, ip2))
}

// Add a device to the network
let addDevice = (
  manager: t,
  ~name: string,
  ~deviceType: deviceType,
  ~ipAddress: string,
  ~securityLevel: securityLevel,
): unit => {
  let device = DeviceFactory.createDevice(~deviceType, ~name, ~ipAddress, ~securityLevel)
  Dict.set(manager.devices, ipAddress, device)
}

// Get a device by IP address
let getDevice = (manager: t, ipAddress: string): option<device> => {
  Dict.get(manager.devices, ipAddress)
}

// Get all devices
let getAllDevices = (manager: t): array<device> => {
  Dict.valuesToArray(manager.devices)
}

// Remove a device from the network
let removeDevice = (manager: t, ipAddress: string): bool => {
  switch Dict.get(manager.devices, ipAddress) {
  | Some(_) =>
    Dict.delete(manager.devices, ipAddress)
    true
  | None => false
  }
}

// Scan network (returns all devices)
let scanNetwork = (manager: t): array<device> => {
  getAllDevices(manager)
}

// Check if a device is reachable FROM a specific source IP
// Uses NetworkZones for proper network segmentation and access control
let isReachableFrom = (manager: t, sourceIp: string, destIp: string): bool => {
  // Can reach yourself
  if sourceIp == destIp {
    true
  } else {
    // Check if destination device exists
    let destExists = Dict.get(manager.devices, destIp)->Option.isSome

    // If destination doesn't exist and not in a defined zone, treat as public internet
    if !destExists {
      switch NetworkZones.getZoneByIp(destIp) {
      | None => NetworkZones.canIpAccessIp(sourceIp, destIp) // Public internet access check
      | Some(_) => false // Zone exists but device doesn't
      }
    } else {
      // Device exists, use zone-based access control
      NetworkZones.canIpAccessIp(sourceIp, destIp)
    }
  }
}

// Legacy function - checks global reachability (used for device existence)
let isReachable = (manager: t, ipAddress: string): bool => {
  Dict.get(manager.devices, ipAddress)->Option.isSome
}

// Get device info for ping/ssh
let getDeviceInfo = (manager: t, ipAddress: string): option<deviceInfo> => {
  switch Dict.get(manager.devices, ipAddress) {
  | Some(device) => Some(device.getInfo())
  | None => None
  }
}

// Check if SSH is available on a device (checks if SSH service is running)
let hasSSH = (manager: t, ipAddress: string): bool => {
  switch Dict.get(manager.devices, ipAddress) {
  | Some(_device) =>
    // Check if SSH service is running via ServiceManager
    LaptopState.ServiceManager.isServiceRunning(ipAddress, SSH)
  | None => false
  }
}

// Get all reachable hosts (for network scanning) - legacy, returns all
let getReachableHosts = (manager: t): array<string> => {
  Dict.keysToArray(manager.devices)
}

// Get hosts reachable from a specific source IP
let getReachableHostsFrom = (manager: t, sourceIp: string): array<string> => {
  Dict.keysToArray(manager.devices)->Array.filter(destIp =>
    isReachableFrom(manager, sourceIp, destIp)
  )
}

// Get trace route from source to destination
// Returns array of (ip, hostname, latency_ms)
let getTraceRoute = (manager: t, sourceIp: string, destIp: string): array<(string, string, int)> => {
  // In star topology, all traffic goes through router
  // trace: source -> router -> (external DNS if needed) -> destination

  let hops = ref([])

  // Check if destination is reachable
  if !isReachableFrom(manager, sourceIp, destIp) {
    [] // Not reachable
  } else {
    // Hop 1: Router (if source is not the router)
    if sourceIp != manager.routerIp {
      hops := Array.concat(hops.contents, [(manager.routerIp, "WIFI-ROUTER", 1)])
    }

    // Check if destination is external (not on local network)
    let isExternal = Dict.get(manager.devices, destIp)->Option.isNone

    if isExternal {
      // Add internet gateway hop (simulated)
      hops := Array.concat(hops.contents, [("10.255.255.1", "isp-gateway", 12)])
      // Add a few internet hops
      hops := Array.concat(hops.contents, [("72.14.215.85", "core-router-1", 18)])
      hops := Array.concat(hops.contents, [("209.85.251.9", "edge-router", 24)])
    } else {
      // Local destination - direct through router
      // If different subnet, show the routing
      if !sameSubnet(sourceIp, destIp) && sourceIp != manager.routerIp {
        // Already added router hop above
        ()
      }
    }

    // Final hop: destination
    let destName = switch Dict.get(manager.devices, destIp) {
    | Some(device) => device.getInfo().name
    | None => destIp // Use IP if external
    }
    let finalLatency = if isExternal { 32 } else { 2 }
    hops := Array.concat(hops.contents, [(destIp, destName, finalLatency)])

    hops.contents
  }
}

// Forward declaration for createNetworkInterfaceFor (needed for recursive setup)
let createNetworkInterfaceForRef: ref<option<(t, string) => LaptopState.networkInterface>> = ref(None)

// Get or create a device state for SSH connections
// Returns the state for SSH-capable devices (Laptop, Server, Terminal)
// Also sets up the device's network interface based on its IP
let getDeviceState = (manager: t, ipAddress: string): option<LaptopState.laptopState> => {
  switch Dict.get(manager.devices, ipAddress) {
  | None => None
  | Some(device) =>
    let info = device.getInfo()
    switch info.deviceType {
    | Laptop | Server | Terminal =>
      // Check if state already exists
      switch Dict.get(manager.deviceStates, ipAddress) {
      | Some(state) => Some(state)
      | None =>
        // Create new state for this device
        let state = LaptopState.createLaptopState(~ipAddress, ~hostname=info.name, ())
        Dict.set(manager.deviceStates, ipAddress, state)
        // Set up network interface for this device
        switch createNetworkInterfaceForRef.contents {
        | Some(createNI) =>
          let ni = createNI(manager, ipAddress)
          LaptopState.setNetworkInterface(state, ni)
        | None => ()
        }
        Some(state)
      }
    | Router | Firewall | IotCamera | PowerStation | UPS => None
    }
  }
}

// Helper to check if a string looks like an IP address
let isIpAddress = (host: string): bool => {
  let parts = String.split(host, ".")
  Array.length(parts) == 4 && Array.every(parts, part => {
    switch Int.fromString(part) {
    | Some(n) => n >= 0 && n <= 255
    | None => false
    }
  })
}

// Create a network interface from the perspective of a specific device
// This is what makes SSH work correctly - each device has its own network view
let createNetworkInterfaceFor = (manager: t, sourceIp: string): LaptopState.networkInterface => {
  {
    ping: (destHost) => {
      // First try to resolve hostname if it's not an IP
      if isIpAddress(destHost) {
        // Direct IP - check reachability
        isReachableFrom(manager, sourceIp, destHost)
      } else {
        // Hostname - must resolve via DNS first
        switch resolveHostname(manager, destHost) {
        | Some(destIp) => isReachableFrom(manager, sourceIp, destIp)
        | None => false // DNS resolution failed
        }
      }
    },
    getHostInfo: (destHost) => {
      let destIpOpt = if isIpAddress(destHost) { Some(destHost) } else { resolveHostname(manager, destHost) }
      switch destIpOpt {
      | None => None // DNS resolution failed
      | Some(destIp) =>
        if isReachableFrom(manager, sourceIp, destIp) {
          switch getDeviceInfo(manager, destIp) {
          | Some(info) =>
            let typeStr = switch info.deviceType {
            | Laptop => "laptop"
            | Server => "server"
            | Router => "router"
            | Firewall => "firewall"
            | IotCamera => "camera"
            | Terminal => "terminal"
            | PowerStation => "power-station"
            | UPS => "ups"
            }
            Some((info.name, typeStr))
          | None => None
          }
        } else {
          None
        }
      }
    },
    hasSSH: (destHost) => {
      let destIpOpt = if isIpAddress(destHost) { Some(destHost) } else { resolveHostname(manager, destHost) }
      switch destIpOpt {
      | None => false // DNS resolution failed
      | Some(destIp) => isReachableFrom(manager, sourceIp, destIp) && hasSSH(manager, destIp)
      }
    },
    getAllHosts: () => getReachableHostsFrom(manager, sourceIp),
    getRemoteState: (destHost) => {
      let destIpOpt = if isIpAddress(destHost) { Some(destHost) } else { resolveHostname(manager, destHost) }
      switch destIpOpt {
      | None => None // DNS resolution failed
      | Some(destIp) =>
        if isReachableFrom(manager, sourceIp, destIp) {
          getDeviceState(manager, destIp)
        } else {
          None
        }
      }
    },
    resolveDns: (hostname) => resolveHostname(manager, hostname),
    traceRoute: (destHost) => {
      let destIpOpt = if isIpAddress(destHost) { Some(destHost) } else { resolveHostname(manager, destHost) }
      switch destIpOpt {
      | None => [] // DNS resolution failed, no route
      | Some(destIp) => getTraceRoute(manager, sourceIp, destIp)
      }
    },
  }
}

// Initialize the reference at module load time
let _ = createNetworkInterfaceForRef := Some(createNetworkInterfaceFor)
