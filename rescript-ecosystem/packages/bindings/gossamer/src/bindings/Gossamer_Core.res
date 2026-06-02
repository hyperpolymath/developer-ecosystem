// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Gossamer_Core.res — Core Gossamer invoke and command bindings.
//
// Provides the primary IPC bridge to the Gossamer runtime via
// `window.__gossamer_invoke`. This is the Gossamer equivalent of
// Tauri_Core.res (which wraps @tauri-apps/api/core).
//
// All Gossamer commands are dispatched through a single invoke function
// injected by gossamer_channel_open() into the webview global scope.

open RescriptCore

// ============================================================================
// Types
// ============================================================================

/// Invoke arguments — any JSON-serializable value.
type invokeArgs = JSON.t

/// Invoke options for customizing command calls.
type invokeOptions = {
  timeout?: int,
  retries?: int,
}

/// Permission state for capability requests.
type permissionState =
  | @as("granted") Granted
  | @as("denied") Denied
  | @as("prompt") Prompt

// ============================================================================
// Runtime Detection
// ============================================================================

/// Check whether the Gossamer runtime is available in the current context.
%%raw(`
function isGossamerAvailable() {
  return typeof window !== 'undefined'
    && typeof window.__gossamer_invoke === 'function';
}
`)
@val external isGossamerAvailable: unit => bool = "isGossamerAvailable"

// ============================================================================
// Core Invoke API
// ============================================================================

/// Raw invoke binding — calls window.__gossamer_invoke(cmd, args).
/// This is the foundation for all Gossamer IPC.
%%raw(`
function gossamerInvokeRaw(cmd, args) {
  if (typeof window !== 'undefined' && typeof window.__gossamer_invoke === 'function') {
    return window.__gossamer_invoke(cmd, args);
  }
  return Promise.reject(new Error('Gossamer runtime not available'));
}
`)
@val external invokeRaw: (string, 'a) => promise<'b> = "gossamerInvokeRaw"

/// Invoke a Gossamer command with typed arguments and response.
/// Commands are defined in the Gossamer backend (Rust/Zig) and
/// exposed via the IPC channel.
let invoke = (command: string, ~args: invokeArgs=?): promise<'response> => {
  let finalArgs = switch args {
  | Some(a) => a
  | None => Obj.magic(Dict.make())
  }
  invokeRaw(command, finalArgs)
}

/// Invoke a command with automatic JSON serialization/deserialization.
/// Use this when you want type safety on both request and response.
let invokeTyped = async (
  ~command: string,
  ~args: 'args,
  ~decoder: JSON.t => result<'response, string>,
): result<'response, string> => {
  try {
    let response = await invokeRaw(command, args)
    decoder(Obj.magic(response))
  } catch {
  | Exn.Error(err) =>
    Error(Exn.message(err)->Option.getOr("Unknown Gossamer invoke error"))
  }
}

// ============================================================================
// App Info API
// ============================================================================

/// Get the application name from the Gossamer runtime.
let getName = (): promise<string> => {
  invokeRaw("__gossamer_app_get_name", {})
}

/// Get the application version from the Gossamer runtime.
let getVersion = (): promise<string> => {
  invokeRaw("__gossamer_app_get_version", {})
}

/// Get the Gossamer runtime version.
let getGossamerVersion = (): promise<string> => {
  invokeRaw("__gossamer_app_get_runtime_version", {})
}

/// Show the application window.
let show = (): promise<unit> => {
  invokeRaw("__gossamer_app_show", {})
}

/// Hide the application window.
let hide = (): promise<unit> => {
  invokeRaw("__gossamer_app_hide", {})
}

// ============================================================================
// Capability API
// ============================================================================

/// Check if a capability is available.
let hasCapability = (capability: string): promise<bool> => {
  invokeRaw("__gossamer_capability_check", {"capability": capability})
}

/// Request a capability from the runtime.
let requestCapability = (capability: string): promise<permissionState> => {
  invokeRaw("__gossamer_capability_request", {"capability": capability})
}
