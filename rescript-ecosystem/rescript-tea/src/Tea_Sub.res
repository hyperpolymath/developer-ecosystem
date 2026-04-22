@@ocaml.doc("
Subscriptions declare external event sources the application listens to.
They are diffed on each update - only changed subscriptions are re-subscribed.
")

// ============================================================================
// Raw DOM bindings (to avoid external dependencies)
// ============================================================================

module Window = {
  @val external window: Dom.window = "window"
  @send external addEventListener: (Dom.window, string, 'a => unit) => unit = "addEventListener"
  @send
  external removeEventListener: (Dom.window, string, 'a => unit) => unit = "removeEventListener"
  @get external innerWidth: Dom.window => int = "innerWidth"
  @get external innerHeight: Dom.window => int = "innerHeight"
}

module KeyboardEvent = {
  @get external key: 'a => string = "key"
}

module MouseEvent = {
  @get external clientX: 'a => int = "clientX"
  @get external clientY: 'a => int = "clientY"
}

// ============================================================================
// Types
// ============================================================================

@ocaml.doc("Internal subscription representation")
type internal<'msg> = {
  key: string,
  setup: ('msg => unit) => option<unit => unit>,
}

@ocaml.doc("The subscription type")
type rec t<'msg> =
  | None
  | Batch(array<t<'msg>>)
  | Sub(internal<'msg>)

// ============================================================================
// Core functions
// ============================================================================

@ocaml.doc("A subscription that does nothing")
let none: t<'msg> = None

@ocaml.doc("Combine multiple subscriptions into one")
let batch = (subs: array<t<'msg>>): t<'msg> => {
  let filtered = Belt.Array.keep(subs, sub =>
    switch sub {
    | None => false
    | Batch(_) | Sub(_) => true
    }
  )
  switch Belt.Array.length(filtered) {
  | 0 => None
  | 1 => Belt.Array.getExn(filtered, 0)
  | _ => Batch(filtered)
  }
}

@ocaml.doc("Transform the message type of a subscription")
let rec map = (f: 'a => 'b, sub: t<'a>): t<'b> => {
  switch sub {
  | None => None
  | Batch(subs) => Batch(Belt.Array.map(subs, s => map(f, s)))
  | Sub(internal) =>
    Sub({
      key: internal.key,
      setup: dispatch => internal.setup(a => dispatch(f(a))),
    })
  }
}

@ocaml.doc("Internal: Convert subscription tree to flat array of internals")
let rec toInternals = (sub: t<'msg>): array<internal<'msg>> => {
  switch sub {
  | None => []
  | Sub(internal) => [internal]
  | Batch(subs) => Belt.Array.flatMap(subs, toInternals)
  }
}

// ============================================================================
// Time subscriptions
// ============================================================================

module Time = {
  @ocaml.doc("Subscribe to time updates at a given interval (in milliseconds)")
  let every = (intervalMs: int, toMsg: float => 'msg): t<'msg> => {
    Sub({
      key: `time-every-${Belt.Int.toString(intervalMs)}`,
      setup: dispatch => {
        let id = Js.Global.setInterval(() => {
          dispatch(toMsg(Js.Date.now()))
        }, intervalMs)
        Some(() => Js.Global.clearInterval(id))
      },
    })
  }
}

// ============================================================================
// Keyboard subscriptions
// ============================================================================

module Keyboard = {
  @ocaml.doc("Subscribe to keyboard key down events")
  let downs = (toMsg: string => 'msg): t<'msg> => {
    Sub({
      key: "keyboard-downs",
      setup: dispatch => {
        let handler = event => {
          let key = KeyboardEvent.key(event)
          dispatch(toMsg(key))
        }
        Window.window->Window.addEventListener("keydown", handler)
        Some(() => Window.window->Window.removeEventListener("keydown", handler))
      },
    })
  }

  @ocaml.doc("Subscribe to keyboard key up events")
  let ups = (toMsg: string => 'msg): t<'msg> => {
    Sub({
      key: "keyboard-ups",
      setup: dispatch => {
        let handler = event => {
          let key = KeyboardEvent.key(event)
          dispatch(toMsg(key))
        }
        Window.window->Window.addEventListener("keyup", handler)
        Some(() => Window.window->Window.removeEventListener("keyup", handler))
      },
    })
  }
}

// ============================================================================
// Mouse subscriptions
// ============================================================================

module Mouse = {
  @ocaml.doc("Subscribe to mouse click events")
  let clicks = (toMsg: ((int, int)) => 'msg): t<'msg> => {
    Sub({
      key: "mouse-clicks",
      setup: dispatch => {
        let handler = event => {
          let x = MouseEvent.clientX(event)
          let y = MouseEvent.clientY(event)
          dispatch(toMsg((x, y)))
        }
        Window.window->Window.addEventListener("click", handler)
        Some(() => Window.window->Window.removeEventListener("click", handler))
      },
    })
  }

  @ocaml.doc("Subscribe to mouse move events")
  let moves = (toMsg: ((int, int)) => 'msg): t<'msg> => {
    Sub({
      key: "mouse-moves",
      setup: dispatch => {
        let handler = event => {
          let x = MouseEvent.clientX(event)
          let y = MouseEvent.clientY(event)
          dispatch(toMsg((x, y)))
        }
        Window.window->Window.addEventListener("mousemove", handler)
        Some(() => Window.window->Window.removeEventListener("mousemove", handler))
      },
    })
  }
}

// ============================================================================
// Browser window subscriptions
// ============================================================================

module BrowserWindow = {
  @ocaml.doc("Subscribe to window resize events")
  let resizes = (toMsg: ((int, int)) => 'msg): t<'msg> => {
    Sub({
      key: "window-resizes",
      setup: dispatch => {
        let handler = _event => {
          let width = Window.window->Window.innerWidth
          let height = Window.window->Window.innerHeight
          dispatch(toMsg((width, height)))
        }
        Window.window->Window.addEventListener("resize", handler)
        Some(() => Window.window->Window.removeEventListener("resize", handler))
      },
    })
  }
}
