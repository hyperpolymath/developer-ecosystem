// SPDX-License-Identifier: Apache-2.0
// Navigation.resi - Browser History API abstraction

/**
 * Navigate to URL, adding entry to browser history (pushState)
 */
let pushUrl: string => unit

/**
 * Navigate to URL, replacing current history entry (replaceState)
 */
let replaceUrl: string => unit

/**
 * Go back in browser history
 */
let back: unit => unit

/**
 * Go forward in browser history
 */
let forward: unit => unit

/**
 * Go to specific point in history (negative = back, positive = forward)
 */
let go: int => unit

/**
 * Get current URL
 */
let currentUrl: unit => Url.t

/**
 * Unsubscribe function returned by onUrlChange
 */
type unsubscribe = unit => unit

/**
 * Subscribe to URL changes (popstate events).
 * Callback receives the new URL when user navigates via back/forward buttons.
 * Returns an unsubscribe function.
 *
 * Note: This does NOT fire on pushUrl/replaceUrl - only on browser navigation.
 */
let onUrlChange: (Url.t => unit) => unsubscribe

/**
 * Type-safe navigation using a Route module.
 * Creates push/replace functions that work with your route type.
 */
module Make: (R: {
  type t
  let toString: t => string
}) => {
  let pushRoute: R.t => unit
  let replaceRoute: R.t => unit
}
