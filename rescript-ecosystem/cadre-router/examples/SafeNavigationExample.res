// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// SafeNavigationExample.res - Demonstrates safePush and safeReplace from Tea_Navigation
//
// Tea_Navigation provides both raw and safe navigation commands for TEA applications.
// The safe variants (safePush, safeReplace) pass the path through Parser.sanitisePath
// before invoking the History API, preventing path-traversal and encoded-traversal
// attacks from reaching the browser.
//
// Return type:
//   - Ok(())          — path was clean; navigation executed.
//   - Error(string)   — path was rejected; no navigation occurred. The error string
//                        describes why (e.g., "Path rejected: contains traversal sequence").
//
// This is the TEA-architecture equivalent of SafeLink in the React layer. Use safePush
// and safeReplace in your TEA update function when handling navigation messages.

open Tea_Url
open Tea_Navigation

// ============================================================================
// Route Definition (shared with other examples)
// ============================================================================

type route =
  | Home
  | Dashboard
  | UserProfile(string)
  | NotFound

let routeToPath = (route: route): string =>
  switch route {
  | Home => "/"
  | Dashboard => "/dashboard"
  | UserProfile(slug) => "/users/" ++ slug
  | NotFound => "/not-found"
  }

let parseRoute = (url: Tea_Url.t): route =>
  switch url.path {
  | "/" => Home
  | "/dashboard" => Dashboard
  | p if String.startsWith(p, "/users/") =>
    UserProfile(String.sliceToEnd(p, ~start=7))
  | _ => NotFound
  }

// ============================================================================
// Example 1: safePush in a TEA Update Function
// ============================================================================
//
// In a TEA application, navigation is typically triggered by messages dispatched
// from the view. The update function handles these messages by constructing
// navigation commands. Using safePush instead of pushPath ensures that any
// user-influenced path segments are validated before reaching the History API.

type msg =
  | NavigateTo(string)
  | NavigateToRoute(route)
  | UrlChanged(Tea_Url.t)
  | NavigationFailed(string)

type model = {
  currentRoute: route,
  lastError: option<string>,
}

// The update function demonstrates both safe and standard navigation.
// In production code, you would typically use safePush for all programmatic
// navigation where the path includes any dynamic or user-controlled data.
let update = (model: model, msg: msg): (model, cmd<msg>) => {
  switch msg {
  | NavigateTo(path) =>
    // Use safePush for paths that may contain user input.
    // If the path contains traversal sequences, navigation is rejected
    // and we can inform the user via the model's error field.
    switch safePush(path) {
    | Ok() => (model, push(parse(path)))
    | Error(reason) =>
      Js.Console.error(`[navigation] Rejected: ${reason} (path: ${path})`)
      ({...model, lastError: Some(reason)}, push(parse("/")))
    }

  | NavigateToRoute(route) =>
    // For typed routes, the path is derived from our own serialiser,
    // so it is always safe. We can use the standard push here.
    let path = routeToPath(route)
    (model, push(parse(path)))

  | UrlChanged(url) =>
    ({...model, currentRoute: parseRoute(url), lastError: None}, push(url))

  | NavigationFailed(reason) =>
    ({...model, lastError: Some(reason)}, push(parse("/")))
  }
}

// ============================================================================
// Example 2: safeReplace for History Replacement
// ============================================================================
//
// safeReplace works identically to safePush but calls replaceState instead of
// pushState. This is useful when you want to redirect without adding a new
// history entry (e.g., normalising a URL, handling a 301-style redirect).

let normaliseAndReplace = (rawPath: string): result<unit, string> => {
  // Attempt to replace the current history entry with a cleaned path.
  // If the raw path contains traversal, safeReplace returns Error and
  // the current history entry remains unchanged.
  safeReplace(rawPath)
}

// ============================================================================
// Example 3: Combining safePush with Guard Results
// ============================================================================
//
// In applications using Tea_Guards, the guard pipeline may return a Redirect
// result with a user-influenced path. Running that redirect through safePush
// adds a second layer of defence: even if a guard's redirect target is
// somehow tainted, the traversal check catches it.

let handleGuardRedirect = (redirectPath: string): unit => {
  switch safePush(redirectPath) {
  | Ok() =>
    Js.Console.log(`[guard] Redirected to: ${redirectPath}`)
  | Error(reason) =>
    // Guard produced a redirect to a path that failed sanitisation.
    // This is a defence-in-depth catch — log it loudly and fall back to home.
    Js.Console.error(
      `[guard] CRITICAL: redirect target rejected by safePush: ${reason} ` ++
      `(path: ${redirectPath}). Falling back to /`
    )
    ignore(safePush("/"))
  }
}

// ============================================================================
// Example 4: Batch Navigation with Error Collection
// ============================================================================
//
// When performing multiple navigations (e.g., in a test harness or migration
// script), collect errors rather than failing fast.

let testPaths = (): unit => {
  let paths = [
    "/",                   // OK
    "/dashboard",          // OK
    "/users/alice",        // OK
    "/users/../admin",     // REJECTED — traversal
    "/users/%2e%2e/admin", // REJECTED — encoded traversal
    "/search?q=hello",     // OK
    "/files//hidden",      // REJECTED — double slash
  ]

  let results = paths->Array.map(path => {
    let result = safePush(path)
    (path, result)
  })

  results->Array.forEach(((path, result)) => {
    switch result {
    | Ok() => Js.Console.log(`  PASS: ${path}`)
    | Error(reason) => Js.Console.warn(`  FAIL: ${path} -> ${reason}`)
    }
  })
}
