// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Command.res - Type-safe command bridge pattern for Tauri IPC
// Provides typed request/response with error channel handling

open RescriptCore

// Timer bindings (not in RescriptCore)
@val external setTimeout: (unit => unit, int) => int = "setTimeout"
@val external clearTimeout: int => unit = "clearTimeout"

// ============================================================================
// Types
// ============================================================================

/** Command error from Rust backend */
type commandError = {
  code: string,
  message: string,
  details: option<JSON.t>,
}

/** Command result type */
type commandResult<'a> = result<'a, commandError>

/** Command definition - describes a Tauri command's contract */
type commandDef<'args, 'response> = {
  name: string,
  encode: 'args => JSON.t,
  decode: JSON.t => result<'response, string>,
}

/** Command execution context */
type commandContext = {
  timeout: option<int>,
  retries: option<int>,
}

// ============================================================================
// Error Handling
// ============================================================================

module CommandError = {
  /** Common error codes */
  let notFound = "NOT_FOUND"
  let permissionDenied = "PERMISSION_DENIED"
  let invalidInput = "INVALID_INPUT"
  let internalError = "INTERNAL_ERROR"
  let timeout = "TIMEOUT"
  let networkError = "NETWORK_ERROR"
  let serializationError = "SERIALIZATION_ERROR"

  /** Create a command error */
  let make = (~code: string, ~message: string, ~details: option<JSON.t>=?) => {
    code,
    message,
    details,
  }

  /** Format error for display */
  let toString = (err: commandError) => `[${err.code}] ${err.message}`

  /** Check if error matches a code */
  let isCode = (err: commandError, code: string) => err.code == code

  /** Extract error from exception */
  let fromExn = (exn: exn): commandError => {
    switch exn {
    | Exn.Error(jsError) => {
        let msg = Exn.message(jsError)->Option.getOr("Unknown error")
        make(~code=internalError, ~message=msg)
      }
    | _ => make(~code=internalError, ~message="Unknown exception")
    }
  }
}

// ============================================================================
// Command Definition Helpers
// ============================================================================

/**
 * Define a command with typed arguments and response.
 * This creates a reusable command definition.
 */
let defineCommand = (
  ~name: string,
  ~encode: 'args => JSON.t,
  ~decode: JSON.t => result<'response, string>,
): commandDef<'args, 'response> => {
  {name, encode: args => encode(args), decode}
}

/**
 * Define a command with no arguments.
 */
let defineNoArgsCommand = (
  ~name: string,
  ~decode: JSON.t => result<'response, string>,
): commandDef<unit, 'response> => {
  {
    name,
    encode: _ => Obj.magic(Dict.make()),
    decode,
  }
}

/**
 * Define a command with no response (unit return).
 */
let defineVoidCommand = (~name: string, ~encode: 'args => JSON.t): commandDef<'args, unit> => {
  {
    name,
    encode,
    decode: _ => Ok(),
  }
}

// ============================================================================
// Command Execution
// ============================================================================

/**
 * Execute a defined command with typed arguments.
 * Returns a typed result with structured error handling.
 */
let execute = async (
  cmd: commandDef<'args, 'response>,
  args: 'args,
): commandResult<'response> => {
  try {
    let encodedArgs = cmd.encode(args)
    let response = await Tauri_Core.invoke(cmd.name, ~args=encodedArgs)

    switch cmd.decode(Obj.magic(response)) {
    | Ok(decoded) => Ok(decoded)
    | Error(msg) =>
      Error(CommandError.make(~code=CommandError.serializationError, ~message=msg))
    }
  } catch {
  | exn => Error(CommandError.fromExn(exn))
  }
}

/**
 * Execute a command with retry logic.
 */
let executeWithRetry = async (
  cmd: commandDef<'args, 'response>,
  args: 'args,
  ~maxRetries: int=3,
  ~delayMs: int=1000,
): commandResult<'response> => {
  let rec loop = async (retriesLeft: int, lastError: option<commandError>) => {
    if retriesLeft <= 0 {
      Error(
        lastError->Option.getOr(
          CommandError.make(~code=CommandError.internalError, ~message="Max retries exceeded"),
        ),
      )
    } else {
      switch await execute(cmd, args) {
      | Ok(result) => Ok(result)
      | Error(err) =>
        if retriesLeft > 1 {
          await Promise.make((resolve, _) => {
            let _ = setTimeout(() => resolve(), delayMs)
          })
          await loop(retriesLeft - 1, Some(err))
        } else {
          Error(err)
        }
      }
    }
  }

  await loop(maxRetries, None)
}

/**
 * Execute a command with timeout.
 */
let executeWithTimeout = async (
  cmd: commandDef<'args, 'response>,
  args: 'args,
  ~timeoutMs: int,
): commandResult<'response> => {
  let timeoutPromise = Promise.make((resolve, _) => {
    let _ = setTimeout(() => {
      resolve(Error(CommandError.make(~code=CommandError.timeout, ~message="Command timed out")))
    }, timeoutMs)
  })

  let commandPromise = execute(cmd, args)

  await Promise.race([commandPromise, timeoutPromise])
}

// ============================================================================
// Batch Commands
// ============================================================================

/**
 * Execute multiple commands in parallel.
 */
let executeAll = async (commands: array<unit => promise<commandResult<'a>>>): array<
  commandResult<'a>,
> => {
  await Promise.all(Array.map(commands, cmd => cmd()))
}

/**
 * Execute commands sequentially, stopping on first error.
 */
let executeSequential = async (commands: array<unit => promise<commandResult<'a>>>): commandResult<
  array<'a>,
> => {
  let results = []
  let error = ref(None)

  let i = ref(0)
  while i.contents < Array.length(commands) && error.contents->Option.isNone {
    let cmd = commands[i.contents]->Option.getExn
    switch await cmd() {
    | Ok(result) => Array.push(results, result)->ignore
    | Error(err) => error := Some(err)
    }
    i := i.contents + 1
  }

  switch error.contents {
  | Some(err) => Error(err)
  | None => Ok(results)
  }
}

// ============================================================================
// Event-Driven Commands
// ============================================================================

/**
 * Execute a command and listen for streaming response events.
 * Useful for long-running operations that emit progress updates.
 */
let executeWithProgress = async (
  cmd: commandDef<'args, 'response>,
  args: 'args,
  ~progressEvent: string,
  ~onProgress: 'progress => unit,
): commandResult<'response> => {
  // Set up progress listener before executing
  let unlisten = await Tauri_Event.listen(progressEvent, event => {
    onProgress(Obj.magic(event.payload))
  })

  let result = await execute(cmd, args)

  // Clean up listener
  unlisten()

  result
}

// ============================================================================
// Command Builder (Fluent API)
// ============================================================================

module Builder = {
  type t<'args, 'response> = {
    cmd: commandDef<'args, 'response>,
    timeout: option<int>,
    retries: option<int>,
    retryDelay: option<int>,
  }

  /** Start building a command execution */
  let make = (cmd: commandDef<'args, 'response>): t<'args, 'response> => {
    {cmd, timeout: None, retries: None, retryDelay: None}
  }

  /** Set timeout for execution */
  let withTimeout = (builder: t<'args, 'response>, ms: int): t<'args, 'response> => {
    {...builder, timeout: Some(ms)}
  }

  /** Set retry count */
  let withRetries = (
    builder: t<'args, 'response>,
    count: int,
    ~delayMs: int=1000,
  ): t<'args, 'response> => {
    {...builder, retries: Some(count), retryDelay: Some(delayMs)}
  }

  /** Execute the command with configured options */
  let run = async (builder: t<'args, 'response>, args: 'args): commandResult<'response> => {
    switch builder.timeout {
    | Some(timeout) => await executeWithTimeout(builder.cmd, args, ~timeoutMs=timeout)
    | None =>
      switch builder.retries {
      | Some(retries) =>
        await executeWithRetry(
          builder.cmd,
          args,
          ~maxRetries=retries,
          ~delayMs=builder.retryDelay->Option.getOr(1000),
        )
      | None => await execute(builder.cmd, args)
      }
    }
  }
}
