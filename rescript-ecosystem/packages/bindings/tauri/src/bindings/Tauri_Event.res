// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Event.res - Tauri 2.0 event system bindings
// ReScript bindings for @tauri-apps/api/event

open RescriptCore

// ============================================================================
// Timer Bindings (for internal use)
// ============================================================================

type timeoutId

@val external setTimeout: (unit => unit, int) => timeoutId = "setTimeout"
@val external clearTimeout: timeoutId => unit = "clearTimeout"

// ============================================================================
// Types
// ============================================================================

/** Event payload wrapper from Tauri */
type event<'payload> = {
  id: int,
  event: string,
  payload: 'payload,
}

/** Event target - where to send/listen for events */
type eventTarget =
  | @as("any") Any
  | @as("app") App
  | @as("webview") Webview
  | @as("webviewWindow") WebviewWindow

/** Options for emitting events */
type emitOptions = {target?: eventTarget}

/** Unlisten function returned from listen/once */
type unlisten = unit => unit

/** Event handler callback */
type eventHandler<'payload> = event<'payload> => unit

// ============================================================================
// Built-in Event Names (Tauri core events)
// ============================================================================

module EventName = {
  let windowResized = "tauri://resize"
  let windowMoved = "tauri://move"
  let windowCloseRequested = "tauri://close-requested"
  let windowDestroyed = "tauri://destroyed"
  let windowFocused = "tauri://focus"
  let windowBlurred = "tauri://blur"
  let windowScaleChanged = "tauri://scale-change"
  let windowThemeChanged = "tauri://theme-changed"
  let windowCreated = "tauri://window-created"
  let menuClicked = "tauri://menu"
  let dragEnter = "tauri://drag-enter"
  let dragOver = "tauri://drag-over"
  let dragDrop = "tauri://drag-drop"
  let dragLeave = "tauri://drag-leave"
}

// ============================================================================
// Event Listeners
// ============================================================================

/**
 * Listen to an event from the Rust backend or other windows.
 * Returns an unlisten function to stop listening.
 */
@module("@tauri-apps/api/event")
external listen: (string, eventHandler<'payload>) => promise<unlisten> = "listen"

/**
 * Listen to an event only once.
 * Automatically unsubscribes after the first event.
 */
@module("@tauri-apps/api/event")
external once: (string, eventHandler<'payload>) => promise<unlisten> = "once"

// ============================================================================
// Event Emitters
// ============================================================================

/**
 * Emit an event to the Rust backend.
 */
@module("@tauri-apps/api/event")
external emit: (string, ~payload: 'payload=?) => promise<unit> = "emit"

/**
 * Emit an event to a specific target (window, webview, etc.).
 */
@module("@tauri-apps/api/event")
external emitTo: (eventTarget, string, ~payload: 'payload=?) => promise<unit> = "emitTo"

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Listen to an event with automatic cleanup.
 * Returns a cleanup function that can be used in useEffect.
 */
let listenWithCleanup = async (
  eventName: string,
  handler: eventHandler<'payload>,
): (unit => unit) => {
  let unlisten = await listen(eventName, handler)
  () => unlisten()
}

/**
 * Create a typed event channel for specific event types.
 */
let createEventChannel = (eventName: string) => {
  let listeners: ref<array<eventHandler<'payload>>> = ref([])

  let subscribe = (handler: eventHandler<'payload>) => {
    listeners := Array.concat(listeners.contents, [handler])
    () => {
      listeners := Array.filter(listeners.contents, h => h !== handler)
    }
  }

  let _ = listen(eventName, event => {
    Array.forEach(listeners.contents, handler => handler(event))
  })

  subscribe
}

/**
 * Emit an event with a typed payload and wait for acknowledgment.
 */
let emitAndWait = async (
  eventName: string,
  payload: 'request,
  responseEvent: string,
  ~timeout: int=5000,
): promise<result<'response, string>> => {
  Promise.make((resolve, _reject) => {
    let timeoutIdRef = ref(None)

    let cleanup = () => {
      switch timeoutIdRef.contents {
      | Some(id) => clearTimeout(id)
      | None => ()
      }
    }

    let _ = once(responseEvent, (event: event<'response>) => {
      cleanup()
      resolve(Ok(event.payload))
    })

    timeoutIdRef := Some(
      setTimeout(() => {
        resolve(Error(`Timeout waiting for ${responseEvent}`))
      }, timeout),
    )

    let _ = emit(eventName, ~payload)
  })
}
