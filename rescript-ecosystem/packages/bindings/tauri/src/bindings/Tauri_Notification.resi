// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Notification.resi - Interface for Tauri notification plugin bindings

open RescriptCore

// ============================================================================
// Types
// ============================================================================

type permissionState =
  | @as("granted") Granted
  | @as("denied") Denied
  | @as("default") Default

type notificationAction = {
  id: string,
  title: string,
}

type notificationOptions = {
  title: string,
  body?: string,
  icon?: string,
  sound?: string,
  tag?: string,
  actions?: array<notificationAction>,
  silent?: bool,
}

type activeNotification = {
  id: int,
}

type notificationEvent = {
  id: int,
  actionId: option<string>,
}

// ============================================================================
// Permission API
// ============================================================================

let isPermissionGranted: unit => promise<bool>
let requestPermission: unit => promise<permissionState>
let permissionState: unit => promise<permissionState>

// ============================================================================
// Notification API
// ============================================================================

let sendNotification: notificationOptions => promise<unit>
let registerActionTypes: array<notificationAction> => promise<unit>
let removeActiveNotifications: array<int> => promise<unit>
let removeAllActiveNotifications: unit => promise<unit>
let getPendingNotifications: unit => promise<array<activeNotification>>
let getActiveNotifications: unit => promise<array<activeNotification>>

// ============================================================================
// Event Listeners
// ============================================================================

let onNotificationReceived: (notificationEvent => unit) => promise<unit => unit>
let onAction: (notificationEvent => unit) => promise<unit => unit>

// ============================================================================
// High-Level Helpers
// ============================================================================

let notify: (string, ~body: string=?) => promise<result<unit, string>>
let send: notificationOptions => promise<result<unit, string>>
let isAvailable: unit => promise<bool>
let ensurePermission: unit => promise<result<unit, string>>

// ============================================================================
// Notification Builder (Fluent API)
// ============================================================================

module NotificationBuilder: {
  type t
  let make: string => t
  let body: (t, string) => t
  let icon: (t, string) => t
  let sound: (t, string) => t
  let tag: (t, string) => t
  let silent: t => t
  let action: (t, string, string) => t
  let send_: t => promise<result<unit, string>>
}
