// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Fs.res - Tauri 2.0 filesystem bindings
// ReScript bindings for @tauri-apps/plugin-fs

open RescriptCore

// ============================================================================
// Types
// ============================================================================

/** Base directory for file operations */
type baseDirectory =
  | @as(1) Audio
  | @as(2) Cache
  | @as(3) Config
  | @as(4) Data
  | @as(5) LocalData
  | @as(6) Document
  | @as(7) Download
  | @as(8) Picture
  | @as(9) Public
  | @as(10) Video
  | @as(11) Resource
  | @as(12) Temp
  | @as(13) AppConfig
  | @as(14) AppData
  | @as(15) AppLocalData
  | @as(16) AppCache
  | @as(17) AppLog
  | @as(18) Desktop
  | @as(19) Executable
  | @as(20) Font
  | @as(21) Home
  | @as(22) Runtime
  | @as(23) Template

/** File seek mode */
type seekMode =
  | @as(0) Start
  | @as(1) Current
  | @as(2) End

/** File open options */
type openOptions = {
  read?: bool,
  write?: bool,
  append?: bool,
  truncate?: bool,
  create?: bool,
  createNew?: bool,
  mode?: int,
  baseDir?: baseDirectory,
}

/** File info (stat result) */
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

/** Directory entry */
type dirEntry = {
  name: string,
  isFile: bool,
  isDirectory: bool,
  isSymlink: bool,
}

/** Watch event kinds */
type watchEventKind =
  | @as("create") Create
  | @as("modify") Modify
  | @as("remove") Remove
  | @as("any") Any

/** Watch event */
type watchEvent = {
  @as("type") kind: watchEventKind,
  paths: array<string>,
  attrs: JSON.t,
}

/** File handle (opaque) */
type fileHandle

/** Read options */
type readOptions = {baseDir?: baseDirectory}

/** Write options */
type writeOptions = {
  append?: bool,
  create?: bool,
  createNew?: bool,
  mode?: int,
  baseDir?: baseDirectory,
}

/** Copy options */
type copyOptions = {
  fromPathBaseDir?: baseDirectory,
  toPathBaseDir?: baseDirectory,
}

/** Remove options */
type removeOptions = {
  recursive?: bool,
  baseDir?: baseDirectory,
}

/** Rename options */
type renameOptions = {
  oldPathBaseDir?: baseDirectory,
  newPathBaseDir?: baseDirectory,
}

/** Mkdir options */
type mkdirOptions = {
  recursive?: bool,
  mode?: int,
  baseDir?: baseDirectory,
}

/** Watch options */
type watchOptions = {
  recursive?: bool,
  baseDir?: baseDirectory,
  delayMs?: int,
}

// ============================================================================
// File Operations
// ============================================================================

/** Read a file as bytes */
@module("@tauri-apps/plugin-fs")
external readFile: (string, ~options: readOptions=?) => promise<Uint8Array.t> = "readFile"

/** Read a file as text */
@module("@tauri-apps/plugin-fs")
external readTextFile: (string, ~options: readOptions=?) => promise<string> = "readTextFile"

/** Write bytes to a file */
@module("@tauri-apps/plugin-fs")
external writeFile: (string, Uint8Array.t, ~options: writeOptions=?) => promise<unit> = "writeFile"

/** Write text to a file */
@module("@tauri-apps/plugin-fs")
external writeTextFile: (string, string, ~options: writeOptions=?) => promise<unit> = "writeTextFile"

// ============================================================================
// File Handle Operations
// ============================================================================

/** Open a file and get a handle */
@module("@tauri-apps/plugin-fs")
external open_: (string, ~options: openOptions=?) => promise<fileHandle> = "open"

/** Close a file handle */
@send external close: fileHandle => promise<unit> = "close"

/** Read from file handle */
@send external read: (fileHandle, Uint8Array.t) => promise<int> = "read"

/** Write to file handle */
@send external write: (fileHandle, Uint8Array.t) => promise<int> = "write"

/** Seek in file */
@send external seek: (fileHandle, float, seekMode) => promise<float> = "seek"

/** Get file stat from handle */
@send external stat: fileHandle => promise<fileInfo> = "stat"

/** Truncate file */
@send external truncate: (fileHandle, ~len: float=?) => promise<unit> = "truncate"

// ============================================================================
// Directory Operations
// ============================================================================

/** Read directory contents */
@module("@tauri-apps/plugin-fs")
external readDir: (string, ~options: readOptions=?) => promise<array<dirEntry>> = "readDir"

/** Create a directory */
@module("@tauri-apps/plugin-fs")
external mkdir: (string, ~options: mkdirOptions=?) => promise<unit> = "mkdir"

/** Remove a file or directory */
@module("@tauri-apps/plugin-fs")
external remove: (string, ~options: removeOptions=?) => promise<unit> = "remove"

/** Copy a file */
@module("@tauri-apps/plugin-fs")
external copyFile: (string, string, ~options: copyOptions=?) => promise<unit> = "copyFile"

/** Rename/move a file */
@module("@tauri-apps/plugin-fs")
external rename: (string, string, ~options: renameOptions=?) => promise<unit> = "rename"

// ============================================================================
// File Metadata
// ============================================================================

/** Get file/directory info */
@module("@tauri-apps/plugin-fs")
external lstat: (string, ~options: readOptions=?) => promise<fileInfo> = "lstat"

/** Check if path exists */
@module("@tauri-apps/plugin-fs")
external exists: (string, ~options: readOptions=?) => promise<bool> = "exists"

// ============================================================================
// File Watching
// ============================================================================

/** Watch a file or directory for changes */
@module("@tauri-apps/plugin-fs")
external watch: (string, watchEvent => unit, ~options: watchOptions=?) => promise<unit => unit> =
  "watch"

/** Watch multiple paths */
@module("@tauri-apps/plugin-fs")
external watchImmediate: (
  array<string>,
  watchEvent => unit,
  ~options: watchOptions=?,
) => promise<unit => unit> = "watchImmediate"

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Read a JSON file and parse it.
 */
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

/**
 * Write a JSON value to a file.
 */
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

/**
 * Ensure a directory exists, creating it if necessary.
 */
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

/**
 * List all files in a directory recursively.
 */
let rec listFilesRecursive = async (
  path: string,
  ~options=?,
): result<array<string>, string> => {
  try {
    let entries = await readDir(path, ~options?)
    let allFiles = []

    for i in 0 to Array.length(entries) - 1 {
      let entry = entries[i]->Option.getExn
      let fullPath = `${path}/${entry.name}`

      if entry.isDirectory {
        switch await listFilesRecursive(fullPath, ~options?) {
        | Ok(subFiles) => Array.forEach(subFiles, f => Array.push(allFiles, f)->ignore)
        | Error(_) => ()
        }
      } else {
        Array.push(allFiles, fullPath)->ignore
      }
    }

    Ok(allFiles)
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to list files"))
  | _ => Error("Failed to list files")
  }
}
