// SPDX-License-Identifier: PMPL-1.0-or-later
// Standalone Terminal Device

open Pixi
open DeviceTypes

type t = {
  name: string,
  ipAddress: string,
  securityLevel: securityLevel,
}

let make = (~name: string, ~ipAddress: string, ~securityLevel: securityLevel, ()): t => {
  name,
  ipAddress,
  securityLevel,
}

let getInfo = (device: t): deviceInfo => {
  name: device.name,
  deviceType: Terminal,
  ipAddress: device.ipAddress,
  securityLevel: device.securityLevel,
}

// Terminal device states (like laptops, not servers)
module TerminalStates = {
  let states: dict<LaptopState.laptopState> = Dict.make()

  let register = (ip: string, state: LaptopState.laptopState): unit => {
    Dict.set(states, ip, state)
    state.bootTime = %raw(`Date.now()`)
  }

  let get = (ip: string): option<LaptopState.laptopState> => {
    Dict.get(states, ip)
  }
}

let openGUI = (device: t): DeviceWindow.t => {
  let win = DeviceWindow.make(
    ~title=`TERMINAL - ${device.name} [${device.ipAddress}]`,
    ~width=500.0,
    ~height=400.0,
    ~titleBarColor=getDeviceColor(Terminal),
    ~backgroundColor=0x000000,
    (),
  )

  // Get or create terminal state (like a laptop, not a server)
  let state = switch TerminalStates.get(device.ipAddress) {
  | Some(s) => s
  | None =>
    let newState = LaptopState.createLaptopState(
      ~ipAddress=device.ipAddress,
      ~hostname=device.name,
      ~isServer=false,
      (),
    )
    TerminalStates.register(device.ipAddress, newState)
    newState
  }

  let terminal = Terminal.make(
    ~width=490.0,
    ~height=360.0,
    ~prompt=`${device.name}> `,
    ~ipAddress=device.ipAddress,
    ~deviceState=state,
    (),
  )
  let _ = Container.addChild(DeviceWindow.getContent(win), terminal.container)

  win
}

// Create device interface
let toDevice = (t: t): device => {
  getInfo: () => getInfo(t),
  openGUI: () => openGUI(t),
}
