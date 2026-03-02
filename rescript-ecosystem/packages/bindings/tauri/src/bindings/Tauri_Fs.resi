// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Fs.resi - Interface for Tauri filesystem bindings

open RescriptCore

// ============================================================================
// Types
// ============================================================================

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

type seekMode =
  | @as(0) Start
  | @as(1) Current
  | @as(2) End

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

type dirEntry = {
  name: string,
  isFile: bool,
  isDirectory: bool,
  isSymlink: bool,
}

type watchEventKind =
  | @as("create") Create
  | @as("modify") Modify
  | @as("remove") Remove
  | @as("any") Any

type watchEvent = {
  @as("type") kind: watchEventKind,
  paths: array<string>,
  attrs: JSON.t,
}

type fileHandle

type readOptions = {baseDir?: baseDirectory}

type writeOptions = {
  append?: bool,
  create?: bool,
  createNew?: bool,
  mode?: int,
  baseDir?: baseDirectory,
}

type copyOptions = {
  fromPathBaseDir?: baseDirectory,
  toPathBaseDir?: baseDirectory,
}

type removeOptions = {
  recursive?: bool,
  baseDir?: baseDirectory,
}

type renameOptions = {
  oldPathBaseDir?: baseDirectory,
  newPathBaseDir?: baseDirectory,
}

type mkdirOptions = {
  recursive?: bool,
  mode?: int,
  baseDir?: baseDirectory,
}

type watchOptions = {
  recursive?: bool,
  baseDir?: baseDirectory,
  delayMs?: int,
}

// ============================================================================
// File Operations
// ============================================================================

let readFile: (string, ~options: readOptions=?) => promise<Uint8Array.t>
let readTextFile: (string, ~options: readOptions=?) => promise<string>
let writeFile: (string, Uint8Array.t, ~options: writeOptions=?) => promise<unit>
let writeTextFile: (string, string, ~options: writeOptions=?) => promise<unit>

// ============================================================================
// File Handle Operations
// ============================================================================

let open_: (string, ~options: openOptions=?) => promise<fileHandle>
let close: fileHandle => promise<unit>
let read: (fileHandle, Uint8Array.t) => promise<int>
let write: (fileHandle, Uint8Array.t) => promise<int>
let seek: (fileHandle, float, seekMode) => promise<float>
let stat: fileHandle => promise<fileInfo>
let truncate: (fileHandle, ~len: float=?) => promise<unit>

// ============================================================================
// Directory Operations
// ============================================================================

let readDir: (string, ~options: readOptions=?) => promise<array<dirEntry>>
let mkdir: (string, ~options: mkdirOptions=?) => promise<unit>
let remove: (string, ~options: removeOptions=?) => promise<unit>
let copyFile: (string, string, ~options: copyOptions=?) => promise<unit>
let rename: (string, string, ~options: renameOptions=?) => promise<unit>

// ============================================================================
// File Metadata
// ============================================================================

let lstat: (string, ~options: readOptions=?) => promise<fileInfo>
let exists: (string, ~options: readOptions=?) => promise<bool>

// ============================================================================
// File Watching
// ============================================================================

let watch: (string, watchEvent => unit, ~options: watchOptions=?) => promise<unit => unit>
let watchImmediate: (
  array<string>,
  watchEvent => unit,
  ~options: watchOptions=?,
) => promise<unit => unit>

// ============================================================================
// Helper Functions
// ============================================================================

let readJsonFile: (string, ~options: readOptions=?) => promise<result<JSON.t, string>>
let writeJsonFile: (string, JSON.t, ~options: writeOptions=?) => promise<result<unit, string>>
let ensureDir: (string, ~options: mkdirOptions=?) => promise<result<unit, string>>
let listFilesRecursive: (string, ~options: readOptions=?) => promise<result<array<string>, string>>
