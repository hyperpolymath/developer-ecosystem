// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// Navigation.res - Browser History API abstraction
//
// Provides both raw navigation helpers (pushUrl, replaceUrl, onUrlChange) and
// SafeDOM-backed variants that validate selectors and sanitise content before
// any DOM interaction. The SafeDOM variants are additive — existing functions
// remain unchanged for backwards compatibility.

// External bindings to browser APIs
@val external historyPushState: (Js.Nullable.t<'a>, string, string) => unit = "window.history.pushState"
@val external historyReplaceState: (Js.Nullable.t<'a>, string, string) => unit = "window.history.replaceState"
@val external historyBack: unit => unit = "window.history.back"
@val external historyForward: unit => unit = "window.history.forward"
@val external historyGo: int => unit = "window.history.go"

@val external addEventListener: (string, 'a => unit) => unit = "window.addEventListener"
@val external removeEventListener: (string, 'a => unit) => unit = "window.removeEventListener"

let pushUrl = (url: string): unit => {
  historyPushState(Js.Nullable.null, "", url)
}

let replaceUrl = (url: string): unit => {
  historyReplaceState(Js.Nullable.null, "", url)
}

let back = (): unit => {
  historyBack()
}

let forward = (): unit => {
  historyForward()
}

let go = (delta: int): unit => {
  historyGo(delta)
}

let currentUrl = (): Url.t => {
  Url.fromLocation()
}

type unsubscribe = unit => unit

let onUrlChange = (callback: Url.t => unit): unsubscribe => {
  let handler = _ => {
    callback(Url.fromLocation())
  }

  addEventListener("popstate", handler)

  () => {
    removeEventListener("popstate", handler)
  }
}

module Make = (R: {
  type t
  let toString: t => string
}) => {
  let pushRoute = (route: R.t): unit => {
    pushUrl(R.toString(route))
  }

  let replaceRoute = (route: R.t): unit => {
    replaceUrl(R.toString(route))
  }
}

// ============================================================================
// SafeDOM Integration
// ============================================================================
//
// The functions below use SafeDOM's formally verified mounting to ensure that
// selectors are validated and HTML content is sanitised before touching the DOM.
// They are additive — all original functions above remain unchanged.

// Mount an application root element using SafeDOM's validated mounting pipeline.
// The selector is checked for CSS validity, and the initial HTML is sanitised
// (XSS stripping, tag balance) before being written to the DOM.
//
// @param selector   CSS selector string for the mount point (e.g., "#app")
// @param html       Initial HTML content to render into the mount point
// @param ~onSuccess Callback receiving the mounted DOM element on success
// @param ~onError   Callback receiving an error description string on failure
let mountApp = (
  selector: string,
  html: string,
  ~onSuccess: Dom.element => unit,
  ~onError: string => unit,
): unit => {
  SafeDOM.mountSafe(selector, html, ~onSuccess, ~onError)
}

// Variant of mountApp that waits for DOMContentLoaded before mounting.
// Use this when the script may load before the mount point exists in the DOM.
//
// @param selector   CSS selector string for the mount point
// @param html       Initial HTML content to render
// @param ~onSuccess Callback on successful mount
// @param ~onError   Callback on mount failure
let mountAppWhenReady = (
  selector: string,
  html: string,
  ~onSuccess: Dom.element => unit,
  ~onError: string => unit,
): unit => {
  SafeDOM.mountWhenReady(~selector, ~html, ~onSuccess, ~onError)
}

// Subscribe to URL changes with SafeDOM-validated selector checking.
// Before invoking the callback, the given selector is validated via
// SafeDOM.ProvenSelector to confirm the mount point exists and is safe.
// If the selector is invalid, the onError callback fires instead.
//
// @param selector   CSS selector for the element that will be updated on nav
// @param ~onChange  Callback receiving the new Url.t on each popstate event
// @param ~onError   Callback if the selector validation fails
// @returns          An unsubscribe function to remove the popstate listener
let onUrlChangeValidated = (
  selector: string,
  ~onChange: Url.t => unit,
  ~onError: string => unit,
): unsubscribe => {
  switch SafeDOM.ProvenSelector.validate(selector) {
  | Error(e) =>
    onError(`Invalid mount selector: ${e}`)
    // Return a no-op unsubscribe since we never attached
    () => ()
  | Ok(_validSelector) =>
    // Selector proven valid — wire up the popstate listener as normal
    let handler = _ => {
      onChange(Url.fromLocation())
    }
    addEventListener("popstate", handler)
    () => {
      removeEventListener("popstate", handler)
    }
  }
}
