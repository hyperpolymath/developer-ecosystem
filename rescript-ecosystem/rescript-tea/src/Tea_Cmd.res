@@ocaml.doc("
Commands represent side effects to be performed by the runtime.
They are pure descriptions of work to do, not the work itself.
")

@ocaml.doc("The command type - abstract to users")
type rec t<'msg> =
  | None
  | Batch(array<t<'msg>>)
  | Effect(('msg => unit) => unit)

@ocaml.doc("A command that does nothing")
let none: t<'msg> = None

@ocaml.doc("Combine multiple commands into one")
let batch = (cmds: array<t<'msg>>): t<'msg> => {
  // Filter out None commands for efficiency
  let filtered = Belt.Array.keep(cmds, cmd =>
    switch cmd {
    | None => false
    | Batch(_) | Effect(_) => true
    }
  )
  switch Belt.Array.length(filtered) {
  | 0 => None
  | 1 => Belt.Array.getExn(filtered, 0)
  | _ => Batch(filtered)
  }
}

@ocaml.doc("Create a command from an async operation that cannot fail")
let perform = (operation: unit => Js.Promise.t<'a>, toMsg: 'a => 'msg): t<'msg> => {
  Effect(
    dispatch => {
      let _ = Js.Promise.then_(value => {
        dispatch(toMsg(value))
        Js.Promise.resolve()
      }, operation())
    },
  )
}

@ocaml.doc("Create a command from an async operation that might fail")
let attempt = (
  operation: unit => Js.Promise.t<'a>,
  toMsg: result<'a, exn> => 'msg,
): t<'msg> => {
  Effect(
    dispatch => {
      let _ =
        operation()
        ->Js.Promise.then_(value => {
          dispatch(toMsg(Ok(value)))
          Js.Promise.resolve()
        }, _)
        ->Js.Promise.catch(err => {
          let exn = Js.Exn.anyToExnInternal(err)
          dispatch(toMsg(Error(exn)))
          Js.Promise.resolve()
        }, _)
    },
  )
}

@ocaml.doc("Transform the message type of a command")
let rec map = (f: 'a => 'b, cmd: t<'a>): t<'b> => {
  switch cmd {
  | None => None
  | Batch(cmds) => Batch(Belt.Array.map(cmds, c => map(f, c)))
  | Effect(effect) =>
    Effect(dispatch => effect(a => dispatch(f(a))))
  }
}

@ocaml.doc("Internal: Execute a command with a dispatch function")
let rec execute = (cmd: t<'msg>, dispatch: 'msg => unit): unit => {
  switch cmd {
  | None => ()
  | Batch(cmds) => Belt.Array.forEach(cmds, c => execute(c, dispatch))
  | Effect(effect) =>
    // Execute asynchronously to not block rendering
    let _ = Js.Global.setTimeout(() => effect(dispatch), 0)
  }
}

@ocaml.doc("Create a command that dispatches a message immediately (for internal use)")
let message = (msg: 'msg): t<'msg> => {
  Effect(dispatch => dispatch(msg))
}
