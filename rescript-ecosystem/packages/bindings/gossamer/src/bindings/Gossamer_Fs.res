// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Gossamer_Fs.res — Gossamer filesystem bindings.
//
// Provides file and directory operations via the Gossamer IPC channel.
// This is the Gossamer equivalent of Tauri_Fs.res (which wraps
// @tauri-apps/plugin-fs).

open RescriptCore

// ============================================================================
// Types
// ============================================================================

/// Base directory for file operations.
type baseDirectory =
  | @as("audio") Audio
  | @as("cache") Cache
  | @as("config") Config
  | @as("data") Data
  | @as("localData") LocalData
  | @as("document") Document
  | @as("download") Download
  | @as("picture") Picture
  | @as("public") Public
  | @as("video") Video
  | @as("resource") Resource
  | @as("temp") Temp
  | @as("appConfig") AppConfig
  | @as("appData") AppData
  | @as("appLocalData") AppLocalData
  | @as("appCache") AppCache
  | @as("appLog") AppLog
  | @as("desktop") Desktop
  | @as("home") Home

/// File info (stat result).
type fileInfo = {
  isFile: bool,
  isDirectory: bool,
  isSymlink: bool,
  size: float,
  mtime: Nullable.t<float>,
  atime: Nullable.t<float>,
  birthtime: Nullable.t<float>,
  readonly: bool,
  mode: Nullable.t<int>,
  uid: Nullable.t<int>,
  gid: Nullable.t<int>,
}

/// Directory entry.
type dirEntry = {
  name: string,
  isFile: bool,
  isDirectory: bool,
  isSymlink: bool,
}

/// Watch event kinds.
type watchEventKind =
  | @as("create") Create
  | @as("modify") Modify
  | @as("remove") Remove
  | @as("any") Any

/// Watch event.
type watchEvent = {
  @as("type") kind: watchEventKind,
  paths: array<string>,
  attrs: JSON.t,
}

/// Read options.
type readOptions = {baseDir?: baseDirectory}

/// Write options.
type writeOptions = {
  append?: bool,
  create?: bool,
  createNew?: bool,
  mode?: int,
  baseDir?: baseDirectory,
}

/// Remove options.
type removeOptions = {
  recursive?: bool,
  baseDir?: baseDirectory,
}

/// Mkdir options.
type mkdirOptions = {
  recursive?: bool,
  mode?: int,
  baseDir?: baseDirectory,
}

/// Watch options.
type watchOptions = {
  recursive?: bool,
  baseDir?: baseDirectory,
  delayMs?: int,
}

// ============================================================================
// File Operations
// ============================================================================

/// Read a file as bytes.
let readFile = (path: string, ~options: readOptions=?): promise<Uint8Array.t> => {
  Gossamer_Core.invokeRaw("__gossamer_fs_read_file", {"path": path, "options": Obj.magic(options)})
}

/// Read a file as text.
let readTextFile = (path: string, ~options: readOptions=?): promise<string> => {
  Gossamer_Core.invokeRaw("__gossamer_fs_read_text", {"path": path, "options": Obj.magic(options)})
}

/// Write bytes to a file.
let writeFile = (path: string, data: Uint8Array.t, ~options: writeOptions=?): promise<unit> => {
  Gossamer_Core.invokeRaw(
    "__gossamer_fs_write_file",
    {"path": path, "data": data, "options": Obj.magic(options)},
  )
}

/// Write text to a file.
let writeTextFile = (path: string, contents: string, ~options: writeOptions=?): promise<unit> => {
  Gossamer_Core.invokeRaw(
    "__gossamer_fs_write_text",
    {"path": path, "contents": contents, "options": Obj.magic(options)},
  )
}

// ============================================================================
// Directory Operations
// ============================================================================

/// Read directory contents.
let readDir = (path: string, ~options: readOptions=?): promise<array<dirEntry>> => {
  Gossamer_Core.invokeRaw("__gossamer_fs_read_dir", {"path": path, "options": Obj.magic(options)})
}

/// Create a directory.
let mkdir = (path: string, ~options: mkdirOptions=?): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_fs_mkdir", {"path": path, "options": Obj.magic(options)})
}

/// Remove a file or directory.
let remove = (path: string, ~options: removeOptions=?): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_fs_remove", {"path": path, "options": Obj.magic(options)})
}

/// Copy a file.
let copyFile = (from: string, to: string): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_fs_copy", {"from": from, "to": to})
}

/// Rename/move a file.
let rename = (oldPath: string, newPath: string): promise<unit> => {
  Gossamer_Core.invokeRaw("__gossamer_fs_rename", {"oldPath": oldPath, "newPath": newPath})
}

// ============================================================================
// File Metadata
// ============================================================================

/// Get file/directory info.
let stat = (path: string, ~options: readOptions=?): promise<fileInfo> => {
  Gossamer_Core.invokeRaw("__gossamer_fs_stat", {"path": path, "options": Obj.magic(options)})
}

/// Check if a path exists.
let exists = (path: string, ~options: readOptions=?): promise<bool> => {
  Gossamer_Core.invokeRaw("__gossamer_fs_exists", {"path": path, "options": Obj.magic(options)})
}

// ============================================================================
// File Watching
// ============================================================================

/// Watch a file or directory for changes.
let watch = (path: string, callback: watchEvent => unit, ~options: watchOptions=?): promise<
  unit => unit,
> => {
  Gossamer_Core.invokeRaw(
    "__gossamer_fs_watch",
    {"path": path, "callback": callback, "options": Obj.magic(options)},
  )
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Read a JSON file and parse it.
let readJsonFile = async (path: string, ~options=?): result<JSON.t, string> => {
  try {
    let content = await readTextFile(path, ~options?)
    switch JSON.parseExn(content) {
    | json => Ok(json)
    | exception _ => Error("Failed to parse JSON")
    }
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to read file"))
  | _ => Error("Failed to read file")
  }
}

/// Write a JSON value to a file.
let writeJsonFile = async (
  path: string,
  data: JSON.t,
  ~options=?,
): result<unit, string> => {
  try {
    let content = JSON.stringify(data, ~space=2)
    await writeTextFile(path, content, ~options?)
    Ok()
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to write file"))
  | _ => Error("Failed to write file")
  }
}

/// Ensure a directory exists, creating it if necessary.
let ensureDir = async (path: string, ~options=?): result<unit, string> => {
  try {
    let baseDir: option<baseDirectory> = switch options {
    | Some(o: mkdirOptions) => o.baseDir
    | None => None
    }
    let dirExists = await exists(path, ~options={baseDir: ?baseDir})
    if !dirExists {
      switch options {
      | Some(o: mkdirOptions) => await mkdir(path, ~options={...o, recursive: true})
      | None => await mkdir(path, ~options={recursive: true})
      }
    }
    Ok()
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to ensure directory"))
  | _ => Error("Failed to ensure directory")
  }
}
