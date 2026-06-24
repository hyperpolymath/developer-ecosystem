// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// SafeLinkExample.res - Demonstrates XSS-safe navigation using SafeLink
//
// The Link module in cadre-router provides two link components:
//
//   1. Link.make        — The standard link component. Intercepts left-clicks and
//                         delegates to Navigation.pushUrl for SPA-style navigation,
//                         but does NOT validate the href for path traversal or XSS.
//
//   2. Link.SafeLink    — A hardened variant that runs Parser.sanitisePath on the
//                         href BEFORE calling Navigation.pushUrl. If the href
//                         contains traversal sequences (.., //, backslash, or their
//                         percent-encoded variants), navigation is silently rejected
//                         and the attempt is logged to console.error.
//
// When to use SafeLink:
//   - Any link whose href is partially or wholly user-controlled (search results,
//     profile slugs, dynamic route segments from an API, etc.)
//   - As a default in applications that prioritise defence-in-depth.
//
// When the standard Link is fine:
//   - Hrefs are compile-time literals (e.g., the typed Link.Make functor-generated
//     component, where toString produces known-safe paths from variant routes).
//
// This file is a self-contained example. It references modules from cadre-router's
// src/client/ directory: Link.res (SafeLink submodule), Parser.res (sanitisePath),
// and Navigation.res (pushUrl).

open React

// ============================================================================
// Example 1: Basic SafeLink Usage
// ============================================================================
//
// SafeLink has the same props as the regular Link component (<a> tag semantics)
// but adds traversal validation. If the href is rejected, the click handler
// logs to console.error and does NOT navigate.

module BasicExample = {
  @react.component
  let make = () => {
    <div>
      <h2> {React.string("Basic SafeLink")} </h2>
      <p> {React.string("These links are validated against path traversal before navigation.")} </p>

      // Safe: simple absolute paths are always accepted.
      <Link.SafeLink href="/dashboard" className={Some("nav-link")}>
        {React.string("Dashboard")}
      </Link.SafeLink>

      <Link.SafeLink href="/profile/settings" className={Some("nav-link")}>
        {React.string("Profile Settings")}
      </Link.SafeLink>

      // Safe: query parameters and fragments are fine — traversal checking
      // focuses on the path component.
      <Link.SafeLink href="/search?q=rescript&page=1" className={Some("nav-link")}>
        {React.string("Search Results")}
      </Link.SafeLink>
    </div>
  }
}

// ============================================================================
// Example 2: SafeLink Rejects Traversal Attacks
// ============================================================================
//
// If a malicious or buggy data source supplies a path containing "..",
// "//", backslash, or their percent-encoded equivalents, SafeLink logs:
//
//   SafeLink: href rejected (traversal): /profiles/../../etc/passwd
//
// and the browser stays on the current page. No history entry is created.

module TraversalRejectionExample = {
  @react.component
  let make = () => {
    // Imagine these slugs come from an untrusted API response.
    let maliciousSlugs = [
      "../../../etc/passwd",          // Direct traversal
      "..%2F..%2Fetc%2Fpasswd",       // Percent-encoded traversal
      "valid-slug",                    // Legitimate slug — will navigate normally
      "foo//bar",                      // Double slash — rejected
      "hello\\world",                 // Backslash — rejected
    ]

    <div>
      <h2> {React.string("Traversal Rejection Demo")} </h2>
      <p> {React.string("Only the 'valid-slug' link will actually navigate.")} </p>
      <ul>
        {maliciousSlugs
        ->Array.mapWithIndex((slug, index) => {
          let href = "/profiles/" ++ slug
          <li key={Belt.Int.toString(index)}>
            <Link.SafeLink href className={Some("slug-link")}>
              {React.string(slug)}
            </Link.SafeLink>
          </li>
        })
        ->React.array}
      </ul>
    </div>
  }
}

// ============================================================================
// Example 3: SafeLink with Custom onClick Handler
// ============================================================================
//
// SafeLink accepts an optional ~onClick prop, just like the standard Link.
// The custom handler fires BEFORE the traversal check. If the handler calls
// preventDefault, SafeLink respects it and skips navigation entirely.

module ClickHandlerExample = {
  @react.component
  let make = () => {
    let handleAnalytics = (_event: ReactEvent.Mouse.t) => {
      // Fire an analytics event before navigation.
      Js.Console.log("[analytics] user clicked navigation link")
    }

    <div>
      <h2> {React.string("SafeLink with onClick")} </h2>

      <Link.SafeLink
        href="/reports/quarterly"
        onClick={Some(handleAnalytics)}
        className={Some("tracked-link")}
        style={Some(ReactDOM.Style.make(~color="blue", ~textDecoration="underline", ()))}
      >
        {React.string("Quarterly Report (tracked)")}
      </Link.SafeLink>
    </div>
  }
}

// ============================================================================
// Example 4: Comparing SafeLink vs Standard Link
// ============================================================================
//
// Side-by-side rendering of both link types to illustrate the difference.
// In production, prefer SafeLink for any href that includes dynamic data.

module ComparisonExample = {
  @react.component
  let make = (~userSlug: string) => {
    let href = "/users/" ++ userSlug

    <div>
      <h2> {React.string("SafeLink vs Standard Link")} </h2>

      <div>
        <h3> {React.string("Standard Link (no validation)")} </h3>
        <Link href className={Some("standard-link")}>
          {React.string("View User (standard)")}
        </Link>
      </div>

      <div>
        <h3> {React.string("SafeLink (traversal-validated)")} </h3>
        <Link.SafeLink href className={Some("safe-link")}>
          {React.string("View User (safe)")}
        </Link.SafeLink>
      </div>

      <p>
        {React.string(
          "If userSlug is '../admin', the standard link navigates to /users/../admin " ++
          "(which the browser resolves to /admin), while SafeLink rejects it entirely."
        )}
      </p>
    </div>
  }
}
