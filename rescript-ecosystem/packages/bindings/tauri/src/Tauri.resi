// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri.resi - Public interface for rescript-tauri

module Core = Tauri_Core
module Event = Tauri_Event
module Window = Tauri_Window
module Command = Tauri_Command
module Fs = Tauri_Fs
module Dialog = Tauri_Dialog
module Shell = Tauri_Shell
module Notification = Tauri_Notification
module Clipboard = Tauri_Clipboard

// Convenience re-exports
let invoke: (string, ~args: Core.invokeArgs=?, ~options: Core.invokeOptions=?) => promise<'response>
let listen: (string, Event.eventHandler<'payload>) => promise<Event.unlisten>
let emit: (string, ~payload: 'payload=?) => promise<unit>
let getCurrentWindow: unit => Window.window
