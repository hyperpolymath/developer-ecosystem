// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Core.resi - Interface for core Tauri 2.0 bindings

open RescriptCore

// ============================================================================
// Types
// ============================================================================

type invokeArgs = JSON.t
type invokeOptions = {headers?: Dict.t<string>}

type permissionState =
  | @as("granted") Granted
  | @as("denied") Denied
  | @as("prompt") Prompt
  | @as("prompt-with-rationale") PromptWithRationale

// ============================================================================
// Core Invoke API
// ============================================================================

/** Invoke a Tauri command */
let invoke: (string, ~args: invokeArgs=?, ~options: invokeOptions=?) => promise<'response>

/** Invoke with type-safe request/response and decoder */
let invokeTyped: (
  ~command: string,
  ~args: 'args,
  ~decoder: JSON.t => result<'response, string>,
) => promise<result<'response, string>>

// ============================================================================
// Transform Callback API
// ============================================================================

type transformCallback<'t> = 't => unit
let transformCallback: transformCallback<'t> => int

// ============================================================================
// Plugin API
// ============================================================================

let isPluginAvailable: string => bool

// ============================================================================
// Channel API
// ============================================================================

type channel<'t>
let makeChannel: unit => channel<'t>
let onMessage: (channel<'t>, 't => unit) => unit
let channelId: channel<'t> => int

// ============================================================================
// Resource API
// ============================================================================

type resource
let makeResource: int => resource
let closeResource: resource => promise<unit>
let resourceRid: resource => int

// ============================================================================
// Image API
// ============================================================================

type imageDimensions = {width: int, height: int}
type image
let imageFromBytes: Uint8Array.t => promise<image>
let imageFromPath: string => promise<image>
let imageRgba: image => promise<Uint8Array.t>
let imageSize: image => imageDimensions

// ============================================================================
// App Info API
// ============================================================================

let getName: unit => promise<string>
let getVersion: unit => promise<string>
let getTauriVersion: unit => promise<string>
let show: unit => promise<unit>
let hide: unit => promise<unit>
