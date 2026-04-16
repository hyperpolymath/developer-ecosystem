// SPDX-License-Identifier: PMPL-1.0-or-later
// Desktop/Laptop Computer Device

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
  deviceType: Laptop,
  ipAddress: device.ipAddress,
  securityLevel: device.securityLevel,
}

// Global network interface setter (set by NetworkDesktop)
// Uses a callback to avoid circular dependency with NetworkManager
let globalNetworkInterfaceSetter: ref<option<LaptopState.laptopState => unit>> = ref(None)

let setGlobalNetworkInterfaceSetter = (setter: LaptopState.laptopState => unit): unit => {
  globalNetworkInterfaceSetter := Some(setter)
}

// Global state getter - retrieves shared state from NetworkManager
let globalStateGetter: ref<option<string => option<LaptopState.laptopState>>> = ref(None)

let setGlobalStateGetter = (getter: string => option<LaptopState.laptopState>): unit => {
  globalStateGetter := Some(getter)
}

let openGUI = (device: t): DeviceWindow.t => {
  let win = DeviceWindow.make(
    ~title=`LAPTOP - ${device.name} [${device.ipAddress}]`,
    ~width=500.0,
    ~height=400.0,
    ~titleBarColor=getDeviceColor(Laptop),
    ~backgroundColor=0x2b5797,
    (),
  )

  // Try to get existing state from NetworkManager, or create new one
  let state = switch globalStateGetter.contents {
  | Some(getter) => getter(device.ipAddress)
  | None => None
  }

  let laptop = switch state {
  | Some(existingState) =>
    // Use existing state - creates GUI with shared state
    LaptopGUI.makeWithState(~width=490.0, ~height=360.0, ~state=existingState, ())
  | None =>
    // Fallback: create new state (shouldn't happen with proper setup)
    let newLaptop = LaptopGUI.make(
      ~width=490.0,
      ~height=360.0,
      ~ipAddress=device.ipAddress,
      ~hostname=device.name,
      (),
    )
    // Set up network interface if setter is available
    switch globalNetworkInterfaceSetter.contents {
    | Some(setter) => setter(newLaptop.state)
    | None => ()
    }
    newLaptop
  }

  let _ = Pixi.Container.addChild(DeviceWindow.getContent(win), laptop.container)

  win
}

// Create device interface
let toDevice = (t: t): device => {
  getInfo: () => getInfo(t),
  openGUI: () => openGUI(t),
}
