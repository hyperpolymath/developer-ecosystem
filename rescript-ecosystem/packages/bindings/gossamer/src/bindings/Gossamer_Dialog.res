// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Gossamer_Dialog.res — Gossamer dialog bindings.
//
// Provides file picker, save, message, and confirmation dialogs via the
// Gossamer IPC channel. This is the Gossamer equivalent of Tauri_Dialog.res
// (which wraps @tauri-apps/plugin-dialog).

open RescriptCore

// ============================================================================
// Types
// ============================================================================

/// Dialog filter for file types.
type dialogFilter = {
  name: string,
  extensions: array<string>,
}

/// Message dialog kind.
type messageKind =
  | @as("info") Info
  | @as("warning") Warning
  | @as("error") Error_

/// Open dialog options.
type openDialogOptions = {
  title?: string,
  defaultPath?: string,
  filters?: array<dialogFilter>,
  multiple?: bool,
  directory?: bool,
  recursive?: bool,
  canCreateDirectories?: bool,
}

/// Save dialog options.
type saveDialogOptions = {
  title?: string,
  defaultPath?: string,
  filters?: array<dialogFilter>,
  canCreateDirectories?: bool,
}

/// Message dialog options.
type messageDialogOptions = {
  title?: string,
  kind?: messageKind,
  okLabel?: string,
  cancelLabel?: string,
}

/// Confirm dialog options.
type confirmDialogOptions = {
  title?: string,
  kind?: messageKind,
  okLabel?: string,
  cancelLabel?: string,
}

// ============================================================================
// File Dialogs
// ============================================================================

/// Open a file picker dialog.
/// Returns the selected path(s) or null if cancelled.
let open_ = (~options: openDialogOptions=?): promise<Nullable.t<array<string>>> => {
  let opts = switch options {
  | Some(o) => Obj.magic(o)
  | None => Obj.magic(Dict.make())
  }
  Gossamer_Core.invokeRaw("__gossamer_dialog_open", opts)
}

/// Open a file picker dialog (single file).
let openSingle = async (~options=?): option<string> => {
  let opts: openDialogOptions = switch options {
  | Some(o) => {...o, multiple: false}
  | None => {multiple: false}
  }
  let result = await open_(~options=opts)
  switch result->Nullable.toOption {
  | Some(paths) => paths[0]
  | None => None
  }
}

/// Open a file picker dialog (multiple files).
let openMultiple = async (~options=?): array<string> => {
  let opts: openDialogOptions = switch options {
  | Some(o) => {...o, multiple: true}
  | None => {multiple: true}
  }
  let result = await open_(~options=opts)
  result->Nullable.toOption->Option.getOr([])
}

/// Open a directory picker dialog.
let openDirectory = async (~options=?): option<string> => {
  let opts: openDialogOptions = switch options {
  | Some(o) => {...o, directory: true, multiple: false}
  | None => {directory: true, multiple: false}
  }
  let result = await open_(~options=opts)
  switch result->Nullable.toOption {
  | Some(paths) => paths[0]
  | None => None
  }
}

/// Open a save file dialog.
/// Returns the selected path or null if cancelled.
let save = (~options: saveDialogOptions=?): promise<Nullable.t<string>> => {
  let opts = switch options {
  | Some(o) => Obj.magic(o)
  | None => Obj.magic(Dict.make())
  }
  Gossamer_Core.invokeRaw("__gossamer_dialog_save", opts)
}

/// Open a save file dialog with result type.
let saveFile = async (~options=?): option<string> => {
  let result = await save(~options?)
  result->Nullable.toOption
}

// ============================================================================
// Message Dialogs
// ============================================================================

/// Show a message dialog.
let message = (msg: string, ~options: messageDialogOptions=?): promise<unit> => {
  let opts = switch options {
  | Some(o) => Obj.magic(o)
  | None => Obj.magic(Dict.make())
  }
  Gossamer_Core.invokeRaw("__gossamer_dialog_message", {"message": msg, "options": opts})
}

/// Show an info message dialog.
let info = (msg: string, ~title=?) => {
  message(msg, ~options={kind: Info, ?title})
}

/// Show a warning message dialog.
let warning = (msg: string, ~title=?) => {
  message(msg, ~options={kind: Warning, ?title})
}

/// Show an error message dialog.
let error = (msg: string, ~title=?) => {
  message(msg, ~options={kind: Error_, ?title})
}

// ============================================================================
// Confirmation Dialogs
// ============================================================================

/// Show a confirmation dialog with OK/Cancel buttons.
/// Returns true if OK was clicked.
let confirm = (msg: string, ~options: confirmDialogOptions=?): promise<bool> => {
  let opts = switch options {
  | Some(o) => Obj.magic(o)
  | None => Obj.magic(Dict.make())
  }
  Gossamer_Core.invokeRaw("__gossamer_dialog_confirm", {"message": msg, "options": opts})
}

/// Show an ask dialog with Yes/No buttons.
/// Returns true if Yes was clicked.
let ask = (msg: string, ~options: confirmDialogOptions=?): promise<bool> => {
  let opts = switch options {
  | Some(o) => Obj.magic(o)
  | None => Obj.magic(Dict.make())
  }
  Gossamer_Core.invokeRaw("__gossamer_dialog_ask", {"message": msg, "options": opts})
}

// ============================================================================
// Filter Presets
// ============================================================================

module Filters = {
  let images: dialogFilter = {
    name: "Images",
    extensions: ["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "ico"],
  }

  let documents: dialogFilter = {
    name: "Documents",
    extensions: ["pdf", "doc", "docx", "txt", "rtf", "odt"],
  }

  let audio: dialogFilter = {
    name: "Audio",
    extensions: ["mp3", "wav", "ogg", "flac", "aac", "m4a"],
  }

  let video: dialogFilter = {
    name: "Video",
    extensions: ["mp4", "webm", "avi", "mkv", "mov", "wmv"],
  }

  let json: dialogFilter = {
    name: "JSON",
    extensions: ["json"],
  }

  let all: dialogFilter = {
    name: "All Files",
    extensions: ["*"],
  }

  let custom = (~name: string, ~extensions: array<string>): dialogFilter => {
    {name, extensions}
  }
}

// ============================================================================
// Dialog Builder (Fluent API)
// ============================================================================

module OpenDialog = {
  type t = {options: openDialogOptions}

  let make = () => {options: {}}

  let title = (builder: t, title: string): t => {
    {options: {...builder.options, title}}
  }

  let defaultPath = (builder: t, path: string): t => {
    {options: {...builder.options, defaultPath: path}}
  }

  let filter = (builder: t, filter: dialogFilter): t => {
    let existing = builder.options.filters->Option.getOr([])
    {options: {...builder.options, filters: Array.concat(existing, [filter])}}
  }

  let filters = (builder: t, filters: array<dialogFilter>): t => {
    {options: {...builder.options, filters}}
  }

  let multiple = (builder: t): t => {
    {options: {...builder.options, multiple: true}}
  }

  let directory = (builder: t): t => {
    {options: {...builder.options, directory: true}}
  }

  let pickSingle = async (builder: t): option<string> => {
    await openSingle(~options=builder.options)
  }

  let pickMultiple = async (builder: t): array<string> => {
    await openMultiple(~options=builder.options)
  }

  let pickDirectory = async (builder: t): option<string> => {
    await openDirectory(~options=builder.options)
  }
}

module SaveDialog = {
  type t = {options: saveDialogOptions}

  let make = () => {options: {}}

  let title = (builder: t, title: string): t => {
    {options: {...builder.options, title}}
  }

  let defaultPath = (builder: t, path: string): t => {
    {options: {...builder.options, defaultPath: path}}
  }

  let filter = (builder: t, filter: dialogFilter): t => {
    let existing = builder.options.filters->Option.getOr([])
    {options: {...builder.options, filters: Array.concat(existing, [filter])}}
  }

  let pick = async (builder: t): option<string> => {
    await saveFile(~options=builder.options)
  }
}
