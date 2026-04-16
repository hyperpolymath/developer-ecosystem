// SPDX-License-Identifier: PMPL-1.0-or-later
// Port Scanner  scan device ports and show open services
// Wired into Terminal.res as the `scan` command

// Known service mappings
type serviceInfo = {
  port: int,
  protocol: string,
  service: string,
  version: string,
}

type scanResult = {
  targetIp: string,
  openPorts: array<serviceInfo>,
  closedPorts: int,
  filteredPorts: int,
  scanDurationMs: float,
}

// Common services database
let knownServices: array<serviceInfo> = [
  {port: 22, protocol: "tcp", service: "ssh", version: "OpenSSH 9.6"},
  {port: 25, protocol: "tcp", service: "smtp", version: "Postfix 3.8"},
  {port: 53, protocol: "udp", service: "dns", version: "BIND 9.18"},
  {port: 80, protocol: "tcp", service: "http", version: "nginx 1.25"},
  {port: 110, protocol: "tcp", service: "pop3", version: "Dovecot 2.3"},
  {port: 143, protocol: "tcp", service: "imap", version: "Dovecot 2.3"},
  {port: 389, protocol: "tcp", service: "ldap", version: "OpenLDAP 2.6"},
  {port: 443, protocol: "tcp", service: "https", version: "nginx 1.25"},
  {port: 993, protocol: "tcp", service: "imaps", version: "Dovecot 2.3"},
  {port: 1194, protocol: "udp", service: "openvpn", version: "OpenVPN 2.6"},
  {port: 3306, protocol: "tcp", service: "mysql", version: "MySQL 8.0"},
  {port: 5432, protocol: "tcp", service: "postgresql", version: "PostgreSQL 16"},
  {port: 6379, protocol: "tcp", service: "redis", version: "Redis 7.2"},
  {port: 8080, protocol: "tcp", service: "http-proxy", version: "Squid 6.5"},
  {port: 8443, protocol: "tcp", service: "https-alt", version: "Tomcat 10.1"},
  {port: 27017, protocol: "tcp", service: "mongodb", version: "MongoDB 7.0"},
]

// Determine which ports are open based on device type and security level
let getOpenPorts = (deviceInfo: DeviceTypes.deviceInfo): array<serviceInfo> => {
  switch deviceInfo.deviceType {
  | Server => [knownServices[0], knownServices[3], knownServices[7]]->Array.filterMap(x => x) // ssh // http // https
  | Router => [knownServices[0], knownServices[3]]->Array.filterMap(x => x) // ssh // http
  | Firewall => [knownServices[0], knownServices[3], knownServices[7]]->Array.filterMap(x => x) // ssh // http // https (management)
  | Laptop | Terminal => [knownServices[0]]->Array.filterMap(x => x) // ssh
  | IotCamera =>
    [
      knownServices[3], // http (web interface)
      Some({port: 554, protocol: "tcp", service: "rtsp", version: "Live555"}),
    ]->Array.filterMap(x => x)
  | PowerStation | UPS =>
    [
      Some({port: 161, protocol: "udp", service: "snmp", version: "SNMPv2c"}),
      knownServices[3], // http (management)
    ]->Array.filterMap(x => x)
  }
}

// Simulate a port scan
let scan = (targetIp: string, deviceInfo: DeviceTypes.deviceInfo): scanResult => {
  let openPorts = getOpenPorts(deviceInfo)
  let startTime = %raw(`Date.now()`)
  // Simulate scan delay based on security level
  let _delay = switch deviceInfo.securityLevel {
  | Open => 50.0
  | Weak => 200.0
  | Medium => 500.0
  | Strong => 1500.0
  }
  let endTime = %raw(`Date.now()`)

  {
    targetIp,
    openPorts,
    closedPorts: 65535 - Array.length(openPorts),
    filteredPorts: switch deviceInfo.securityLevel {
    | Open => 0
    | Weak => 100
    | Medium => 500
    | Strong => 2000
    },
    scanDurationMs: endTime -. startTime +. _delay,
  }
}

// Format scan results as terminal output
let formatResult = (result: scanResult): string => {
  let header = `Starting scan of ${result.targetIp}...\n`
  let portLines =
    result.openPorts
    ->Array.map(svc => {
      let portStr = `${Int.toString(svc.port)}/${svc.protocol}`
      `  ${portStr->String.padEnd(10, " ")}  open   ${svc.service->String.padEnd(
          12,
          " ",
        )}  ${svc.version}`
    })
    ->Array.join("\n")

  let summary = `\nPorts: ${Int.toString(Array.length(result.openPorts))} open, ${Int.toString(
      result.closedPorts,
    )} closed, ${Int.toString(result.filteredPorts)} filtered`
  let timing = `Scan completed in ${Int.toString(Float.toInt(result.scanDurationMs))}ms`

  `${header}\nPORT        STATE  SERVICE       VERSION\n${portLines}\n${summary}\n${timing}`
}
