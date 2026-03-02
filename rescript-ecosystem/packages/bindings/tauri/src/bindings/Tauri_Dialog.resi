// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Dialog.resi - Interface for Tauri dialog bindings

open RescriptCore

// ============================================================================
// Types
// ============================================================================

type dialogFilter = {
  name: string,
  extensions: array<string>,
}

type openDialogOptions = {
  title?: string,
  defaultPath?: string,
  filters?: array<dialogFilter>,
  multiple?: bool,
  directory?: bool,
  recursive?: bool,
  canCreateDirectories?: bool,
}

type saveDialogOptions = {
  title?: string,
  defaultPath?: string,
  filters?: array<dialogFilter>,
  canCreateDirectories?: bool,
}

type messageKind =
  | @as("info") Info
  | @as("warning") Warning
  | @as("error") Error_

type messageDialogOptions = {
  title?: string,
  kind?: messageKind,
  okLabel?: string,
  cancelLabel?: string,
}

type confirmDialogOptions = {
  title?: string,
  kind?: messageKind,
  okLabel?: string,
  cancelLabel?: string,
}

type askDialogOptions = {
  title?: string,
  kind?: messageKind,
  okLabel?: string,
  cancelLabel?: string,
}

// ============================================================================
// File Dialogs
// ============================================================================

let open_: (~options: openDialogOptions=?) => promise<Nullable.t<array<string>>>
let openSingle: (~options: openDialogOptions=?) => promise<option<string>>
let openMultiple: (~options: openDialogOptions=?) => promise<array<string>>
let openDirectory: (~options: openDialogOptions=?) => promise<option<string>>
let save: (~options: saveDialogOptions=?) => promise<Nullable.t<string>>
let saveFile: (~options: saveDialogOptions=?) => promise<option<string>>

// ============================================================================
// Message Dialogs
// ============================================================================

let message: (string, ~options: messageDialogOptions=?) => promise<unit>
let info: (string, ~title: string=?) => promise<unit>
let warning: (string, ~title: string=?) => promise<unit>
let error: (string, ~title: string=?) => promise<unit>

// ============================================================================
// Confirmation Dialogs
// ============================================================================

let confirm: (string, ~options: confirmDialogOptions=?) => promise<bool>
let ask: (string, ~options: askDialogOptions=?) => promise<bool>

// ============================================================================
// Filter Presets
// ============================================================================

module Filters: {
  let images: dialogFilter
  let documents: dialogFilter
  let audio: dialogFilter
  let video: dialogFilter
  let json: dialogFilter
  let all: dialogFilter
  let custom: (~name: string, ~extensions: array<string>) => dialogFilter
}

// ============================================================================
// Dialog Builder (Fluent API)
// ============================================================================

module OpenDialog: {
  type t
  let make: unit => t
  let title: (t, string) => t
  let defaultPath: (t, string) => t
  let filter: (t, dialogFilter) => t
  let filters: (t, array<dialogFilter>) => t
  let multiple: t => t
  let directory: t => t
  let pickSingle: t => promise<option<string>>
  let pickMultiple: t => promise<array<string>>
  let pickDirectory: t => promise<option<string>>
}

module SaveDialog: {
  type t
  let make: unit => t
  let title: (t, string) => t
  let defaultPath: (t, string) => t
  let filter: (t, dialogFilter) => t
  let pick: t => promise<option<string>>
}
