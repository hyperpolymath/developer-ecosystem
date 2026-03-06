// SPDX-License-Identifier: MIT AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
The Elm Architecture for ReScript.
")

// Core modules
module Cmd = Tea_Cmd
module Sub = Tea_Sub
module Html = Tea_Html
module Json = Tea_Json
module Http = Tea_Http

// Application types
type app<'flags, 'model, 'msg> = Tea_App.app<'flags, 'model, 'msg>
type simpleApp<'model, 'msg> = Tea_App.simpleApp<'model, 'msg>

// Functors
module Make: (
  App: {
    type model
    type msg
    type flags
    let app: app<flags, model, msg>
  },
) =>
{
  @react.component
  let make: (~flags: App.flags) => React.element
}

module MakeSimple: (
  App: {
    type model
    type msg
    let app: simpleApp<model, msg>
  },
) =>
{
  @react.component
  let make: unit => React.element
}

module MakeWithDispatch: (
  App: {
    type model
    type msg
    type flags
    let init: flags => (model, Tea_Cmd.t<msg>)
    let update: (msg, model) => (model, Tea_Cmd.t<msg>)
    let view: (model, msg => unit) => React.element
    let subscriptions: model => Tea_Sub.t<msg>
  },
) =>
{
  @react.component
  let make: (~flags: App.flags) => React.element
}

// Convenience
let none: Tea_Cmd.t<'msg>
let batch: array<Tea_Cmd.t<'msg>> => Tea_Cmd.t<'msg>

// Testing
module Test = Tea_Test
