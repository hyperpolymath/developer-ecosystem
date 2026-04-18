// SPDX-License-Identifier: Apache-2.0
// HashNavigation.resi - Hash-based routing for static hosting
//
// Use this module when deploying to static hosts (GitHub Pages, S3, etc.)
// where you cannot configure server-side routing.
//
// URLs look like: https://example.com/#/profile instead of https://example.com/profile

/**
 * Navigate to URL using hash, adding entry to browser history
 * Example: pushUrl("/profile") navigates to /#/profile
 */
let pushUrl: string => unit

/**
 * Navigate to URL using hash, replacing current history entry
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
 * Get current URL from hash (parses the hash as a URL)
 * Example: /#/profile?tab=settings returns Url.t with path ["profile"]
 */
let currentUrl: unit => Url.t

/**
 * Unsubscribe function
 */
type unsubscribe = unit => unit

/**
 * Subscribe to hash changes.
 * Callback receives the new URL when hash changes (via hashchange event).
 */
let onUrlChange: (Url.t => unit) => unsubscribe

/**
 * Type-safe navigation using a Route module.
 */
module Make: (R: {
  type t
  let toString: t => string
}) => {
  let pushRoute: R.t => unit
  let replaceRoute: R.t => unit
}
