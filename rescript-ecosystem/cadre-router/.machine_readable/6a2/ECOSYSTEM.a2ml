;; SPDX-License-Identifier: PMPL-1.0-or-later
;; ECOSYSTEM.scm - Ecosystem position for cadre-router
;; Media-Type: application/vnd.ecosystem+scm

(ecosystem
  (version "1.0")
  (name "cadre-router")
  (type "routing-library")
  (purpose "Type-safe URL routing library for ReScript applications, providing Elm-style parser combinators, bidirectional route serialisation, browser History API navigation, security hardening (path traversal rejection, XSS sanitisation, ReDoS detection), and client-side K9-SVC service contract enforcement. Supports both React (Link, SafeLink) and TEA/Elm Architecture (Tea_Router, Tea_Guards, Tea_Navigation) integration patterns. Part of the cadre-* family of ReScript application infrastructure libraries.")

  (position-in-ecosystem
    (layer "application-infrastructure")
    (role "client-side-routing")
    (category "rescript-ecosystem")
    (subcategory "routing")
    (unique-value
      ("Elm-style parser combinators in ReScript — composable, type-safe URL parsing DSL")
      ("Bidirectional route definitions — parse and serialise from the same type")
      ("O(1) grouped dispatch via Dict-based first-segment matching (oneOfGrouped)")
      ("Security-hardened navigation: SafeLink, safePush, sanitisePath reject path traversal")
      ("K9-SVC client-side service contracts for navigation, guard, and mount timing SLAs")
      ("Framework-agnostic core with dedicated React and TEA integration modules")
      ("Async navigation guards with configurable timeout and redirect loop detection"))
    (dependencies-on ["rescript" "rescript-react" "rescript-dom-mounter"])
    (provides-to ["aerie" "nqc-web" "rescript-applications"]))

  (related-projects
    (archived-predecessor
      (project "cadre-tea-router")
      (relationship "superseded-by")
      (url "https://github.com/hyperpolymath/cadre-tea-router")
      (rationale "cadre-tea-router was the original TEA-only router. cadre-router unifies both React and TEA integration in a single package. cadre-tea-router is archived in hyperpolymath-archive."))

    (dependency
      (project "rescript-dom-mounter")
      (relationship "uses-for-safe-dom-mounting")
      (url "https://github.com/hyperpolymath/rescript-dom-mounter")
      (rationale "Provides SafeDOM — formally verified DOM mounting with ProvenSelector validation and ProvenHTML sanitisation. cadre-router's SafeLink, safeInit, and mountAndInit delegate to rescript-dom-mounter for defence-in-depth."))

    (first-consumer
      (project "aerie")
      (relationship "dogfooded-in")
      (url "https://github.com/hyperpolymath/aerie")
      (rationale "aerie is the first production consumer of cadre-router. Performance optimisations (oneOfGrouped, Set-based auth, async guards, CSS transitions) were developed while dogfooding cadre-router in aerie's verb governance UI."))

    (consumer
      (project "nqc-web")
      (relationship "used-by")
      (url "https://github.com/hyperpolymath/nextgen-databases")
      (rationale "The NQC Web UI (nextgen-databases/nqc/web/) uses cadre-router for client-side routing between VeriSimDB, QuandleDB, and LithoGlyph database panels."))

    (sibling-ecosystem
      (project "rescript-ecosystem")
      (relationship "lives-in")
      (url "https://github.com/hyperpolymath/developer-ecosystem")
      (rationale "cadre-router is a subdirectory of developer-ecosystem/rescript-ecosystem, alongside rescript-vite, packages/core/*, and other ReScript infrastructure."))

    (contract-standard
      (project "http-capability-gateway")
      (relationship "shares-k9-svc-pattern-with")
      (url "https://github.com/hyperpolymath/http-capability-gateway")
      (rationale "Both cadre-router and http-capability-gateway implement K9-SVC service contracts. The gateway uses server-side blocking contracts (reject/circuit-break on breach); cadre-router uses client-side observational contracts (log/warn/degrade, never block navigation). Together they provide end-to-end SLA enforcement from client through gateway."))

    (contract-standard
      (project "hybrid-automation-router")
      (relationship "shares-k9-svc-pattern-with")
      (url "https://github.com/hyperpolymath/hybrid-automation-router")
      (rationale "HAR implements server-side K9 contracts with circuit breaker patterns. cadre-router's client-side K9 contracts are the observational counterpart — they measure and report timing but never block the user."))

    (integration
      (project "rescript-tea")
      (relationship "integrates-with")
      (rationale "cadre-router's Tea_* modules (Tea_Router, Tea_Navigation, Tea_Guards, Tea_QueryParams) integrate directly with rescript-tea's update/subscription model for Elm Architecture applications."))

    (specification
      (project "proven")
      (relationship "builds-on-proofs-from")
      (url "https://github.com/hyperpolymath/proven")
      (rationale "SafeTrust and SafeCycleDetect are formally verified in Idris2 within proven. cadre-router's SafeDOM integration builds on proofs defined there for redirect loop detection and trust validation."))

    (interface-layer
      (project "panll")
      (relationship "potential-routing-provider")
      (url "https://github.com/hyperpolymath/panll")
      (rationale "PanLL's ReScript frontend panes could use cadre-router for inter-pane navigation and deep-linking to specific database views, analysis panels, or agent reasoning traces."))

    (inspiration
      (project "elm-url-parser")
      (relationship "architectural-inspiration")
      (url "https://package.elm-lang.org/packages/elm/url/latest/Url.Parser")
      (rationale "cadre-router's Parser module is directly inspired by Elm's URL parser combinators (s, int, string, custom, map, oneOf, top). The bidirectional route pattern also follows Elm conventions.")))

  (what-this-is
    "cadre-router is a ReScript routing library for single-page applications. It provides:\n  - Elm-style parser combinators: s(), int(), string(), custom(), map(), oneOf(), top()\n  - Bidirectional routes: define a route variant type and get both parse and serialise\n  - O(1) grouped dispatch: oneOfGrouped for Dict-based first-segment matching\n  - Browser History API: push, replace, back, forward via Navigation module\n  - Security hardening: SafeLink (traversal-validated links), safePush/safeReplace (validated navigation), sanitisePath (path traversal rejection), escapeHtml (XSS neutralisation), sanitisedStr (combined protection), isRegexSafe (ReDoS heuristic)\n  - Navigation guards: sync and async guard pipelines with configurable timeout and redirect loop detection (guardedPushAsyncSafe)\n  - Route metadata: titles, breadcrumbs, auth guards with O(1) Set-based role checking\n  - CSS transition delegation: offload route transition animation to browser compositor\n  - K9-SVC contracts: client-side performance SLAs for navigation, guard, and mount timing\n  - React integration: Link, SafeLink, Link.Make functor, K9Contract.ReactHook\n  - TEA integration: Tea_Router, Tea_Navigation, Tea_Guards, Tea_QueryParams\n  - Hash routing: HashNavigation for legacy or embedded contexts\n\nArchitecture: src/client/ (React + framework-agnostic core) and src/tea/ (TEA/Elm Architecture integration).")

  (what-this-is-not
    "- NOT a server-side router (use http-capability-gateway for server routing)\n- NOT a full web framework (cadre-router handles routing only, not rendering)\n- NOT React Router (cadre-router is ReScript-native, not a wrapper around react-router)\n- NOT limited to React (the core parser, navigation, and security modules are framework-agnostic)\n- NOT a state management solution (use rescript-tea or your own state layer)\n- NOT a replacement for Next.js/Remix file-based routing (cadre-router is for SPAs with explicit route definitions)\n- NOT suitable for server-side rendering without additional work (SSR support is a future consideration)\n- NOT a blocker on navigation failure — K9 contracts log and measure but never prevent navigation"))
