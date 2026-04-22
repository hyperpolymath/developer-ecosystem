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
