// SPDX-License-Identifier: MPL-2.0 AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
The Elm Architecture for ReScript.

This module re-exports all TEA functionality for convenient access.

Example:
```rescript
open Tea

type model = {count: int}
type msg = Increment | Decrement

let init = () => ({count: 0}, Cmd.none)

let update = (msg, model) => {
  switch msg {
  | Increment => ({count: model.count + 1}, Cmd.none)
  | Decrement => ({count: model.count - 1}, Cmd.none)
  }
}

let view = model => {
  <div>
    <button onClick={_ => Decrement}> {\"-\"->React.string} </button>
    <span> {model.count->Int.toString->React.string} </span>
    <button onClick={_ => Increment}> {\"+\"->React.string} </button>
  </div>
}

let subscriptions = _ => Sub.none

module App = MakeSimple({
  type model = model
  type msg = msg
  let app = {init, update, view, subscriptions}
})
```
")

// ============================================================================
// Core modules
// ============================================================================

module Cmd = Tea_Cmd
module Sub = Tea_Sub
module Html = Tea_Html
module Json = Tea_Json
module Http = Tea_Http
module Layout = Tea_Layout

// ============================================================================
// Application types and functors
// ============================================================================

@ocaml.doc("Full application specification with initialization flags")
type app<'flags, 'model, 'msg> = Tea_App.app<'flags, 'model, 'msg>

@ocaml.doc("Simple application specification without flags")
type simpleApp<'model, 'msg> = Tea_App.simpleApp<'model, 'msg>

@ocaml.doc("Create a React component from an app specification with flags")
module Make = Tea_App.Make

@ocaml.doc("Create a React component from a simple app specification")
module MakeSimple = Tea_App.MakeSimple

@ocaml.doc("Create a React component where view receives dispatch")
module MakeWithDispatch = Tea_App.MakeWithDispatch

// ============================================================================
// Convenience re-exports
// ============================================================================

// Common command operations
let none = Cmd.none
let batch = Cmd.batch

// For testing
module Test = Tea_Test
