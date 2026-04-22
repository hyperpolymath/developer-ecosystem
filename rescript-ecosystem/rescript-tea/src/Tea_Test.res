@@ocaml.doc("
Testing utilities for TEA applications.
Allows testing update functions in isolation without mounting components.
")

// ============================================================================
// Model simulation
// ============================================================================

@ocaml.doc("
Simulate running update with a sequence of messages.
Returns the final model after processing all messages.

Example:
```rescript
let finalModel = Tea_Test.simulate(
  ~init=MyApp.init,
  ~update=MyApp.update,
  ~msgs=[Increment, Increment, Decrement],
)
```
")
let simulate = (
  ~init: unit => ('model, Tea_Cmd.t<'msg>),
  ~update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  ~msgs: array<'msg>,
): 'model => {
  let (initialModel, _) = init()
  Belt.Array.reduce(msgs, initialModel, (model, msg) => {
    let (newModel, _) = update(msg, model)
    newModel
  })
}

@ocaml.doc("
Simulate with flags.
")
let simulateWithFlags = (
  ~init: 'flags => ('model, Tea_Cmd.t<'msg>),
  ~update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  ~flags: 'flags,
  ~msgs: array<'msg>,
): 'model => {
  let (initialModel, _) = init(flags)
  Belt.Array.reduce(msgs, initialModel, (model, msg) => {
    let (newModel, _) = update(msg, model)
    newModel
  })
}

// ============================================================================
// Command collection
// ============================================================================

@ocaml.doc("
Collect all commands produced while processing a sequence of messages.
Useful for verifying that the right side effects are triggered.

Example:
```rescript
let cmds = Tea_Test.collectCmds(
  ~init=MyApp.init,
  ~update=MyApp.update,
  ~msgs=[FetchUser(\"alice\")],
)
// cmds contains the HTTP command that would be executed
```
")
let collectCmds = (
  ~init: unit => ('model, Tea_Cmd.t<'msg>),
  ~update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  ~msgs: array<'msg>,
): array<Tea_Cmd.t<'msg>> => {
  let (initialModel, initialCmd) = init()
  let (_, cmds) = Belt.Array.reduce(msgs, (initialModel, [initialCmd]), ((model, cmds), msg) => {
    let (newModel, cmd) = update(msg, model)
    (newModel, Belt.Array.concat(cmds, [cmd]))
  })
  cmds
}

// ============================================================================
// Step-by-step simulation
// ============================================================================

@ocaml.doc("Result of a single update step")
type step<'model, 'msg> = {
  model: 'model,
  cmd: Tea_Cmd.t<'msg>,
}

@ocaml.doc("
Run a single update step and return both the model and command.
")
let step = (
  ~update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  ~model: 'model,
  ~msg: 'msg,
): step<'model, 'msg> => {
  let (newModel, cmd) = update(msg, model)
  {model: newModel, cmd}
}

@ocaml.doc("
Run multiple steps, returning all intermediate results.
")
let steps = (
  ~init: unit => ('model, Tea_Cmd.t<'msg>),
  ~update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  ~msgs: array<'msg>,
): array<step<'model, 'msg>> => {
  let (initialModel, initialCmd) = init()
  let initialStep = {model: initialModel, cmd: initialCmd}
  let (_, allSteps) = Belt.Array.reduce(msgs, (initialModel, [initialStep]), ((model, steps), msg) => {
    let (newModel, cmd) = update(msg, model)
    let step = {model: newModel, cmd}
    (newModel, Belt.Array.concat(steps, [step]))
  })
  allSteps
}

// ============================================================================
// Assertions
// ============================================================================

@ocaml.doc("
Assert that a model satisfies a predicate. Throws if not.
")
let expectModel = (model: 'model, predicate: 'model => bool, message: string): unit => {
  if !predicate(model) {
    Js.Exn.raiseError(`Assertion failed: ${message}`)
  }
}

@ocaml.doc("
Assert that two values are equal. Throws if not.
")
let assertEqual = (actual: 'a, expected: 'a, message: string): unit => {
  if actual != expected {
    Js.Exn.raiseError(`Assertion failed: ${message}`)
  }
}

// ============================================================================
// Command inspection (limited - commands are opaque by design)
// ============================================================================

@ocaml.doc("
Check if a command is none (no-op).
")
let isNone = (cmd: Tea_Cmd.t<'msg>): bool => {
  // Use internal representation check
  Obj.magic(cmd) === Obj.magic(Tea_Cmd.none)
}

@ocaml.doc("
Check if a command is a batch.
")
let isBatch = (cmd: Tea_Cmd.t<'msg>): bool => {
  // Peek at internal structure
  let internal: {"TAG": int} = Obj.magic(cmd)
  switch Js.typeof(internal) {
  | "object" =>
    switch internal["TAG"] {
    | 1 => true // Batch tag
    | _ => false
    }
  | _ => false
  }
}
