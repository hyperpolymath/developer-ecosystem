;; SPDX-License-Identifier: PMPL-1.0-or-later
;; STATE.scm - Project state for cadre-router
;; Media-Type: application/vnd.state+scm

(state
  (metadata
    (version "0.3.0")
    (schema-version "1.0")
    (created "2026-01-03")
    (updated "2026-02-28T6")
    (project "cadre-router")
    (repo "github.com/hyperpolymath/cadre-router"))

  (project-context
    (name "cadre-router")
    (tagline "Type-safe URL routing for ReScript applications")
    (tech-stack (rescript deno browser-history-api)))

  (current-position
    (phase "hardening")
    (overall-completion 85)
    (components
      (parser 97 "Elm-style URL parser combinators with O(1) grouped dispatch, sanitisation, ReDoS protection")
      (url 90 "URL parsing, query params, fragments")
      (navigation 85 "Browser History API, push/replace/back/forward")
      (route-builder 90 "Bidirectional route definitions with grouped dispatch")
      (route-meta 90 "Metadata, breadcrumbs, auth guards with Set-based roles")
      (transition 85 "Route transition animations, CSS delegation, React hooks")
      (tea-guards 92 "Navigation guards, sync + async, timeout, redirect loop detection")
      (tea-integration 80 "TEA/Elm Architecture integration modules")
      (link 80 "Type-safe React link component")
      (k9-contracts 100 "K9-SVC service contracts: navigation/guard/mount timing enforcement, breach policies, React hooks"))
    (working-features
      ("type-safe variant routes")
      ("bidirectional parse/serialize")
      ("elm-style parser combinators")
      ("oneOfGrouped O(1) first-segment dispatch")
      ("query parameter parsing")
      ("fragment parsing")
      ("browser history navigation")
      ("route metadata and breadcrumbs")
      ("auth guards with Set-based role checking")
      ("sync and async navigation guards")
      ("deferred async navigation (guardedPushAsync)")
      ("guard timeout via Promise.race (guardedPushAsync)")
      ("redirect loop detection (guardedPushAsyncSafe)")
      ("route parameter sanitisation (sanitisePath, escapeHtml, sanitisedStr)")
      ("ReDoS pattern detection (isRegexSafe)")
      ("CSS transition delegation")
      ("requestAnimationFrame transitions")
      ("React hooks for transition state")
      ("K9-SVC navigation contracts (route resolution SLA)")
      ("K9-SVC guard contracts (sync + async timing enforcement)")
      ("K9-SVC mount contracts (DOM mount SLA)")
      ("K9 contract sets (standard + strict presets)")
      ("K9 React hook for breach tracking")))

  (route-to-mvp
    (milestones
      (v0.1 "Core parser + navigation" 100)
      (v0.2 "TEA integration + route meta" 100)
      (v0.3 "Performance optimisations + CSS transitions" 100)
      (v0.4 "Test suite + documentation" 90)
      (v1.0 "Production release" 0)))

  (blockers-and-issues
    (critical)
    (high
      ("Test coverage at ~90% — remaining: oneOfGrouped benchmarks, server-side routing"))
    (medium)
    (low
      ("Consider server-side routing support")))

  (critical-next-actions
    (immediate
      ("Benchmark oneOfGrouped vs oneOf for realistic route sets")
      ("Write tests for server-side routing stubs"))
    (this-week
      ("Benchmark oneOfGrouped vs oneOf for realistic route sets"))
    (this-month
      ("v1.0 release preparation")
      ("Server-side routing exploration")))

  (session-history
    (session
      (date "2026-02-28T6")
      (focus "CssTransition test coverage and test runner registration")
      (completed
        ("Added CssTransition_test.res — 965 lines, 72 assertions across 10 test sections")
        ("Sections: addClass/removeClass, exit/enter phases, class log sequence, cancellation, subscriptions, direction, sequential, history, edge cases")
        ("Mock DOM element tracks classNames, eventListeners, and ordered classLog for verification")
        ("Registered 4 previously-unregistered modules in run_tests.res: Transition_test, CssTransition_test, NestedRoute_test, RouteMeta_test")
        ("v0.4 test milestone now at ~90% — remaining: benchmarks and server-side routing"))
      (notes
        ("CssTransition tests simulate full animation lifecycle via mock transitionend events")
        ("All test sections independent — no shared mutable state between assertions")))
    (session
      (date "2026-02-28T5")
      (focus "Additional sanitisation test coverage")
      (completed
        ("Added Sanitisation_test.res — 565 lines, 53 test cases covering sanitisePath, escapeHtml, sanitisedStr, isRegexSafe")
        ("Custom assertion harness (assertEq, assertSome, assertNone) with summary reporting")
        ("Security domains covered: path traversal, XSS injection, ReDoS pattern detection")
        ("All security-hardening test files now complete: Sanitisation, GuardTimeout, GroupedRouting, K9Contract"))
      (notes
        ("Sanitisation_test.res adds dedicated coverage for Parser security functions (previously in integration tests)")
        ("v0.4 test milestone now at ~75% — remaining work is benchmarks and CssTransition")))
    (session
      (date "2026-02-28")
      (focus "ECOSYSTEM.scm full population and basic-routing example update for newer APIs")
      (completed
        ("Rewrote ECOSYSTEM.scm from stub to full 90+ line file with 10 related projects")
        ("ECOSYSTEM.scm now covers: cadre-tea-router (archived), rescript-dom-mounter, aerie, nqc-web, rescript-ecosystem, http-capability-gateway, HAR, rescript-tea, proven, panll, elm-url-parser")
        ("Updated basic-routing/Route.res to demonstrate oneOfGrouped, RouteMeta, checkAuthFast, K9 contracts, SafeLink, CSS transitions")
        ("Added fromUrlGrouped function showing O(1) grouped dispatch as alternative to fromUrl")
        ("Added getMeta function with route metadata, titles, breadcrumbs, and auth roles")
        ("Added checkAuth function using RouteMeta.makeRoleSet + checkAuthFast for O(1) role checks")
        ("Added fromUrlWithContract function wrapping resolution in K9 standardSet contracts")
        ("Added comprehensive annotations explaining architecture and API choices"))
      (notes
        ("ECOSYSTEM.scm was previously only a 20-line stub with empty fields")
        ("basic-routing/Route.res now serves as a comprehensive reference for all cadre-router APIs")
        ("Existing examples (SafeLinkExample, SafeNavigationExample, SafeInitExample, K9ContractExample) were already up to date")))
    (session
      (date "2026-02-28")
      (focus "Examples for security-hardened APIs, ECOSYSTEM.scm population, SPDX fixes")
      (completed
        ("Created SafeLinkExample.res — SafeLink usage with traversal rejection demos")
        ("Created SafeNavigationExample.res — safePush/safeReplace in TEA update functions")
        ("Created SafeInitExample.res — safeInit/mountAndInit with ProvenSelector validation")
        ("Created K9ContractExample.res — navigation/guard/mount contracts, sets, React hook")
        ("Fixed SPDX header in basic-routing/Route.res (Apache-2.0 -> PMPL-1.0-or-later)")
        ("Populated ECOSYSTEM.scm with full project metadata, related projects, position")
        ("Updated STATE.scm — resolved examples and ECOSYSTEM.scm blockers"))
      (notes
        ("All four example files demonstrate exact API signatures from the source modules")
        ("Examples are self-contained — each can be read independently")
        ("K9ContractExample covers all 7 contract operations plus React hook and custom IDs")
        ("ECOSYSTEM.scm now documents 6 related projects with relationship types")))
    (session
      (date "2026-02-28")
      (focus "K9-SVC service contracts for client-side SLA enforcement")
      (completed
        ("Created K9Contract.res with navigation, guard, and mount contract types")
        ("Three breach policies: Log (console.warn), Warn (+ callback), Degrade (console.error + callback)")
        ("enforceNavigation: wraps route resolution with performance.now() timing")
        ("enforceSyncGuard: wraps synchronous guard evaluation with timing")
        ("enforceAsyncGuard: wraps Promise-based async guard evaluation with timing")
        ("enforceMount: wraps SafeDOM mount operations with callback-style timing")
        ("contractSet: bundles navigation + guard + mount contracts for easy setup")
        ("standardSet: 20ms nav, 1ms sync guard, 2000ms async guard, 100ms mount")
        ("strictSet: 5ms nav, 0.5ms sync guard, 1000ms async guard, 50ms mount")
        ("ReactHook.useContractBreaches: tracks breach count and recent breaches for dev tools")
        ("DJB2 hash for lightweight contract ID generation (client-side performance)")
        ("Updated CadreRouter.res barrel module to export K9Contract"))
      (notes
        ("K9 contracts are observational on the client — they log and measure but never block navigation")
        ("Complements server-side K9 contracts in http-capability-gateway (blocking) and HAR (timing wrapper)")
        ("Contract IDs use DJB2 hash for bundle size; server-side uses SHA-256 for security")))
    (session
      (date "2026-02-28")
      (focus "Security hardening — guard timeout, redirect loop detection, sanitisation, ReDoS")
      (completed
        ("Tea_Guards: Added configurable guard timeout via Promise.race in guardedPushAsync")
        ("Tea_Guards: Added guardedPushAsyncSafe with redirect loop detection via Belt.Set.String")
        ("Tea_Guards: Added defaultGuardTimeoutMs (5000ms) and maxRedirectDepth (10) constants")
        ("Tea_Guards: Added timeoutPromise helper and setTimeout external binding")
        ("Parser: Added sanitisePath — rejects path traversal (.., //, backslash) with decodeURIComponent")
        ("Parser: Added escapeHtml — neutralises 5 HTML-significant chars to prevent XSS")
        ("Parser: Added sanitisedStr — combined traversal + XSS protection wrapping str parser")
        ("Parser: Added isRegexSafe — heuristic ReDoS detection for nested quantifiers and overlapping alternation")
        ("Both files: Fixed SPDX header from Apache-2.0 to PMPL-1.0-or-later")
        ("Both files: Added comprehensive annotations to all functions and sections"))
      (notes
        ("Guard timeout prevents hung network requests from freezing navigation indefinitely")
        ("Redirect loop detection tracks visited URLs in Set — O(log n) membership checks")
        ("guardedPushAsyncSafe re-runs guards on each redirect target with fresh timeout per hop")
        ("sanitisedStr is a drop-in replacement for str with path traversal and XSS protection")
        ("isRegexSafe is a heuristic — detects structural patterns but not all ReDoS vectors")
        ("Inspired by http-capability-gateway's policy gate and security hardening patterns")))
    (session
      (date "2026-02-28")
      (focus "Performance optimisations inspired by aerie dogfooding")
      (completed
        ("Added oneOfGrouped to Parser.res — O(1) first-segment dispatch via Dict grouping")
        ("Added checkAuthFast + makeRoleSet to RouteMeta.res — O(1) Set-based role checking")
        ("Added guardedPushAsync to Tea_Guards.res — deferred navigation with async guards")
        ("Added CssTransition module to Transition.res — CSS-driven animation delegation")
        ("Added oneOfGrouped to RouteBuilder.res — bidirectional grouped dispatch")
        ("Updated STATE.scm, API_GUIDE.md, README.adoc with new features"))
      (notes
        ("Optimisations inspired by dogfooding cadre-router in aerie's verb governance")
        ("Parser.oneOfGrouped uses Dict for O(1) lookup by first path segment")
        ("RouteMeta Set-based roles replace O(R*U) nested array scan with O(R) Set lookups")
        ("CssTransition offloads animation to browser compositor thread — GPU-accelerated")
        ("guardedPushAsync closes gap where guardedPush ignored async guards entirely")))))
