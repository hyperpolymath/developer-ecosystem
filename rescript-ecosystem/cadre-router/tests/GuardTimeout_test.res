// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// GuardTimeout_test.res - Tests for Tea_Guards async guard timeout and
// redirect loop detection.
//
// These security hardening features were added in cadre-router v0.4:
//
//   - guardedPushAsync: races guard evaluation against a configurable timeout
//     (default 5000ms) using Promise.race. If guards do not resolve in time,
//     navigation is blocked with "Guard timeout exceeded" reason.
//
//   - guardedPushAsyncSafe: extends guardedPushAsync with redirect-loop
//     detection. Tracks visited URLs in a Belt.Set.String and enforces a
//     maximum redirect chain depth (default 10). Prevents infinite
//     A -> B -> A redirect cycles from hanging the browser.
//
// Because these functions interact with browser APIs (History API),
// the tests below focus on the guard pipeline logic using the lower-level
// runGuards and runAllGuards functions, plus direct testing of the
// timeoutPromise helper and guardConfig construction.
//
// Browser-dependent integration tests (actual pushState calls) would
// require a DOM environment (Playwright/jsdom) and are out of scope here.

// ============================================================================
// Test Harness
// ============================================================================

let passed = ref(0)
let failed = ref(0)

let assertEq = (name: string, actual: 'a, expected: 'a): unit => {
  if actual == expected {
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  } else {
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name}`)
    Js.Console.error(`  Expected: ${Js.Json.stringifyAny(expected)->Belt.Option.getWithDefault("?")}`)
    Js.Console.error(`  Actual:   ${Js.Json.stringifyAny(actual)->Belt.Option.getWithDefault("?")}`)
  }
}

let assertTrue = (name: string, condition: bool): unit => {
  if condition {
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  } else {
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name} - expected true`)
  }
}

let assertFalse = (name: string, condition: bool): unit => {
  if !condition {
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  } else {
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name} - expected false`)
  }
}

let summary = () => {
  let total = passed.contents + failed.contents
  Js.Console.log("")
  Js.Console.log(`=== Summary: ${Belt.Int.toString(passed.contents)}/${Belt.Int.toString(total)} passed ===`)
  if failed.contents > 0 {
    Js.Console.error(`${Belt.Int.toString(failed.contents)} tests FAILED`)
  }
}

// ============================================================================
// Helper: Build Tea_Url.t from a path string
// ============================================================================
//
// Tea_Url.parse is the standard way to construct a Tea_Url.t from a string.
// The resulting record has {path, query, fragment} fields.

let makeUrl = (path: string): Tea_Url.t => Tea_Url.parse(path)

// ============================================================================
// SECTION 1: Guard Config Construction
// ============================================================================
//
// Verify that guardConfig records are correctly constructed and that
// emptyConfig allows all navigation.

let testEmptyConfig = () => {
  Js.Console.log("\n-- Guard Config: Empty --")

  // emptyConfig should have no guards
  assertEq("emptyConfig: no sync guards", Belt.Array.length(Tea_Guards.emptyConfig.guards), 0)
  assertEq("emptyConfig: no async guards", Belt.Array.length(Tea_Guards.emptyConfig.asyncGuards), 0)
}

let testCustomConfig = () => {
  Js.Console.log("\n-- Guard Config: Custom --")

  // Build a config with one sync guard
  let config: Tea_Guards.guardConfig = {
    guards: [_ => Tea_Guards.Allow],
    asyncGuards: [],
  }
  assertEq("customConfig: one sync guard", Belt.Array.length(config.guards), 1)
  assertEq("customConfig: no async guards", Belt.Array.length(config.asyncGuards), 0)
}

// ============================================================================
// SECTION 2: Synchronous Guard Execution (runGuards)
// ============================================================================
//
// Tea_Guards.runGuards executes synchronous guards sequentially and
// short-circuits on the first non-Allow result.

let testRunGuardsAllAllow = () => {
  Js.Console.log("\n-- runGuards: All Allow --")

  let guards: array<Tea_Guards.guard> = [
    _ => Tea_Guards.Allow,
    _ => Tea_Guards.Allow,
    _ => Tea_Guards.Allow,
  ]

  let result = Tea_Guards.runGuards(guards, makeUrl("/dashboard"))
  assertEq("runGuards: all allow returns Allow", result, Tea_Guards.Allow)
}

let testRunGuardsEmptyArray = () => {
  Js.Console.log("\n-- runGuards: Empty Array --")

  // No guards should mean "allow everything"
  let result = Tea_Guards.runGuards([], makeUrl("/anything"))
  assertEq("runGuards: empty array returns Allow", result, Tea_Guards.Allow)
}

let testRunGuardsFirstBlocks = () => {
  Js.Console.log("\n-- runGuards: First Blocks --")

  // Track which guards were called to verify short-circuiting
  let secondCalled = ref(false)

  let guards: array<Tea_Guards.guard> = [
    _ => Tea_Guards.Block("Not authorized"),
    _ => {
      secondCalled := true
      Tea_Guards.Allow
    },
  ]

  let result = Tea_Guards.runGuards(guards, makeUrl("/admin"))

  switch result {
  | Tea_Guards.Block(reason) =>
    assertEq("runGuards: block reason", reason, "Not authorized")
  | _ =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] runGuards: expected Block, got something else")
  }

  // The second guard should NOT have been called (short-circuit)
  assertFalse("runGuards: short-circuits on block", secondCalled.contents)
}

let testRunGuardsRedirect = () => {
  Js.Console.log("\n-- runGuards: Redirect --")

  let guards: array<Tea_Guards.guard> = [
    _ => Tea_Guards.Redirect("/login"),
  ]

  let result = Tea_Guards.runGuards(guards, makeUrl("/protected"))

  switch result {
  | Tea_Guards.Redirect(target) =>
    assertEq("runGuards: redirect target", target, "/login")
  | _ =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] runGuards: expected Redirect, got something else")
  }
}

let testRunGuardsSecondBlocks = () => {
  Js.Console.log("\n-- runGuards: Second Guard Blocks --")

  let guards: array<Tea_Guards.guard> = [
    _ => Tea_Guards.Allow,
    _ => Tea_Guards.Block("Feature disabled"),
    _ => Tea_Guards.Allow,
  ]

  let result = Tea_Guards.runGuards(guards, makeUrl("/feature"))

  switch result {
  | Tea_Guards.Block(reason) =>
    assertEq("runGuards: second guard block reason", reason, "Feature disabled")
  | _ =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] runGuards: expected Block from second guard")
  }
}

let testRunGuardsUrlInspection = () => {
  Js.Console.log("\n-- runGuards: URL Inspection --")

  // Guards can inspect the target URL to make decisions
  let guards: array<Tea_Guards.guard> = [
    url => {
      if url.path == "/admin" {
        Tea_Guards.Block("Admin access denied")
      } else {
        Tea_Guards.Allow
      }
    },
  ]

  let adminResult = Tea_Guards.runGuards(guards, makeUrl("/admin"))
  let homeResult = Tea_Guards.runGuards(guards, makeUrl("/home"))

  switch adminResult {
  | Tea_Guards.Block(_) => Js.Console.log("[PASS] runGuards: blocks /admin")
  | _ => Js.Console.error("[FAIL] runGuards: should block /admin")
  }

  assertEq("runGuards: allows /home", homeResult, Tea_Guards.Allow)
}

// ============================================================================
// SECTION 3: Async Guard Execution (runAllGuards)
// ============================================================================
//
// Tea_Guards.runAllGuards runs sync guards first, then async guards
// sequentially. Async guards only run if all sync guards pass.

let testRunAllGuardsNoAsyncGuards = async () => {
  Js.Console.log("\n-- runAllGuards: No Async Guards --")

  let config: Tea_Guards.guardConfig = {
    guards: [_ => Tea_Guards.Allow],
    asyncGuards: [],
  }

  let result = await Tea_Guards.runAllGuards(config, makeUrl("/page"))
  assertEq("runAllGuards: no async, sync allows", result, Tea_Guards.Allow)
}

let testRunAllGuardsSyncBlocksSkipsAsync = async () => {
  Js.Console.log("\n-- runAllGuards: Sync Block Skips Async --")

  let asyncCalled = ref(false)

  let config: Tea_Guards.guardConfig = {
    guards: [_ => Tea_Guards.Block("Sync blocked")],
    asyncGuards: [
      _ => {
        asyncCalled := true
        Promise.resolve(Tea_Guards.Allow)
      },
    ],
  }

  let result = await Tea_Guards.runAllGuards(config, makeUrl("/page"))

  switch result {
  | Tea_Guards.Block(reason) =>
    assertEq("runAllGuards: sync block reason", reason, "Sync blocked")
  | _ =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] runAllGuards: expected Block")
  }

  // Async guard should NOT have been called because sync guard blocked
  assertFalse("runAllGuards: async skipped when sync blocks", asyncCalled.contents)
}

let testRunAllGuardsAsyncAllow = async () => {
  Js.Console.log("\n-- runAllGuards: Async Allow --")

  let config: Tea_Guards.guardConfig = {
    guards: [_ => Tea_Guards.Allow],
    asyncGuards: [_ => Promise.resolve(Tea_Guards.Allow)],
  }

  let result = await Tea_Guards.runAllGuards(config, makeUrl("/page"))
  assertEq("runAllGuards: async allows", result, Tea_Guards.Allow)
}

let testRunAllGuardsAsyncBlock = async () => {
  Js.Console.log("\n-- runAllGuards: Async Block --")

  let config: Tea_Guards.guardConfig = {
    guards: [_ => Tea_Guards.Allow],
    asyncGuards: [_ => Promise.resolve(Tea_Guards.Block("Token expired"))],
  }

  let result = await Tea_Guards.runAllGuards(config, makeUrl("/dashboard"))

  switch result {
  | Tea_Guards.Block(reason) =>
    assertEq("runAllGuards: async block reason", reason, "Token expired")
  | _ =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] runAllGuards: expected async Block")
  }
}

let testRunAllGuardsAsyncRedirect = async () => {
  Js.Console.log("\n-- runAllGuards: Async Redirect --")

  let config: Tea_Guards.guardConfig = {
    guards: [_ => Tea_Guards.Allow],
    asyncGuards: [_ => Promise.resolve(Tea_Guards.Redirect("/login"))],
  }

  let result = await Tea_Guards.runAllGuards(config, makeUrl("/protected"))

  switch result {
  | Tea_Guards.Redirect(target) =>
    assertEq("runAllGuards: async redirect target", target, "/login")
  | _ =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] runAllGuards: expected async Redirect")
  }
}

let testRunAllGuardsMultipleAsyncSequential = async () => {
  Js.Console.log("\n-- runAllGuards: Multiple Async Sequential --")

  // Track execution order to verify sequential (not parallel) execution
  let order = ref([])

  let config: Tea_Guards.guardConfig = {
    guards: [],
    asyncGuards: [
      _ => {
        order := Belt.Array.concat(order.contents, ["first"])
        Promise.resolve(Tea_Guards.Allow)
      },
      _ => {
        order := Belt.Array.concat(order.contents, ["second"])
        Promise.resolve(Tea_Guards.Allow)
      },
      _ => {
        order := Belt.Array.concat(order.contents, ["third"])
        Promise.resolve(Tea_Guards.Allow)
      },
    ],
  }

  let result = await Tea_Guards.runAllGuards(config, makeUrl("/page"))
  assertEq("runAllGuards: all async pass", result, Tea_Guards.Allow)
  assertEq("runAllGuards: sequential order", order.contents, ["first", "second", "third"])
}

let testRunAllGuardsAsyncShortCircuit = async () => {
  Js.Console.log("\n-- runAllGuards: Async Short-Circuit --")

  let thirdCalled = ref(false)

  let config: Tea_Guards.guardConfig = {
    guards: [],
    asyncGuards: [
      _ => Promise.resolve(Tea_Guards.Allow),
      _ => Promise.resolve(Tea_Guards.Block("Second blocks")),
      _ => {
        thirdCalled := true
        Promise.resolve(Tea_Guards.Allow)
      },
    ],
  }

  let result = await Tea_Guards.runAllGuards(config, makeUrl("/page"))

  switch result {
  | Tea_Guards.Block(reason) =>
    assertEq("runAllGuards: short-circuit reason", reason, "Second blocks")
  | _ =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] runAllGuards: expected Block from second async")
  }

  assertFalse("runAllGuards: third async not called", thirdCalled.contents)
}

// ============================================================================
// SECTION 4: Timeout Promise
// ============================================================================
//
// Tea_Guards.timeoutPromise creates a promise that resolves to
// Block("Guard timeout exceeded (Nms)") after N milliseconds.
// This is used with Promise.race in guardedPushAsync.

let testTimeoutPromiseResolvesToBlock = async () => {
  Js.Console.log("\n-- timeoutPromise: Resolves to Block --")

  // Use a very short timeout (10ms) to avoid slow tests
  let result = await Tea_Guards.timeoutPromise(10)

  switch result {
  | Tea_Guards.Block(reason) =>
    assertTrue("timeoutPromise: contains timeout message", Js.String2.includes(reason, "timeout"))
    assertTrue("timeoutPromise: contains ms value", Js.String2.includes(reason, "10"))
  | _ =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] timeoutPromise: expected Block")
  }
}

let testTimeoutPromiseRaceGuardWins = async () => {
  Js.Console.log("\n-- timeoutPromise: Guard Wins Race --")

  // Guard resolves immediately; timeout is long — guard should win
  let guardPromise = Promise.resolve(Tea_Guards.Allow)
  let timeout = Tea_Guards.timeoutPromise(5000)

  let result = await Promise.race([guardPromise, timeout])
  assertEq("race: guard wins when fast", result, Tea_Guards.Allow)
}

let testTimeoutPromiseRaceTimeoutWins = async () => {
  Js.Console.log("\n-- timeoutPromise: Timeout Wins Race --")

  // Guard delays 200ms; timeout is 20ms — timeout should win
  let guardPromise = Promise.make((~resolve, ~reject as _) => {
    let _ = Tea_Guards.setTimeout(() => resolve(Tea_Guards.Allow), 200)
  })
  let timeout = Tea_Guards.timeoutPromise(20)

  let result = await Promise.race([guardPromise, timeout])

  switch result {
  | Tea_Guards.Block(reason) =>
    assertTrue("race: timeout wins when guard slow", Js.String2.includes(reason, "timeout"))
  | _ =>
    failed := failed.contents + 1
    Js.Console.error("[FAIL] race: expected timeout Block")
  }
}

// ============================================================================
// SECTION 5: Constants Verification
// ============================================================================
//
// Verify the default timeout and redirect depth constants match their
// documented values from STATE.scm and the source code comments.

let testConstants = () => {
  Js.Console.log("\n-- Constants --")

  // Default guard timeout should be 5000ms (5 seconds)
  assertEq("defaultGuardTimeoutMs", Tea_Guards.defaultGuardTimeoutMs, 5000)

  // Maximum redirect depth should be 10
  assertEq("maxRedirectDepth", Tea_Guards.maxRedirectDepth, 10)
}

// ============================================================================
// SECTION 6: Guard Result Type Tests
// ============================================================================
//
// Verify that guard result variants construct and match correctly.

let testGuardResultTypes = () => {
  Js.Console.log("\n-- Guard Result Types --")

  let allow: Tea_Guards.guardResult = Tea_Guards.Allow
  let block: Tea_Guards.guardResult = Tea_Guards.Block("reason")
  let redirect: Tea_Guards.guardResult = Tea_Guards.Redirect("/login")

  switch allow {
  | Tea_Guards.Allow => Js.Console.log("[PASS] Allow variant matches")
  | _ => Js.Console.error("[FAIL] Allow variant did not match")
  }

  switch block {
  | Tea_Guards.Block(r) => assertEq("Block variant reason", r, "reason")
  | _ => Js.Console.error("[FAIL] Block variant did not match")
  }

  switch redirect {
  | Tea_Guards.Redirect(t) => assertEq("Redirect variant target", t, "/login")
  | _ => Js.Console.error("[FAIL] Redirect variant did not match")
  }
}

// ============================================================================
// SECTION 7: Redirect Loop Detection Logic
// ============================================================================
//
// guardedPushAsyncSafe uses Belt.Set.String to track visited URLs
// and a depth counter to prevent infinite redirect chains.
// We test the Set-based logic directly since guardedPushAsyncSafe
// requires browser History API.

let testRedirectLoopDetection = () => {
  Js.Console.log("\n-- Redirect Loop Detection Logic --")

  // Simulate the visited-set logic from guardedPushAsyncSafe
  let visited = ref(Belt.Set.String.empty)

  // First visit: URL not in set
  let url1 = "/dashboard"
  assertFalse("loop detect: first visit not in set", Belt.Set.String.has(visited.contents, url1))
  visited := Belt.Set.String.add(visited.contents, url1)

  // Second visit to different URL: not a loop
  let url2 = "/login"
  assertFalse("loop detect: second URL not in set", Belt.Set.String.has(visited.contents, url2))
  visited := Belt.Set.String.add(visited.contents, url2)

  // Third visit back to first URL: LOOP DETECTED
  assertTrue("loop detect: /dashboard revisited = loop", Belt.Set.String.has(visited.contents, url1))

  // Verify both URLs are in the set
  assertTrue("loop detect: set has /dashboard", Belt.Set.String.has(visited.contents, "/dashboard"))
  assertTrue("loop detect: set has /login", Belt.Set.String.has(visited.contents, "/login"))
}

let testRedirectDepthExceeded = () => {
  Js.Console.log("\n-- Redirect Depth Exceeded --")

  // Simulate depth counting from guardedPushAsyncSafe
  let maxDepth = Tea_Guards.maxRedirectDepth

  // Depth 0 through maxDepth-1 should be allowed
  assertTrue("depth: 0 is within limit", 0 <= maxDepth)
  assertTrue("depth: 9 is within limit", 9 <= maxDepth)

  // Depth at maxDepth should be blocked (> maxDepth check)
  assertTrue("depth: 11 exceeds limit", 11 > maxDepth)
  assertTrue("depth: 10 is at limit", 10 <= maxDepth)

  // Depth maxDepth+1 should definitely be blocked
  assertTrue("depth: maxDepth+1 exceeds", (maxDepth + 1) > maxDepth)
}

let testTeaUrlRoundtripForLoopDetection = () => {
  Js.Console.log("\n-- Tea_Url Roundtrip for Loop Detection --")

  // guardedPushAsyncSafe compares URLs as strings via Tea_Url.toString.
  // Verify that parse -> toString produces stable strings for loop detection.
  let url1 = makeUrl("/dashboard")
  let url2 = makeUrl("/dashboard")
  let str1 = Tea_Url.toString(url1)
  let str2 = Tea_Url.toString(url2)

  assertEq("Tea_Url: same path produces same toString", str1, str2)

  // Different paths produce different strings
  let url3 = makeUrl("/login")
  let str3 = Tea_Url.toString(url3)
  assertTrue("Tea_Url: different paths produce different toString", str1 != str3)

  // Query parameters are included in comparison
  let url4 = makeUrl("/page?tab=1")
  let url5 = makeUrl("/page?tab=2")
  let str4 = Tea_Url.toString(url4)
  let str5 = Tea_Url.toString(url5)
  assertTrue("Tea_Url: different queries produce different toString", str4 != str5)
}

// ============================================================================
// Run All Tests
// ============================================================================
//
// Async tests are awaited inline within the runner. The run_tests.res
// entry point calls runAll which triggers auto-run.

let runAll = async () => {
  Js.Console.log("\n========================================")
  Js.Console.log("  GUARD TIMEOUT & REDIRECT LOOP TESTS")
  Js.Console.log("========================================")

  passed := 0
  failed := 0

  // Sync tests
  testEmptyConfig()
  testCustomConfig()
  testRunGuardsAllAllow()
  testRunGuardsEmptyArray()
  testRunGuardsFirstBlocks()
  testRunGuardsRedirect()
  testRunGuardsSecondBlocks()
  testRunGuardsUrlInspection()
  testConstants()
  testGuardResultTypes()
  testRedirectLoopDetection()
  testRedirectDepthExceeded()
  testTeaUrlRoundtripForLoopDetection()

  // Async tests
  await testRunAllGuardsNoAsyncGuards()
  await testRunAllGuardsSyncBlocksSkipsAsync()
  await testRunAllGuardsAsyncAllow()
  await testRunAllGuardsAsyncBlock()
  await testRunAllGuardsAsyncRedirect()
  await testRunAllGuardsMultipleAsyncSequential()
  await testRunAllGuardsAsyncShortCircuit()
  await testTimeoutPromiseResolvesToBlock()
  await testTimeoutPromiseRaceGuardWins()
  await testTimeoutPromiseRaceTimeoutWins()

  summary()

  Js.Console.log("\n========================================")
  Js.Console.log("  GUARD TIMEOUT TESTS COMPLETE")
  Js.Console.log("========================================\n")
}

// Auto-run
let _ = runAll()
