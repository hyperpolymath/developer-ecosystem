// SPDX-License-Identifier: MPL-2.0
// Global singleton for NetworkManager
// Ensures WorldScreen and NetworkDesktop share the same device state

let instance: ref<option<NetworkManager.t>> = ref(None)

let get = (): NetworkManager.t => {
  switch instance.contents {
  | Some(nm) => nm
  | None =>
    let nm = NetworkManager.make()
    instance := Some(nm)
    nm
  }
}

// Reset the network (for testing or new game)
let reset = (): unit => {
  instance := None
}
