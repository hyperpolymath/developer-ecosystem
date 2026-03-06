// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Clipboard.resi - Interface for Tauri clipboard plugin bindings

open RescriptCore

// ============================================================================
// Types
// ============================================================================

type clipboardKind =
  | @as("text") Text
  | @as("image") Image
  | @as("html") Html

type imageData = {
  width: int,
  height: int,
  bytes: Uint8Array.t,
}

// ============================================================================
// Text Operations
// ============================================================================

let readText: unit => promise<string>
let writeText: string => promise<unit>

// ============================================================================
// Image Operations
// ============================================================================

let readImageBase64: unit => promise<Nullable.t<string>>
let writeImageBase64: string => promise<unit>

// ============================================================================
// HTML Operations
// ============================================================================

let readHtml: unit => promise<Nullable.t<string>>
let writeHtml: (string, ~alt: string=?) => promise<unit>

// ============================================================================
// Clear
// ============================================================================

let clear: unit => promise<unit>

// ============================================================================
// High-Level Helpers
// ============================================================================

let getText: unit => promise<result<string, string>>
let setText: string => promise<result<unit, string>>
let getImage: unit => promise<result<option<string>, string>>
let setImage: string => promise<result<unit, string>>
let getHtml: unit => promise<result<option<string>, string>>
let setHtml: (string, ~alt: string=?) => promise<result<unit, string>>
let copy: string => promise<result<unit, string>>
let paste: unit => promise<result<string, string>>
let clearClipboard: unit => promise<result<unit, string>>
