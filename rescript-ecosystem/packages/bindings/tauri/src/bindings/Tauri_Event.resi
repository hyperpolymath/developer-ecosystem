// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Event.resi - Interface for Tauri event system bindings

// ============================================================================
// Types
// ============================================================================

type event<'payload> = {
  id: int,
  event: string,
  payload: 'payload,
}

type eventTarget =
  | @as("any") Any
  | @as("app") App
  | @as("webview") Webview
  | @as("webviewWindow") WebviewWindow

type emitOptions = {target?: eventTarget}
type unlisten = unit => unit
type eventHandler<'payload> = event<'payload> => unit

// ============================================================================
// Built-in Event Names
// ============================================================================

module EventName: {
  let windowResized: string
  let windowMoved: string
  let windowCloseRequested: string
  let windowDestroyed: string
  let windowFocused: string
  let windowBlurred: string
  let windowScaleChanged: string
  let windowThemeChanged: string
  let windowCreated: string
  let menuClicked: string
  let dragEnter: string
  let dragOver: string
  let dragDrop: string
  let dragLeave: string
}

// ============================================================================
// Event Listeners
// ============================================================================

let listen: (string, eventHandler<'payload>) => promise<unlisten>
let once: (string, eventHandler<'payload>) => promise<unlisten>

// ============================================================================
// Event Emitters
// ============================================================================

let emit: (string, ~payload: 'payload=?) => promise<unit>
let emitTo: (eventTarget, string, ~payload: 'payload=?) => promise<unit>

// ============================================================================
// Helper Functions
// ============================================================================

let listenWithCleanup: (string, eventHandler<'payload>) => promise<unit => unit>
let createEventChannel: string => (eventHandler<'payload> => unit => unit)
let emitAndWait: (
  string,
  'request,
  string,
  ~timeout: int=?,
) => promise<promise<result<'response, string>>>
