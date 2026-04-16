// SPDX-License-Identifier: PMPL-1.0-or-later
// Factory for creating device instances

open DeviceTypes

let createDevice = (
  ~deviceType: deviceType,
  ~name: string,
  ~ipAddress: string,
  ~securityLevel: securityLevel,
  ~worldX: float=0.0,
  ~connectedStationIp: string="192.168.1.250",
): device => {
  switch deviceType {
  | Laptop =>
    let d = DesktopDevice.make(~name, ~ipAddress, ~securityLevel, ())
    DesktopDevice.toDevice(d)
  | Router =>
    let d = RouterDevice.make(~name, ~ipAddress, ~securityLevel, ())
    RouterDevice.toDevice(d)
  | Server =>
    let d = ServerDevice.make(~name, ~ipAddress, ~securityLevel, ())
    ServerDevice.toDevice(d)
  | IotCamera =>
    let d = CameraDevice.make(~name, ~ipAddress, ~securityLevel, ~worldX, ())
    CameraDevice.toDevice(d)
  | Terminal =>
    let d = TerminalDevice.make(~name, ~ipAddress, ~securityLevel, ())
    TerminalDevice.toDevice(d)
  | PowerStation =>
    let d = PowerStationDevice.make(~name, ~ipAddress, ~securityLevel, ())
    PowerStationDevice.toDevice(d)
  | UPS =>
    let d = UPSDevice.make(~name, ~ipAddress, ~securityLevel, ~connectedStationIp, ())
    UPSDevice.toDevice(d)
  | Firewall =>
    let d = FirewallDevice.make(~name, ~ipAddress, ~securityLevel, ())
    FirewallDevice.toDevice(d)
  }
}
