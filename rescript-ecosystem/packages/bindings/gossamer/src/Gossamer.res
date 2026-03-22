// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Gossamer.res — Top-level re-export module for rescript-gossamer bindings.
//
// Usage:
//   open Gossamer
//   let _ = Core.invoke("my_command")
//   let _ = Dialog.openSingle()
//   let _ = Fs.readTextFile("/path/to/file")
//   let _ = Window.Current.closeCurrent()

/// Core invoke and command bindings for Gossamer IPC.
module Core = Gossamer_Core

/// File picker, save, message, and confirmation dialog bindings.
module Dialog = Gossamer_Dialog

/// Filesystem operations (read, write, mkdir, stat, watch).
module Fs = Gossamer_Fs

/// Window management (resize, move, minimize, maximize, etc.).
module Window = Gossamer_Window
