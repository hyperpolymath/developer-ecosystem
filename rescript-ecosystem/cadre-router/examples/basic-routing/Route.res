// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// Route.res - Example route definition for a typical SPA
//
// This example demonstrates core cadre-router patterns:
//   - Typed ID parameters (JourneyId.t)
//   - Nested routes (Journey sub-routes)
//   - Query parameters
//   - O(1) grouped dispatch via oneOfGrouped
//   - Route metadata with Set-based auth (checkAuthFast)
//   - SafeLink for XSS-safe navigation
//   - K9-SVC service contracts for performance SLA enforcement
//   - CSS transition delegation
//
// ## Architecture
//
// cadre-router separates concerns into composable modules:
//   - Parser: Elm-style URL parser combinators
//   - Navigation: Browser History API push/replace/back/forward
//   - RouteMeta: Titles, breadcrumbs, auth guards
//   - K9Contract: Client-side performance SLA enforcement
//   - Link / SafeLink: React link components with optional traversal validation
//   - Transition: CSS-driven route transition animations
//
// This file defines routes, parsing, serialisation, metadata, and typed
// navigation for an example application. See the other files in examples/
// for focused demonstrations of SafeLink, safePush, safeInit, and K9 contracts.

// ============================================================================
// Typed ID Module
// ============================================================================
//
// Wrapping string IDs in a nominal type prevents accidental mixing of
// different ID namespaces (e.g., passing a UserId where a JourneyId is
// expected). The custom parser validates the raw string before wrapping.

module JourneyId = {
  type t = JourneyId(string)

  // Validate and wrap a raw string into a JourneyId.
  // Returns None for empty strings; extend with UUID validation as needed.
  let fromString = (str: string): option<t> => {
    if Js.String2.length(str) > 0 {
      Some(JourneyId(str))
    } else {
      None
    }
  }

  // Unwrap a JourneyId to its raw string for URL serialisation.
  let toString = (JourneyId(str): t): string => str

  // Parser combinator for use with cadre-router's Parser module.
  // Wraps the fromString validator as a custom parser.
  let parser: CadreRouter.Parser.t<t> =
    CadreRouter.Parser.custom(fromString)
}

// ============================================================================
// Journey Sub-Routes
// ============================================================================
//
// Nested routes within a journey. Each sub-route maps to a path suffix
// under /journey/:id/. The overview route has no suffix.

type journeySubRoute =
  | JourneyOverview
  | JourneyMap
  | JourneyLog
  | JourneySettings

// Serialise a sub-route to its path suffix.
let journeySubToString = (sub: journeySubRoute): string =>
  switch sub {
  | JourneyOverview => ""
  | JourneyMap => "/map"
  | JourneyLog => "/log"
  | JourneySettings => "/settings"
  }

// Parser for journey sub-routes. Uses oneOf with the top-level route
// (JourneyOverview) as the fallback when no sub-route segment is present.
let journeySubParser: CadreRouter.Parser.t<journeySubRoute> = {
  open CadreRouter.Parser
  oneOf([
    s("map")->map(_ => JourneyMap),
    s("log")->map(_ => JourneyLog),
    s("settings")->map(_ => JourneySettings),
    top->map(_ => JourneyOverview),
  ])
}

// ============================================================================
// Main Route Type
// ============================================================================

type t =
  | Home
  | MoodInput
  | Journey(JourneyId.t, journeySubRoute)
  | Profile
  | Search({query: string, page: option<int>})
  | NotFound

// ============================================================================
// Parser — Standard (oneOf)
// ============================================================================
//
// The standard parser uses oneOf, which tries each parser in order until
// one matches. This is O(n) in the number of routes. For applications with
// many routes, consider oneOfGrouped (see below) for O(1) first-segment dispatch.

let parser: CadreRouter.Parser.t<t> = {
  open CadreRouter.Parser
  oneOf([
    // Home: /
    top->map(_ => Home),

    // MoodInput: /mood
    s("mood")->map(_ => MoodInput),

    // Journey: /journey/:id or /journey/:id/map etc.
    s("journey")
      ->andThen(JourneyId.parser)
      ->andThen(journeySubParser)
      ->map((((_, id), sub)) => Journey(id, sub)),

    // Profile: /profile
    s("profile")->map(_ => Profile),

    // Search: /search?q=...&page=...
    s("search")
      ->andThen(queryRequired("q"))
      ->andThen(queryInt("page"))
      ->map((((_, q), page)) => Search({query: q, page})),
  ])
}

// ============================================================================
// Parser — Grouped (oneOfGrouped, O(1) dispatch)
// ============================================================================
//
// oneOfGrouped uses a Dict to group parsers by their first path segment,
// enabling O(1) lookup instead of O(n) sequential matching. This matters
// when you have dozens or hundreds of routes (e.g., an admin panel).
//
// The API is identical to oneOf — each parser entry includes the first
// segment and the continuation parser. The grouping happens internally.
//
// Tradeoff: oneOfGrouped requires that each parser starts with a string
// segment (s("...")). The top-level root route ("/") is handled separately
// via the ~fallback parameter.

let groupedParser: CadreRouter.Parser.t<t> = {
  open CadreRouter.Parser
  oneOfGrouped(
    [
      // MoodInput: /mood
      ("mood", s("mood")->map(_ => MoodInput)),

      // Journey: /journey/:id/...
      ("journey",
        s("journey")
          ->andThen(JourneyId.parser)
          ->andThen(journeySubParser)
          ->map((((_, id), sub)) => Journey(id, sub))),

      // Profile: /profile
      ("profile", s("profile")->map(_ => Profile)),

      // Search: /search?q=...&page=...
      ("search",
        s("search")
          ->andThen(queryRequired("q"))
          ->andThen(queryInt("page"))
          ->map((((_, q), page)) => Search({query: q, page}))),
    ],
    // Fallback for the root path ("/") and unmatched segments.
    ~fallback=top->map(_ => Home),
  )
}

// ============================================================================
// Serialiser
// ============================================================================
//
// Bidirectional routing: the same route type can be parsed from a URL and
// serialised back to a URL string. This guarantees round-trip correctness.

let toString = (route: t): string =>
  switch route {
  | Home => "/"
  | MoodInput => "/mood"
  | Journey(id, sub) =>
    "/journey/" ++ JourneyId.toString(id) ++ journeySubToString(sub)
  | Profile => "/profile"
  | Search({query, page}) => {
      let pageParam = switch page {
      | Some(p) => "&page=" ++ Belt.Int.toString(p)
      | None => ""
      }
      "/search?q=" ++ Js.Global.encodeURIComponent(query) ++ pageParam
    }
  | NotFound => "/not-found"
  }

// ============================================================================
// Parse URL to Route
// ============================================================================
//
// Convenience function that wraps Parser.parse with a NotFound fallback.
// This is the main entry point for route resolution in update/init functions.

let fromUrl = (url: CadreRouter.Url.t): t => {
  switch CadreRouter.Parser.parse(parser, url) {
  | Some(route) => route
  | None => NotFound
  }
}

// Grouped variant — uses oneOfGrouped for O(1) dispatch.
// Swap this in for fromUrl when your route table grows large.
let fromUrlGrouped = (url: CadreRouter.Url.t): t => {
  switch CadreRouter.Parser.parse(groupedParser, url) {
  | Some(route) => route
  | None => NotFound
  }
}

// ============================================================================
// Route Metadata — Titles, Breadcrumbs, Auth Guards
// ============================================================================
//
// RouteMeta attaches metadata to routes for breadcrumb rendering, page titles,
// and access control. The checkAuthFast function uses a Set for O(1) role
// lookups instead of O(R*U) nested array scanning.

let getMeta = (route: t): CadreRouter.RouteMeta.meta<unit> => {
  open CadreRouter.RouteMeta
  switch route {
  | Home =>
    empty
    ->withTitle("Home")
    ->withBreadcrumb("Home")
  | MoodInput =>
    empty
    ->withTitle("Mood Input")
    ->withBreadcrumb("Mood")
  | Journey(id, sub) => {
      let subLabel = switch sub {
      | JourneyOverview => "Overview"
      | JourneyMap => "Map"
      | JourneyLog => "Log"
      | JourneySettings => "Settings"
      }
      empty
      ->withTitle(`Journey ${JourneyId.toString(id)} - ${subLabel}`)
      ->withBreadcrumb(subLabel)
      ->withAuth
    }
  | Profile =>
    empty
    ->withTitle("Profile")
    ->withBreadcrumb("Profile")
    ->withRoles(["user", "admin"])
  | Search(_) =>
    empty
    ->withTitle("Search")
    ->withBreadcrumb("Search")
  | NotFound =>
    empty
    ->withTitle("Not Found")
    ->withBreadcrumb("404")
  }
}

// O(1) Set-based auth check using RouteMeta.checkAuthFast.
// Build a role set once (e.g., at login), then use it for all route checks.
// This replaces the O(R*U) nested array scan of Array.some + Array.includes.
let checkAuth = (route: t, userRoles: array<string>): bool => {
  let meta = getMeta(route)
  let roleSet = CadreRouter.RouteMeta.makeRoleSet(userRoles)
  CadreRouter.RouteMeta.checkAuthFast(meta, roleSet)
}

// ============================================================================
// K9-SVC Contract — Performance SLA for Route Resolution
// ============================================================================
//
// K9 contracts wrap operations with timing measurement. If the operation
// exceeds the SLA threshold, the breach policy fires (log, warn, or degrade).
// Contracts are observational — they NEVER block navigation.
//
// For a full K9 contract example including guard and mount contracts,
// see examples/K9ContractExample.res.

// Standard contract set: 20ms nav, 1ms sync guard, 2000ms async guard, 100ms mount.
let contracts = CadreRouter.K9Contract.standardSet(
  ~breachPolicy=Warn,
  ~onBreach=Some((contractId, elapsedMs) => {
    Js.Console.log(
      `[k9] SLA breach: contract=${contractId} elapsed=${Belt.Float.toString(elapsedMs)}ms`
    )
  }),
)

// Contract-enforced route resolution. The K9 wrapper measures parse time
// and reports breaches without blocking the result.
let fromUrlWithContract = (url: CadreRouter.Url.t): t => {
  switch contracts.navigation {
  | Some(navContract) => {
      let result = CadreRouter.K9Contract.enforceNavigation(navContract, () => {
        CadreRouter.Parser.parse(parser, url)
      })
      switch result.value {
      | Some(route) => route
      | None => NotFound
      }
    }
  | None => fromUrl(url)
  }
}

// ============================================================================
// Typed Navigation
// ============================================================================
//
// The Navigation.Make functor creates a typed navigation module from a route
// type and its serialiser. This gives you pushRoute(Profile) instead of
// pushUrl("/profile"), ensuring compile-time safety.

module Nav = CadreRouter.Navigation.Make({
  type t = t
  let toString = toString
})

// ============================================================================
// Typed Link — For React Applications
// ============================================================================
//
// Link.Make creates a typed React link component. The route variant is
// serialised to an href automatically. For dynamic or user-controlled hrefs,
// use Link.SafeLink instead (see examples/SafeLinkExample.res).

module TypedLink = CadreRouter.Link.Make({
  type t = t
  let toString = toString
})

// ============================================================================
// SafeLink Usage — Traversal-Validated Navigation
// ============================================================================
//
// For hrefs that include dynamic or user-controlled data, use Link.SafeLink
// instead of the standard Link. SafeLink runs Parser.sanitisePath on the href
// before navigation, rejecting path traversal sequences (.., //, backslash,
// and their percent-encoded variants).
//
// See examples/SafeLinkExample.res for a full demonstration.
//
// Quick usage:
//   <Link.SafeLink href={"/users/" ++ userSlug} className={Some("nav-link")}>
//     {React.string("View User")}
//   </Link.SafeLink>

// ============================================================================
// CSS Transition Delegation
// ============================================================================
//
// The Transition module provides CSS-driven route transition animations.
// CssTransition offloads animation to the browser's compositor thread
// (GPU-accelerated) instead of using JavaScript requestAnimationFrame.
//
// Usage pattern:
//   1. Define CSS transition classes for enter/exit states
//   2. Use CadreRouter.Transition.CssTransition to manage class application
//   3. The browser handles the actual animation on the GPU
//
// This was developed while dogfooding cadre-router in aerie's verb governance
// UI, where smooth transitions between verb detail views were needed without
// jank from JavaScript-driven animation.
