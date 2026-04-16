// SPDX-License-Identifier: PMPL-1.0-or-later
// Engine singleton getter for ReScript

let instance: ref<option<Engine.t>> = ref(None)

// Get the main application engine
let get = (): option<Engine.t> => instance.contents

// Set the engine instance
let set = (engine: Engine.t): unit => {
  instance := Some(engine)
}
