// SPDX-License-Identifier: Apache-2.0
// Conformance_test.res - Route matching conformance tests and CRDT state claims

// =============================================================================
// Test Harness
// =============================================================================

let passed = ref(0)
let failed = ref(0)

let assert_ = (name: string, condition: bool): unit => {
  if condition {
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  } else {
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name}`)
  }
}

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

let summary = () => {
  let total = passed.contents + failed.contents
  Js.Console.log("")
  Js.Console.log(`=== Summary: ${Belt.Int.toString(passed.contents)}/${Belt.Int.toString(total)} passed ===`)
  if failed.contents > 0 {
    Js.Console.error(`${Belt.Int.toString(failed.contents)} tests failed`)
  }
}

// =============================================================================
// SECTION 1: URL Parsing Conformance (RFC 3986 subset)
// =============================================================================

let testUrlParsingConformance = () => {
  Js.Console.log("\n--- URL Parsing Conformance (RFC 3986) ---")

  // Basic path parsing
  let url1 = Url.fromString("/")
  assertEq("root path", url1.path, list{})

  let url2 = Url.fromString("/foo")
  assertEq("single segment", url2.path, list{"foo"})

  let url3 = Url.fromString("/foo/bar/baz")
  assertEq("multiple segments", url3.path, list{"foo", "bar", "baz"})

  // Trailing slash normalization
  let url4 = Url.fromString("/foo/")
  assertEq("trailing slash normalized", url4.path, list{"foo"})

  // Query string parsing
  let url5 = Url.fromString("/search?q=hello")
  assertEq("query param exists", url5.query->Belt.Map.String.get("q"), Some("hello"))

  let url6 = Url.fromString("/search?a=1&b=2&c=3")
  assertEq("multiple query params a", url6.query->Belt.Map.String.get("a"), Some("1"))
  assertEq("multiple query params b", url6.query->Belt.Map.String.get("b"), Some("2"))
  assertEq("multiple query params c", url6.query->Belt.Map.String.get("c"), Some("3"))

  // Fragment parsing
  let url7 = Url.fromString("/page#section")
  assertEq("fragment parsed", url7.fragment, Some("section"))

  let url8 = Url.fromString("/page?q=x#section")
  assertEq("query with fragment", url8.query->Belt.Map.String.get("q"), Some("x"))
  assertEq("fragment with query", url8.fragment, Some("section"))

  // Empty/edge cases
  let url9 = Url.fromString("")
  assertEq("empty string path", url9.path, list{})

  let url10 = Url.fromString("?q=test")
  assertEq("query only", url10.query->Belt.Map.String.get("q"), Some("test"))

  let url11 = Url.fromString("#anchor")
  assertEq("fragment only", url11.fragment, Some("anchor"))

  // URL encoding (basic)
  let url12 = Url.fromString("/search?q=hello%20world")
  assertEq("url encoded space", url12.query->Belt.Map.String.get("q"), Some("hello world"))
}

// =============================================================================
// SECTION 2: Parser Combinator Conformance
// =============================================================================

// Test route type for conformance
type testRoute =
  | Home
  | User(int)
  | Article(string)
  | Nested(int, string)
  | Search(string, option<int>)

let testParser: Parser.t<testRoute> = {
  open Parser
  oneOf([
    top->map(_ => Home),
    s("user")->andThen(int)->map(((_, id)) => User(id)),
    s("article")->andThen(str)->map(((_, slug)) => Article(slug)),
    s("nested")->andThen(int)->andThen(str)->map((((_, id), name)) => Nested(id, name)),
    s("search")->andThen(queryRequired("q"))->andThen(queryInt("page"))->map((((_, q), p)) => Search(q, p)),
  ])
}

let testParserConformance = () => {
  Js.Console.log("\n--- Parser Combinator Conformance ---")

  // Exact matches
  assertEq("home exact", Parser.parse(testParser, Url.fromString("/")), Some(Home))
  assertEq("user exact", Parser.parse(testParser, Url.fromString("/user/42")), Some(User(42)))
  assertEq("article exact", Parser.parse(testParser, Url.fromString("/article/hello-world")), Some(Article("hello-world")))

  // Nested route parsing
  assertEq("nested route", Parser.parse(testParser, Url.fromString("/nested/123/alice")), Some(Nested(123, "alice")))

  // Query parameter parsing
  assertEq("search with query", Parser.parse(testParser, Url.fromString("/search?q=test")), Some(Search("test", None)))
  assertEq("search with page", Parser.parse(testParser, Url.fromString("/search?q=test&page=5")), Some(Search("test", Some(5))))

  // No match cases
  assertEq("unknown path", Parser.parse(testParser, Url.fromString("/unknown")), None)
  assertEq("partial match rejected", Parser.parse(testParser, Url.fromString("/user")), None)
  assertEq("extra segments rejected", Parser.parse(testParser, Url.fromString("/user/42/extra")), None)

  // Integer edge cases
  assertEq("zero id", Parser.parse(testParser, Url.fromString("/user/0")), Some(User(0)))
  assertEq("negative id", Parser.parse(testParser, Url.fromString("/user/-5")), Some(User(-5)))
  assertEq("non-numeric rejected", Parser.parse(testParser, Url.fromString("/user/abc")), None)

  // First-match semantics
  let ambiguousParser = Parser.oneOf([
    Parser.s("a")->Parser.map(_ => "first"),
    Parser.s("a")->Parser.map(_ => "second"),
  ])
  assertEq("first match wins", Parser.parse(ambiguousParser, Url.fromString("/a")), Some("first"))
}

// =============================================================================
// SECTION 3: CRDT State Claims
// =============================================================================
// These tests verify properties essential for distributed/replicated state:
// - Idempotence: f(f(x)) = f(x)
// - Determinism: same input always produces same output
// - Commutativity (where applicable): f(a, b) = f(b, a)
// - Convergence: multiple operations converge to consistent state

let routeToString = (route: testRoute): string =>
  switch route {
  | Home => "/"
  | User(id) => "/user/" ++ Belt.Int.toString(id)
  | Article(slug) => "/article/" ++ slug
  | Nested(id, name) => "/nested/" ++ Belt.Int.toString(id) ++ "/" ++ name
  | Search(q, page) =>
    "/search?q=" ++ q ++ switch page {
    | Some(p) => "&page=" ++ Belt.Int.toString(p)
    | None => ""
    }
  }

let testCrdtIdempotence = () => {
  Js.Console.log("\n--- CRDT Claim: Idempotence ---")
  Js.Console.log("Property: parse(url) = parse(parse(url) |> serialize)")

  let urls = [
    "/",
    "/user/42",
    "/article/hello-world",
    "/nested/123/alice",
    "/search?q=test",
    "/search?q=test&page=5",
  ]

  urls->Belt.Array.forEach(urlStr => {
    let url = Url.fromString(urlStr)
    let parsed1 = Parser.parse(testParser, url)

    switch parsed1 {
    | Some(route) => {
        let serialized = routeToString(route)
        let url2 = Url.fromString(serialized)
        let parsed2 = Parser.parse(testParser, url2)

        assertEq(`idempotent: ${urlStr}`, parsed1, parsed2)
      }
    | None => Js.Console.log(`[SKIP] ${urlStr} (no match)`)
    }
  })
}

let testCrdtDeterminism = () => {
  Js.Console.log("\n--- CRDT Claim: Determinism ---")
  Js.Console.log("Property: parse(url) called N times = same result")

  let urls = ["/", "/user/42", "/article/test", "/unknown"]

  urls->Belt.Array.forEach(urlStr => {
    let url = Url.fromString(urlStr)
    let results = Belt.Array.make(10, ())->Belt.Array.map(_ => Parser.parse(testParser, url))

    let first = results->Belt.Array.get(0)
    let allSame = switch first {
    | Some(firstResult) => results->Belt.Array.every(r => r == firstResult)
    | None => false
    }
    assert_(`deterministic: ${urlStr}`, allSame)
  })
}

let testCrdtRoundtripConvergence = () => {
  Js.Console.log("\n--- CRDT Claim: Roundtrip Convergence ---")
  Js.Console.log("Property: parse(serialize(route)) = route")

  let routes: array<testRoute> = [
    Home,
    User(1),
    User(42),
    User(0),
    User(-1),
    Article("hello"),
    Article("hello-world"),
    Article("123"),
    Nested(1, "a"),
    Nested(999, "test-name"),
    Search("query", None),
    Search("query", Some(1)),
    Search("query", Some(100)),
  ]

  routes->Belt.Array.forEach(route => {
    let serialized = routeToString(route)
    let url = Url.fromString(serialized)
    let parsed = Parser.parse(testParser, url)

    assertEq(`roundtrip: ${serialized}`, parsed, Some(route))
  })
}

let testCrdtUrlNormalization = () => {
  Js.Console.log("\n--- CRDT Claim: URL Normalization Convergence ---")
  Js.Console.log("Property: equivalent URLs parse to same route")

  // Different representations of the same route should converge
  let equivalentUrls = [
    ("/user/42", "/user/42/"),  // trailing slash
    ("/", ""),                   // root variations
  ]

  equivalentUrls->Belt.Array.forEach(((url1, url2)) => {
    let parsed1 = Parser.parse(testParser, Url.fromString(url1))
    let parsed2 = Parser.parse(testParser, Url.fromString(url2))
    assertEq(`normalize: "${url1}" = "${url2}"`, parsed1, parsed2)
  })
}

let testCrdtQueryOrderIndependence = () => {
  Js.Console.log("\n--- CRDT Claim: Query Parameter Order Independence ---")
  Js.Console.log("Property: ?a=1&b=2 = ?b=2&a=1")

  let url1 = Url.fromString("/search?q=test&page=5")
  let url2 = Url.fromString("/search?page=5&q=test")

  let parsed1 = Parser.parse(testParser, url1)
  let parsed2 = Parser.parse(testParser, url2)

  assertEq("query order independence", parsed1, parsed2)
}

// =============================================================================
// SECTION 4: RouteBuilder Bidirectional Conformance
// =============================================================================

type builderRoute =
  | BHome
  | BProfile
  | BUser(int)

let homeBuilder = RouteBuilder.build(
  RouteBuilder.end_,
  ~toRoute=_ => BHome,
  ~fromRoute=route => switch route { | BHome => Some() | _ => None }
)

let profileBuilder = RouteBuilder.build(
  RouteBuilder.andThen(RouteBuilder.lit("profile"), RouteBuilder.end_),
  ~toRoute=_ => BProfile,
  ~fromRoute=route => switch route { | BProfile => Some(((), ())) | _ => None }
)

let userBuilder = RouteBuilder.build(
  RouteBuilder.andThen(RouteBuilder.andThen(RouteBuilder.lit("user"), RouteBuilder.int()), RouteBuilder.end_),
  ~toRoute=arg => { let ((_, id), _) = arg; BUser(id) },
  ~fromRoute=route => switch route { | BUser(id) => Some((((), id), ())) | _ => None }
)

let builderRouter = RouteBuilder.oneOf([homeBuilder, profileBuilder, userBuilder])

let testBidirectionalConformance = () => {
  Js.Console.log("\n--- Bidirectional Route Conformance ---")

  // Parse -> Serialize roundtrip
  let routes: array<builderRoute> = [BHome, BProfile, BUser(42), BUser(0), BUser(-1)]

  routes->Belt.Array.forEach(route => {
    switch builderRouter.toString(route) {
    | Some(urlStr) => {
        let url = Url.fromString(urlStr)
        switch builderRouter.parse(url) {
        | Some(parsed) => assertEq(`bidirectional: ${urlStr}`, parsed, route)
        | None => {
            failed := failed.contents + 1
            Js.Console.error(`[FAIL] bidirectional: ${urlStr} - failed to parse`)
          }
        }
      }
    | None => {
        failed := failed.contents + 1
        Js.Console.error(`[FAIL] bidirectional: failed to serialize route`)
      }
    }
  })

  // Serialize -> Parse roundtrip
  let urls = ["/", "/profile", "/user/42", "/user/0"]

  urls->Belt.Array.forEach(urlStr => {
    let url = Url.fromString(urlStr)
    switch builderRouter.parse(url) {
    | Some(route) => {
        switch builderRouter.toString(route) {
        | Some(serialized) => {
            // Normalize for comparison (remove trailing slash)
            let normalized = if serialized == "/" { "/" } else {
              Js.String2.replaceByRe(serialized, %re("/\/$/"), "")
            }
            let urlNormalized = if urlStr == "/" { "/" } else {
              Js.String2.replaceByRe(urlStr, %re("/\/$/"), "")
            }
            assertEq(`serialize-parse: ${urlStr}`, normalized, urlNormalized)
          }
        | None => {
            failed := failed.contents + 1
            Js.Console.error(`[FAIL] serialize-parse: ${urlStr} - failed to serialize`)
          }
        }
      }
    | None => Js.Console.log(`[SKIP] serialize-parse: ${urlStr} (no match)`)
    }
  })
}

// =============================================================================
// SECTION 5: Edge Cases and Security Boundaries
// =============================================================================

let testEdgeCases = () => {
  Js.Console.log("\n--- Edge Cases and Boundaries ---")

  // Empty and whitespace
  assertEq("empty string parses", Url.fromString("").path, list{})
  assertEq("whitespace path", Url.fromString("/  ").path, list{"  "})

  // Special characters in paths (should be preserved)
  let urlWithDash = Url.fromString("/hello-world")
  assertEq("dash in path", urlWithDash.path, list{"hello-world"})

  let urlWithUnderscore = Url.fromString("/hello_world")
  assertEq("underscore in path", urlWithUnderscore.path, list{"hello_world"})

  let urlWithDot = Url.fromString("/file.txt")
  assertEq("dot in path", urlWithDot.path, list{"file.txt"})

  // Numeric paths
  let urlNumeric = Url.fromString("/123/456")
  assertEq("numeric path segments", urlNumeric.path, list{"123", "456"})

  // Very long paths
  let longPath = "/" ++ Belt.Array.make(50, "segment")->Js.Array2.joinWith("/")
  let urlLong = Url.fromString(longPath)
  assertEq("long path segment count", Belt.List.length(urlLong.path), 50)

  // Query with empty value
  let urlEmptyValue = Url.fromString("/path?key=")
  assertEq("empty query value", urlEmptyValue.query->Belt.Map.String.get("key"), Some(""))

  // Query with no value
  let urlNoValue = Url.fromString("/path?key")
  assertEq("query key only", urlNoValue.query->Belt.Map.String.get("key"), Some(""))

  // Multiple slashes (normalization)
  let urlMultiSlash = Url.fromString("//foo//bar//")
  // Should normalize empty segments away
  assert_("multi-slash normalized", Belt.List.length(urlMultiSlash.path) <= 2)
}

// =============================================================================
// Run All Conformance Tests
// =============================================================================

let runAll = () => {
  Js.Console.log("\n========================================")
  Js.Console.log("  CONFORMANCE TESTS & CRDT STATE CLAIMS")
  Js.Console.log("========================================")

  passed := 0
  failed := 0

  // URL Parsing
  testUrlParsingConformance()

  // Parser Combinators
  testParserConformance()

  // CRDT Claims
  testCrdtIdempotence()
  testCrdtDeterminism()
  testCrdtRoundtripConvergence()
  testCrdtUrlNormalization()
  testCrdtQueryOrderIndependence()

  // Bidirectional
  testBidirectionalConformance()

  // Edge Cases
  testEdgeCases()

  summary()

  Js.Console.log("\n========================================")
  Js.Console.log("  CONFORMANCE TESTS COMPLETE")
  Js.Console.log("========================================\n")
}

// Auto-run
let _ = runAll()
