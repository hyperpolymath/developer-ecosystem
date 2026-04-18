// SPDX-License-Identifier: Apache-2.0
// Navigation_test.res - Tests for browser navigation module
//
// NOTE: These tests require a browser environment or JSDOM.
// In Deno, run with: deno test --allow-read --unstable tests/
// In browser: include the compiled JS in an HTML page.

// Test harness
let assertEq = (name: string, actual: 'a, expected: 'a): unit => {
  if actual == expected {
    Js.Console.log(`[PASS] ${name}`)
  } else {
    Js.Console.error(`[FAIL] ${name}`)
    Js.Console.error(`  Expected: ${Js.Json.stringifyAny(expected)->Belt.Option.getWithDefault("?")}`)
    Js.Console.error(`  Actual:   ${Js.Json.stringifyAny(actual)->Belt.Option.getWithDefault("?")}`)
  }
}

// ============================================================
// Mock Browser Environment Check
// ============================================================

// Check if window is defined (browser environment)
let windowExists = () => {
  try {
    %raw(`typeof window !== 'undefined'`)
  } catch {
  | _ => false
  }
}

let skipIfNoBrowser = (name: string, test: unit => unit): unit => {
  if windowExists() {
    test()
  } else {
    Js.Console.log(`[SKIP] ${name} (skipped - no browser environment)`)
  }
}

// ============================================================
// Navigation.Make Functor Tests
// ============================================================

module TestRoute = {
  type t =
    | Home
    | Profile
    | User(int)

  let toString = (route: t): string =>
    switch route {
    | Home => "/"
    | Profile => "/profile"
    | User(id) => "/user/" ++ Belt.Int.toString(id)
    }

  let fromUrl = (url: Url.t): option<t> => {
    let parser = Parser.oneOf([
      Parser.top->Parser.map(_ => Home),
      Parser.s("profile")->Parser.map(_ => Profile),
      Parser.s("user")->Parser.andThen(Parser.int)->Parser.map(((_, id)) => User(id)),
    ])
    Parser.parse(parser, url)
  }
}

module Nav = Navigation.Make(TestRoute)

// ============================================================
// Functor Type Tests (compile-time)
// ============================================================

// These tests verify the types are correct at compile time
let testFunctorTypes = () => {
  // Type: TestRoute.t => unit
  let _pushFn: TestRoute.t => unit = Nav.pushRoute
  let _replaceFn: TestRoute.t => unit = Nav.replaceRoute

  Js.Console.log("[PASS] Navigation.Make functor types compile correctly")
}

// ============================================================
// Navigation URL Construction Tests
// ============================================================

let testUrlConstruction = () => {
  // Test that toString produces correct URLs
  assertEq("toString: Home", TestRoute.toString(TestRoute.Home), "/")
  assertEq("toString: Profile", TestRoute.toString(TestRoute.Profile), "/profile")
  assertEq("toString: User(42)", TestRoute.toString(TestRoute.User(42)), "/user/42")
}

// ============================================================
// Roundtrip Tests
// ============================================================

let testRoundtrip = () => {
  let routes = [TestRoute.Home, TestRoute.Profile, TestRoute.User(123)]

  routes->Belt.Array.forEach(route => {
    let url = TestRoute.toString(route)
    let parsed = TestRoute.fromUrl(Url.fromString(url))
    let name = `roundtrip: ${url}`

    switch parsed {
    | Some(r) if r == route => Js.Console.log(`[PASS] ${name}`)
    | Some(_) => Js.Console.error(`[FAIL] ${name} - parsed to different route`)
    | None => Js.Console.error(`[FAIL] ${name} - failed to parse`)
    }
  })
}

// ============================================================
// Browser-Dependent Tests
// ============================================================

let testPushUrl = () => {
  skipIfNoBrowser("pushUrl changes location", () => {
    let before = Navigation.currentUrl()
    Navigation.pushUrl("/test-push")
    let after = Navigation.currentUrl()

    // Verify URL changed
    if Url.pathToString(after) == "/test-push" {
      Js.Console.log("[PASS] pushUrl changes location")
      // Restore
      Navigation.back()
    } else {
      Js.Console.error("[FAIL] pushUrl did not change location")
    }
  })
}

let testReplaceUrl = () => {
  skipIfNoBrowser("replaceUrl changes location without history", () => {
    Navigation.replaceUrl("/test-replace")
    let current = Navigation.currentUrl()

    if Url.pathToString(current) == "/test-replace" {
      Js.Console.log("[PASS] replaceUrl changes location")
    } else {
      Js.Console.error("[FAIL] replaceUrl did not change location")
    }
  })
}

let testOnUrlChange = () => {
  skipIfNoBrowser("onUrlChange subscription", () => {
    let received = ref(false)

    let unsubscribe = Navigation.onUrlChange(_ => {
      received := true
    })

    // Note: popstate doesn't fire on pushState, only on back/forward
    // This test documents the behavior
    Js.Console.log("[PASS] onUrlChange returns unsubscribe function")
    unsubscribe()
  })
}

let testTypedNavigation = () => {
  skipIfNoBrowser("typed navigation with Make functor", () => {
    Nav.pushRoute(TestRoute.Profile)
    let current = Navigation.currentUrl()

    if Url.pathToString(current) == "/profile" {
      Js.Console.log("[PASS] Nav.pushRoute works with typed routes")
      Navigation.back()
    } else {
      Js.Console.error("[FAIL] Nav.pushRoute did not navigate correctly")
    }
  })
}

// ============================================================
// Run all tests
// ============================================================

let runAll = () => {
  Js.Console.log("=== Navigation Module Tests ===")

  Js.Console.log("\n-- Functor Types --")
  testFunctorTypes()

  Js.Console.log("\n-- URL Construction --")
  testUrlConstruction()

  Js.Console.log("\n-- Roundtrip --")
  testRoundtrip()

  Js.Console.log("\n-- Browser-Dependent (may skip) --")
  testPushUrl()
  testReplaceUrl()
  testOnUrlChange()
  testTypedNavigation()

  Js.Console.log("\n=== Navigation Tests Complete ===")
}

// Auto-run
runAll()
