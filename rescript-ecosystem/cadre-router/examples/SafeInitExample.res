// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// SafeInitExample.res - Demonstrates safeInit and mountAndInit from Tea_Router
//
// Tea_Router provides two SafeDOM-backed initialisation functions:
//
//   1. safeInit       — Validates the mount-point CSS selector via
//                        SafeDOM.ProvenSelector.validate before parsing the initial
//                        route. Returns Result — Error if the selector is invalid
//                        (e.g., contains injection characters), Ok with the parsed
//                        route if the selector is safe.
//
//   2. mountAndInit   — Combines SafeDOM.mountSafe (DOM mounting with selector
//                        validation and HTML sanitisation) with router initialisation.
//                        Mounts the given HTML into the validated element AND returns
//                        the initial route in a single call. Errors are reported via
//                        the ~onError callback.
//
// Both functions rely on rescript-dom-mounter's ProvenSelector module, which checks
// that:
//   - The selector string is valid CSS (not an arbitrary expression).
//   - The selector does not contain characters that could cause injection
//     when used in querySelector.
//
// Why validate the selector?
//   In most apps the selector is a compile-time literal ("#app"). But in
//   micro-frontend architectures, dynamic widget systems, or CMS integrations,
//   the selector may come from configuration or even URL parameters. Validating
//   it prevents a class of DOM clobbering and selector injection attacks.

open Tea_Url
open Tea_Router

// ============================================================================
// Shared Route Type
// ============================================================================

type route =
  | Home
  | About
  | Users
  | UserDetail(string)
  | NotFound

let parseRoute = (url: Tea_Url.t): route =>
  switch url.path {
  | "/" => Home
  | "/about" => About
  | "/users" => Users
  | p if String.startsWith(p, "/users/") =>
    UserDetail(String.sliceToEnd(p, ~start=7))
  | _ => NotFound
  }

// ============================================================================
// Example 1: safeInit — Validate Selector Before Routing
// ============================================================================
//
// safeInit takes a CSS selector string and a route parser function.
// If the selector passes ProvenSelector.validate, it calls initFromUrl
// with the parser and returns Ok(route). Otherwise it returns Error.
//
// Use this when you want to validate the mount point but handle the actual
// DOM mounting yourself (e.g., via React's createRoot or a custom renderer).

let initWithSafeSelector = (): unit => {
  // Typical usage: hard-coded selector, always valid.
  switch safeInit(~selector="#app", ~parseRoute) {
  | Ok(route) =>
    Js.Console.log("[safeInit] Initial route parsed successfully")
    switch route {
    | Home => Js.Console.log("  -> Home")
    | About => Js.Console.log("  -> About")
    | Users => Js.Console.log("  -> Users")
    | UserDetail(id) => Js.Console.log(`  -> UserDetail(${id})`)
    | NotFound => Js.Console.log("  -> NotFound")
    }
  | Error(reason) =>
    // This branch fires if the selector string is structurally invalid.
    Js.Console.error(`[safeInit] Failed: ${reason}`)
  }
}

// ============================================================================
// Example 2: safeInit with Dynamic Selector
// ============================================================================
//
// In a micro-frontend or widget scenario, the mount selector may come from
// configuration. safeInit validates it before proceeding.

let initDynamicWidget = (selectorFromConfig: string): unit => {
  switch safeInit(~selector=selectorFromConfig, ~parseRoute) {
  | Ok(route) =>
    Js.Console.log(`[widget] Mounted at ${selectorFromConfig}, route:`)
    ignore(route)
  | Error(reason) =>
    // Configuration supplied a bad selector. Log and abort the widget.
    Js.Console.error(
      `[widget] Cannot mount at '${selectorFromConfig}': ${reason}. ` ++
      "Check your widget configuration."
    )
  }
}

// ============================================================================
// Example 3: mountAndInit — Mount DOM + Parse Route in One Call
// ============================================================================
//
// mountAndInit wraps SafeDOM.mountSafe: it validates the selector, sanitises
// the initial HTML, mounts it into the DOM, and then parses the initial route.
// The route is returned as option<route> — None if the mount failed.
//
// The ~onError callback fires if selector validation fails or the element is
// not found in the DOM. The ~html parameter is the initial HTML content to
// render into the mount point.

let mountAndStart = (): unit => {
  let initialHtml = "<div id='root'><p>Loading...</p></div>"

  let maybeRoute = mountAndInit(
    ~selector="#app",
    ~html=initialHtml,
    ~parseRoute,
    ~onError=err => {
      Js.Console.error(`[mountAndInit] Mount failed: ${err}`)
    },
  )

  switch maybeRoute {
  | Some(route) =>
    Js.Console.log("[mountAndInit] App mounted and route parsed")
    // Proceed with TEA init, wire up subscriptions, etc.
    ignore(route)
  | None =>
    Js.Console.error("[mountAndInit] Mount did not complete — app not started")
  }
}

// ============================================================================
// Example 4: mountAndInit with Rich Initial HTML
// ============================================================================
//
// mountAndInit sanitises the HTML through SafeDOM before inserting it.
// This means script tags, event handlers (onclick, onerror), and other
// XSS vectors are stripped. The example below shows safe and unsafe HTML
// to illustrate what survives sanitisation.

let mountWithSanitisedHtml = (): unit => {
  // SafeDOM will strip the <script> tag and the onerror handler,
  // but keep the structural HTML elements and safe attributes.
  let htmlFromCms =
    "<div class='app-shell'>" ++
    "  <header><h1>My App</h1></header>" ++
    "  <main><p>Welcome back!</p></main>" ++
    "  <script>alert('xss')</script>" ++           // Stripped by SafeDOM
    "  <img src=x onerror='alert(1)' />" ++         // onerror stripped
    "</div>"

  let _route = mountAndInit(
    ~selector="#widget-container",
    ~html=htmlFromCms,
    ~parseRoute,
    ~onError=err => {
      Js.Console.error(`[sanitised mount] Error: ${err}`)
    },
  )
}

// ============================================================================
// Example 5: Full TEA Application Bootstrap
// ============================================================================
//
// Putting it all together: mount the app shell, parse the initial route,
// wire up URL change subscriptions, and start the TEA loop.

type model = {
  currentRoute: route,
  content: string,
}

type msg =
  | UrlChanged(Tea_Url.t)

let init = (route: route): model => {
  {
    currentRoute: route,
    content: switch route {
    | Home => "Welcome home!"
    | About => "About this application."
    | Users => "User listing."
    | UserDetail(id) => "User: " ++ id
    | NotFound => "Page not found."
    },
  }
}

let bootstrapApp = (): unit => {
  let initialHtml = "<div id='tea-root'></div>"

  let maybeRoute = mountAndInit(
    ~selector="#app",
    ~html=initialHtml,
    ~parseRoute,
    ~onError=err => {
      Js.Console.error(`[bootstrap] Failed to mount: ${err}`)
    },
  )

  switch maybeRoute {
  | Some(route) => {
      let _model = init(route)

      // Wire up URL change listener via Tea_Router.listen
      listen(url => {
        let newRoute = parseRoute(url)
        Js.Console.log(`[router] URL changed -> ${url.path}`)
        ignore(newRoute)
      })

      Js.Console.log("[bootstrap] App started successfully")
    }
  | None =>
    Js.Console.error("[bootstrap] App failed to start — mount point invalid or missing")
  }
}
