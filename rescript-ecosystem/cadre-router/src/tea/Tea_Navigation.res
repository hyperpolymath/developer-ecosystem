// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell

@@ocaml.doc("Navigation commands for TEA applications.

Provides both raw and SafeDOM-validated navigation commands.
The safe variants (safePush, safeReplace) sanitise URLs through
Parser.sanitisePath before invoking the History API, preventing
path-traversal and encoded-traversal attacks from reaching the browser.")

open Tea_Url

@ocaml.doc("Navigation command type - represents intent to navigate")
type cmd<'msg> =
  | Push(t)
  | Replace(t)
  | Back(int)
  | Forward(int)
  | External(string)

@ocaml.doc("Create a command to push a new URL onto the history stack")
let push: t => cmd<'msg> = url => Push(url)

@ocaml.doc("Create a command to push a path string onto the history stack")
let pushPath: string => cmd<'msg> = path => Push(parse(path))

@ocaml.doc("Create a command to replace the current URL in history")
let replace: t => cmd<'msg> = url => Replace(url)

@ocaml.doc("Create a command to replace with a path string")
let replacePath: string => cmd<'msg> = path => Replace(parse(path))

@ocaml.doc("Create a command to go back N steps in history")
let back: (~steps: int=?) => cmd<'msg> = (~steps=1) => Back(steps)

@ocaml.doc("Create a command to go forward N steps in history")
let forward: (~steps: int=?) => cmd<'msg> = (~steps=1) => Forward(steps)

@ocaml.doc("Create a command to navigate to an external URL")
let external_: string => cmd<'msg> = url => External(url)

@ocaml.doc("Execute a navigation command (side-effect)")
let execute: cmd<'msg> => unit = cmd => {
  switch %external(__unsafe_window) {
  | None => ()
  | Some(_) =>
    switch cmd {
    | Push(url) => %raw(`window.history.pushState({}, '', url)`)(toString(url))
    | Replace(url) => %raw(`window.history.replaceState({}, '', url)`)(toString(url))
    | Back(n) => %raw(`window.history.go(-n)`)(n)
    | Forward(n) => %raw(`window.history.go(n)`)(n)
    | External(url) => %raw(`window.location.href = url`)(url)
    }
  }
}

// ============================================================================
// SafeDOM-validated navigation
// ============================================================================
//
// The safe variants run Parser.sanitisePath on the URL path before pushing
// to the History API. This catches path-traversal attacks (.. sequences,
// encoded variants, backslashes) that could otherwise reach the browser.
// Returns Ok() on success, Error(reason) if the path was rejected.

@ocaml.doc("Push a path string onto the history stack after sanitisation.
Rejects paths containing traversal sequences (.., //, backslash).")
let safePush: string => result<unit, string> = path => {
  switch Parser.sanitisePath(path) {
  | Some(clean) =>
    execute(Push(parse(clean)))
    Ok()
  | None => Error("Path rejected: contains traversal sequence")
  }
}

@ocaml.doc("Replace the current URL after sanitisation.
Rejects paths containing traversal sequences (.., //, backslash).")
let safeReplace: string => result<unit, string> = path => {
  switch Parser.sanitisePath(path) {
  | Some(clean) =>
    execute(Replace(parse(clean)))
    Ok()
  | None => Error("Path rejected: contains traversal sequence")
  }
}
