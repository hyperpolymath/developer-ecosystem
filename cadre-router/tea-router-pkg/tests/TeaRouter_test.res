// SPDX-License-Identifier: Apache-2.0
// TeaRouter_test.res - Tests for TEA router integration

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

let assertSome = (name: string, actual: option<'a>): unit => {
  switch actual {
  | Some(_) => Js.Console.log(`[PASS] ${name}`)
  | None => Js.Console.error(`[FAIL] ${name} - expected Some, got None`)
  }
}

let assertNone = (name: string, actual: option<'a>): unit => {
  switch actual {
  | None => Js.Console.log(`[PASS] ${name}`)
  | Some(_) => Js.Console.error(`[FAIL] ${name} - expected None, got Some`)
  }
}

// ============================================================
// Test Route and Message Types
// ============================================================

type route =
  | Home
  | Profile
  | User(int)
  | NotFound

type msg =
  | RouteChanged(route)
  | UrlNotFound(CadreRouter.Url.t)

let routeParser = {
  open CadreRouter.Parser
  oneOf([
    top->map(_ => Home),
    s("profile")->map(_ => Profile),
    s("user")->andThen(int)->map(((_, id)) => User(id)),
  ])
}

let routeToString = route =>
  switch route {
  | Home => "/"
  | Profile => "/profile"
  | User(id) => "/user/" ++ Belt.Int.toString(id)
  | NotFound => "/404"
  }

// ============================================================
// Create Router Module
// ============================================================

module Router = TeaRouter.Make({
  type route = route
  type msg = msg

  let parser = routeParser
  let toString = routeToString
  let onRouteChange = route => RouteChanged(route)
  let onNotFound = url => UrlNotFound(url)
})

// ============================================================
// Type Tests (compile-time verification)
// ============================================================

let testTypes = () => {
  // These verify that the types compile correctly
  let _: unit => (option<route>, Tea.Cmd.t<msg>) = Router.init
  let _: route => Tea.Cmd.t<msg> = Router.push
  let _: route => Tea.Cmd.t<msg> = Router.replace
  let _: Tea.Cmd.t<msg> = Router.back
  let _: Tea.Cmd.t<msg> = Router.forward
  let _: int => Tea.Cmd.t<msg> = Router.go
  let _: Tea.Sub.t<msg> = Router.urlChanges
  let _: CadreRouter.Url.t => option<route> = Router.parseUrl
  let _: unit => option<route> = Router.currentRoute

  Js.Console.log("[PASS] Router module types compile correctly")
}

// ============================================================
// URL Parsing Tests
// ============================================================

let testParseUrl = () => {
  assertEq(
    "parseUrl: /",
    Router.parseUrl(CadreRouter.Url.fromString("/")),
    Some(Home),
  )
  assertEq(
    "parseUrl: /profile",
    Router.parseUrl(CadreRouter.Url.fromString("/profile")),
    Some(Profile),
  )
  assertEq(
    "parseUrl: /user/42",
    Router.parseUrl(CadreRouter.Url.fromString("/user/42")),
    Some(User(42)),
  )
  assertNone(
    "parseUrl: /unknown",
    Router.parseUrl(CadreRouter.Url.fromString("/unknown")),
  )
}

// ============================================================
// Route Serialization Tests
// ============================================================

let testToString = () => {
  assertEq("toString: Home", routeToString(Home), "/")
  assertEq("toString: Profile", routeToString(Profile), "/profile")
  assertEq("toString: User(42)", routeToString(User(42)), "/user/42")
  assertEq("toString: NotFound", routeToString(NotFound), "/404")
}

// ============================================================
// Roundtrip Tests
// ============================================================

let testRoundtrip = () => {
  let routes = [Home, Profile, User(42), User(0), User(999)]

  routes->Belt.Array.forEach(route => {
    if route == NotFound {
      // NotFound doesn't roundtrip (it's the fallback)
      ()
    } else {
      let url = routeToString(route)
      let parsed = Router.parseUrl(CadreRouter.Url.fromString(url))
      let name = `roundtrip: ${url}`

      switch parsed {
      | Some(r) if r == route => Js.Console.log(`[PASS] ${name}`)
      | Some(_) => Js.Console.error(`[FAIL] ${name} - parsed to different route`)
      | None => Js.Console.error(`[FAIL] ${name} - failed to parse`)
      }
    }
  })
}

// ============================================================
// Message Construction Tests
// ============================================================

let testMessageConstruction = () => {
  // Test that message constructors work correctly
  let msg1 = RouteChanged(Home)
  let msg2 = RouteChanged(Profile)
  let msg3 = UrlNotFound(CadreRouter.Url.fromString("/unknown"))

  switch msg1 {
  | RouteChanged(Home) => Js.Console.log("[PASS] RouteChanged(Home) message")
  | _ => Js.Console.error("[FAIL] RouteChanged(Home) message")
  }

  switch msg2 {
  | RouteChanged(Profile) => Js.Console.log("[PASS] RouteChanged(Profile) message")
  | _ => Js.Console.error("[FAIL] RouteChanged(Profile) message")
  }

  switch msg3 {
  | UrlNotFound(_) => Js.Console.log("[PASS] UrlNotFound message")
  | _ => Js.Console.error("[FAIL] UrlNotFound message")
  }
}

// ============================================================
// HashRouter Type Tests
// ============================================================

module HashRouter = TeaRouter.HashRouter.Make({
  type route = route
  type msg = msg

  let parser = routeParser
  let toString = routeToString
  let onRouteChange = route => RouteChanged(route)
  let onNotFound = url => UrlNotFound(url)
})

let testHashRouterTypes = () => {
  let _: unit => (option<route>, Tea.Cmd.t<msg>) = HashRouter.init
  let _: route => Tea.Cmd.t<msg> = HashRouter.push
  let _: route => Tea.Cmd.t<msg> = HashRouter.replace
  let _: Tea.Cmd.t<msg> = HashRouter.back
  let _: Tea.Cmd.t<msg> = HashRouter.forward
  let _: int => Tea.Cmd.t<msg> = HashRouter.go
  let _: Tea.Sub.t<msg> = HashRouter.urlChanges
  let _: CadreRouter.Url.t => option<route> = HashRouter.parseUrl
  let _: unit => option<route> = HashRouter.currentRoute

  Js.Console.log("[PASS] HashRouter module types compile correctly")
}

// ============================================================
// Run all tests
// ============================================================

let runAll = () => {
  Js.Console.log("=== TeaRouter Module Tests ===")

  Js.Console.log("\n-- Type Verification --")
  testTypes()
  testHashRouterTypes()

  Js.Console.log("\n-- URL Parsing --")
  testParseUrl()

  Js.Console.log("\n-- Route Serialization --")
  testToString()

  Js.Console.log("\n-- Roundtrip --")
  testRoundtrip()

  Js.Console.log("\n-- Message Construction --")
  testMessageConstruction()

  Js.Console.log("\n=== TeaRouter Tests Complete ===")
}

// Auto-run
runAll()
