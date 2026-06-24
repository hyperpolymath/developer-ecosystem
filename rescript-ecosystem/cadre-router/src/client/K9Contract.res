// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// K9Contract.res - Client-side K9-SVC service contract enforcement for cadre-router.
//
// K9 contracts sit ABOVE a2ml attestations (which handle identity/audit). On the client
// side, contracts declare performance obligations for navigation, guard evaluation, and
// DOM mount operations. The router enforces contracts by measuring actual timing against
// declared thresholds and executing breach policies (log, warn, or degrade).
//
// This is intentionally lightweight — client-side contracts are observational, not
// blocking. A breached navigation contract logs a warning and emits a metric, but does
// not prevent the navigation from completing. This differs from the server-side gateway
// and HAR contracts which can reject or circuit-break on breach.
//
// ## Contract Types
//
//   - Navigation contracts: max time for route resolution + URL push/replace
//   - Guard contracts: max time for guard evaluation (sync and async)
//   - Mount contracts: max time for DOM mount via rescript-dom-mounter / SafeDOM
//
// ## Architecture
//
// Contracts are pure records — no mutable state, no ETS. Enforcement is a simple
// wrapper function that measures timing and compares against the threshold. This
// keeps the client bundle small and avoids any runtime overhead when no contracts
// are registered.

// ============================================================================
// Breach Policy
// ============================================================================

// Breach policy determines the client's response when a contract is violated.
//
// - Log: console.warn the breach (default, lightest touch)
// - Warn: console.warn + call an optional onBreach callback for metrics/telemetry
// - Degrade: console.error + call onBreach + mark the operation as degraded
//   (downstream code can check the result to show degraded UI)
type breachPolicy =
  | Log
  | Warn
  | Degrade

// ============================================================================
// Contract Result
// ============================================================================

// Result of a contract-enforced operation. Contains the operation's return
// value plus timing metadata and breach status.
//
// - value: the actual result of the wrapped operation
// - elapsedMs: wall-clock time in milliseconds
// - breached: true if elapsedMs exceeded the contract threshold
// - contractId: SHA-256 hex string identifying the contract
type contractResult<'a> = {
  value: 'a,
  elapsedMs: float,
  breached: bool,
  contractId: string,
}

// ============================================================================
// Contract Specifications
// ============================================================================

// Navigation contract — max time for route resolution (URL parse + match).
// Typical threshold: 5-20ms for synchronous parsing.
type navigationContract = {
  contractId: string,
  maxResolutionMs: float,
  breachPolicy: breachPolicy,
  onBreach: option<(string, float) => unit>,
}

// Guard contract — max time for guard evaluation.
// Sync guards should resolve in <1ms; async guards (network checks) get more room.
// The existing guard timeout in Tea_Guards (guardedPushAsync, default 5000ms) is
// the hard timeout; the K9 contract threshold is the SLA for "acceptable" time.
type guardContract = {
  contractId: string,
  maxSyncGuardMs: float,
  maxAsyncGuardMs: float,
  breachPolicy: breachPolicy,
  onBreach: option<(string, float) => unit>,
}

// Mount contract — max time for DOM mount via SafeDOM / rescript-dom-mounter.
// Covers the time from mount call to onSuccess callback firing.
type mountContract = {
  contractId: string,
  maxMountMs: float,
  breachPolicy: breachPolicy,
  onBreach: option<(string, float) => unit>,
}

// ============================================================================
// Performance.now() Binding
// ============================================================================

// High-resolution monotonic timestamp in milliseconds.
// Uses the Performance API which provides sub-millisecond precision
// and is not affected by system clock adjustments.
@val external performanceNow: unit => float = "performance.now"

// Console bindings for breach reporting.
@val external consoleWarn: string => unit = "console.warn"
@val external consoleError: string => unit = "console.error"

// ============================================================================
// Contract ID Generation
// ============================================================================

// Compute a deterministic contract ID from a content string.
//
// Uses a simple DJB2-style hash on the client side for performance.
// Server-side contracts use SHA-256; the client uses a lighter hash
// because contract IDs here are for correlation/logging, not security.
// The hash is encoded as a hex string for readability in logs.
//
// @param content  The string to hash (typically "type|field1|field2|...")
// @returns        Hex string of the hash
let computeContractId = (content: string): string => {
  // DJB2 hash: fast, good distribution, deterministic.
  let hash = ref(5381)
  for i in 0 to String.length(content) - 1 {
    let charCode = String.charCodeAt(content, i)
    // hash * 33 + charCode, keeping it as a 32-bit integer.
    hash := lor(lsl(hash.contents, 5) + hash.contents, 0) + Belt.Float.toInt(charCode)
  }
  // Convert to positive hex string.
  let h = land(hash.contents, 0x7FFFFFFF)
  Belt.Int.toStringWithRadix(h, ~radix=16)
}

// ============================================================================
// Contract Constructors
// ============================================================================

// Create a navigation contract with the given SLA threshold.
//
// @param maxResolutionMs  Maximum acceptable route resolution time in milliseconds.
//                         Typical values: 5ms (fast), 20ms (standard), 50ms (tolerant).
// @param ~breachPolicy    What to do when the threshold is exceeded (default: Log).
// @param ~onBreach        Optional callback receiving (contractId, elapsedMs) on breach.
// @returns                A fully constructed navigation contract with computed ID.
let makeNavigationContract = (
  maxResolutionMs: float,
  ~breachPolicy: breachPolicy=Log,
  ~onBreach: option<(string, float) => unit>=?,
): navigationContract => {
  let id = computeContractId(`nav|${Belt.Float.toString(maxResolutionMs)}|${switch breachPolicy {
  | Log => "log"
  | Warn => "warn"
  | Degrade => "degrade"
  }}`)
  {
    contractId: id,
    maxResolutionMs,
    breachPolicy,
    onBreach,
  }
}

// Create a guard contract with separate sync and async thresholds.
//
// @param maxSyncGuardMs   Maximum acceptable time for synchronous guard evaluation.
//                         Typical value: 1ms (guards should be near-instant).
// @param maxAsyncGuardMs  Maximum acceptable time for async guard evaluation.
//                         Typical value: 2000ms (network round-trip).
//                         Note: Tea_Guards.guardedPushAsync has a hard timeout
//                         (default 5000ms); this K9 threshold is the SLA target.
// @param ~breachPolicy    Breach handling policy (default: Warn).
// @param ~onBreach        Optional callback on breach.
// @returns                A fully constructed guard contract.
let makeGuardContract = (
  maxSyncGuardMs: float,
  maxAsyncGuardMs: float,
  ~breachPolicy: breachPolicy=Warn,
  ~onBreach: option<(string, float) => unit>=?,
): guardContract => {
  let id = computeContractId(`guard|${Belt.Float.toString(maxSyncGuardMs)}|${Belt.Float.toString(maxAsyncGuardMs)}`)
  {
    contractId: id,
    maxSyncGuardMs,
    maxAsyncGuardMs,
    breachPolicy,
    onBreach,
  }
}

// Create a mount contract for DOM mounting operations.
//
// @param maxMountMs     Maximum acceptable mount time in milliseconds.
//                       Typical value: 100ms (initial mount), 50ms (re-mount).
// @param ~breachPolicy  Breach handling policy (default: Warn).
// @param ~onBreach      Optional callback on breach.
// @returns              A fully constructed mount contract.
let makeMountContract = (
  maxMountMs: float,
  ~breachPolicy: breachPolicy=Warn,
  ~onBreach: option<(string, float) => unit>=?,
): mountContract => {
  let id = computeContractId(`mount|${Belt.Float.toString(maxMountMs)}`)
  {
    contractId: id,
    maxMountMs,
    breachPolicy,
    onBreach,
  }
}

// ============================================================================
// Breach Handling
// ============================================================================

// Execute a breach policy. Called internally when a contract threshold is exceeded.
//
// @param policy       The breach policy to execute.
// @param contractId   The contract that was breached.
// @param label        Human-readable label (e.g., "navigation", "sync guard").
// @param thresholdMs  The contract's threshold in milliseconds.
// @param elapsedMs    The actual elapsed time in milliseconds.
// @param onBreach     Optional callback for metrics/telemetry.
let handleBreach = (
  policy: breachPolicy,
  contractId: string,
  label: string,
  thresholdMs: float,
  elapsedMs: float,
  onBreach: option<(string, float) => unit>,
): unit => {
  let overshoot = elapsedMs -. thresholdMs
  let message = `[K9-SVC] Contract breach: ${label} took ${Belt.Float.toString(elapsedMs)}ms (max: ${Belt.Float.toString(thresholdMs)}ms, overshoot: ${Belt.Float.toString(overshoot)}ms) [${contractId}]`

  switch policy {
  | Log =>
    consoleWarn(message)
  | Warn =>
    consoleWarn(message)
    switch onBreach {
    | Some(cb) => cb(contractId, elapsedMs)
    | None => ()
    }
  | Degrade =>
    consoleError(message)
    switch onBreach {
    | Some(cb) => cb(contractId, elapsedMs)
    | None => ()
    }
  }
}

// ============================================================================
// Enforcement Wrappers
// ============================================================================

// Enforce a navigation contract around a route resolution operation.
//
// Wraps a synchronous route parsing/matching function with timing measurement.
// If the resolution time exceeds the contract's maxResolutionMs, the breach
// policy fires. The result is always returned regardless of breach status.
//
// Usage:
//   let contract = K9Contract.makeNavigationContract(20.0)
//   let result = K9Contract.enforceNavigation(contract, () => parser(url))
//   // result.value is the parsed route (option<'route>)
//   // result.breached is true if resolution took > 20ms
//
// @param contract  The navigation contract to enforce.
// @param resolve   Zero-argument function that performs route resolution.
// @returns         ContractResult wrapping the resolution output with timing metadata.
let enforceNavigation = (
  contract: navigationContract,
  resolve: unit => 'a,
): contractResult<'a> => {
  let start = performanceNow()
  let value = resolve()
  let elapsed = performanceNow() -. start

  let breached = elapsed > contract.maxResolutionMs

  if breached {
    handleBreach(
      contract.breachPolicy,
      contract.contractId,
      "navigation resolution",
      contract.maxResolutionMs,
      elapsed,
      contract.onBreach,
    )
  }

  {
    value,
    elapsedMs: elapsed,
    breached,
    contractId: contract.contractId,
  }
}

// Enforce a guard contract around a synchronous guard evaluation.
//
// @param contract  The guard contract to enforce.
// @param evaluate  Zero-argument function that evaluates the sync guard.
// @returns         ContractResult with guard evaluation output and timing.
let enforceSyncGuard = (
  contract: guardContract,
  evaluate: unit => 'a,
): contractResult<'a> => {
  let start = performanceNow()
  let value = evaluate()
  let elapsed = performanceNow() -. start

  let breached = elapsed > contract.maxSyncGuardMs

  if breached {
    handleBreach(
      contract.breachPolicy,
      contract.contractId,
      "sync guard",
      contract.maxSyncGuardMs,
      elapsed,
      contract.onBreach,
    )
  }

  {
    value,
    elapsedMs: elapsed,
    breached,
    contractId: contract.contractId,
  }
}

// Enforce a guard contract around an asynchronous guard evaluation (Promise).
//
// The returned Promise resolves to a contractResult containing the guard's
// output and timing metadata. The K9 threshold here is the SLA target —
// it's separate from the hard timeout in Tea_Guards.guardedPushAsync.
//
// @param contract  The guard contract to enforce.
// @param evaluate  Zero-argument function returning a Promise from the async guard.
// @returns         Promise resolving to ContractResult.
let enforceAsyncGuard = (
  contract: guardContract,
  evaluate: unit => promise<'a>,
): promise<contractResult<'a>> => {
  let start = performanceNow()

  evaluate()->Promise.then(value => {
    let elapsed = performanceNow() -. start
    let breached = elapsed > contract.maxAsyncGuardMs

    if breached {
      handleBreach(
        contract.breachPolicy,
        contract.contractId,
        "async guard",
        contract.maxAsyncGuardMs,
        elapsed,
        contract.onBreach,
      )
    }

    Promise.resolve({
      value,
      elapsedMs: elapsed,
      breached,
      contractId: contract.contractId,
    })
  })
}

// Enforce a mount contract around a DOM mount operation.
//
// Since SafeDOM.mountSafe and SafeDOM.mountWhenReady use callbacks (onSuccess/onError)
// rather than returning values directly, this wrapper provides a callback-style API
// that measures the time from invocation to callback firing.
//
// Usage:
//   let contract = K9Contract.makeMountContract(100.0)
//   K9Contract.enforceMount(contract, onResult => {
//     SafeDOM.mountSafe("#app", html,
//       ~onSuccess=el => onResult(Ok(el)),
//       ~onError=e => onResult(Error(e)),
//     )
//   }, ~onComplete=result => {
//     // result.value is Ok(element) or Error(string)
//     // result.breached tells you if mount was too slow
//   })
//
// @param contract    The mount contract to enforce.
// @param mount       Function that accepts a result callback and performs the mount.
// @param ~onComplete Callback receiving the contractResult when the mount completes.
let enforceMount = (
  contract: mountContract,
  mount: (result<Dom.element, string> => unit) => unit,
  ~onComplete: contractResult<result<Dom.element, string>> => unit,
): unit => {
  let start = performanceNow()

  mount(mountResult => {
    let elapsed = performanceNow() -. start
    let breached = elapsed > contract.maxMountMs

    if breached {
      handleBreach(
        contract.breachPolicy,
        contract.contractId,
        "DOM mount",
        contract.maxMountMs,
        elapsed,
        contract.onBreach,
      )
    }

    onComplete({
      value: mountResult,
      elapsedMs: elapsed,
      breached,
      contractId: contract.contractId,
    })
  })
}

// ============================================================================
// Contract Set — Group Multiple Contracts
// ============================================================================

// A contract set bundles navigation, guard, and mount contracts for a route
// or application. This is the typical entry point for users who want full
// K9-SVC coverage across all cadre-router operations.
type contractSet = {
  navigation: option<navigationContract>,
  guard: option<guardContract>,
  mount: option<mountContract>,
}

// Create an empty contract set (no enforcement).
let emptySet: contractSet = {
  navigation: None,
  guard: None,
  mount: None,
}

// Create a contract set with standard SLA thresholds.
//
// Standard thresholds:
//   - Navigation resolution: 20ms
//   - Sync guard evaluation: 1ms
//   - Async guard evaluation: 2000ms
//   - DOM mount: 100ms
//
// @param ~breachPolicy  Default breach policy for all contracts (default: Warn).
// @param ~onBreach      Optional callback for all contracts.
// @returns              A contract set with standard SLA thresholds.
let standardSet = (
  ~breachPolicy: breachPolicy=Warn,
  ~onBreach: option<(string, float) => unit>=?,
): contractSet => {
  {
    navigation: Some(makeNavigationContract(20.0, ~breachPolicy, ~onBreach?)),
    guard: Some(makeGuardContract(1.0, 2000.0, ~breachPolicy, ~onBreach?)),
    mount: Some(makeMountContract(100.0, ~breachPolicy, ~onBreach?)),
  }
}

// Create a strict contract set with tight SLA thresholds.
//
// Strict thresholds (for performance-critical applications):
//   - Navigation resolution: 5ms
//   - Sync guard evaluation: 0.5ms
//   - Async guard evaluation: 1000ms
//   - DOM mount: 50ms
//
// @param ~onBreach  Optional callback for all contracts.
// @returns          A contract set with strict SLA thresholds.
let strictSet = (
  ~onBreach: option<(string, float) => unit>=?,
): contractSet => {
  {
    navigation: Some(makeNavigationContract(5.0, ~breachPolicy=Degrade, ~onBreach?)),
    guard: Some(makeGuardContract(0.5, 1000.0, ~breachPolicy=Degrade, ~onBreach?)),
    mount: Some(makeMountContract(50.0, ~breachPolicy=Degrade, ~onBreach?)),
  }
}

// ============================================================================
// React Hook Integration
// ============================================================================

// React hook for tracking K9 contract breaches in a component.
//
// Returns a tuple of (breachCount, breachLog) that updates whenever a
// contract breach occurs. The breachLog contains the most recent N breaches
// for display in a developer tools panel or performance dashboard.
//
// Usage:
//   let (breachCount, breachLog) = K9Contract.React.useContractBreaches()
//   // Pass the onBreach callback from useContractBreaches to your contracts
module ReactHook = {
  // Breach log entry for display in developer tools.
  type breachEntry = {
    contractId: string,
    elapsedMs: float,
    timestamp: float,
  }

  // Hook that tracks contract breaches and provides a callback for contracts.
  // Returns (breachCount, latestBreaches, onBreachCallback).
  let useContractBreaches = (~maxEntries: int=20): (int, array<breachEntry>, (string, float) => unit) => {
    let (breaches, setBreaches) = React.useState(() => [])
    let (count, setCount) = React.useState(() => 0)

    let onBreach = React.useCallback1((contractId: string, elapsedMs: float) => {
      let entry = {
        contractId,
        elapsedMs,
        timestamp: performanceNow(),
      }

      setBreaches(prev => {
        let updated = Belt.Array.concat([entry], prev)
        Belt.Array.slice(updated, ~offset=0, ~len=maxEntries)
      })

      setCount(prev => prev + 1)
    }, [maxEntries])

    (count, breaches, onBreach)
  }
}
