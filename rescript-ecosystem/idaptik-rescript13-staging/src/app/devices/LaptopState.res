// SPDX-License-Identifier: PMPL-1.0-or-later
// Shared Laptop State - Process Manager Only
// Filesystem moved to GlobalNetworkData for unified architecture
// Uses unified Storage model (Gq) - inspired by Uplink

// ============================================
// Service Manager - Maps services to processes
// ============================================

module ServiceManager = {
  type serviceType =
    | SSH // Port 22, process: sshd.exe
    | HTTP // Port 80, process: httpd.exe
    | RDP // Port 3389, process: rdp-svc.exe
    | Desktop // Desktop environment: explorer.exe, dwm.exe
    | Security // Security monitor: secmon.exe

  type serviceInfo = {
    serviceType: serviceType,
    processName: string,
    port: option<int>,
    cpuPercent: float,
    sizeGq: int,
  }

  // Service definitions
  let serviceDefinitions = [
    {serviceType: SSH, processName: "sshd.exe", port: Some(22), cpuPercent: 0.3, sizeGq: 1},
    {serviceType: HTTP, processName: "httpd.exe", port: Some(80), cpuPercent: 0.8, sizeGq: 2},
    {serviceType: RDP, processName: "rdp-svc.exe", port: Some(3389), cpuPercent: 0.5, sizeGq: 1},
    {serviceType: Desktop, processName: "explorer.exe", port: None, cpuPercent: 1.5, sizeGq: 2},
    {serviceType: Desktop, processName: "dwm.exe", port: None, cpuPercent: 1.2, sizeGq: 1},
    {serviceType: Security, processName: "secmon.exe", port: None, cpuPercent: 0.5, sizeGq: 1},
  ]

  // Global registry: ipAddress -> serviceType -> bool (running)
  let runningServices: dict<dict<bool>> = Dict.make()

  // Get device services dict
  let getDeviceServices = (ip: string): dict<bool> => {
    switch Dict.get(runningServices, ip) {
    | Some(services) => services
    | None =>
      let services = Dict.make()
      Dict.set(runningServices, ip, services)
      services
    }
  }

  // Service type to string key
  let serviceTypeToKey = (st: serviceType): string => {
    switch st {
    | SSH => "ssh"
    | HTTP => "http"
    | RDP => "rdp"
    | Desktop => "desktop"
    | Security => "security"
    }
  }

  // Check if a service is running
  let isServiceRunning = (ip: string, service: serviceType): bool => {
    let services = getDeviceServices(ip)
    let key = serviceTypeToKey(service)
    switch Dict.get(services, key) {
    | Some(running) => running
    | None => false
    }
  }

  // Start a service
  let startService = (ip: string, service: serviceType): unit => {
    let services = getDeviceServices(ip)
    let key = serviceTypeToKey(service)
    Dict.set(services, key, true)
  }

  // Stop a service
  let stopService = (ip: string, service: serviceType): unit => {
    let services = getDeviceServices(ip)
    let key = serviceTypeToKey(service)
    Dict.set(services, key, false)
  }

  // Get all running service processes for a device
  let getRunningServiceProcesses = (ip: string): array<(string, float, int)> => {
    let services = getDeviceServices(ip)
    let runningProcs = []

    Array.forEach(serviceDefinitions, def => {
      let key = serviceTypeToKey(def.serviceType)
      let isRunning = switch Dict.get(services, key) {
      | Some(true) => true
      | _ => false
      }

      if isRunning {
        let _ = Array.push(runningProcs, (def.processName, def.cpuPercent, def.sizeGq))
      }
    })

    runningProcs
  }

  // Check if a port is open (service running on that port)
  let isPortOpen = (ip: string, port: int): bool => {
    let services = getDeviceServices(ip)

    // Find service definition with matching port
    let matchingService = Array.find(serviceDefinitions, def => {
      switch def.port {
      | Some(p) => p == port
      | None => false
      }
    })

    switch matchingService {
    | Some(def) =>
      let key = serviceTypeToKey(def.serviceType)
      switch Dict.get(services, key) {
      | Some(running) => running
      | None => false
      }
    | None => false
    }
  }

  // Initialize default services for a device
  let initializeServices = (ip: string, ~isServer: bool): unit => {
    if isServer {
      // Servers auto-start: SSH, HTTP, Security
      startService(ip, SSH)
      startService(ip, HTTP)
      startService(ip, Security)
    } else {
      // Laptops auto-start: Desktop, Security
      startService(ip, Desktop)
      startService(ip, Security)
      // SSH optional on laptops
    }
  }
}

// ============================================
// Process Manager Types and Implementation
// Unified Storage Model (Gq)
// ============================================

type processInfo = {
  pid: int,
  name: string,
  mutable cpuPercent: float,
  sizeGq: int, // Storage used by this process in Gq
  isSystem: bool,
}

type systemSpec = {
  totalStorageGq: int, // Total storage in Gq
  cpuCores: int,
}

type processManager = {
  spec: systemSpec,
  mutable nextPid: int,
  mutable processes: array<processInfo>,
  mutable openApps: dict<int>, // app name -> pid
  mutable windowClosers: dict<unit => unit>, // pid -> close callback
  mutable cpuSpike: float, // Temporary CPU spike from commands
  mutable lastSpikeTime: float, // For decay calculation
}

// Create process manager with system specs
let createProcessManager = (): processManager => {
  let spec = {
    totalStorageGq: 8192, // 8192 Gq total storage
    cpuCores: 4,
  }

  // Only core OS processes - no services yet
  // Services will be added dynamically based on ServiceManager state
  let coreProcesses = [
    {pid: 1, name: "System", cpuPercent: 0.5, sizeGq: 1, isSystem: true},
    {pid: 4, name: "smss.exe", cpuPercent: 0.1, sizeGq: 1, isSystem: true},
    {pid: 128, name: "csrss.exe", cpuPercent: 0.2, sizeGq: 1, isSystem: true},
    {pid: 256, name: "services.exe", cpuPercent: 0.3, sizeGq: 1, isSystem: true},
    {pid: 512, name: "lsass.exe", cpuPercent: 0.2, sizeGq: 1, isSystem: true},
    {pid: 768, name: "svchost.exe", cpuPercent: 0.8, sizeGq: 1, isSystem: true},
  ]

  {
    spec,
    nextPid: 1024, // Start service PIDs from here
    processes: coreProcesses,
    openApps: Dict.make(),
    windowClosers: Dict.make(),
    cpuSpike: 0.0,
    lastSpikeTime: 0.0,
  }
}

// Sync process list with running services (call this periodically)
let syncServicesWithProcesses = (pm: processManager, ipAddress: string): unit => {
  // Get running service processes from ServiceManager
  let runningServiceProcs = ServiceManager.getRunningServiceProcesses(ipAddress)

  // Remove service processes that are no longer running
  pm.processes = Array.filter(pm.processes, proc => {
    // Keep core OS processes (PID < 1024)
    if proc.pid < 1024 {
      true
    } else {
      // Keep user apps (in openApps)
      let isUserApp = Dict.toArray(pm.openApps)->Array.some(((_, pid)) => pid == proc.pid)
      if isUserApp {
        true
      } else {
        // Check if this service process is still running
        Array.some(runningServiceProcs, ((name, _, _)) => name == proc.name)
      }
    }
  })

  // Add service processes that aren't in the list yet
  Array.forEach(runningServiceProcs, ((processName, cpuPercent, sizeGq)) => {
    let alreadyExists = Array.some(pm.processes, proc => proc.name == processName)
    if !alreadyExists {
      let pid = pm.nextPid
      pm.nextPid = pm.nextPid + 1
      let proc = {
        pid,
        name: processName,
        cpuPercent,
        sizeGq,
        isSystem: true,
      }
      pm.processes = Array.concat(pm.processes, [proc])
    }
  })
}

// App storage requirements (in Gq) - all basic apps are 1-2 Gq
let appSize = (appName: string): int => {
  switch appName {
  | "explorer.exe" => 2 // File Manager
  | "notepad.exe" => 1 // Notepad
  | "netman.exe" => 1 // Network Manager
  | "taskmgr.exe" => 1 // Process Explorer
  | "cmd.exe" => 1 // Terminal
  | "recyclebin.exe" => 1 // Recycle Bin
  | _ => 1
  }
}

// Open an application (returns pid)
let openApp = (pm: processManager, appName: string): int => {
  // Check if already open
  switch Dict.get(pm.openApps, appName) {
  | Some(pid) => pid
  | None =>
    let pid = pm.nextPid
    pm.nextPid = pm.nextPid + 1

    // Base CPU usage for app (low, will spike with activity)
    let cpuPercent = 0.3 +. Int.toFloat(mod(pid, 10)) /. 20.0

    let process = {
      pid,
      name: appName,
      cpuPercent,
      sizeGq: appSize(appName),
      isSystem: false,
    }

    pm.processes = Array.concat(pm.processes, [process])
    Dict.set(pm.openApps, appName, pid)
    pid
  }
}

// Register a window closer callback for a PID
let registerWindowCloser = (pm: processManager, pid: int, closer: unit => unit): unit => {
  Dict.set(pm.windowClosers, Int.toString(pid), closer)
}

// Close an application
let closeApp = (pm: processManager, appName: string): unit => {
  switch Dict.get(pm.openApps, appName) {
  | None => ()
  | Some(pid) =>
    pm.processes = Array.filter(pm.processes, p => p.pid != pid)
    Dict.delete(pm.openApps, appName)
    Dict.delete(pm.windowClosers, Int.toString(pid))
  }
}

// Map process name to service type
let processNameToService = (processName: string): option<ServiceManager.serviceType> => {
  switch processName {
  | "sshd.exe" => Some(SSH)
  | "httpd.exe" => Some(HTTP)
  | "rdp-svc.exe" => Some(RDP)
  | "explorer.exe" | "dwm.exe" => Some(Desktop)
  | "secmon.exe" => Some(Security)
  | _ => None
  }
}

// Kill a process by PID
let killProcess = (pm: processManager, pid: int, ipAddress: string): result<unit, string> => {
  switch Array.find(pm.processes, p => p.pid == pid) {
  | None => Error(`No such process: ${Int.toString(pid)}`)
  | Some(proc) =>
    // Check if it's a core OS process (PID < 1024, excluding service processes)
    let isCoreOS = proc.pid < 1024 && processNameToService(proc.name) == None

    if isCoreOS {
      Error(`Cannot kill core OS process: ${proc.name}`)
    } else {
      // If it's a service process, stop the service
      switch processNameToService(proc.name) {
      | Some(serviceType) => ServiceManager.stopService(ipAddress, serviceType)
      | None => ()
      }

      // Call the window closer if registered
      switch Dict.get(pm.windowClosers, Int.toString(pid)) {
      | Some(closer) => closer()
      | None => ()
      }

      pm.processes = Array.filter(pm.processes, p => p.pid != pid)

      // Also remove from openApps if it's there
      Dict.toArray(pm.openApps)->Array.forEach(((name, appPid)) => {
        if appPid == pid {
          Dict.delete(pm.openApps, name)
        }
      })
      Dict.delete(pm.windowClosers, Int.toString(pid))
      Ok()
    }
  }
}

// Get all processes
let getProcesses = (pm: processManager): array<processInfo> => pm.processes

// Get storage usage from processes only
let getProcessStorageUsage = (pm: processManager): int => {
  Array.reduce(pm.processes, 0, (acc, p) => acc + p.sizeGq)
}

// Get total storage usage (processes + files from DeviceView)
let getTotalStorageUsage = (pm: processManager, ipAddress: string): (int, int) => {
  let processUsage = getProcessStorageUsage(pm)

  // Get file storage from device filesystem (in MB)
  let fileUsageMB = DeviceView.getTotalStorageUsed(ipAddress)
  // Convert MB to Gq (rough conversion: 100MB ~ 1Gq)
  let fileUsageGq = Float.toInt(fileUsageMB /. 100.0)
  let fileUsageGq = if fileUsageGq < 1 {
    1
  } else {
    fileUsageGq
  }

  (processUsage + fileUsageGq, pm.spec.totalStorageGq)
}

// Add CPU spike (called when running commands)
let addCpuSpike = (pm: processManager, amount: float): unit => {
  pm.cpuSpike = pm.cpuSpike +. amount

  // Cap at reasonable max
  if pm.cpuSpike > 50.0 {
    pm.cpuSpike = 50.0
  }
}

// Update CPU spike decay (call this periodically, e.g., every frame)
let updateCpuSpike = (pm: processManager, deltaSeconds: float): unit => {
  // Decay spike over time (lose ~20% per second)
  pm.cpuSpike = pm.cpuSpike *. (1.0 -. deltaSeconds *. 2.0)
  if pm.cpuSpike < 0.1 {
    pm.cpuSpike = 0.0
  }
}

// Get CPU usage (base + spike)
let getCpuUsage = (pm: processManager): float => {
  let base = Array.reduce(pm.processes, 0.0, (acc, p) => acc +. p.cpuPercent)
  let total = base +. pm.cpuSpike
  let maxCpu = Int.toFloat(pm.spec.cpuCores) *. 100.0
  if total < maxCpu {
    total
  } else {
    maxCpu
  }
}

// ============================================
// Global Laptop State
// ============================================

// Forward declaration for SSH session support
type rec laptopState = {
  processManager: processManager,
  mutable commandHistory: array<string>,
  mutable loginHistory: array<(string, string)>, // (user, timestamp)
  mutable currentUser: string,
  mutable bootTime: float,
  mutable ipAddress: string,
  mutable hostname: string,
  mutable networkInterface: option<networkInterface>,
  networkDevices: dict<DeviceTypes.device>,
}

// Network interface for terminal commands
and networkInterface = {
  ping: string => bool, // Returns true if host is reachable
  getHostInfo: string => option<(string, string)>, // Returns (hostname, deviceType)
  hasSSH: string => bool, // Returns true if host has SSH
  getAllHosts: unit => array<string>, // Returns all IPs on the network
  getRemoteState: string => option<laptopState>, // Get remote device state for SSH
  resolveDns: string => option<string>, // Resolve hostname to IP
  traceRoute: string => array<(string, string, int)>, // Get trace route to destination (ip, name, latency)
}

// Create a new laptop state with configurable IP and hostname
let createLaptopState = (
  ~ipAddress: string="192.168.1.102",
  ~hostname: string="WORKSTATION-PC",
  ~isServer: bool=false,
  (),
): laptopState => {
  // Initialize services for this device
  ServiceManager.initializeServices(ipAddress, ~isServer)

  // Create process manager
  let pm = createProcessManager()

  // Sync processes with running services
  syncServicesWithProcesses(pm, ipAddress)

  {
    processManager: pm,
    commandHistory: [],
    loginHistory: [("Admin", "Dec 07 22:15:32"), ("Admin", "Dec 06 10:23:01")],
    currentUser: "Admin",
    bootTime: 0.0, // Will be set when system "boots"
    ipAddress,
    hostname,
    networkInterface: None,
    networkDevices: Dict.make(),
  }
}

// Set the network interface (called after NetworkManager is available)
let setNetworkInterface = (state: laptopState, ni: networkInterface): unit => {
  state.networkInterface = Some(ni)
}

// Add command to history
let addToHistory = (state: laptopState, cmd: string): unit => {
  state.commandHistory = Array.concat(state.commandHistory, [cmd])
}

// Clear command history
let clearHistory = (state: laptopState): unit => {
  state.commandHistory = []
}

// Get command history
let getHistory = (state: laptopState): array<string> => state.commandHistory
