// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Path.res - ReScript bindings for @tauri-apps/api/path

// ============================================================================
// Base Directory Enum
// ============================================================================

/** Base directories available on the system */
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

// ============================================================================
// Directory Path Functions
// ============================================================================

/** Returns the path to the user's audio directory */
@module("@tauri-apps/api/path")
external audioDir: unit => promise<string> = "audioDir"

/** Returns the path to the user's cache directory */
@module("@tauri-apps/api/path")
external cacheDir: unit => promise<string> = "cacheDir"

/** Returns the path to the user's config directory */
@module("@tauri-apps/api/path")
external configDir: unit => promise<string> = "configDir"

/** Returns the path to the user's data directory */
@module("@tauri-apps/api/path")
external dataDir: unit => promise<string> = "dataDir"

/** Returns the path to the user's local data directory */
@module("@tauri-apps/api/path")
external localDataDir: unit => promise<string> = "localDataDir"

/** Returns the path to the user's document directory */
@module("@tauri-apps/api/path")
external documentDir: unit => promise<string> = "documentDir"

/** Returns the path to the user's download directory */
@module("@tauri-apps/api/path")
external downloadDir: unit => promise<string> = "downloadDir"

/** Returns the path to the user's picture directory */
@module("@tauri-apps/api/path")
external pictureDir: unit => promise<string> = "pictureDir"

/** Returns the path to the user's public directory */
@module("@tauri-apps/api/path")
external publicDir: unit => promise<string> = "publicDir"

/** Returns the path to the user's video directory */
@module("@tauri-apps/api/path")
external videoDir: unit => promise<string> = "videoDir"

/** Returns the path to the user's desktop directory */
@module("@tauri-apps/api/path")
external desktopDir: unit => promise<string> = "desktopDir"

/** Returns the path to the user's executable directory */
@module("@tauri-apps/api/path")
external executableDir: unit => promise<string> = "executableDir"

/** Returns the path to the user's font directory */
@module("@tauri-apps/api/path")
external fontDir: unit => promise<string> = "fontDir"

/** Returns the path to the user's home directory */
@module("@tauri-apps/api/path")
external homeDir: unit => promise<string> = "homeDir"

/** Returns the path to the user's runtime directory */
@module("@tauri-apps/api/path")
external runtimeDir: unit => promise<string> = "runtimeDir"

/** Returns the path to the user's template directory */
@module("@tauri-apps/api/path")
external templateDir: unit => promise<string> = "templateDir"

/** Returns the path to the application's resource directory */
@module("@tauri-apps/api/path")
external resourceDir: unit => promise<string> = "resourceDir"

/** Returns the path to the system's temp directory */
@module("@tauri-apps/api/path")
external tempDir: unit => promise<string> = "tempDir"

/** Returns the path to the application's config directory */
@module("@tauri-apps/api/path")
external appConfigDir: unit => promise<string> = "appConfigDir"

/** Returns the path to the application's data directory */
@module("@tauri-apps/api/path")
external appDataDir: unit => promise<string> = "appDataDir"

/** Returns the path to the application's local data directory */
@module("@tauri-apps/api/path")
external appLocalDataDir: unit => promise<string> = "appLocalDataDir"

/** Returns the path to the application's cache directory */
@module("@tauri-apps/api/path")
external appCacheDir: unit => promise<string> = "appCacheDir"

/** Returns the path to the application's log directory */
@module("@tauri-apps/api/path")
external appLogDir: unit => promise<string> = "appLogDir"

// ============================================================================
// Path Manipulation Functions
// ============================================================================

/** Returns the path separator for the current platform */
@module("@tauri-apps/api/path")
external sep: unit => string = "sep"

/** Returns the path delimiter for the current platform (: on Unix, ; on Windows) */
@module("@tauri-apps/api/path")
external delimiter: unit => string = "delimiter"

/** Joins path segments */
@module("@tauri-apps/api/path")
external join: array<string> => promise<string> = "join"

/** Normalizes a path */
@module("@tauri-apps/api/path")
external normalize: string => promise<string> = "normalize"

/** Resolves a path to an absolute path */
@module("@tauri-apps/api/path")
external resolve: array<string> => promise<string> = "resolve"

/** Returns the directory name of a path */
@module("@tauri-apps/api/path")
external dirname: string => promise<string> = "dirname"

/** Returns the base name of a path */
@module("@tauri-apps/api/path")
external basename: string => promise<string> = "basename"

/** Returns the base name of a path, optionally removing a suffix */
@module("@tauri-apps/api/path")
external basenameWithExt: (string, string) => promise<string> = "basename"

/** Returns the extension of a path */
@module("@tauri-apps/api/path")
external extname: string => promise<string> = "extname"

/** Checks if a path is absolute */
@module("@tauri-apps/api/path")
external isAbsolute: string => promise<bool> = "isAbsolute"

// ============================================================================
// Helper Functions
// ============================================================================

/** Get the directory for a base directory enum value */
let getBaseDir = async (dir: baseDirectory) => {
  switch dir {
  | Audio => await audioDir()
  | Cache => await cacheDir()
  | Config => await configDir()
  | Data => await dataDir()
  | LocalData => await localDataDir()
  | Document => await documentDir()
  | Download => await downloadDir()
  | Picture => await pictureDir()
  | Public => await publicDir()
  | Video => await videoDir()
  | Resource => await resourceDir()
  | Temp => await tempDir()
  | AppConfig => await appConfigDir()
  | AppData => await appDataDir()
  | AppLocalData => await appLocalDataDir()
  | AppCache => await appCacheDir()
  | AppLog => await appLogDir()
  | Desktop => await desktopDir()
  | Executable => await executableDir()
  | Font => await fontDir()
  | Home => await homeDir()
  | Runtime => await runtimeDir()
  | Template => await templateDir()
  }
}

// Helper to prepend an element to an array using JS spread
@val external arraySpread: (array<'a>, array<'a>) => array<'a> = "Array.prototype.concat.call"

let prependToArray = (elem: 'a, arr: array<'a>): array<'a> => {
  Array.concat(list{[elem], arr})
}

/** Join a base directory with path segments */
let joinFromBase = async (dir: baseDirectory, segments: array<string>) => {
  let base = await getBaseDir(dir)
  await join(prependToArray(base, segments))
}

/** Build a path in the app data directory */
let inAppData = async (segments: array<string>) => {
  await joinFromBase(AppData, segments)
}

/** Build a path in the app config directory */
let inAppConfig = async (segments: array<string>) => {
  await joinFromBase(AppConfig, segments)
}

/** Build a path in the app cache directory */
let inAppCache = async (segments: array<string>) => {
  await joinFromBase(AppCache, segments)
}

/** Build a path in the temp directory */
let inTemp = async (segments: array<string>) => {
  await joinFromBase(Temp, segments)
}

/** Build a path in the home directory */
let inHome = async (segments: array<string>) => {
  await joinFromBase(Home, segments)
}
