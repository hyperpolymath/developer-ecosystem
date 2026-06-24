// SPDX-License-Identifier: MPL-2.0 AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
Subscriptions declare external event sources the application listens to.
They are diffed on each update - only changed subscriptions are re-subscribed.
")

@ocaml.doc("The subscription type")
type t<'msg>

@ocaml.doc("Internal subscription representation - for runtime use")
type internal<'msg> = {
  key: string,
  setup: ('msg => unit) => option<unit => unit>,
}

@ocaml.doc("A subscription that does nothing")
let none: t<'msg>

@ocaml.doc("Combine multiple subscriptions into one")
let batch: array<t<'msg>> => t<'msg>

@ocaml.doc("Transform the message type of a subscription")
let map: ('a => 'b, t<'a>) => t<'b>

@ocaml.doc("Internal: Convert subscription tree to flat array of internals")
let toInternals: t<'msg> => array<internal<'msg>>

module Time: {
  @ocaml.doc("Subscribe to time updates at a given interval (in milliseconds)")
  let every: (int, float => 'msg) => t<'msg>
}

module Keyboard: {
  @ocaml.doc("Subscribe to keyboard key down events")
  let downs: (string => 'msg) => t<'msg>

  @ocaml.doc("Subscribe to keyboard key up events")
  let ups: (string => 'msg) => t<'msg>
}

module Mouse: {
  @ocaml.doc("Subscribe to mouse click events")
  let clicks: (((int, int)) => 'msg) => t<'msg>

  @ocaml.doc("Subscribe to mouse move events")
  let moves: (((int, int)) => 'msg) => t<'msg>
}

module BrowserWindow: {
  @ocaml.doc("Subscribe to window resize events")
  let resizes: (((int, int)) => 'msg) => t<'msg>
}

module Animation: {
  @ocaml.doc("Animation frame data passed to message handlers")
  type frameData = {
    timestamp: float,
    deltaTime: float,
  }

  @ocaml.doc("
  Subscribe to animation frames via requestAnimationFrame.
  Provides smooth 60fps updates for animations without dropping frames.
  ")
  let frames: (float => 'msg) => t<'msg>

  @ocaml.doc("
  Subscribe to animation frames with delta time calculation.
  Provides both the current timestamp and time since last frame.
  ")
  let framesWithDelta: (frameData => 'msg) => t<'msg>

  @ocaml.doc("
  Throttled animation subscription that fires at most once per specified interval.
  Useful for SWOT 'flip switch' animations where you want smooth updates
  but don't need 60fps.
  ")
  let throttledFrames: (float, float => 'msg) => t<'msg>

  @ocaml.doc("
  Animation subscription that only fires when explicitly enabled.
  Useful for conditional animations.
  ")
  let conditionalFrames: (bool, float => 'msg) => t<'msg>

  @ocaml.doc("
  Animation subscription with automatic frame skipping when browser is under load.
  Returns (timestamp, wasOverBudget) tuple.
  ")
  let adaptiveFrames: (float, ((float, bool)) => 'msg) => t<'msg>

  @ocaml.doc("
  Tween subscription that animates between 0.0 and 1.0 over a duration.
  Automatically unsubscribes when complete.
  ")
  let tween: (float, float => 'msg) => t<'msg>
}
