// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Clipboard.res - Tauri 2.0 clipboard plugin bindings
// ReScript bindings for @tauri-apps/plugin-clipboard-manager

open RescriptCore

// ============================================================================
// Types
// ============================================================================

/** Clipboard content kinds */
type clipboardKind =
  | @as("text") Text
  | @as("image") Image
  | @as("html") Html

/** Image data for clipboard */
type imageData = {
  width: int,
  height: int,
  bytes: Uint8Array.t,
}

// ============================================================================
// Text Operations
// ============================================================================

/** Read text from clipboard */
@module("@tauri-apps/plugin-clipboard-manager")
external readText: unit => promise<string> = "readText"

/** Write text to clipboard */
@module("@tauri-apps/plugin-clipboard-manager")
external writeText: string => promise<unit> = "writeText"

// ============================================================================
// Image Operations
// ============================================================================

/** Read image from clipboard (returns base64) */
@module("@tauri-apps/plugin-clipboard-manager")
external readImageBase64: unit => promise<Nullable.t<string>> = "readImage"

/** Write image to clipboard from base64 */
@module("@tauri-apps/plugin-clipboard-manager")
external writeImageBase64: string => promise<unit> = "writeImage"

// ============================================================================
// HTML Operations
// ============================================================================

/** Read HTML from clipboard */
@module("@tauri-apps/plugin-clipboard-manager")
external readHtml: unit => promise<Nullable.t<string>> = "readHtml"

/** Write HTML to clipboard */
@module("@tauri-apps/plugin-clipboard-manager")
external writeHtml: (string, ~alt: string=?) => promise<unit> = "writeHtml"

// ============================================================================
// Clear
// ============================================================================

/** Clear clipboard contents */
@module("@tauri-apps/plugin-clipboard-manager")
external clear: unit => promise<unit> = "clear"

// ============================================================================
// High-Level Helpers
// ============================================================================

/**
 * Read text from clipboard with error handling.
 */
let getText = async (): result<string, string> => {
  try {
    let text = await readText()
    Ok(text)
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to read clipboard"))
  | _ => Error("Failed to read clipboard")
  }
}

/**
 * Write text to clipboard with error handling.
 */
let setText = async (text: string): result<unit, string> => {
  try {
    await writeText(text)
    Ok()
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to write to clipboard"))
  | _ => Error("Failed to write to clipboard")
  }
}

/**
 * Read image from clipboard as base64.
 */
let getImage = async (): result<option<string>, string> => {
  try {
    let img = await readImageBase64()
    Ok(img->Nullable.toOption)
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to read image from clipboard"))
  | _ => Error("Failed to read image from clipboard")
  }
}

/**
 * Write image to clipboard from base64.
 */
let setImage = async (base64: string): result<unit, string> => {
  try {
    await writeImageBase64(base64)
    Ok()
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to write image to clipboard"))
  | _ => Error("Failed to write image to clipboard")
  }
}

/**
 * Read HTML from clipboard.
 */
let getHtml = async (): result<option<string>, string> => {
  try {
    let html = await readHtml()
    Ok(html->Nullable.toOption)
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to read HTML from clipboard"))
  | _ => Error("Failed to read HTML from clipboard")
  }
}

/**
 * Write HTML to clipboard with optional plain text alternative.
 */
let setHtml = async (html: string, ~alt=?): result<unit, string> => {
  try {
    await writeHtml(html, ~alt?)
    Ok()
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to write HTML to clipboard"))
  | _ => Error("Failed to write HTML to clipboard")
  }
}

/**
 * Copy text to clipboard (alias for setText).
 */
let copy = setText

/**
 * Paste text from clipboard (alias for getText).
 */
let paste = getText

/**
 * Clear the clipboard.
 */
let clearClipboard = async (): result<unit, string> => {
  try {
    await clear()
    Ok()
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to clear clipboard"))
  | _ => Error("Failed to clear clipboard")
  }
}
