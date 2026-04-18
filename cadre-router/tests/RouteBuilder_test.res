// SPDX-License-Identifier: Apache-2.0
// RouteBuilder_test.res - Tests for bidirectional route builder

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
// Test Route Type
// ============================================================

module UserId = {
  type t = UserId(string)

  let fromString = (s: string): option<t> =>
    if Js.String2.length(s) > 0 { Some(UserId(s)) } else { None }

  let toString = (UserId(s): t): string => s
}

type route =
  | Home
  | Profile
  | User(int)
  | UserProfile(int, string)
  | Item(UserId.t)
  | NotFound

// ============================================================
// Route Definitions
// ============================================================

let homeRoute = RouteBuilder.build(
  RouteBuilder.end_,
  ~toRoute=_ => Home,
  ~fromRoute=route => switch route { | Home => Some() | _ => None }
)

let profileRoute = RouteBuilder.build(
  RouteBuilder.andThen(RouteBuilder.lit("profile"), RouteBuilder.end_),
  ~toRoute=_ => Profile,
  ~fromRoute=route => switch route { | Profile => Some(((), ())) | _ => None }
)

let userRoute = RouteBuilder.build(
  RouteBuilder.andThen(RouteBuilder.andThen(RouteBuilder.lit("user"), RouteBuilder.int()), RouteBuilder.end_),
  ~toRoute=(((_, id), _)) => User(id),
  ~fromRoute=route => switch route { | User(id) => Some((((), id), ())) | _ => None }
)

let userProfileRoute = RouteBuilder.build(
  RouteBuilder.andThen(
    RouteBuilder.andThen(
      RouteBuilder.andThen(
        RouteBuilder.andThen(RouteBuilder.lit("user"), RouteBuilder.int()),
        RouteBuilder.lit("profile")
      ),
      RouteBuilder.str()
    ),
    RouteBuilder.end_
  ),
  ~toRoute=arg => {
    let ((((_, id), _), section), _) = arg
    UserProfile(id, section)
  },
  ~fromRoute=route => switch route {
    | UserProfile(id, section) => Some((((((), id), ()), section), ()))
    | _ => None
  }
)

let itemRoute = RouteBuilder.build(
  RouteBuilder.andThen(
    RouteBuilder.andThen(
      RouteBuilder.lit("item"),
      RouteBuilder.custom(~parse=UserId.fromString, ~serialize=UserId.toString)
    ),
    RouteBuilder.end_
  ),
  ~toRoute=arg => {
    let ((_, id), _) = arg
    Item(id)
  },
  ~fromRoute=route => switch route {
    | Item(id) => Some((((), id), ()))
    | _ => None
  }
)

let router = RouteBuilder.oneOf([
  homeRoute,
  profileRoute,
  userRoute,
  userProfileRoute,
  itemRoute,
])

// ============================================================
// Basic Segment Tests
// ============================================================

let testLiteralSegment = () => {
  let route = RouteBuilder.build(
    RouteBuilder.andThen(RouteBuilder.lit("test"), RouteBuilder.end_),
    ~toRoute=_ => Profile,
    ~fromRoute=route => switch route { | Profile => Some(((), ())) | _ => None }
  )

  assertSome("lit: parses /test", route.parse(Url.fromString("/test")))
  assertNone("lit: rejects /other", route.parse(Url.fromString("/other")))
  assertEq("lit: serializes", route.toString(Profile), Some("/test"))
}

let testIntSegment = () => {
  let route = RouteBuilder.build(
    RouteBuilder.andThen(RouteBuilder.andThen(RouteBuilder.lit("num"), RouteBuilder.int()), RouteBuilder.end_),
    ~toRoute=arg => { let ((_, n), _) = arg; User(n) },
    ~fromRoute=route => switch route { | User(n) => Some((((), n), ())) | _ => None }
  )

  switch route.parse(Url.fromString("/num/42")) {
  | Some(User(n)) => assertEq("int: parses /num/42", n, 42)
  | _ => Js.Console.error("[FAIL] int: failed to parse /num/42")
  }

  assertNone("int: rejects /num/abc", route.parse(Url.fromString("/num/abc")))
  assertEq("int: serializes", route.toString(User(123)), Some("/num/123"))
}

let testStrSegment = () => {
  let route = RouteBuilder.build(
    RouteBuilder.andThen(RouteBuilder.andThen(RouteBuilder.lit("name"), RouteBuilder.str()), RouteBuilder.end_),
    ~toRoute=arg => { let ((_, s), _) = arg; UserProfile(0, s) },
    ~fromRoute=route => switch route { | UserProfile(_, s) => Some((((), s), ())) | _ => None }
  )

  switch route.parse(Url.fromString("/name/alice")) {
  | Some(UserProfile(_, s)) => assertEq("str: parses /name/alice", s, "alice")
  | _ => Js.Console.error("[FAIL] str: failed to parse /name/alice")
  }

  assertEq("str: serializes", route.toString(UserProfile(0, "bob")), Some("/name/bob"))
}

let testCustomSegment = () => {
  assertSome("custom: parses /item/xyz", itemRoute.parse(Url.fromString("/item/xyz")))
  assertNone("custom: rejects /item/", itemRoute.parse(Url.fromString("/item/")))

  switch itemRoute.toString(Item(UserId.UserId("abc"))) {
  | Some(s) => assertEq("custom: serializes", s, "/item/abc")
  | None => Js.Console.error("[FAIL] custom: failed to serialize")
  }
}

// ============================================================
// Router Tests
// ============================================================

let testRouterParsing = () => {
  assertEq("router: parses /", router.parse(Url.fromString("/")), Some(Home))
  assertEq("router: parses /profile", router.parse(Url.fromString("/profile")), Some(Profile))
  assertEq("router: parses /user/42", router.parse(Url.fromString("/user/42")), Some(User(42)))

  switch router.parse(Url.fromString("/user/5/profile/settings")) {
  | Some(UserProfile(id, section)) => {
      assertEq("router: user id", id, 5)
      assertEq("router: section", section, "settings")
    }
  | _ => Js.Console.error("[FAIL] router: failed to parse /user/5/profile/settings")
  }

  assertNone("router: rejects unknown", router.parse(Url.fromString("/unknown")))
}

let testRouterSerialization = () => {
  assertEq("router: serializes Home", router.toString(Home), Some("/"))
  assertEq("router: serializes Profile", router.toString(Profile), Some("/profile"))
  assertEq("router: serializes User(42)", router.toString(User(42)), Some("/user/42"))
  assertEq("router: serializes UserProfile", router.toString(UserProfile(5, "settings")), Some("/user/5/profile/settings"))
  assertEq("router: serializes Item", router.toString(Item(UserId.UserId("xyz"))), Some("/item/xyz"))
  assertNone("router: NotFound returns None", router.toString(NotFound))
}

// ============================================================
// Roundtrip Tests (Bidirectional Guarantee)
// ============================================================

let testRoundtrip = () => {
  Js.Console.log("\n-- Roundtrip Tests (Bidirectional Guarantee) --")

  let routes = [
    Home,
    Profile,
    User(42),
    User(0),
    User(-5),
    UserProfile(1, "dashboard"),
    Item(UserId.UserId("abc123")),
  ]

  routes->Belt.Array.forEach(route => {
    switch router.toString(route) {
    | Some(url) => {
        switch router.parse(Url.fromString(url)) {
        | Some(parsed) if parsed == route =>
          Js.Console.log(`[PASS] roundtrip: ${url}`)
        | Some(_) =>
          Js.Console.error(`[FAIL] roundtrip: ${url} - parsed to different route`)
        | None =>
          Js.Console.error(`[FAIL] roundtrip: ${url} - failed to parse`)
        }
      }
    | None => Js.Console.error(`[FAIL] roundtrip: failed to serialize route`)
    }
  })
}

// ============================================================
// Make Functor Tests
// ============================================================

module Router = RouteBuilder.Make({
  type route = route
  let definition = router
  let notFound = NotFound
})

let testMakeFunctor = () => {
  Js.Console.log("\n-- Make Functor Tests --")

  assertEq("Make.parse: /", Router.parse(Url.fromString("/")), Home)
  assertEq("Make.parse: /profile", Router.parse(Url.fromString("/profile")), Profile)
  assertEq("Make.parse: /unknown returns notFound", Router.parse(Url.fromString("/unknown")), NotFound)

  assertEq("Make.toString: Home", Router.toString(Home), "/")
  assertEq("Make.toString: Profile", Router.toString(Profile), "/profile")
  assertEq("Make.toString: NotFound returns /", Router.toString(NotFound), "/")

  assertSome("Make.parseOption: /", Router.parseOption(Url.fromString("/")))
  assertNone("Make.parseOption: /unknown", Router.parseOption(Url.fromString("/unknown")))
}

// ============================================================
// Run all tests
// ============================================================

let runAll = () => {
  Js.Console.log("=== RouteBuilder Module Tests ===")

  Js.Console.log("\n-- Basic Segments --")
  testLiteralSegment()
  testIntSegment()
  testStrSegment()
  testCustomSegment()

  Js.Console.log("\n-- Router Parsing --")
  testRouterParsing()

  Js.Console.log("\n-- Router Serialization --")
  testRouterSerialization()

  testRoundtrip()
  testMakeFunctor()

  Js.Console.log("\n=== RouteBuilder Tests Complete ===")
}

// Auto-run
runAll()
