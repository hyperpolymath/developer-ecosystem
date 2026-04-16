// SPDX-License-Identifier: PMPL-1.0-or-later
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
