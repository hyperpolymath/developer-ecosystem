// SPDX-License-Identifier: Apache-2.0
// Url_test.res - Tests for URL parsing and serialization

// Simple test harness (no external dependencies)
let assertEq = (name: string, actual: 'a, expected: 'a): unit => {
  if actual == expected {
    Js.Console.log(`[PASS] ${name}`)
  } else {
    Js.Console.error(`[FAIL] ${name}`)
    Js.Console.error(`  Expected: ${Js.Json.stringifyAny(expected)->Belt.Option.getWithDefault("?")}`)
    Js.Console.error(`  Actual:   ${Js.Json.stringifyAny(actual)->Belt.Option.getWithDefault("?")}`)
  }
}

let assertTrue = (name: string, condition: bool): unit => {
  if condition {
    Js.Console.log(`[PASS] ${name}`)
  } else {
    Js.Console.error(`[FAIL] ${name}`)
  }
}

// ============================================================
// fromString tests
// ============================================================

let testFromStringSimplePath = () => {
  let url = Url.fromString("/profile")
  assertEq("fromString: simple path", url.path, list{"profile"})
  assertEq("fromString: simple path - no query", Belt.Map.String.isEmpty(url.query), true)
  assertEq("fromString: simple path - no fragment", url.fragment, None)
}

let testFromStringRoot = () => {
  let url = Url.fromString("/")
  assertEq("fromString: root path is empty list", url.path, list{})
}

let testFromStringNestedPath = () => {
  let url = Url.fromString("/journey/abc123/map")
  assertEq("fromString: nested path", url.path, list{"journey", "abc123", "map"})
}

let testFromStringWithQuery = () => {
  let url = Url.fromString("/search?q=hello&page=2")
  assertEq("fromString: path with query", url.path, list{"search"})
  assertEq("fromString: query param q", url.query->Belt.Map.String.get("q"), Some("hello"))
  assertEq("fromString: query param page", url.query->Belt.Map.String.get("page"), Some("2"))
}

let testFromStringWithFragment = () => {
  let url = Url.fromString("/docs#section-1")
  assertEq("fromString: path with fragment", url.path, list{"docs"})
  assertEq("fromString: fragment", url.fragment, Some("section-1"))
}

let testFromStringWithQueryAndFragment = () => {
  let url = Url.fromString("/page?tab=settings#advanced")
  assertEq("fromString: full URL - path", url.path, list{"page"})
  assertEq("fromString: full URL - query", url.query->Belt.Map.String.get("tab"), Some("settings"))
  assertEq("fromString: full URL - fragment", url.fragment, Some("advanced"))
}

let testFromStringEncodedQuery = () => {
  let url = Url.fromString("/search?q=hello%20world")
  assertEq("fromString: URL-decoded query", url.query->Belt.Map.String.get("q"), Some("hello world"))
}

let testFromStringEmptyQueryValue = () => {
  let url = Url.fromString("/page?flag")
  assertEq("fromString: empty query value", url.query->Belt.Map.String.get("flag"), Some(""))
}

// ============================================================
// toString tests
// ============================================================

let testToStringSimple = () => {
  let url: Url.t = {
    path: list{"profile"},
    query: Belt.Map.String.empty,
    fragment: None,
  }
  assertEq("toString: simple path", Url.toString(url), "/profile")
}

let testToStringRoot = () => {
  let url: Url.t = {
    path: list{},
    query: Belt.Map.String.empty,
    fragment: None,
  }
  assertEq("toString: root", Url.toString(url), "/")
}

let testToStringWithQuery = () => {
  let url: Url.t = {
    path: list{"search"},
    query: Belt.Map.String.fromArray([("q", "hello"), ("page", "2")]),
    fragment: None,
  }
  let result = Url.toString(url)
  // Query params order may vary, so check contains
  assertTrue("toString: has path", Js.String2.startsWith(result, "/search?"))
  assertTrue("toString: has q param", Js.String2.includes(result, "q=hello"))
  assertTrue("toString: has page param", Js.String2.includes(result, "page=2"))
}

let testToStringWithFragment = () => {
  let url: Url.t = {
    path: list{"docs"},
    query: Belt.Map.String.empty,
    fragment: Some("section"),
  }
  assertEq("toString: with fragment", Url.toString(url), "/docs#section")
}

let testToStringEncodesSpecialChars = () => {
  let url: Url.t = {
    path: list{"search"},
    query: Belt.Map.String.fromArray([("q", "hello world")]),
    fragment: None,
  }
  let result = Url.toString(url)
  assertTrue("toString: encodes spaces", Js.String2.includes(result, "hello%20world"))
}

// ============================================================
// pathToString tests
// ============================================================

let testPathToString = () => {
  let url: Url.t = {
    path: list{"journey", "abc", "map"},
    query: Belt.Map.String.fromArray([("tab", "settings")]),
    fragment: Some("top"),
  }
  assertEq("pathToString: excludes query and fragment", Url.pathToString(url), "/journey/abc/map")
}

// ============================================================
// Query helper tests
// ============================================================

let testGetQueryParam = () => {
  let url = Url.fromString("/page?name=value&other=123")
  assertEq("getQueryParam: existing", Url.getQueryParam(url, "name"), Some("value"))
  assertEq("getQueryParam: missing", Url.getQueryParam(url, "missing"), None)
}

let testGetQueryParamInt = () => {
  let url = Url.fromString("/page?count=42&name=text")
  assertEq("getQueryParamInt: valid int", Url.getQueryParamInt(url, "count"), Some(42))
  assertEq("getQueryParamInt: not an int", Url.getQueryParamInt(url, "name"), None)
  assertEq("getQueryParamInt: missing", Url.getQueryParamInt(url, "missing"), None)
}

let testGetQueryParamBool = () => {
  let url = Url.fromString("/page?enabled=true&disabled=false&flag=1&off=0&other=maybe")
  assertEq("getQueryParamBool: true", Url.getQueryParamBool(url, "enabled"), Some(true))
  assertEq("getQueryParamBool: false", Url.getQueryParamBool(url, "disabled"), Some(false))
  assertEq("getQueryParamBool: 1", Url.getQueryParamBool(url, "flag"), Some(true))
  assertEq("getQueryParamBool: 0", Url.getQueryParamBool(url, "off"), Some(false))
  assertEq("getQueryParamBool: other", Url.getQueryParamBool(url, "other"), Some(false))
}

// ============================================================
// isRoot tests
// ============================================================

let testIsRoot = () => {
  let root = Url.fromString("/")
  let notRoot = Url.fromString("/page")
  assertTrue("isRoot: true for /", Url.isRoot(root))
  assertTrue("isRoot: false for /page", !Url.isRoot(notRoot))
}

// ============================================================
// Roundtrip tests
// ============================================================

let testRoundtrip = () => {
  let original = "/journey/abc123?tab=map&page=1#section"
  let url = Url.fromString(original)
  let result = Url.toString(url)

  // Parse again and compare structure
  let reparsed = Url.fromString(result)
  assertEq("roundtrip: path preserved", reparsed.path, url.path)
  assertEq("roundtrip: fragment preserved", reparsed.fragment, url.fragment)
  assertEq("roundtrip: query q preserved",
    reparsed.query->Belt.Map.String.get("tab"),
    url.query->Belt.Map.String.get("tab"))
}

// ============================================================
// Run all tests
// ============================================================

let runAll = () => {
  Js.Console.log("=== Url Module Tests ===")

  Js.Console.log("\n-- fromString --")
  testFromStringSimplePath()
  testFromStringRoot()
  testFromStringNestedPath()
  testFromStringWithQuery()
  testFromStringWithFragment()
  testFromStringWithQueryAndFragment()
  testFromStringEncodedQuery()
  testFromStringEmptyQueryValue()

  Js.Console.log("\n-- toString --")
  testToStringSimple()
  testToStringRoot()
  testToStringWithQuery()
  testToStringWithFragment()
  testToStringEncodesSpecialChars()

  Js.Console.log("\n-- pathToString --")
  testPathToString()

  Js.Console.log("\n-- Query helpers --")
  testGetQueryParam()
  testGetQueryParamInt()
  testGetQueryParamBool()

  Js.Console.log("\n-- isRoot --")
  testIsRoot()

  Js.Console.log("\n-- Roundtrip --")
  testRoundtrip()

  Js.Console.log("\n=== Url Tests Complete ===")
}

// Auto-run
runAll()
