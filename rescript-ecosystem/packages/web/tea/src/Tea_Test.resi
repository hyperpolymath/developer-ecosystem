// SPDX-License-Identifier: MIT AND Palimpsest-0.8
// SPDX-FileCopyrightText: 2024 Jonathan D.A. Jewell

@@ocaml.doc("
Testing utilities for TEA applications.
")

@ocaml.doc("Simulate running update with a sequence of messages")
let simulate: (
  ~init: unit => ('model, Tea_Cmd.t<'msg>),
  ~update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  ~msgs: array<'msg>,
) => 'model

@ocaml.doc("Simulate with flags")
let simulateWithFlags: (
  ~init: 'flags => ('model, Tea_Cmd.t<'msg>),
  ~update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  ~flags: 'flags,
  ~msgs: array<'msg>,
) => 'model

@ocaml.doc("Collect all commands produced while processing messages")
let collectCmds: (
  ~init: unit => ('model, Tea_Cmd.t<'msg>),
  ~update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  ~msgs: array<'msg>,
) => array<Tea_Cmd.t<'msg>>

@ocaml.doc("Result of a single update step")
type step<'model, 'msg> = {
  model: 'model,
  cmd: Tea_Cmd.t<'msg>,
}

@ocaml.doc("Run a single update step")
let step: (
  ~update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  ~model: 'model,
  ~msg: 'msg,
) => step<'model, 'msg>

@ocaml.doc("Run multiple steps, returning all intermediate results")
let steps: (
  ~init: unit => ('model, Tea_Cmd.t<'msg>),
  ~update: ('msg, 'model) => ('model, Tea_Cmd.t<'msg>),
  ~msgs: array<'msg>,
) => array<step<'model, 'msg>>

@ocaml.doc("Assert that a model satisfies a predicate")
let expectModel: ('model, 'model => bool, string) => unit

@ocaml.doc("Assert that two values are equal")
let assertEqual: ('a, 'a, string) => unit

@ocaml.doc("Check if a command is none")
let isNone: Tea_Cmd.t<'msg> => bool

@ocaml.doc("Check if a command is a batch")
let isBatch: Tea_Cmd.t<'msg> => bool
