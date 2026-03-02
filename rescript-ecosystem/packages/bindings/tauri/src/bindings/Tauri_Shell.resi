// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Shell.resi - Interface for Tauri shell plugin bindings

open RescriptCore

// ============================================================================
// Types
// ============================================================================

type spawnOptions = {
  cwd?: string,
  env?: Dict.t<string>,
  encoding?: string,
}

type outputEvent = {
  @as("type") kind: string,
  data: string,
}

type childProcess = {
  pid: int,
}

type commandOutput = {
  code: int,
  stdout: string,
  stderr: string,
}

type sidecarOptions = {
  args?: array<string>,
  cwd?: string,
  env?: Dict.t<string>,
  encoding?: string,
}

type command

// ============================================================================
// Command Construction
// ============================================================================

let makeCommand: (string, ~args: array<string>=?, ~options: spawnOptions=?) => command
let sidecar: (string, ~args: array<string>=?, ~options: sidecarOptions=?) => command

// ============================================================================
// Command Methods
// ============================================================================

let execute: command => promise<commandOutput>
let spawn: command => promise<childProcess>
let onStdout: (command, outputEvent => unit) => command
let onStderr: (command, outputEvent => unit) => command
let onClose: (command, int => unit) => command

// ============================================================================
// Child Process Methods
// ============================================================================

let write: (childProcess, string) => promise<unit>
let kill: childProcess => promise<unit>

// ============================================================================
// Open URL/Path
// ============================================================================

let open_: (string, ~openWith: string=?) => promise<unit>

// ============================================================================
// High-Level Helpers
// ============================================================================

let run: (string, ~args: array<string>=?, ~cwd: string=?) => promise<result<commandOutput, string>>
let runAndCapture: (string, ~args: array<string>=?, ~cwd: string=?) => promise<result<string, string>>
let openUrl: string => promise<unit>
let openFile: string => promise<unit>
let openWith: (string, string) => promise<unit>

// ============================================================================
// Command Builder (Fluent API)
// ============================================================================

module CommandBuilder: {
  type t
  let make: string => t
  let args: (t, array<string>) => t
  let arg: (t, string) => t
  let cwd: (t, string) => t
  let env: (t, string, string) => t
  let encoding: (t, string) => t
  let toCommand: t => command
  let execute_: t => promise<result<commandOutput, string>>
  let spawn_: t => promise<result<childProcess, string>>
}
