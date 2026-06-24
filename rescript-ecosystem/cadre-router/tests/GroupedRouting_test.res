// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// GroupedRouting_test.res - Tests for Parser.oneOfGrouped O(1) dispatch.
//
// Parser.oneOfGrouped pre-groups route parsers by their first literal path
// segment, building an internal Dict for O(1) dispatch on the first segment.
// Within each group, parsers are tried linearly (first-match semantics).
//
// For N routes with K unique first segments, this reduces average complexity
// from O(N) (linear scan in oneOf) to O(N/K). For typical apps where K is
// close to N (each route has a unique prefix), this approaches O(1).
//
// The function also supports a fallback to the empty-string ("") group
// when no group matches the first segment, enabling catch-all or root
// route handling.
//
// These tests verify:
//   1. Exact-match dispatch to the correct group
//   2. First-match semantics within a group (multiple parsers per prefix)
//   3. Empty group fallback for root routes
//   4. No-match behaviour when no group and no fallback match
//   5. Equivalence with oneOf for the same route set
//   6. Edge cases: empty entries, single entry, duplicate prefixes

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

let assertSome = (name: string, actual: option<'a>): unit => {
  switch actual {
  | Some(_) =>
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  | None =>
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name} - expected Some, got None`)
  }
}

let assertNone = (name: string, actual: option<'a>): unit => {
  switch actual {
  | None =>
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  | Some(_) =>
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name} - expected None, got Some`)
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
// Route Type for Testing
// ============================================================================
//
// A representative set of route variants covering different URL shapes:
// root, single-segment, two-segment, parameterised.

type testRoute =
  | Home
  | ApiUsers
  | ApiUser(int)
  | ApiPosts
  | ApiPost(string)
  | AdminDashboard
  | AdminSettings
  | UserProfile(string)
  | NotFound

// ============================================================================
// SECTION 1: Basic Grouped Dispatch
// ============================================================================
//
// Each group key ("api", "admin", "user") maps to one or more parsers.
// The first segment of the URL determines which group is consulted.

let testBasicGroupedDispatch = () => {
  Js.Console.log("\n-- oneOfGrouped: Basic Dispatch --")

  let router = Parser.oneOfGrouped([
    (
      "api",
      Parser.s("api")->Parser.andThen(Parser.s("users"))->Parser.map(_ => ApiUsers),
    ),
    (
      "api",
      Parser.s("api")->Parser.andThen(Parser.s("users"))->Parser.andThen(Parser.int)->Parser.map(
        (((_, _), id)) => ApiUser(id),
      ),
    ),
    (
      "api",
      Parser.s("api")->Parser.andThen(Parser.s("posts"))->Parser.map(_ => ApiPosts),
    ),
    (
      "admin",
      Parser.s("admin")->Parser.andThen(Parser.s("dashboard"))->Parser.map(_ => AdminDashboard),
    ),
    (
      "admin",
      Parser.s("admin")->Parser.andThen(Parser.s("settings"))->Parser.map(_ => AdminSettings),
    ),
    (
      "user",
      Parser.s("user")->Parser.andThen(Parser.str)->Parser.map(((_, name)) => UserProfile(name)),
    ),
  ])

  // API routes dispatch to the "api" group
  assertEq(
    "grouped: /api/users -> ApiUsers",
    Parser.parse(router, Url.fromString("/api/users")),
    Some(ApiUsers),
  )

  assertEq(
    "grouped: /api/posts -> ApiPosts",
    Parser.parse(router, Url.fromString("/api/posts")),
    Some(ApiPosts),
  )

  // Admin routes dispatch to the "admin" group
  assertEq(
    "grouped: /admin/dashboard -> AdminDashboard",
    Parser.parse(router, Url.fromString("/admin/dashboard")),
    Some(AdminDashboard),
  )

  assertEq(
    "grouped: /admin/settings -> AdminSettings",
    Parser.parse(router, Url.fromString("/admin/settings")),
    Some(AdminSettings),
  )

  // User routes dispatch to the "user" group
  assertEq(
    "grouped: /user/alice -> UserProfile",
    Parser.parse(router, Url.fromString("/user/alice")),
    Some(UserProfile("alice")),
  )

  assertEq(
    "grouped: /user/bob -> UserProfile",
    Parser.parse(router, Url.fromString("/user/bob")),
    Some(UserProfile("bob")),
  )
}

// ============================================================================
// SECTION 2: First-Match Semantics Within a Group
// ============================================================================
//
// When multiple parsers share the same group key, they are tried in order.
// The first parser that matches wins (just like oneOf).

let testFirstMatchWithinGroup = () => {
  Js.Console.log("\n-- oneOfGrouped: First-Match Within Group --")

  // Both parsers are in the "api" group. /api/users matches the first parser
  // (which parses /api/users without a trailing ID). The second parser
  // (which requires an ID) should not be reached for /api/users.
  let router = Parser.oneOfGrouped([
    (
      "api",
      Parser.s("api")->Parser.andThen(Parser.s("posts"))->Parser.map(_ => ApiPosts),
    ),
    (
      "api",
      Parser.s("api")->Parser.andThen(Parser.s("posts"))->Parser.andThen(Parser.str)->Parser.map(
        (((_, _), slug)) => ApiPost(slug),
      ),
    ),
  ])

  // /api/posts should match the FIRST parser (ApiPosts)
  assertEq(
    "first-match: /api/posts -> ApiPosts (not ApiPost)",
    Parser.parse(router, Url.fromString("/api/posts")),
    Some(ApiPosts),
  )

  // /api/posts/my-article should match the SECOND parser (ApiPost)
  assertEq(
    "first-match: /api/posts/my-article -> ApiPost",
    Parser.parse(router, Url.fromString("/api/posts/my-article")),
    Some(ApiPost("my-article")),
  )
}

// ============================================================================
// SECTION 3: Empty-String Group Fallback
// ============================================================================
//
// When no group matches the first segment, oneOfGrouped falls back to the
// "" (empty string) group. This enables root route handling and catch-all
// patterns.

let testEmptyGroupFallback = () => {
  Js.Console.log("\n-- oneOfGrouped: Empty-String Group Fallback --")

  let router = Parser.oneOfGrouped([
    (
      "api",
      Parser.s("api")->Parser.andThen(Parser.s("users"))->Parser.map(_ => ApiUsers),
    ),
    (
      "",
      Parser.top->Parser.map(_ => Home),
    ),
  ])

  // API route dispatches normally
  assertEq(
    "fallback: /api/users -> ApiUsers",
    Parser.parse(router, Url.fromString("/api/users")),
    Some(ApiUsers),
  )

  // Root "/" has empty first segment, matches "" group -> Home
  assertEq(
    "fallback: / -> Home (via empty group)",
    Parser.parse(router, Url.fromString("/")),
    Some(Home),
  )
}

let testEmptyGroupFallbackForUnknown = () => {
  Js.Console.log("\n-- oneOfGrouped: Empty Group Fallback for Unknown Prefix --")

  // The "" group is tried when the first segment has no matching group
  let router = Parser.oneOfGrouped([
    (
      "api",
      Parser.s("api")->Parser.andThen(Parser.s("users"))->Parser.map(_ => ApiUsers),
    ),
    (
      "",
      Parser.str->Parser.map(_ => NotFound),
    ),
  ])

  // /api/users dispatches to "api" group
  assertEq(
    "unknown fallback: /api/users -> ApiUsers",
    Parser.parse(router, Url.fromString("/api/users")),
    Some(ApiUsers),
  )

  // /unknown has no "unknown" group -> falls back to "" group
  // The "" group's parser (str -> NotFound) will try to match
  assertEq(
    "unknown fallback: /unknown -> NotFound",
    Parser.parse(router, Url.fromString("/unknown")),
    Some(NotFound),
  )
}

// ============================================================================
// SECTION 4: No Match Behaviour
// ============================================================================
//
// When neither the dispatched group nor the "" fallback group match,
// oneOfGrouped returns None.

let testNoMatchReturnsNone = () => {
  Js.Console.log("\n-- oneOfGrouped: No Match Returns None --")

  let router = Parser.oneOfGrouped([
    (
      "api",
      Parser.s("api")->Parser.andThen(Parser.s("users"))->Parser.map(_ => ApiUsers),
    ),
    (
      "admin",
      Parser.s("admin")->Parser.andThen(Parser.s("dashboard"))->Parser.map(_ => AdminDashboard),
    ),
  ])

  // /unknown has no "unknown" group and no "" fallback
  assertNone(
    "no match: /unknown -> None",
    Parser.parse(router, Url.fromString("/unknown")),
  )

  // /api/unknown is in the "api" group but no parser matches
  assertNone(
    "no match: /api/unknown -> None (group exists but no parser matches)",
    Parser.parse(router, Url.fromString("/api/unknown")),
  )

  // Empty path with no "" group
  assertNone(
    "no match: / -> None (no empty group)",
    Parser.parse(router, Url.fromString("/")),
  )
}

// ============================================================================
// SECTION 5: Edge Cases
// ============================================================================

let testEmptyEntries = () => {
  Js.Console.log("\n-- oneOfGrouped: Empty Entries Array --")

  // An empty entries array should match nothing
  let router: Parser.t<testRoute> = Parser.oneOfGrouped([])

  assertNone(
    "empty entries: / -> None",
    Parser.parse(router, Url.fromString("/")),
  )

  assertNone(
    "empty entries: /anything -> None",
    Parser.parse(router, Url.fromString("/anything")),
  )
}

let testSingleEntry = () => {
  Js.Console.log("\n-- oneOfGrouped: Single Entry --")

  let router = Parser.oneOfGrouped([
    (
      "page",
      Parser.s("page")->Parser.map(_ => Home),
    ),
  ])

  assertEq(
    "single entry: /page -> Home",
    Parser.parse(router, Url.fromString("/page")),
    Some(Home),
  )

  assertNone(
    "single entry: /other -> None",
    Parser.parse(router, Url.fromString("/other")),
  )
}

let testDuplicatePrefixesAccumulate = () => {
  Js.Console.log("\n-- oneOfGrouped: Duplicate Prefixes Accumulate --")

  // Multiple entries with the same key should be accumulated into one group
  let router = Parser.oneOfGrouped([
    ("x", Parser.s("x")->Parser.andThen(Parser.s("a"))->Parser.map(_ => Home)),
    ("x", Parser.s("x")->Parser.andThen(Parser.s("b"))->Parser.map(_ => NotFound)),
  ])

  assertEq(
    "duplicate prefix: /x/a -> Home",
    Parser.parse(router, Url.fromString("/x/a")),
    Some(Home),
  )

  assertEq(
    "duplicate prefix: /x/b -> NotFound",
    Parser.parse(router, Url.fromString("/x/b")),
    Some(NotFound),
  )
}

// ============================================================================
// SECTION 6: Equivalence with oneOf
// ============================================================================
//
// For any route set, oneOfGrouped should produce the same results as oneOf
// (assuming correct group keys). This test verifies behavioural equivalence
// across a representative set of URLs.

let testEquivalenceWithOneOf = () => {
  Js.Console.log("\n-- oneOfGrouped: Equivalence with oneOf --")

  // Define the same routes using both oneOf and oneOfGrouped
  let apiUsersParser = Parser.s("api")->Parser.andThen(Parser.s("users"))->Parser.map(_ => ApiUsers)
  let apiPostsParser = Parser.s("api")->Parser.andThen(Parser.s("posts"))->Parser.map(_ => ApiPosts)
  let adminParser = Parser.s("admin")->Parser.andThen(Parser.s("dashboard"))->Parser.map(_ => AdminDashboard)
  let homeParser = Parser.top->Parser.map(_ => Home)

  // oneOf — linear scan
  let linearRouter = Parser.oneOf([apiUsersParser, apiPostsParser, adminParser, homeParser])

  // oneOfGrouped — O(1) dispatch
  let groupedRouter = Parser.oneOfGrouped([
    ("api", apiUsersParser),
    ("api", apiPostsParser),
    ("admin", adminParser),
    ("", homeParser),
  ])

  // Test URLs that should produce the same result from both routers
  let testUrls = [
    "/",
    "/api/users",
    "/api/posts",
    "/admin/dashboard",
    "/unknown",
    "/api/unknown",
    "/admin/unknown",
  ]

  testUrls->Array.forEach(urlStr => {
    let url = Url.fromString(urlStr)
    let linearResult = Parser.parse(linearRouter, url)
    let groupedResult = Parser.parse(groupedRouter, url)
    assertEq(
      `equivalence: oneOf vs oneOfGrouped for ${urlStr}`,
      groupedResult,
      linearResult,
    )
  })
}

// ============================================================================
// SECTION 7: Parameterised Routes in Groups
// ============================================================================
//
// Verify that parameterised parsers (str, int, uuid) work correctly
// within grouped dispatch.

let testParameterisedRoutesInGroups = () => {
  Js.Console.log("\n-- oneOfGrouped: Parameterised Routes --")

  let router = Parser.oneOfGrouped([
    (
      "user",
      Parser.s("user")->Parser.andThen(Parser.int)->Parser.map(((_, id)) => ApiUser(id)),
    ),
    (
      "user",
      Parser.s("user")->Parser.andThen(Parser.str)->Parser.map(((_, name)) => UserProfile(name)),
    ),
  ])

  // Integer parameter matches first parser
  assertEq(
    "parameterised: /user/42 -> ApiUser(42)",
    Parser.parse(router, Url.fromString("/user/42")),
    Some(ApiUser(42)),
  )

  // Non-integer parameter falls through to second parser
  assertEq(
    "parameterised: /user/alice -> UserProfile",
    Parser.parse(router, Url.fromString("/user/alice")),
    Some(UserProfile("alice")),
  )

  // No parameter — neither parser matches
  assertNone(
    "parameterised: /user -> None",
    Parser.parse(router, Url.fromString("/user")),
  )
}

// ============================================================================
// SECTION 8: Query Parameters with Grouped Routes
// ============================================================================
//
// Query parameters do not affect group dispatch (which is based on path
// segments only), but they should be available to parsers within the group.

let testQueryParamsWithGroupedRoutes = () => {
  Js.Console.log("\n-- oneOfGrouped: Query Parameters --")

  type searchRoute = Search(string, option<int>)

  let router = Parser.oneOfGrouped([
    (
      "search",
      Parser.s("search")
      ->Parser.andThen(Parser.queryRequired("q"))
      ->Parser.andThen(Parser.queryInt("page"))
      ->Parser.map((((_, q), p)) => Search(q, p)),
    ),
  ])

  // Query params should be parsed correctly within the grouped dispatch
  assertEq(
    "query+grouped: /search?q=hello&page=2",
    Parser.parse(router, Url.fromString("/search?q=hello&page=2")),
    Some(Search("hello", Some(2))),
  )

  assertEq(
    "query+grouped: /search?q=world",
    Parser.parse(router, Url.fromString("/search?q=world")),
    Some(Search("world", None)),
  )

  // Missing required query param -> parse fails
  assertNone(
    "query+grouped: /search without q -> None",
    Parser.parse(router, Url.fromString("/search")),
  )
}

// ============================================================================
// Run All Tests
// ============================================================================

let runAll = () => {
  Js.Console.log("\n========================================")
  Js.Console.log("  GROUPED ROUTING (oneOfGrouped) TESTS")
  Js.Console.log("========================================")

  passed := 0
  failed := 0

  // Basic dispatch
  testBasicGroupedDispatch()

  // First-match semantics
  testFirstMatchWithinGroup()

  // Empty-string group fallback
  testEmptyGroupFallback()
  testEmptyGroupFallbackForUnknown()

  // No match
  testNoMatchReturnsNone()

  // Edge cases
  testEmptyEntries()
  testSingleEntry()
  testDuplicatePrefixesAccumulate()

  // Equivalence
  testEquivalenceWithOneOf()

  // Parameterised routes
  testParameterisedRoutesInGroups()

  // Query parameters
  testQueryParamsWithGroupedRoutes()

  summary()

  Js.Console.log("\n========================================")
  Js.Console.log("  GROUPED ROUTING TESTS COMPLETE")
  Js.Console.log("========================================\n")
}

// Auto-run
let _ = runAll()
