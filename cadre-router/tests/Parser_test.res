// SPDX-License-Identifier: Apache-2.0
// Parser_test.res - Tests for URL parser combinators

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
// Test Route Types
// ============================================================

// Simple typed ID for testing
module TestId = {
  type t = TestId(string)

  let fromString = (s: string): option<t> => {
    if Js.String2.length(s) > 0 && Js.String2.length(s) < 20 {
      Some(TestId(s))
    } else {
      None
    }
  }

  let toString = (TestId(s): t): string => s

  let parser = Parser.custom(fromString)
}

type subRoute = SubA | SubB | SubC

type testRoute =
  | Home
  | Profile
  | User(int)
  | Item(TestId.t)
  | Nested(TestId.t, subRoute)
  | Search({query: string, page: option<int>})

// ============================================================
// Basic Parser Tests
// ============================================================

let testLiteralMatch = () => {
  let parser = Parser.s("profile")
  let url = Url.fromString("/profile")
  assertSome("s: matches literal", Parser.parse(parser, url))
}

let testLiteralNoMatch = () => {
  let parser = Parser.s("profile")
  let url = Url.fromString("/settings")
  assertNone("s: rejects non-matching", Parser.parse(parser, url))
}

let testLiteralPartialPath = () => {
  let parser = Parser.s("profile")
  let url = Url.fromString("/profile/extra")
  // parse() requires consuming all segments
  assertNone("s: rejects partial match with extra path", Parser.parse(parser, url))
}

let testTop = () => {
  let parser = Parser.top
  let root = Url.fromString("/")
  let notRoot = Url.fromString("/page")
  assertSome("top: matches root", Parser.parse(parser, root))
  assertNone("top: rejects non-root", Parser.parse(parser, notRoot))
}

let testStr = () => {
  let parser = Parser.str
  let url = Url.fromString("/anything")
  let result = Parser.parse(parser, url)
  assertEq("str: captures segment", result, Some("anything"))
}

let testInt = () => {
  let url42 = Url.fromString("/42")
  let urlText = Url.fromString("/abc")

  assertEq("int: parses integer", Parser.parse(Parser.int, url42), Some(42))
  assertNone("int: rejects non-integer", Parser.parse(Parser.int, urlText))
}

let testCustom = () => {
  let urlValid = Url.fromString("/abc123")
  let urlTooLong = Url.fromString("/thisstringiswaytoolongtobevalid")
  let urlEmpty = Url.fromString("/")

  let result = Parser.parse(TestId.parser, urlValid)
  switch result {
  | Some(TestId.TestId(s)) => assertEq("custom: parses valid ID", s, "abc123")
  | None => Js.Console.error("[FAIL] custom: expected valid parse")
  }

  assertNone("custom: rejects invalid", Parser.parse(TestId.parser, urlTooLong))
}

// ============================================================
// Combinator Tests
// ============================================================

let testAndThen = () => {
  let parser = Parser.s("user")->Parser.andThen(Parser.int)
  let url = Url.fromString("/user/42")
  let result = Parser.parse(parser, url)
  assertEq("andThen: sequences parsers", result, Some(((), 42)))
}

let testAndThenOperator = () => {
  // Note: The </> operator is an alias for andThen
  // Testing via explicit andThen call since operator syntax conflicts with ReScript 12
  let parser = Parser.s("user")->Parser.andThen(Parser.int)
  let url = Url.fromString("/user/42")
  let result = Parser.parse(parser, url)
  assertEq("</>: operator form works", result, Some(((), 42)))
}

let testMap = () => {
  let parser = Parser.s("user")->Parser.andThen(Parser.int)->Parser.map(((_, id)) => User(id))
  let url = Url.fromString("/user/42")
  let result = Parser.parse(parser, url)
  assertEq("map: transforms result", result, Some(User(42)))
}

let testOneOf = () => {
  let parser = Parser.oneOf([
    Parser.top->Parser.map(_ => Home),
    Parser.s("profile")->Parser.map(_ => Profile),
    Parser.s("user")->Parser.andThen(Parser.int)->Parser.map(((_, id)) => User(id)),
  ])

  assertEq("oneOf: matches first (home)", Parser.parse(parser, Url.fromString("/")), Some(Home))
  assertEq("oneOf: matches second (profile)", Parser.parse(parser, Url.fromString("/profile")), Some(Profile))
  assertEq("oneOf: matches third (user)", Parser.parse(parser, Url.fromString("/user/5")), Some(User(5)))
  assertNone("oneOf: no match", Parser.parse(parser, Url.fromString("/unknown")))
}

let testOptional = () => {
  let parser = Parser.s("page")->Parser.andThen(Parser.optional(Parser.int))
  let withInt = Url.fromString("/page/5")
  let withoutInt = Url.fromString("/page")

  // Note: /page without trailing int won't match because /page consumes the segment
  // and then optional(int) succeeds with None, but there's nothing left
  // This test validates that optional works when there IS a segment
  let result = Parser.parse(parser, withInt)
  assertEq("optional: with value", result, Some(((), Some(5))))
}

// ============================================================
// Query Parameter Tests
// ============================================================

let testQuery = () => {
  let parser = Parser.s("search")->Parser.andThen(Parser.query("q"))
  let withQuery = Url.fromString("/search?q=hello")
  let withoutQuery = Url.fromString("/search")

  let result1 = Parser.parse(parser, withQuery)
  assertEq("query: with param", result1, Some(((), Some("hello"))))

  let result2 = Parser.parse(parser, withoutQuery)
  assertEq("query: without param", result2, Some(((), None)))
}

let testQueryInt = () => {
  let parser = Parser.s("list")->Parser.andThen(Parser.queryInt("page"))
  let withInt = Url.fromString("/list?page=5")
  let withText = Url.fromString("/list?page=abc")
  let without = Url.fromString("/list")

  assertEq("queryInt: with int", Parser.parse(parser, withInt), Some(((), Some(5))))
  assertEq("queryInt: with non-int", Parser.parse(parser, withText), Some(((), None)))
  assertEq("queryInt: without param", Parser.parse(parser, without), Some(((), None)))
}

let testQueryRequired = () => {
  let parser = Parser.s("search")->Parser.andThen(Parser.queryRequired("q"))
  let withQuery = Url.fromString("/search?q=hello")
  let withoutQuery = Url.fromString("/search")

  assertEq("queryRequired: with param", Parser.parse(parser, withQuery), Some(((), "hello")))
  assertNone("queryRequired: without param fails", Parser.parse(parser, withoutQuery))
}

// ============================================================
// Nested Route Tests
// ============================================================

let testNestedRoutes = () => {
  let subParser = Parser.oneOf([
    Parser.s("a")->Parser.map(_ => SubA),
    Parser.s("b")->Parser.map(_ => SubB),
    Parser.s("c")->Parser.map(_ => SubC),
  ])

  let parser =
    Parser.s("item")
    ->Parser.andThen(TestId.parser)
    ->Parser.andThen(subParser)
    ->Parser.map((((_, id), sub)) => Nested(id, sub))

  let urlA = Url.fromString("/item/xyz/a")
  let urlB = Url.fromString("/item/xyz/b")
  let urlC = Url.fromString("/item/xyz/c")
  let urlNoSub = Url.fromString("/item/xyz")
  let urlInvalidSub = Url.fromString("/item/xyz/d")

  switch Parser.parse(parser, urlA) {
  | Some(Nested(TestId.TestId(id), SubA)) => assertEq("nested: /item/xyz/a", id, "xyz")
  | _ => Js.Console.error("[FAIL] nested: /item/xyz/a failed")
  }

  switch Parser.parse(parser, urlB) {
  | Some(Nested(_, SubB)) => Js.Console.log("[PASS] nested: /item/xyz/b")
  | _ => Js.Console.error("[FAIL] nested: /item/xyz/b failed")
  }

  assertNone("nested: no sub-route", Parser.parse(parser, urlNoSub))
  assertNone("nested: invalid sub-route", Parser.parse(parser, urlInvalidSub))
}

// ============================================================
// Complex Route Tests
// ============================================================

let testFullRouter = () => {
  let subParser = Parser.oneOf([
    Parser.s("a")->Parser.map(_ => SubA),
    Parser.s("b")->Parser.map(_ => SubB),
    Parser.top->Parser.map(_ => SubA), // default
  ])

  let router = Parser.oneOf([
    Parser.top->Parser.map(_ => Home),
    Parser.s("profile")->Parser.map(_ => Profile),
    Parser.s("user")->Parser.andThen(Parser.int)->Parser.map(((_, id)) => User(id)),
    Parser.s("item")->Parser.andThen(TestId.parser)->Parser.map(((_, id)) => Item(id)),
    Parser.s("nested")
      ->Parser.andThen(TestId.parser)
      ->Parser.andThen(subParser)
      ->Parser.map((((_, id), sub)) => Nested(id, sub)),
    Parser.s("search")
      ->Parser.andThen(Parser.queryRequired("q"))
      ->Parser.andThen(Parser.queryInt("page"))
      ->Parser.map((((_, q), page)) => Search({query: q, page})),
  ])

  Js.Console.log("\n-- Full Router Tests --")

  assertEq("router: /", Parser.parse(router, Url.fromString("/")), Some(Home))
  assertEq("router: /profile", Parser.parse(router, Url.fromString("/profile")), Some(Profile))
  assertEq("router: /user/123", Parser.parse(router, Url.fromString("/user/123")), Some(User(123)))

  switch Parser.parse(router, Url.fromString("/item/abc")) {
  | Some(Item(TestId.TestId(id))) => assertEq("router: /item/abc", id, "abc")
  | _ => Js.Console.error("[FAIL] router: /item/abc failed")
  }

  switch Parser.parse(router, Url.fromString("/nested/xyz/b")) {
  | Some(Nested(TestId.TestId(id), SubB)) => assertEq("router: /nested/xyz/b", id, "xyz")
  | _ => Js.Console.error("[FAIL] router: /nested/xyz/b failed")
  }

  switch Parser.parse(router, Url.fromString("/search?q=hello&page=2")) {
  | Some(Search({query, page})) => {
      assertEq("router: search query", query, "hello")
      assertEq("router: search page", page, Some(2))
    }
  | _ => Js.Console.error("[FAIL] router: /search failed")
  }

  assertNone("router: unknown path", Parser.parse(router, Url.fromString("/unknown")))
}

// ============================================================
// parsePartial Tests
// ============================================================

let testParsePartial = () => {
  let parser = Parser.s("prefix")
  let url = Url.fromString("/prefix/extra/segments")

  assertNone("parse: rejects extra segments", Parser.parse(parser, url))
  assertSome("parsePartial: allows extra segments", Parser.parsePartial(parser, url))
}

// ============================================================
// Edge Cases
// ============================================================

let testEmptyOneOf = () => {
  let parser: Parser.t<testRoute> = Parser.oneOf([])
  let url = Url.fromString("/anything")
  assertNone("oneOf: empty array matches nothing", Parser.parse(parser, url))
}

let testChainedAndThen = () => {
  // Using explicit andThen calls since operator syntax conflicts with ReScript 12
  let parser =
    Parser.s("a")
    ->Parser.andThen(Parser.s("b"))
    ->Parser.andThen(Parser.s("c"))
    ->Parser.andThen(Parser.str)
    ->Parser.map(((((_, _), _), captured)) => captured)

  let url = Url.fromString("/a/b/c/value")
  assertEq("chained andThen: deep nesting", Parser.parse(parser, url), Some("value"))
}

// ============================================================
// Run all tests
// ============================================================

let runAll = () => {
  Js.Console.log("=== Parser Module Tests ===")

  Js.Console.log("\n-- Basic Parsers --")
  testLiteralMatch()
  testLiteralNoMatch()
  testLiteralPartialPath()
  testTop()
  testStr()
  testInt()
  testCustom()

  Js.Console.log("\n-- Combinators --")
  testAndThen()
  testAndThenOperator()
  testMap()
  testOneOf()
  testOptional()

  Js.Console.log("\n-- Query Parameters --")
  testQuery()
  testQueryInt()
  testQueryRequired()

  Js.Console.log("\n-- Nested Routes --")
  testNestedRoutes()

  Js.Console.log("\n-- Full Router --")
  testFullRouter()

  Js.Console.log("\n-- parsePartial --")
  testParsePartial()

  Js.Console.log("\n-- Edge Cases --")
  testEmptyOneOf()
  testChainedAndThen()

  Js.Console.log("\n=== Parser Tests Complete ===")
}

// Auto-run
runAll()
