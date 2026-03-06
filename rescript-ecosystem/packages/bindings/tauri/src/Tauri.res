// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri.res - Main entry point for rescript-tauri
// ReScript bindings for Tauri 2.0

/**
 * rescript-tauri provides type-safe ReScript bindings for Tauri 2.0.
 *
 * ## Quick Start
 *
 * ```rescript
 * open Tauri
 *
 * // Define a typed command
 * let greetCommand = Command.defineCommand(
 *   ~name="greet",
 *   ~encode=args => {"name": args},
 *   ~decode=json => Ok(Obj.magic(json)),
 * )
 *
 * // Execute the command
 * let result = await Command.execute(greetCommand, "World")
 * ```
 *
 * ## Modules
 *
 * - `Core` - Core invoke and app info
 * - `Event` - Event system for pub/sub
 * - `Window` - Window management
 * - `Command` - Type-safe command bridge
 * - `Fs` - Filesystem operations
 * - `Dialog` - Native file/message dialogs
 * - `Shell` - Shell commands and process spawning
 * - `Notification` - System notifications
 * - `Clipboard` - Clipboard read/write
 */

// Re-export all modules
module Core = Tauri_Core
module Event = Tauri_Event
module Window = Tauri_Window
module Command = Tauri_Command
module Fs = Tauri_Fs
module Dialog = Tauri_Dialog
module Shell = Tauri_Shell
module Notification = Tauri_Notification
module Clipboard = Tauri_Clipboard

// Convenience re-exports for common operations
let invoke = Core.invoke
let listen = Event.listen
let emit = Event.emit
let getCurrentWindow = Window.getCurrentWindow
