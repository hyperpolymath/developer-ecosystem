; SPDX-License-Identifier: PMPL-1.0-or-later
; SPDX-FileCopyrightText: 2026 Hyperpolymath
;
; STATE.scm - Project state for rescript-tauri
; Media-Type: application/vnd.hyperpolymath.state+scm

(state
  (metadata
    (version "0.1.0")
    (schema-version "1.0")
    (created "2026-01-05")
    (updated "2026-01-05")
    (project "rescript-tauri")
    (repo "hyperpolymath/rescript-tauri"))

  (project-context
    (name "rescript-tauri")
    (tagline "ReScript bindings for Tauri 2.0 - Desktop and mobile apps with type safety")
    (tech-stack
      (primary "ReScript")
      (runtime "Tauri 2.0")
      (backend "Rust")
      (frontend-pattern "TEA via rescript-tea")))

  (current-position
    (phase "v0-initial")
    (overall-completion 30)
    (components
      (core-bindings
        (status "complete")
        (items
          ("Tauri_Core" "complete" "invoke, channel, resource, app info")
          ("Tauri_Event" "complete" "listen, emit, event channels")
          ("Tauri_Window" "complete" "window management, properties, events")))
      (command-bridge
        (status "complete")
        (items
          ("Tauri_Command" "complete" "typed request/response, error handling, retry, timeout")))
      (plugins
        (status "partial")
        (items
          ("Tauri_Fs" "complete" "filesystem operations, watch, helpers")
          ("Tauri_Dialog" "complete" "file pickers, message dialogs, builders")
          ("Tauri_Shell" "gap" "open URLs, spawn processes")
          ("Tauri_Notification" "gap" "system notifications")
          ("Tauri_Clipboard" "gap" "clipboard operations")
          ("Tauri_Os" "gap" "platform info")
          ("Tauri_Path" "gap" "path utilities")))
      (examples
        (status "partial")
        (items
          ("counter" "complete" "TEA counter with Rust backend"))))
    (working-features
      ("Core invoke with typed arguments")
      ("Event system with listeners and emitters")
      ("Window management and events")
      ("Command bridge with error handling")
      ("Filesystem read/write operations")
      ("Native file/save dialogs")
      ("Reference counter app with rescript-tea")))

  (route-to-mvp
    (milestones
      (v0-core
        (status "complete")
        (description "Core bindings for basic Tauri apps")
        (items
          ("Core invoke API" #t)
          ("Event system" #t)
          ("Window management" #t)
          ("Command bridge pattern" #t)
          ("Filesystem plugin" #t)
          ("Dialog plugin" #t)
          ("Counter example" #t)))
      (v0-plugins
        (status "in-progress")
        (description "Essential plugin bindings")
        (items
          ("Shell plugin" #f)
          ("Notification plugin" #f)
          ("Clipboard plugin" #f)
          ("OS info plugin" #f)
          ("Path utilities" #f)))
      (v1-production
        (status "planned")
        (description "Production-ready bindings")
        (items
          ("HTTP client plugin" #f)
          ("Updater plugin" #f)
          ("Deep link plugin" #f)
          ("Global shortcut plugin" #f)
          ("System tray" #f)
          ("Comprehensive test suite" #f)
          ("Documentation site" #f)))))

  (blockers-and-issues
    (critical ())
    (high-priority
      (("Tauri 2.0 API stability" "API may change before final release")))
    (medium-priority
      (("Mobile platform testing" "Need iOS/Android test devices")))
    (low-priority
      (("Plugin coverage" "Many plugins not yet bound"))))

  (critical-next-actions
    (immediate
      ("Add shell plugin bindings")
      ("Add notification plugin bindings")
      ("Test on macOS/Windows/Linux"))
    (this-week
      ("Add clipboard plugin")
      ("Create todoapp example with rescript-sqlite mock"))
    (this-month
      ("Test mobile builds (iOS/Android)")
      ("Integration with rescript-sqlite when ready")
      ("Publish to npm/jsr")))

  (session-history
    (("2026-01-05" "initial-setup"
      ("Created repo structure")
      ("Implemented core bindings (Core, Event, Window)")
      ("Implemented command bridge pattern")
      ("Implemented Fs and Dialog plugins")
      ("Created counter example app")))))
