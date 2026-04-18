// SPDX-License-Identifier: Apache-2.0
// ServerRouter_test.res - Tests for server-side routing

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
// HTTP Method Tests
// ============================================================

let testMethodFromString = () => {
  assertEq("methodFromString GET", ServerRouter.methodFromString("GET"), Some(ServerRouter.GET))
  assertEq("methodFromString POST", ServerRouter.methodFromString("POST"), Some(ServerRouter.POST))
  assertEq("methodFromString PUT", ServerRouter.methodFromString("PUT"), Some(ServerRouter.PUT))
  assertEq(
    "methodFromString PATCH",
    ServerRouter.methodFromString("PATCH"),
    Some(ServerRouter.PATCH),
  )
  assertEq(
    "methodFromString DELETE",
    ServerRouter.methodFromString("DELETE"),
    Some(ServerRouter.DELETE),
  )
  assertEq("methodFromString HEAD", ServerRouter.methodFromString("HEAD"), Some(ServerRouter.HEAD))
  assertEq(
    "methodFromString OPTIONS",
    ServerRouter.methodFromString("OPTIONS"),
    Some(ServerRouter.OPTIONS),
  )
  assertNone("methodFromString invalid", ServerRouter.methodFromString("INVALID"))
}

let testMethodFromStringCaseInsensitive = () => {
  assertEq(
    "methodFromString lowercase",
    ServerRouter.methodFromString("get"),
    Some(ServerRouter.GET),
  )
  assertEq(
    "methodFromString mixed case",
    ServerRouter.methodFromString("Post"),
    Some(ServerRouter.POST),
  )
}

let testMethodToString = () => {
  assertEq("methodToString GET", ServerRouter.methodToString(ServerRouter.GET), "GET")
  assertEq("methodToString POST", ServerRouter.methodToString(ServerRouter.POST), "POST")
  assertEq("methodToString DELETE", ServerRouter.methodToString(ServerRouter.DELETE), "DELETE")
}

// ============================================================
// Request Context Tests
// ============================================================

let testMakeContext = () => {
  let ctx = ServerRouter.makeContext(~urlString="/api/users", ~method=ServerRouter.GET, ())

  assertEq("makeContext: method", ctx.method, ServerRouter.GET)
  assertEq("makeContext: path", ctx.path, "/api/users")
  assertEq("makeContext: url path", ctx.url.path, list{"api", "users"})
}

let testMakeContextWithQuery = () => {
  let ctx = ServerRouter.makeContext(
    ~urlString="/search?q=hello&page=2",
    ~method=ServerRouter.GET,
    (),
  )

  assertEq("makeContext query: path", ctx.path, "/search")
  assertSome("makeContext query: has query param", ctx.url->Url.getQueryParam("q"))
}

let testMakeContextWithHeaders = () => {
  let headers = Belt.Map.String.fromArray([("Content-Type", "application/json")])

  let ctx = ServerRouter.makeContext(
    ~urlString="/api/data",
    ~method=ServerRouter.POST,
    ~headers,
    (),
  )

  assertEq("makeContext headers: has header", ctx.headers->Belt.Map.String.get("Content-Type"), Some("application/json"))
}

// ============================================================
// Route Matching Tests
// ============================================================

type apiRoute =
  | GetUsers
  | GetUser(int)
  | CreateUser
  | NotFound

let testMakeServerRoute = () => {
  let usersRoute = ServerRouter.make(
    ~parser=Parser.s("api")->Parser.andThen(Parser.s("users"))->Parser.map(_ => GetUsers),
    ~methods=[ServerRouter.GET],
    ~handler=(_, _) => ServerRouter.Render("users list"),
  )

  let ctx = ServerRouter.makeContext(~urlString="/api/users", ~method=ServerRouter.GET, ())
  let result = ServerRouter.matchRoute(usersRoute, ctx)

  switch result {
  | ServerRouter.Matched(ServerRouter.Render(data)) =>
    assertEq("matchRoute: renders data", data, "users list")
  | _ => Js.Console.error("[FAIL] matchRoute: should match and render")
  }
}

let testMatchRouteWrongMethod = () => {
  let usersRoute = ServerRouter.make(
    ~parser=Parser.s("api")->Parser.andThen(Parser.s("users"))->Parser.map(_ => GetUsers),
    ~methods=[ServerRouter.GET],
    ~handler=(_, _) => ServerRouter.Render("users list"),
  )

  let ctx = ServerRouter.makeContext(~urlString="/api/users", ~method=ServerRouter.POST, ())
  let result = ServerRouter.matchRoute(usersRoute, ctx)

  switch result {
  | ServerRouter.WrongMethod(methods) =>
    assertEq("matchRoute wrong method: allowed methods", methods, [ServerRouter.GET])
  | _ => Js.Console.error("[FAIL] matchRoute wrong method: should return WrongMethod")
  }
}

let testMatchRouteNoMatch = () => {
  let usersRoute = ServerRouter.make(
    ~parser=Parser.s("api")->Parser.andThen(Parser.s("users"))->Parser.map(_ => GetUsers),
    ~methods=[ServerRouter.GET],
    ~handler=(_, _) => ServerRouter.Render("users list"),
  )

  let ctx = ServerRouter.makeContext(~urlString="/api/posts", ~method=ServerRouter.GET, ())
  let result = ServerRouter.matchRoute(usersRoute, ctx)

  switch result {
  | ServerRouter.NoMatch => Js.Console.log("[PASS] matchRoute no match: returns NoMatch")
  | _ => Js.Console.error("[FAIL] matchRoute no match: should return NoMatch")
  }
}

// ============================================================
// Handler Result Tests
// ============================================================

let testHandlerRedirect = () => {
  let loginRoute = ServerRouter.make(
    ~parser=Parser.s("dashboard")->Parser.map(_ => ()),
    ~methods=[ServerRouter.GET],
    ~handler=(_, _) => ServerRouter.Redirect("/login"),
  )

  let ctx = ServerRouter.makeContext(~urlString="/dashboard", ~method=ServerRouter.GET, ())
  let result = ServerRouter.matchRoute(loginRoute, ctx)

  switch result {
  | ServerRouter.Matched(ServerRouter.Redirect(url)) =>
    assertEq("handler redirect: url", url, "/login")
  | _ => Js.Console.error("[FAIL] handler redirect: should redirect")
  }
}

let testHandlerNotFound = () => {
  let maybeRoute = ServerRouter.make(
    ~parser=Parser.s("maybe")->Parser.map(_ => ()),
    ~methods=[ServerRouter.GET],
    ~handler=(_, _) => ServerRouter.NotFound,
  )

  let ctx = ServerRouter.makeContext(~urlString="/maybe", ~method=ServerRouter.GET, ())
  let result = ServerRouter.matchRoute(maybeRoute, ctx)

  switch result {
  | ServerRouter.Matched(ServerRouter.NotFound) =>
    Js.Console.log("[PASS] handler not found: returns NotFound")
  | _ => Js.Console.error("[FAIL] handler not found: should return NotFound")
  }
}

let testHandlerServerError = () => {
  let errorRoute = ServerRouter.make(
    ~parser=Parser.s("error")->Parser.map(_ => ()),
    ~methods=[ServerRouter.GET],
    ~handler=(_, _) => ServerRouter.ServerError("Something went wrong"),
  )

  let ctx = ServerRouter.makeContext(~urlString="/error", ~method=ServerRouter.GET, ())
  let result = ServerRouter.matchRoute(errorRoute, ctx)

  switch result {
  | ServerRouter.Matched(ServerRouter.ServerError(msg)) =>
    assertEq("handler error: message", msg, "Something went wrong")
  | _ => Js.Console.error("[FAIL] handler error: should return ServerError")
  }
}

// ============================================================
// Utility Tests
// ============================================================

let testExtractParams = () => {
  let url = Url.fromString("/api/users/123/posts")
  let params = ServerRouter.extractParams(url)
  assertEq("extractParams: extracts path segments", params, ["api", "users", "123", "posts"])
}

let testRedirectWithQuery = () => {
  let url = Url.fromString("/old-page?utm_source=google&ref=twitter")
  let newUrl = ServerRouter.redirectWithQuery("/new-page", url)
  // Should preserve query params
  assertEq(
    "redirectWithQuery: preserves query",
    Js.String2.includes(newUrl, "utm_source=google"),
    true,
  )
}

// ============================================================
// Run All Tests
// ============================================================

let runTests = () => {
  Js.Console.log("=== ServerRouter Tests ===")

  // HTTP methods
  testMethodFromString()
  testMethodFromStringCaseInsensitive()
  testMethodToString()

  // Request context
  testMakeContext()
  testMakeContextWithQuery()
  testMakeContextWithHeaders()

  // Route matching
  testMakeServerRoute()
  testMatchRouteWrongMethod()
  testMatchRouteNoMatch()

  // Handler results
  testHandlerRedirect()
  testHandlerNotFound()
  testHandlerServerError()

  // Utilities
  testExtractParams()
  testRedirectWithQuery()

  Js.Console.log("=== ServerRouter Tests Complete ===")
}

// Auto-run tests
let _ = runTests()
