// SPDX-License-Identifier: MIT AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
The TEA application runtime. Creates React components from app specifications.
")

@ocaml.doc("Full application specification with flags")
type app<'flags, 'model, 'msg> = {
  init: 'flags => ('model, Tea_Cmd.t<'msg>),
  update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  view: 'model => React.element,
  subscriptions: 'model => Tea_Sub.t<'msg>,
}

@ocaml.doc("Simple application specification without flags")
type simpleApp<'model, 'msg> = {
  init: unit => ('model, Tea_Cmd.t<'msg>),
  update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  view: 'model => React.element,
  subscriptions: 'model => Tea_Sub.t<'msg>,
}

@ocaml.doc("Create a React component from an app specification with flags")
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

@ocaml.doc("Create a React component from a simple app specification (no flags)")
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

@ocaml.doc("Create a React component where view receives dispatch function")
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
