// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Core.res - Core Tauri 2.0 invoke and command bindings
// ReScript bindings for @tauri-apps/api/core

open RescriptCore

// ============================================================================
// Types
// ============================================================================

/** Invoke arguments - any JSON-serializable record */
type invokeArgs = JSON.t

/** Invoke options for customizing command calls */
type invokeOptions = {
  headers?: Dict.t<string>,
}

/** Permission state for capability requests */
type permissionState =
  | @as("granted") Granted
  | @as("denied") Denied
  | @as("prompt") Prompt
  | @as("prompt-with-rationale") PromptWithRationale

// ============================================================================
// Core Invoke API
// ============================================================================

/**
 * Invoke a Tauri command with typed arguments and response.
 * Commands are defined in Rust and exposed via #[tauri::command].
 */
@module("@tauri-apps/api/core")
external invoke: (string, ~args: invokeArgs=?, ~options: invokeOptions=?) => promise<'response> = "invoke"

/**
 * Invoke a command with automatic JSON serialization/deserialization.
 * Use this when you want type safety on both request and response.
 */
let invokeTyped = async (
  ~command: string,
  ~args: 'args,
  ~decoder: JSON.t => result<'response, string>,
): result<'response, string> => {
  try {
    let response = await invoke(command, ~args=Obj.magic(args))
    decoder(Obj.magic(response))
  } catch {
  | Exn.Error(err) =>
    Error(Exn.message(err)->Option.getOr("Unknown Tauri invoke error"))
  }
}

// ============================================================================
// Transform Callback API (for streaming responses)
// ============================================================================

/** Transform callback receives chunks of data during streaming */
type transformCallback<'t> = 't => unit

@module("@tauri-apps/api/core")
external transformCallback: transformCallback<'t> => int = "transformCallback"

// ============================================================================
// Plugin API
// ============================================================================

/** Check if a plugin is loaded */
@module("@tauri-apps/api/core")
external isPluginAvailable: string => bool = "isPluginAvailable"

// ============================================================================
// Channel API (bidirectional communication)
// ============================================================================

/** Channel for bidirectional communication with Rust backend */
type channel<'t>

@module("@tauri-apps/api/core") @new
external makeChannel: unit => channel<'t> = "Channel"

@send
external onMessage: (channel<'t>, 't => unit) => unit = "onmessage"

@get
external channelId: channel<'t> => int = "id"

// ============================================================================
// Resource API (for managing Rust resources)
// ============================================================================

/** Resource handle for Rust-side resources */
type resource

@module("@tauri-apps/api/core") @new
external makeResource: int => resource = "Resource"

@send
external closeResource: resource => promise<unit> = "close"

@get
external resourceRid: resource => int = "rid"

// ============================================================================
// Image API
// ============================================================================

/** Image size */
type imageDimensions = {width: int, height: int}

/** Image handle for Tauri image operations */
type image

@module("@tauri-apps/api/image") @new
external imageFromBytes: Uint8Array.t => promise<image> = "Image"

@module("@tauri-apps/api/image") @new
external imageFromPath: string => promise<image> = "Image"

@send
external imageRgba: image => promise<Uint8Array.t> = "rgba"

@send
external imageSize: image => imageDimensions = "size"

// ============================================================================
// App Info API
// ============================================================================

@module("@tauri-apps/api/app")
external getName: unit => promise<string> = "getName"

@module("@tauri-apps/api/app")
external getVersion: unit => promise<string> = "getVersion"

@module("@tauri-apps/api/app")
external getTauriVersion: unit => promise<string> = "getTauriVersion"

@module("@tauri-apps/api/app")
external show: unit => promise<unit> = "show"

@module("@tauri-apps/api/app")
external hide: unit => promise<unit> = "hide"
