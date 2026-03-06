// The Elm Architecture (TEA) Interface
// SPDX-License-Identifier: AGPL-3.0-or-later

// Command type - represents side effects
type cmd<'msg>

// Subscription type - represents external events
type sub<'msg>

// Program definition
type program<'model, 'msg> = {
  init: unit => ('model, cmd<'msg>),
  update: ('msg, 'model) => ('model, cmd<'msg>),
  view: 'model => Vdom.vnode,
  subscriptions: 'model => sub<'msg>,
}

// Command constructors
let none: cmd<'msg>
let cmd: (unit => option<'msg>) => cmd<'msg>
let batch: array<cmd<'msg>> => cmd<'msg>

// Subscription constructors
let noSub: sub<'msg>
let sub: (string, ('msg => unit) => unit => unit) => sub<'msg>
let batchSub: array<sub<'msg>> => sub<'msg>

// Common effects
module Effect: {
  let after: (int, 'msg) => cmd<'msg>
  let random: (int, int, int => 'msg) => cmd<'msg>
  let focus: string => cmd<'msg>
}

// Common subscriptions
module Subscriptions: {
  let every: (int, 'msg) => sub<'msg>
  let onResize: ((int, int) => 'msg) => sub<'msg>
  let onKeyDown: (string => 'msg) => sub<'msg>
}

// Run a TEA application
let run: (program<'model, 'msg>, string) => unit

// Create a simple program (no commands/subscriptions)
let simple: (
  ~init: unit => 'model,
  ~update: ('msg, 'model) => 'model,
  ~view: 'model => Vdom.vnode,
) => program<'model, 'msg>
