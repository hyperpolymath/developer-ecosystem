// SPDX-License-Identifier: MPL-2.0 AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
Subscriptions declare external event sources the application listens to.
They are diffed on each update - only changed subscriptions are re-subscribed.
")

// ============================================================================
// Raw DOM bindings
// ============================================================================

module Window = {
  @val external window: Dom.window = "window"
  @send external addEventListener: (Dom.window, string, 'a => unit) => unit = "addEventListener"
  @send
  external removeEventListener: (Dom.window, string, 'a => unit) => unit = "removeEventListener"
  @get external innerWidth: Dom.window => int = "innerWidth"
  @get external innerHeight: Dom.window => int = "innerHeight"
}

// ============================================================================
// Types
// ============================================================================

@ocaml.doc("Internal subscription representation - for runtime use")
type internal<'msg> = {
  key: string,
  setup: ('msg => unit) => option<unit => unit>,
}

@ocaml.doc("The subscription type")
type rec t<'msg> =
  | NoSub
  | Batch(array<t<'msg>>)
  | SingleSub(internal<'msg>)

// ============================================================================
// Core functions
// ============================================================================

@ocaml.doc("A subscription that does nothing")
let none: t<'msg> = NoSub

@ocaml.doc("Combine multiple subscriptions into one")
let batch = (subs: array<t<'msg>>): t<'msg> => {
  let filtered = Belt.Array.keep(subs, sub =>
    switch sub {
    | NoSub => false
    | Batch(_) | SingleSub(_) => true
    }
  )

  if Belt.Array.length(filtered) == 0 {
    NoSub
  } else if Belt.Array.length(filtered) == 1 {
    Belt.Array.getExn(filtered, 0)
  } else {
    Batch(filtered)
  }
}

@ocaml.doc("Transform the message type of a subscription")
let rec map = (f: 'a => 'b, sub: t<'a>): t<'b> => {
  switch sub {
  | NoSub => NoSub
  | Batch(subs) => Batch(Belt.Array.map(subs, map(f, _)))
  | SingleSub(internal) =>
    SingleSub({
      key: internal.key,
      setup: dispatch => internal.setup(msg => dispatch(f(msg))),
    })
  }
}

@ocaml.doc("Internal: Convert subscription tree to flat array of internals")
let rec toInternals = (sub: t<'msg>): array<internal<'msg>> => {
  switch sub {
  | NoSub => []
  | Batch(subs) => Belt.Array.flatMap(subs, toInternals)
  | SingleSub(internal) => [internal]
  }
}

// ============================================================================
// Time
// ============================================================================

module Time = {
  @ocaml.doc("Subscribe to time updates at a given interval (in milliseconds)")
  let every = (intervalMs: int, toMsg: float => 'msg): t<'msg> => {
    SingleSub({
      key: "time-every-" ++ Belt.Int.toString(intervalMs),
      setup: dispatch => {
        let id = RescriptCore.setInterval(() => {
          dispatch(toMsg(Js.Date.now()))
        }, intervalMs)
        Some(() => RescriptCore.clearInterval(id))
      },
    })
  }
}

// ============================================================================
// Shims for missing modules
// ============================================================================

module BrowserWindow = {
  let resizes = _ => none
}

module Mouse = {
  let clicks = _ => none
  let moves = _ => none
}

module Keyboard = {
  let downs = _ => none
  let ups = _ => none
}

// ============================================================================
// Animation
// ============================================================================

module Animation = {
  @val external requestAnimationFrame: (float => unit) => int = "requestAnimationFrame"
  @val external cancelAnimationFrame: int => unit = "cancelAnimationFrame"
  @val external performanceNow: unit => float = "performance.now"

  type frameData = {
    timestamp: float,
    deltaTime: float,
  }

  let frames = (toMsg: float => 'msg): t<'msg> => {
    SingleSub({
      key: "animation-frames",
      setup: dispatch => {
        let running = ref(true)
        let rec loop = (timestamp: float) => {
          if running.contents {
            dispatch(toMsg(timestamp))
            let _ = requestAnimationFrame(loop)
          }
        }
        let id = requestAnimationFrame(loop)
        Some(
          () => {
            running := false
            cancelAnimationFrame(id)
          },
        )
      },
    })
  }

  let framesWithDelta = _ => none
  let throttledFrames = (_, _) => none
  let conditionalFrames = (_, _) => none
  let adaptiveFrames = (_, _) => none

  let tween = (durationMs: float, toMsg: float => 'msg): t<'msg> => {
    SingleSub({
      key: "animation-tween-" ++ Belt.Float.toString(durationMs),
      setup: dispatch => {
        let running = ref(true)
        let startTime = ref(None)
        let rec loop = (timestamp: float) => {
          if running.contents {
            let start = switch startTime.contents {
            | Some(t) => t
            | None => {
                startTime := Some(timestamp)
                timestamp
              }
            }
            let elapsed = timestamp -. start
            let progress = Js.Math.min_float(elapsed /. durationMs, 1.0)
            dispatch(toMsg(progress))
            if progress < 1.0 {
              let _ = requestAnimationFrame(loop)
            } else {
              running := false
            }
          }
        }
        let id = requestAnimationFrame(loop)
        Some(
          () => {
            running := false
            cancelAnimationFrame(id)
          },
        )
      },
    })
  }
}
