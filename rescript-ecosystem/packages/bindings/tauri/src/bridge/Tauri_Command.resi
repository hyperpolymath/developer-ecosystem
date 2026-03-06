// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Command.resi - Interface for type-safe command bridge pattern

open RescriptCore

// ============================================================================
// Types
// ============================================================================

type commandError = {
  code: string,
  message: string,
  details: option<JSON.t>,
}

type commandResult<'a> = result<'a, commandError>

type commandDef<'args, 'response> = {
  name: string,
  encode: 'args => JSON.t,
  decode: JSON.t => result<'response, string>,
}

type commandContext = {
  timeout: option<int>,
  retries: option<int>,
}

// ============================================================================
// Error Handling
// ============================================================================

module CommandError: {
  let notFound: string
  let permissionDenied: string
  let invalidInput: string
  let internalError: string
  let timeout: string
  let networkError: string
  let serializationError: string

  let make: (~code: string, ~message: string, ~details: JSON.t=?) => commandError
  let toString: commandError => string
  let isCode: (commandError, string) => bool
  let fromExn: exn => commandError
}

// ============================================================================
// Command Definition Helpers
// ============================================================================

let defineCommand: (
  ~name: string,
  ~encode: 'args => JSON.t,
  ~decode: JSON.t => result<'response, string>,
) => commandDef<'args, 'response>

let defineNoArgsCommand: (
  ~name: string,
  ~decode: JSON.t => result<'response, string>,
) => commandDef<unit, 'response>

let defineVoidCommand: (~name: string, ~encode: 'args => JSON.t) => commandDef<'args, unit>

// ============================================================================
// Command Execution
// ============================================================================

let execute: (commandDef<'args, 'response>, 'args) => promise<commandResult<'response>>

let executeWithRetry: (
  commandDef<'args, 'response>,
  'args,
  ~maxRetries: int=?,
  ~delayMs: int=?,
) => promise<commandResult<'response>>

let executeWithTimeout: (
  commandDef<'args, 'response>,
  'args,
  ~timeoutMs: int,
) => promise<commandResult<'response>>

// ============================================================================
// Batch Commands
// ============================================================================

let executeAll: array<unit => promise<commandResult<'a>>> => promise<array<commandResult<'a>>>

let executeSequential: array<unit => promise<commandResult<'a>>> => promise<commandResult<array<'a>>>

// ============================================================================
// Event-Driven Commands
// ============================================================================

let executeWithProgress: (
  commandDef<'args, 'response>,
  'args,
  ~progressEvent: string,
  ~onProgress: 'progress => unit,
) => promise<commandResult<'response>>

// ============================================================================
// Command Builder (Fluent API)
// ============================================================================

module Builder: {
  type t<'args, 'response>

  let make: commandDef<'args, 'response> => t<'args, 'response>
  let withTimeout: (t<'args, 'response>, int) => t<'args, 'response>
  let withRetries: (t<'args, 'response>, int, ~delayMs: int=?) => t<'args, 'response>
  let run: (t<'args, 'response>, 'args) => promise<commandResult<'response>>
}
