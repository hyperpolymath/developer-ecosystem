// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Shell.res - Tauri 2.0 shell plugin bindings
// ReScript bindings for @tauri-apps/plugin-shell

open RescriptCore

// ============================================================================
// Types
// ============================================================================

/** Command spawn options */
type spawnOptions = {
  cwd?: string,
  env?: Dict.t<string>,
  encoding?: string,
}

/** Child process output event */
type outputEvent = {
  @as("type") kind: string,
  data: string,
}

/** Child process */
type childProcess = {
  pid: int,
}

/** Command output (after execution completes) */
type commandOutput = {
  code: int,
  stdout: string,
  stderr: string,
}

/** Sidecar options - for bundled binaries */
type sidecarOptions = {
  args?: array<string>,
  cwd?: string,
  env?: Dict.t<string>,
  encoding?: string,
}

// ============================================================================
// Command Class (Opaque)
// ============================================================================

/** Command builder for shell execution */
type command

/** Create a new command */
@module("@tauri-apps/plugin-shell") @new
external makeCommand: (string, ~args: array<string>=?, ~options: spawnOptions=?) => command =
  "Command"

/** Create a sidecar command (bundled binary) */
@module("@tauri-apps/plugin-shell") @scope("Command")
external sidecar: (string, ~args: array<string>=?, ~options: sidecarOptions=?) => command = "sidecar"

// ============================================================================
// Command Methods
// ============================================================================

/** Execute command and wait for output */
@send
external execute: command => promise<commandOutput> = "execute"

/** Spawn command as child process */
@send
external spawn: command => promise<childProcess> = "spawn"

/** Listen to stdout events */
@send
external onStdout: (command, outputEvent => unit) => command = "on"

/** Listen to stderr events */
@send
external onStderr: (command, outputEvent => unit) => command = "on"

/** Listen to close/error events */
@send
external onClose: (command, int => unit) => command = "on"

// ============================================================================
// Child Process Methods
// ============================================================================

/** Write to child process stdin */
@send
external write: (childProcess, string) => promise<unit> = "write"

/** Kill child process */
@send
external kill: childProcess => promise<unit> = "kill"

// ============================================================================
// Open URL/Path (shell-specific)
// ============================================================================

/** Open a URL in the default browser or file in default application */
@module("@tauri-apps/plugin-shell")
external open_: (string, ~openWith: string=?) => promise<unit> = "open"

// ============================================================================
// High-Level Helpers
// ============================================================================

/**
 * Execute a command and return the output.
 * Simple wrapper for common use case.
 */
let run = async (program: string, ~args: array<string>=[], ~cwd=?): result<commandOutput, string> => {
  try {
    let cmd = makeCommand(program, ~args, ~options={?cwd})
    let output = await execute(cmd)
    Ok(output)
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Command failed"))
  | _ => Error("Command failed")
  }
}

/**
 * Execute a command and return stdout only.
 * Returns error if exit code is non-zero.
 */
let runAndCapture = async (
  program: string,
  ~args: array<string>=[],
  ~cwd=?,
): result<string, string> => {
  switch await run(program, ~args, ~cwd?) {
  | Ok(output) if output.code == 0 => Ok(output.stdout)
  | Ok(output) => Error(`Command failed with code ${Int.toString(output.code)}: ${output.stderr}`)
  | Error(e) => Error(e)
  }
}

/**
 * Open a URL in the default browser.
 */
let openUrl = (url: string): promise<unit> => open_(url)

/**
 * Open a file with the default application.
 */
let openFile = (path: string): promise<unit> => open_(path)

/**
 * Open a file with a specific application.
 */
let openWith = (path: string, app: string): promise<unit> => open_(path, ~openWith=app)

// ============================================================================
// Command Builder (Fluent API)
// ============================================================================

module CommandBuilder = {
  type t = {
    program: string,
    args: array<string>,
    options: spawnOptions,
  }

  let make = (program: string): t => {
    {program, args: [], options: {}}
  }

  let args = (builder: t, args: array<string>): t => {
    {...builder, args: Array.concat(builder.args, args)}
  }

  let arg = (builder: t, arg: string): t => {
    {...builder, args: Array.concat(builder.args, [arg])}
  }

  let cwd = (builder: t, dir: string): t => {
    {...builder, options: {...builder.options, cwd: dir}}
  }

  let env = (builder: t, key: string, value: string): t => {
    let existing = builder.options.env->Option.getOr(Dict.make())
    Dict.set(existing, key, value)
    {...builder, options: {...builder.options, env: existing}}
  }

  let encoding = (builder: t, enc: string): t => {
    {...builder, options: {...builder.options, encoding: enc}}
  }

  let toCommand = (builder: t): command => {
    makeCommand(builder.program, ~args=builder.args, ~options=builder.options)
  }

  let execute_ = async (builder: t): result<commandOutput, string> => {
    try {
      let cmd = toCommand(builder)
      let output = await execute(cmd)
      Ok(output)
    } catch {
    | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Command failed"))
    | _ => Error("Command failed")
    }
  }

  let spawn_ = async (builder: t): result<childProcess, string> => {
    try {
      let cmd = toCommand(builder)
      let child = await spawn(cmd)
      Ok(child)
    } catch {
    | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to spawn process"))
    | _ => Error("Failed to spawn process")
    }
  }
}
