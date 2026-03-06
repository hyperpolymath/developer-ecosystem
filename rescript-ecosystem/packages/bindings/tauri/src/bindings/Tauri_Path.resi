// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Path.resi - Interface for Tauri Path bindings

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
let audioDir: unit => promise<string>

/** Returns the path to the user's cache directory */
let cacheDir: unit => promise<string>

/** Returns the path to the user's config directory */
let configDir: unit => promise<string>

/** Returns the path to the user's data directory */
let dataDir: unit => promise<string>

/** Returns the path to the user's local data directory */
let localDataDir: unit => promise<string>

/** Returns the path to the user's document directory */
let documentDir: unit => promise<string>

/** Returns the path to the user's download directory */
let downloadDir: unit => promise<string>

/** Returns the path to the user's picture directory */
let pictureDir: unit => promise<string>

/** Returns the path to the user's public directory */
let publicDir: unit => promise<string>

/** Returns the path to the user's video directory */
let videoDir: unit => promise<string>

/** Returns the path to the user's desktop directory */
let desktopDir: unit => promise<string>

/** Returns the path to the user's executable directory */
let executableDir: unit => promise<string>

/** Returns the path to the user's font directory */
let fontDir: unit => promise<string>

/** Returns the path to the user's home directory */
let homeDir: unit => promise<string>

/** Returns the path to the user's runtime directory */
let runtimeDir: unit => promise<string>

/** Returns the path to the user's template directory */
let templateDir: unit => promise<string>

/** Returns the path to the application's resource directory */
let resourceDir: unit => promise<string>

/** Returns the path to the system's temp directory */
let tempDir: unit => promise<string>

/** Returns the path to the application's config directory */
let appConfigDir: unit => promise<string>

/** Returns the path to the application's data directory */
let appDataDir: unit => promise<string>

/** Returns the path to the application's local data directory */
let appLocalDataDir: unit => promise<string>

/** Returns the path to the application's cache directory */
let appCacheDir: unit => promise<string>

/** Returns the path to the application's log directory */
let appLogDir: unit => promise<string>

// ============================================================================
// Path Manipulation Functions
// ============================================================================

/** Returns the path separator for the current platform */
let sep: unit => string

/** Returns the path delimiter for the current platform (: on Unix, ; on Windows) */
let delimiter: unit => string

/** Joins path segments */
let join: array<string> => promise<string>

/** Normalizes a path */
let normalize: string => promise<string>

/** Resolves a path to an absolute path */
let resolve: array<string> => promise<string>

/** Returns the directory name of a path */
let dirname: string => promise<string>

/** Returns the base name of a path */
let basename: string => promise<string>

/** Returns the base name of a path, optionally removing a suffix */
let basenameWithExt: (string, string) => promise<string>

/** Returns the extension of a path */
let extname: string => promise<string>

/** Checks if a path is absolute */
let isAbsolute: string => promise<bool>

// ============================================================================
// Helper Functions
// ============================================================================

/** Get the directory for a base directory enum value */
let getBaseDir: baseDirectory => promise<string>

/** Join a base directory with path segments */
let joinFromBase: (baseDirectory, array<string>) => promise<string>

/** Build a path in the app data directory */
let inAppData: array<string> => promise<string>

/** Build a path in the app config directory */
let inAppConfig: array<string> => promise<string>

/** Build a path in the app cache directory */
let inAppCache: array<string> => promise<string>

/** Build a path in the temp directory */
let inTemp: array<string> => promise<string>

/** Build a path in the home directory */
let inHome: array<string> => promise<string>
