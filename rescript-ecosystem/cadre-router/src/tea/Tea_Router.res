// SPDX-License-Identifier: MPL-2.0
@@ocaml.doc("
  Core router functionality for TEA applications.

  Provides subscriptions for URL changes and helpers for wiring
  routing into your TEA update loop.
")

open Tea_Url
open Tea_Navigation

@ocaml.doc("Subscription type for URL change events")
type subscription<'msg> = UrlChange(t => 'msg)

@ocaml.doc("Create a subscription that fires when the URL changes")
let urlChanges: (t => 'msg) => subscription<'msg> = toMsg => UrlChange(toMsg)

@ocaml.doc("
  Initialize router state from the current URL.
  Use this in your TEA init function.
")
let initFromUrl: (t => 'route) => 'route = parseRoute => {
  current()->parseRoute
}

@ocaml.doc("
  Helper to create a TEA update handler for navigation.
  Returns (model, cmd) tuple.
")
let handleNavigation: (
  ~model: 'model,
  ~cmd: cmd<'msg>,
) => ('model, unit) = (~model, ~cmd) => {
  execute(cmd)
  (model, ())
}

@ocaml.doc("
  Wire up the popstate listener.
  Call this once during app initialization.
")
let listen: (t => unit) => unit = onUrlChange => {
  switch %external(__unsafe_window) {
  | None => ()
  | Some(_) =>
    %raw(`
      window.addEventListener('popstate', function() {
        onUrlChange(window.location.pathname + window.location.search + window.location.hash)
      })
    `)(url => onUrlChange(parse(url)))
  }
}

@ocaml.doc("
  Stop listening for URL changes.
  Returns a cleanup function.
")
let unlisten: unit => unit = () => {
  switch %external(__unsafe_window) {
  | None => ()
  | Some(_) =>
    // Note: In a real implementation, we'd store the handler reference
    // to properly remove the listener
    ()
  }
}

// ============================================================================
// SafeDOM-backed initialisation
// ============================================================================

@ocaml.doc("
  Initialize router with SafeDOM mount-point validation.
  Validates that the mount selector is a safe CSS selector via
  rescript-dom-mounter's ProvenSelector before parsing the initial route.
  Returns Error if the selector is invalid.
")
let safeInit: (
  ~selector: string,
  ~parseRoute: t => 'route,
) => result<'route, string> = (~selector, ~parseRoute) => {
  switch SafeDOM.ProvenSelector.validate(selector) {
  | Error(e) => Error(`Invalid mount selector: ${e}`)
  | Ok(_) => Ok(initFromUrl(parseRoute))
  }
}

@ocaml.doc("
  Mount a TEA app into a validated DOM element using rescript-dom-mounter.
  Combines SafeDOM mounting with router initialisation in a single call.
")
let mountAndInit: (
  ~selector: string,
  ~html: string,
  ~parseRoute: t => 'route,
  ~onError: string => unit,
) => option<'route> = (~selector, ~html, ~parseRoute, ~onError) => {
  let routeRef = ref(None)
  SafeDOM.mountSafe(selector, html,
    ~onSuccess=_el => {
      routeRef := Some(initFromUrl(parseRoute))
    },
    ~onError,
  )
  routeRef.contents
}
