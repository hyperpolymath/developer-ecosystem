// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Counter.res - Reference app demonstrating rescript-tauri with rescript-tea
// A simple counter that persists state via Tauri commands

open RescriptCore
open Tea

// ============================================================================
// Command Definitions (Rust backend contract)
// ============================================================================

module Commands = {
  // Define typed commands that map to Rust backend
  let getCount = Tauri.Command.defineNoArgsCommand(
    ~name="get_count",
    ~decode=json => {
      switch JSON.Decode.int(json) {
      | Some(n) => Ok(n)
      | None => Error("Expected int for count")
      }
    },
  )

  let setCount = Tauri.Command.defineCommand(
    ~name="set_count",
    ~encode=(count: int) => {"count": count},
    ~decode=_ => Ok(),
  )

  let increment = Tauri.Command.defineNoArgsCommand(
    ~name="increment",
    ~decode=json => {
      switch JSON.Decode.int(json) {
      | Some(n) => Ok(n)
      | None => Error("Expected int for count")
      }
    },
  )

  let decrement = Tauri.Command.defineNoArgsCommand(
    ~name="decrement",
    ~decode=json => {
      switch JSON.Decode.int(json) {
      | Some(n) => Ok(n)
      | None => Error("Expected int for count")
      }
    },
  )
}

// ============================================================================
// Model
// ============================================================================

type model = {
  count: int,
  loading: bool,
  error: option<string>,
  windowTitle: string,
}

let init = () => (
  {
    count: 0,
    loading: true,
    error: None,
    windowTitle: "Counter - rescript-tauri",
  },
  Cmd.msg(LoadCount),
)

// ============================================================================
// Messages
// ============================================================================

type msg =
  | LoadCount
  | CountLoaded(result<int, Tauri.Command.commandError>)
  | Increment
  | Decrement
  | CountUpdated(result<int, Tauri.Command.commandError>)
  | SetWindowTitle(string)
  | WindowTitleSet

// ============================================================================
// Update
// ============================================================================

let update = (model: model, msg: msg): (model, Cmd.t<msg>) => {
  switch msg {
  | LoadCount => (
      {...model, loading: true},
      Cmd.call(_dispatch => {
        let _ = Tauri.Command.execute(Commands.getCount, ())->Promise.thenResolve(result => {
          _dispatch(CountLoaded(result))
        })
      }),
    )

  | CountLoaded(Ok(count)) => ({...model, count, loading: false, error: None}, Cmd.none)

  | CountLoaded(Error(err)) => (
      {...model, loading: false, error: Some(Tauri.Command.CommandError.toString(err))},
      Cmd.none,
    )

  | Increment => (
      {...model, loading: true},
      Cmd.call(_dispatch => {
        let _ = Tauri.Command.execute(Commands.increment, ())->Promise.thenResolve(result => {
          _dispatch(CountUpdated(result))
        })
      }),
    )

  | Decrement => (
      {...model, loading: true},
      Cmd.call(_dispatch => {
        let _ = Tauri.Command.execute(Commands.decrement, ())->Promise.thenResolve(result => {
          _dispatch(CountUpdated(result))
        })
      }),
    )

  | CountUpdated(Ok(count)) => (
      {...model, count, loading: false, error: None},
      Cmd.msg(SetWindowTitle(`Counter: ${Int.toString(count)}`)),
    )

  | CountUpdated(Error(err)) => (
      {...model, loading: false, error: Some(Tauri.Command.CommandError.toString(err))},
      Cmd.none,
    )

  | SetWindowTitle(title) => (
      {...model, windowTitle: title},
      Cmd.call(_dispatch => {
        let _ = Tauri.Window.Current.setTitle(title)->Promise.thenResolve(_ => {
          _dispatch(WindowTitleSet)
        })
      }),
    )

  | WindowTitleSet => (model, Cmd.none)
  }
}

// ============================================================================
// Subscriptions
// ============================================================================

let subscriptions = (_model: model): Sub.t<msg> => {
  // Subscribe to window theme changes if needed
  Sub.none
}

// ============================================================================
// View
// ============================================================================

let view = (model: model): Html.t<msg> => {
  open Html

  div(
    [class'("counter-app")],
    [
      h1([], [text("ReScript + Tauri Counter")]),
      // Error display
      switch model.error {
      | Some(err) => div([class'("error")], [text(`Error: ${err}`)])
      | None => noNode
      },
      // Counter display
      div(
        [class'("counter-display")],
        [
          span([class'("count")], [text(Int.toString(model.count))]),
          if model.loading {
            span([class'("loading")], [text(" (loading...)")])
          } else {
            noNode
          },
        ],
      ),
      // Buttons
      div(
        [class'("counter-buttons")],
        [
          button(
            [onClick(Decrement), disabled(model.loading), class'("btn btn-decrement")],
            [text("-")],
          ),
          button(
            [onClick(Increment), disabled(model.loading), class'("btn btn-increment")],
            [text("+")],
          ),
        ],
      ),
      // App info
      div([class'("app-info")], [text("Built with rescript-tauri + rescript-tea")]),
    ],
  )
}

// ============================================================================
// Main Program
// ============================================================================

let main = App.standardProgram({
  init,
  update,
  subscriptions,
  view,
})
