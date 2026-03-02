// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Notification.res - Tauri 2.0 notification plugin bindings
// ReScript bindings for @tauri-apps/plugin-notification

open RescriptCore

// ============================================================================
// Types
// ============================================================================

/** Permission state for notifications */
type permissionState =
  | @as("granted") Granted
  | @as("denied") Denied
  | @as("default") Default

/** Notification action */
type notificationAction = {
  id: string,
  title: string,
}

/** Notification options */
type notificationOptions = {
  title: string,
  body?: string,
  icon?: string,
  sound?: string,
  tag?: string,
  actions?: array<notificationAction>,
  silent?: bool,
}

/** Active notification (returned after send) */
type activeNotification = {
  id: int,
}

/** Notification event payload */
type notificationEvent = {
  id: int,
  actionId: option<string>,
}

// ============================================================================
// Permission API
// ============================================================================

/** Check if notifications are permitted */
@module("@tauri-apps/plugin-notification")
external isPermissionGranted: unit => promise<bool> = "isPermissionGranted"

/** Request notification permission */
@module("@tauri-apps/plugin-notification")
external requestPermission: unit => promise<permissionState> = "requestPermission"

/** Check current permission state */
@module("@tauri-apps/plugin-notification")
external permissionState: unit => promise<permissionState> = "permissionState"

// ============================================================================
// Notification API
// ============================================================================

/** Send a notification */
@module("@tauri-apps/plugin-notification")
external sendNotification: notificationOptions => promise<unit> = "sendNotification"

/** Register a notification channel (Android) */
@module("@tauri-apps/plugin-notification")
external registerActionTypes: array<notificationAction> => promise<unit> = "registerActionTypes"

/** Remove active notifications */
@module("@tauri-apps/plugin-notification")
external removeActiveNotifications: array<int> => promise<unit> = "removeActiveNotifications"

/** Remove all active notifications */
@module("@tauri-apps/plugin-notification")
external removeAllActiveNotifications: unit => promise<unit> = "removeAllActiveNotifications"

/** Get all pending notifications */
@module("@tauri-apps/plugin-notification")
external getPendingNotifications: unit => promise<array<activeNotification>> =
  "getPendingNotifications"

/** Get all active notifications */
@module("@tauri-apps/plugin-notification")
external getActiveNotifications: unit => promise<array<activeNotification>> =
  "getActiveNotifications"

// ============================================================================
// Event Listeners
// ============================================================================

/** Listen for notification action events */
@module("@tauri-apps/plugin-notification")
external onNotificationReceived: (notificationEvent => unit) => promise<unit => unit> =
  "onNotificationReceived"

/** Listen for notification action clicks */
@module("@tauri-apps/plugin-notification")
external onAction: (notificationEvent => unit) => promise<unit => unit> = "onAction"

// ============================================================================
// High-Level Helpers
// ============================================================================

/**
 * Send a simple notification with just title and body.
 */
let notify = async (title: string, ~body=?): result<unit, string> => {
  try {
    let permitted = await isPermissionGranted()
    if !permitted {
      let state = await requestPermission()
      if state != Granted {
        Error("Notification permission denied")
      } else {
        await sendNotification({title, ?body})
        Ok()
      }
    } else {
      await sendNotification({title, ?body})
      Ok()
    }
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to send notification"))
  | _ => Error("Failed to send notification")
  }
}

/**
 * Send a notification with full options.
 * Automatically handles permission request.
 */
let send = async (options: notificationOptions): result<unit, string> => {
  try {
    let permitted = await isPermissionGranted()
    if !permitted {
      let state = await requestPermission()
      if state != Granted {
        Error("Notification permission denied")
      } else {
        await sendNotification(options)
        Ok()
      }
    } else {
      await sendNotification(options)
      Ok()
    }
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to send notification"))
  | _ => Error("Failed to send notification")
  }
}

/**
 * Check if notifications are available (permission granted).
 */
let isAvailable = async (): bool => {
  try {
    await isPermissionGranted()
  } catch {
  | _ => false
  }
}

/**
 * Ensure notification permission is granted, requesting if needed.
 */
let ensurePermission = async (): result<unit, string> => {
  try {
    let permitted = await isPermissionGranted()
    if permitted {
      Ok()
    } else {
      let state = await requestPermission()
      if state == Granted {
        Ok()
      } else {
        Error("Notification permission denied")
      }
    }
  } catch {
  | Exn.Error(err) => Error(Exn.message(err)->Option.getOr("Failed to check permission"))
  | _ => Error("Failed to check permission")
  }
}

// ============================================================================
// Notification Builder (Fluent API)
// ============================================================================

module NotificationBuilder = {
  type t = notificationOptions

  let make = (title: string): t => {title: title}

  let body = (builder: t, text: string): t => {
    {...builder, body: text}
  }

  let icon = (builder: t, path: string): t => {
    {...builder, icon: path}
  }

  let sound = (builder: t, name: string): t => {
    {...builder, sound: name}
  }

  let tag = (builder: t, tag: string): t => {
    {...builder, tag}
  }

  let silent = (builder: t): t => {
    {...builder, silent: true}
  }

  let action = (builder: t, id: string, title: string): t => {
    let existing = builder.actions->Option.getOr([])
    {...builder, actions: Array.concat(existing, [{id, title}])}
  }

  let send_ = async (builder: t): result<unit, string> => {
    await send(builder)
  }
}
