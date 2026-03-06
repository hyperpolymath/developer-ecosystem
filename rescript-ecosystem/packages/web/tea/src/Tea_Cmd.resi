// SPDX-License-Identifier: MIT AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
Commands represent side effects to be performed by the runtime.
They are pure descriptions of work to do, not the work itself.
")

@ocaml.doc("The command type")
type t<'msg>

@ocaml.doc("A command that does nothing")
let none: t<'msg>

@ocaml.doc("Combine multiple commands into one")
let batch: array<t<'msg>> => t<'msg>

@ocaml.doc("Create a command from an async operation that cannot fail")
let perform: (unit => promise<'a>, 'a => 'msg) => t<'msg>

@ocaml.doc("Create a command from an async operation that might fail")
let attempt: (unit => promise<'a>, result<'a, exn> => 'msg) => t<'msg>

@ocaml.doc("Transform the message type of a command")
let map: ('a => 'b, t<'a>) => t<'b>

@ocaml.doc("Internal: Execute a command with a dispatch function")
let execute: (t<'msg>, 'msg => unit) => unit

@ocaml.doc("Create a command that dispatches a message immediately")
let message: 'msg => t<'msg>

@ocaml.doc(
  "Create a command from an effect callback. The callback receives dispatch and can call it asynchronously."
)
let effect: (('msg => unit) => unit) => t<'msg>
