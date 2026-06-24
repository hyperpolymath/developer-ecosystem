// SPDX-License-Identifier: MPL-2.0
// Tea_Guards.res - Navigation guards for TEA applications
//
// Provides a guard pipeline for client-side route navigation in the TEA
// (The Elm Architecture) pattern. Guards inspect a target URL before
// navigation occurs and can Allow, Block, or Redirect the transition.
//
// Two guard flavours exist:
//   - Synchronous guards (`guard`): run inline, no network, no delay.
//     Suitable for auth-role checks, feature flags, static rules.
//   - Asynchronous guards (`asyncGuard`): return a promise, enabling
//     network-dependent checks like JWT refresh, server-side permission
//     queries, or feature-flag service lookups.
//
// Guard evaluation order:
//   1. All synchronous guards run first (short-circuit on first non-Allow).
//   2. If sync guards pass, all async guards run sequentially (short-circuit).
//   3. Navigation only happens when every guard returns Allow.
//
// Timeout and loop protection (added 2026-02-28):
//   - `guardedPushAsync` races guard execution against a configurable timeout
//     to prevent hung guards from blocking navigation indefinitely.
//   - `guardedPushAsyncSafe` adds redirect-loop detection on top of the
//     timeout, tracking visited URLs in a Set and enforcing a maximum
//     redirect chain depth.
//
// Inspired by http-capability-gateway's policy gate pattern, where every
// request must pass through the full policy chain before reaching the handler.

open Tea_Url

// ============================================================================
// External Bindings
// ============================================================================

// Browser setTimeout binding. Returns a timer ID (ignored here — we never
// cancel the timeout, the Promise.race winner simply discards the loser).
@val external setTimeout: (unit => unit, int) => float = "setTimeout"

// ============================================================================
// Types
// ============================================================================

@ocaml.doc("Result of a guard check.
  - Allow: navigation proceeds to the target URL.
  - Block(reason): navigation is prevented; `reason` explains why (for logging/UI).
  - Redirect(path): navigation is rerouted to a different URL path string.")
type guardResult =
  | Allow
  | Block(string)
  | Redirect(string)

@ocaml.doc("A synchronous navigation guard function.
  Receives the target URL and returns an immediate Allow/Block/Redirect decision.
  Suitable for in-memory checks like role-based access control.")
type guard = Tea_Url.t => guardResult

@ocaml.doc("An asynchronous navigation guard function.
  Receives the target URL and returns a promise that resolves to a guard decision.
  Suitable for network-dependent checks like token refresh or server-side ACLs.")
type asyncGuard = Tea_Url.t => promise<guardResult>

@ocaml.doc("Configuration for navigation guards.
  Contains both synchronous and asynchronous guard arrays.
  Sync guards always run first; async guards only run if all sync guards pass.")
type guardConfig = {
  guards: array<guard>,
  asyncGuards: array<asyncGuard>,
}

@ocaml.doc("Empty guard configuration — no guards, all navigation allowed.
  Useful as a default or for routes that require no protection.")
let emptyConfig: guardConfig = {
  guards: [],
  asyncGuards: [],
}

// ============================================================================
// Timeout Configuration
// ============================================================================

// Default timeout in milliseconds for async guard execution.
// If guards do not resolve within this window, navigation is blocked
// with a timeout reason. 5 seconds is generous for most network checks;
// callers can override via the ~timeoutMs parameter.
let defaultGuardTimeoutMs = 5000

// Maximum number of redirects before declaring a redirect loop.
// Prevents infinite A -> B -> A cycles or long redirect chains
// from hanging the application. 10 is a practical ceiling — most
// legitimate redirect chains are 1-3 hops (e.g., /login -> /dashboard).
let maxRedirectDepth = 10

// ============================================================================
// Timeout Promise
// ============================================================================

// Creates a promise that resolves to Block after the given number of
// milliseconds. Used with Promise.race to ensure guard evaluation
// cannot hang indefinitely — if the real guard promise wins the race,
// this timeout is harmlessly discarded.
//
// The Block result includes a descriptive reason so callers or logging
// middleware can distinguish a timeout from a deliberate Block.
let timeoutPromise = (ms: int): promise<guardResult> => {
  Promise.make((~resolve, ~reject as _) => {
    let _ = setTimeout(() => {
      resolve(Block("Guard timeout exceeded (" ++ Belt.Int.toString(ms) ++ "ms)"))
    }, ms)
  })
}

// ============================================================================
// Guard Execution
// ============================================================================

@ocaml.doc("Run all synchronous guards sequentially, short-circuiting on the first
  non-Allow result. Returns Allow only if every guard in the array passes.
  This is an O(N) linear scan — for typical guard counts (1-5) this is optimal.
  The guards array is traversed by index to avoid allocating intermediate lists.")
let runGuards = (guards: array<guard>, url: Tea_Url.t): guardResult => {
  let rec check = (idx: int): guardResult => {
    if idx >= Belt.Array.length(guards) {
      Allow
    } else {
      switch Belt.Array.getExn(guards, idx)(url) {
      | Allow => check(idx + 1)
      | result => result
      }
    }
  }
  check(0)
}

@ocaml.doc("Run all guards (synchronous first, then asynchronous) against a target URL.
  Returns a promise resolving to the first non-Allow result, or Allow if all pass.

  Execution order:
    1. Sync guards run immediately. If any blocks or redirects, async guards are skipped.
    2. Async guards run sequentially (not in parallel) to preserve ordering guarantees.
       Sequential execution ensures that guard N can depend on side-effects from guard N-1
       (e.g., a token-refresh guard must complete before a permission-check guard runs).

  Note: This function does NOT enforce a timeout. Callers should use guardedPushAsync
  (which wraps this in a Promise.race with timeoutPromise) for production navigation.")
let runAllGuards = async (config: guardConfig, url: Tea_Url.t): promise<guardResult> => {
  // First run sync guards — these are fast (no I/O) and can reject early
  switch runGuards(config.guards, url) {
  | Allow => {
      // Sync guards passed. Now run async guards sequentially.
      let rec checkAsync = async (idx: int): promise<guardResult> => {
        if idx >= Belt.Array.length(config.asyncGuards) {
          Promise.resolve(Allow)
        } else {
          switch await Belt.Array.getExn(config.asyncGuards, idx)(url) {
          | Allow => await checkAsync(idx + 1)
          | result => Promise.resolve(result)
          }
        }
      }
      await checkAsync(0)
    }
  | result => Promise.resolve(result)
  }
}

// ============================================================================
// Navigation Integration
// ============================================================================

@ocaml.doc("Guarded synchronous navigation — only navigates if all synchronous guards pass.

  This is the simplest guard-aware navigation function. It only evaluates
  synchronous guards (the `guards` array in guardConfig); async guards are
  ignored. For routes protected by async guards, use `guardedPushAsync` instead.

  Returns true if navigation occurred (Allow or Redirect), false if blocked.

  Redirect handling: when a guard returns Redirect(path), the redirect target
  is parsed via Tea_Url.parse and pushed as a new history entry. Note that this
  does NOT re-run guards on the redirect target — use `guardedPushAsyncSafe`
  for redirect-safe navigation with loop detection.")
let guardedPush = (config: guardConfig, url: Tea_Url.t): bool => {
  switch runGuards(config.guards, url) {
  | Allow => {
      Tea_Navigation.execute(Tea_Navigation.Push(url))
      true
    }
  | Block(_) => false
  | Redirect(target) => {
      Tea_Navigation.execute(Tea_Navigation.Push(parse(target)))
      true
    }
  }
}

// ============================================================================
// Async Guarded Navigation (with Timeout)
// ============================================================================

// guardedPushAsync runs both synchronous and asynchronous guards before
// navigating. This enables guards that need to check remote state
// (e.g., token validity, feature flags, server-side permissions)
// without blocking the UI thread.
//
// The deferred navigation pattern:
//   1. Run sync guards first (fast, no network)
//   2. If sync guards pass, run async guards (may hit network)
//   3. Only navigate after ALL guards pass
//   4. Return a promise<bool> so callers can react to the outcome
//
// Timeout protection (added 2026-02-28):
//   Guard execution is raced against a configurable timeout promise.
//   If guards do not resolve within ~timeoutMs (default: 5000ms), the
//   navigation is blocked with a "Guard timeout exceeded" reason.
//   This prevents hung network requests from freezing navigation.
//
// This avoids the problem where guardedPush ignores asyncGuards
// entirely, meaning routes protected by async guards (e.g., checking
// a JWT refresh endpoint) would incorrectly allow navigation.
//
// Inspired by http-capability-gateway's policy gate pattern, where
// every request must pass through the full policy chain before
// reaching the handler.
@ocaml.doc("Guarded navigation with async guard support and timeout protection.

  Runs all guards (sync then async) and races the result against a timeout.
  If guards resolve before the timeout, their decision is honoured. If the
  timeout fires first, navigation is blocked.

  Parameters:
    config    — Guard configuration containing sync and async guard arrays.
    url       — Target URL to navigate to.
    ~timeoutMs — Maximum time in milliseconds to wait for guard resolution.
                 Defaults to defaultGuardTimeoutMs (5000ms).

  Returns: promise<bool> — true if navigation occurred, false if blocked/timed out.")
let guardedPushAsync = async (
  config: guardConfig,
  url: Tea_Url.t,
  ~timeoutMs: int=defaultGuardTimeoutMs,
): promise<bool> => {
  // Race the actual guard pipeline against a timeout sentinel.
  // Whichever promise settles first wins; the loser is discarded.
  let guardPromise = runAllGuards(config, url)
  let result = await Promise.race([guardPromise, timeoutPromise(timeoutMs)])
  switch result {
  | Allow => {
      Tea_Navigation.execute(Tea_Navigation.Push(url))
      true
    }
  | Block(_) => false
  | Redirect(target) => {
      Tea_Navigation.execute(Tea_Navigation.Push(parse(target)))
      true
    }
  }
}

// ============================================================================
// Redirect-Safe Navigation (with Loop Detection)
// ============================================================================

// guardedPushAsyncSafe wraps guardedPushAsync with redirect-loop detection.
//
// Problem it solves:
//   Without loop detection, a misconfigured guard set can cause infinite
//   redirect chains. For example:
//     - Guard on /dashboard redirects to /login
//     - Guard on /login redirects to /dashboard (if user IS authenticated)
//   This creates an A -> B -> A -> B -> ... loop that hangs the browser tab.
//
// Solution:
//   Track every URL visited during the redirect chain in a Set. Before
//   following a redirect, check:
//     1. Has this URL been visited before? (cycle detection)
//     2. Has the chain exceeded maxRedirectDepth? (runaway detection)
//   If either condition is true, navigation is blocked.
//
// Implementation notes:
//   - The visited set uses Belt.Set.String for O(log n) membership checks.
//   - URLs are compared as full strings (path + query + fragment) via
//     Tea_Url.toString, so /foo?a=1 and /foo?a=2 are treated as different.
//   - The recursive `loop` function is async to support the await on
//     Promise.race at each hop.
//   - Each hop in the redirect chain gets its own fresh timeout, so a
//     chain of 5 redirects at 5s timeout could take up to 25s total.
//     This is intentional — each guard evaluation deserves its own window.
@ocaml.doc("Redirect-safe navigation with loop detection and timeout.

  Like guardedPushAsync, but follows Redirect results by re-running guards
  on the redirect target. Detects and prevents redirect loops by tracking
  visited URLs in a Set, and enforces a maximum redirect chain depth.

  Parameters:
    config     — Guard configuration containing sync and async guard arrays.
    url        — Initial target URL to navigate to.
    ~timeoutMs — Maximum time per guard evaluation (default: 5000ms).
    ~maxDepth  — Maximum redirect chain length (default: 10 hops).

  Returns: promise<bool> — true if navigation occurred, false if blocked,
           timed out, or a redirect loop was detected.")
let guardedPushAsyncSafe = async (
  config: guardConfig,
  url: Tea_Url.t,
  ~timeoutMs: int=defaultGuardTimeoutMs,
  ~maxDepth: int=maxRedirectDepth,
): promise<bool> => {
  // Mutable set tracking all URLs visited in this redirect chain.
  // Using a ref because the recursive async `loop` closure captures it.
  let visited = ref(Belt.Set.String.empty)

  // Recursive redirect-following loop.
  // Each iteration: check depth/cycle, run guards with timeout, handle result.
  let rec loop = async (target: Tea_Url.t, depth: int): promise<bool> => {
    let urlStr = Tea_Url.toString(target)

    if depth > maxDepth {
      // Maximum redirect depth exceeded — likely a misconfiguration.
      // Block navigation to prevent runaway chains.
      false
    } else if Belt.Set.String.has(visited.contents, urlStr) {
      // This URL was already visited in the current redirect chain.
      // A -> B -> A cycle detected — block to prevent infinite loop.
      false
    } else {
      // Record this URL as visited before running guards.
      visited := Belt.Set.String.add(visited.contents, urlStr)

      // Race guard evaluation against the timeout for this hop.
      let guardPromise = runAllGuards(config, target)
      let result = await Promise.race([guardPromise, timeoutPromise(timeoutMs)])

      switch result {
      | Allow => {
          // All guards passed — execute the actual browser navigation.
          Tea_Navigation.execute(Tea_Navigation.Push(target))
          true
        }
      | Block(_) => {
          // A guard explicitly blocked navigation (or timeout fired).
          false
        }
      | Redirect(nextTarget) => {
          // A guard wants to redirect. Parse the target and recurse,
          // incrementing depth so we eventually hit the ceiling.
          await loop(parse(nextTarget), depth + 1)
        }
      }
    }
  }

  // Start the redirect chain at depth 0 with the original URL.
  await loop(url, 0)
}
