// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// Sanitisation_test.res - Tests for Parser.sanitisePath, Parser.escapeHtml,
// Parser.sanitisedStr, and Parser.isRegexSafe.
//
// These security hardening functions were added in cadre-router v0.4 to protect
// against three attack vectors:
//
//   1. Path traversal — "..", "//", backslash sequences that escape intended
//      directory boundaries when route parameters are used in file operations.
//
//   2. Cross-site scripting (XSS) — HTML-significant characters in route
//      parameters that could execute arbitrary JavaScript when rendered.
//
//   3. Regular Expression Denial of Service (ReDoS) — malicious regex patterns
//      with nested quantifiers or overlapping alternation that cause exponential
//      backtracking in JavaScript's regex engine.
//
// Each test section below validates both positive cases (safe inputs pass through)
// and negative cases (dangerous inputs are rejected or neutralised).

// ============================================================================
// Test Harness
// ============================================================================
//
// Uses the same assertion pattern as all other cadre-router test files:
// console.log for PASS, console.error for FAIL. No external test framework
// dependency — tests run as plain ES module scripts via Deno.

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
// SECTION 1: sanitisePath Tests
// ============================================================================
//
// Parser.sanitisePath decodes percent-encoded input via decodeURIComponent,
// then rejects segments containing:
//   - ".."     (parent directory traversal)
//   - "//"     (path separator injection)
//   - "\"      (Windows-style path separators)
//
// Returns Some(decoded_value) for safe segments, None for dangerous ones.

let testSanitisePathNormalSegments = () => {
  Js.Console.log("\n-- sanitisePath: Normal Segments --")

  // Simple alphanumeric segments should pass through unchanged
  assertEq("sanitisePath: simple string", Parser.sanitisePath("hello"), Some("hello"))

  // Hyphenated slugs are common in URLs and should be safe
  assertEq("sanitisePath: slug with hyphens", Parser.sanitisePath("my-page"), Some("my-page"))

  // Underscored identifiers are equally safe
  assertEq("sanitisePath: underscore segment", Parser.sanitisePath("user_123"), Some("user_123"))

  // Numeric segments (user IDs, page numbers) should pass
  assertEq("sanitisePath: numeric segment", Parser.sanitisePath("42"), Some("42"))

  // Single dot is valid (refers to current directory, not traversal)
  assertEq("sanitisePath: single dot is safe", Parser.sanitisePath("."), Some("."))

  // Empty string is technically safe (no traversal pattern)
  assertEq("sanitisePath: empty string passes", Parser.sanitisePath(""), Some(""))

  // File extensions with dots are safe — only ".." is dangerous
  assertEq("sanitisePath: file extension", Parser.sanitisePath("report.pdf"), Some("report.pdf"))

  // Unicode characters should pass through (URL-decoded)
  // %C3%A9 is the UTF-8 encoding of U+00E9 (latin small letter e with acute)
  let decoded = Parser.sanitisePath("caf%C3%A9")
  assertSome("sanitisePath: unicode chars pass", decoded)
}

let testSanitisePathTraversalRejection = () => {
  Js.Console.log("\n-- sanitisePath: Path Traversal Rejection --")

  // Direct ".." traversal — the most basic attack vector
  assertNone("sanitisePath: rejects direct ..", Parser.sanitisePath(".."))

  // Traversal embedded in a path-like segment
  assertNone("sanitisePath: rejects ../etc/passwd", Parser.sanitisePath("../etc/passwd"))

  // Traversal at the end of a segment
  assertNone("sanitisePath: rejects foo/..", Parser.sanitisePath("foo/.."))

  // Traversal in the middle of a segment
  assertNone("sanitisePath: rejects foo/../bar", Parser.sanitisePath("foo/../bar"))

  // Percent-encoded traversal: %2e = ".", so %2e%2e = ".."
  // sanitisePath decodes first, so this should be caught
  assertNone("sanitisePath: rejects %2e%2e (encoded ..)", Parser.sanitisePath("%2e%2e"))

  // Mixed encoding: one dot literal, one encoded
  assertNone("sanitisePath: rejects .%2e (mixed encoding)", Parser.sanitisePath(".%2e"))

  // Double slash injection — could cause path confusion
  assertNone("sanitisePath: rejects //", Parser.sanitisePath("//"))
  assertNone("sanitisePath: rejects foo//bar", Parser.sanitisePath("foo//bar"))

  // Backslash — Windows path separator, could bypass Unix-style path checks
  assertNone("sanitisePath: rejects backslash", Parser.sanitisePath("foo\\bar"))
  assertNone("sanitisePath: rejects lone backslash", Parser.sanitisePath("\\"))

  // Encoded backslash: %5c = "\"
  assertNone("sanitisePath: rejects %5c (encoded backslash)", Parser.sanitisePath("%5c"))
}

let testSanitisePathEdgeCases = () => {
  Js.Console.log("\n-- sanitisePath: Edge Cases --")

  // Triple dot is NOT a traversal (only ".." is special)
  assertEq("sanitisePath: triple dot contains ..", Parser.sanitisePath("..."), None)

  // Single dot followed by other chars is safe
  assertEq("sanitisePath: .hidden is safe", Parser.sanitisePath(".hidden"), Some(".hidden"))

  // Dots separated by characters are safe
  assertEq("sanitisePath: a.b.c is safe", Parser.sanitisePath("a.b.c"), Some("a.b.c"))
}

// ============================================================================
// SECTION 2: escapeHtml Tests
// ============================================================================
//
// Parser.escapeHtml converts the 5 HTML-significant characters to their
// entity equivalents. This is a defense-in-depth measure — the primary
// XSS defense should be the view layer's own escaping (React JSX auto-escape).
//
// Character mappings:
//   & -> &amp;   (must be first to avoid double-escaping)
//   < -> &lt;    (prevents tag injection)
//   > -> &gt;    (closes injected tags)
//   " -> &quot;  (prevents attribute breakout in double-quoted attrs)
//   ' -> &#x27;  (prevents attribute breakout in single-quoted attrs)

let testEscapeHtmlSafeStrings = () => {
  Js.Console.log("\n-- escapeHtml: Safe Strings Pass Through --")

  // Plain text with no special characters should be unchanged
  assertEq("escapeHtml: plain text", Parser.escapeHtml("hello world"), "hello world")

  // Numbers are always safe
  assertEq("escapeHtml: numbers", Parser.escapeHtml("12345"), "12345")

  // Hyphens and underscores are safe
  assertEq("escapeHtml: hyphens/underscores", Parser.escapeHtml("my-page_title"), "my-page_title")

  // Empty string
  assertEq("escapeHtml: empty string", Parser.escapeHtml(""), "")
}

let testEscapeHtmlXssPayloads = () => {
  Js.Console.log("\n-- escapeHtml: XSS Payloads Neutralised --")

  // Classic script injection — the angle brackets must be escaped
  assertEq(
    "escapeHtml: script tag",
    Parser.escapeHtml("<script>alert(1)</script>"),
    "&lt;script&gt;alert(1)&lt;/script&gt;",
  )

  // Image onerror injection — angle brackets and quotes escaped
  assertEq(
    "escapeHtml: img onerror",
    Parser.escapeHtml("<img onerror=\"alert(1)\">"),
    "&lt;img onerror=&quot;alert(1)&quot;&gt;",
  )

  // Ampersand must be escaped to prevent entity injection
  assertEq("escapeHtml: ampersand", Parser.escapeHtml("a&b"), "a&amp;b")

  // Single quotes must be escaped to prevent attribute breakout
  assertEq("escapeHtml: single quotes", Parser.escapeHtml("it's"), "it&#x27;s")

  // Double quotes
  assertEq("escapeHtml: double quotes", Parser.escapeHtml("say \"hello\""), "say &quot;hello&quot;")

  // Greater-than sign
  assertEq("escapeHtml: greater than", Parser.escapeHtml("a > b"), "a &gt; b")

  // Less-than sign
  assertEq("escapeHtml: less than", Parser.escapeHtml("a < b"), "a &lt; b")

  // All 5 special characters in one string
  assertEq(
    "escapeHtml: all special chars",
    Parser.escapeHtml("<div class=\"x\" data-v='y'>&</div>"),
    "&lt;div class=&quot;x&quot; data-v=&#x27;y&#x27;&gt;&amp;&lt;/div&gt;",
  )
}

let testEscapeHtmlSqlInjection = () => {
  Js.Console.log("\n-- escapeHtml: SQL Injection Payloads --")

  // SQL injection payloads that contain HTML-significant characters
  // Note: escapeHtml does NOT protect against SQL injection — that is handled
  // by parameterised queries. These tests verify that the SQL metacharacters
  // that are also HTML metacharacters get escaped for HTML safety.
  assertEq(
    "escapeHtml: SQL with quotes",
    Parser.escapeHtml("'; DROP TABLE users; --"),
    "&#x27;; DROP TABLE users; --",
  )

  // SQL injection with angle brackets (less common but possible in error display)
  assertEq(
    "escapeHtml: SQL with angle brackets",
    Parser.escapeHtml("1 OR 1=1; <script>alert('xss')</script>"),
    "1 OR 1=1; &lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;",
  )
}

// ============================================================================
// SECTION 3: sanitisedStr Parser Tests
// ============================================================================
//
// Parser.sanitisedStr is a drop-in replacement for Parser.str that combines:
//   1. Parse a non-empty path segment (via str)
//   2. Run sanitisePath — reject if traversal detected (parse FAILS)
//   3. Run escapeHtml on the clean value before returning
//
// The parse failure on traversal means the router falls through to 404/error
// rather than silently passing a dangerous value to the handler.

let testSanitisedStrNormalRouting = () => {
  Js.Console.log("\n-- sanitisedStr: Normal Routing --")

  // Normal string segment should parse and pass through (with HTML escaping)
  let url = Url.fromString("/users/alice")
  let parser = Parser.s("users")->Parser.andThen(Parser.sanitisedStr)
  let result = Parser.parse(parser, url)
  assertEq("sanitisedStr: normal segment", result, Some(((), "alice")))

  // Numeric segment
  let url2 = Url.fromString("/items/42")
  let parser2 = Parser.s("items")->Parser.andThen(Parser.sanitisedStr)
  let result2 = Parser.parse(parser2, url2)
  assertEq("sanitisedStr: numeric segment", result2, Some(((), "42")))

  // Slug segment
  let url3 = Url.fromString("/posts/my-first-post")
  let parser3 = Parser.s("posts")->Parser.andThen(Parser.sanitisedStr)
  let result3 = Parser.parse(parser3, url3)
  assertEq("sanitisedStr: slug segment", result3, Some(((), "my-first-post")))
}

let testSanitisedStrXssProtection = () => {
  Js.Console.log("\n-- sanitisedStr: XSS Protection --")

  // Segment containing angle brackets should have them escaped
  // Note: In a real URL, angle brackets would typically be percent-encoded,
  // but we test the raw case to verify the escaping pipeline.
  let url = Url.fromString("/search/<script>alert(1)</script>")
  let parser = Parser.s("search")->Parser.andThen(Parser.sanitisedStr)
  let result = Parser.parse(parser, url)
  // The angle brackets should be escaped to HTML entities
  assertEq(
    "sanitisedStr: escapes angle brackets",
    result,
    Some(((), "&lt;script&gt;alert(1)&lt;/script&gt;")),
  )

  // Ampersand in segment
  let url2 = Url.fromString("/tags/rock&roll")
  let parser2 = Parser.s("tags")->Parser.andThen(Parser.sanitisedStr)
  let result2 = Parser.parse(parser2, url2)
  assertEq("sanitisedStr: escapes ampersand", result2, Some(((), "rock&amp;roll")))
}

let testSanitisedStrTraversalRejection = () => {
  Js.Console.log("\n-- sanitisedStr: Traversal Rejection (Parse Fails) --")

  // ".." segment should cause the entire parse to FAIL (not just sanitise)
  let url = Url.fromString("/files/..")
  let parser = Parser.s("files")->Parser.andThen(Parser.sanitisedStr)
  let result = Parser.parse(parser, url)
  assertNone("sanitisedStr: rejects .. (parse fails)", result)

  // Backslash should also fail
  let url2 = Url.fromString("/files/foo\\bar")
  let parser2 = Parser.s("files")->Parser.andThen(Parser.sanitisedStr)
  let result2 = Parser.parse(parser2, url2)
  assertNone("sanitisedStr: rejects backslash (parse fails)", result2)
}

let testSanitisedStrVsStr = () => {
  Js.Console.log("\n-- sanitisedStr vs str: Behaviour Comparison --")

  // For safe inputs, sanitisedStr should produce the same result as str
  let safeUrl = Url.fromString("/api/users")
  let strParser = Parser.s("api")->Parser.andThen(Parser.str)
  let sanitisedParser = Parser.s("api")->Parser.andThen(Parser.sanitisedStr)
  let strResult = Parser.parse(strParser, safeUrl)
  let sanitisedResult = Parser.parse(sanitisedParser, safeUrl)
  assertEq("sanitisedStr vs str: same for safe input", sanitisedResult, strResult)

  // For dangerous inputs, str succeeds but sanitisedStr fails
  let dangerousUrl = Url.fromString("/api/..")
  let strDangerous = Parser.parse(strParser, dangerousUrl)
  let sanitisedDangerous = Parser.parse(sanitisedParser, dangerousUrl)
  assertSome("str: allows .. (unsafe)", strDangerous)
  assertNone("sanitisedStr: rejects .. (safe)", sanitisedDangerous)
}

// ============================================================================
// SECTION 4: isRegexSafe Tests
// ============================================================================
//
// Parser.isRegexSafe performs a heuristic check for ReDoS-vulnerable regex
// patterns. It detects two structural red flags:
//
//   1. Nested quantifiers: (x+)+, (x*)+, (x+)*, (x*)* — any group ending
//      with + or * that is itself followed by + or * or ?.
//
//   2. Overlapping alternation with quantifiers: (a|b)+ where the alternatives
//      can match the same input.
//
// Returns true if the pattern appears safe, false if dangerous.

let testIsRegexSafeSafePatterns = () => {
  Js.Console.log("\n-- isRegexSafe: Safe Patterns --")

  // Simple literal — no quantifiers at all
  assertTrue("isRegexSafe: literal string", Parser.isRegexSafe("hello"))

  // Character class with quantifier — safe because no nesting
  assertTrue("isRegexSafe: [a-z]+", Parser.isRegexSafe("[a-z]+"))

  // Anchored pattern with fixed-length quantifier — safe
  assertTrue("isRegexSafe: ^[0-9]{3}$", Parser.isRegexSafe("^[0-9]{3}$"))

  // UUID pattern — the standard format used in cadre-router's uuid parser
  assertTrue(
    "isRegexSafe: UUID pattern",
    Parser.isRegexSafe("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"),
  )

  // Slug pattern — the standard format used in cadre-router's slug parser
  assertTrue("isRegexSafe: slug pattern", Parser.isRegexSafe("^[a-z0-9]+(?:-[a-z0-9]+)*$"))

  // Simple alternation without quantifier on the group — safe
  assertTrue("isRegexSafe: (a|b) without quantifier", Parser.isRegexSafe("(a|b)"))

  // Version pattern: v followed by digits — safe
  assertTrue("isRegexSafe: ^v[0-9]+$", Parser.isRegexSafe("^v[0-9]+$"))

  // Empty pattern — vacuously safe
  assertTrue("isRegexSafe: empty pattern", Parser.isRegexSafe(""))

  // Fixed repetition — no backtracking risk
  assertTrue("isRegexSafe: a{3}", Parser.isRegexSafe("a{3}"))
}

let testIsRegexSafeDangerousPatterns = () => {
  Js.Console.log("\n-- isRegexSafe: Dangerous Patterns --")

  // Classic nested quantifier: (a+)+ — O(2^N) backtracking
  assertFalse("isRegexSafe: (a+)+ nested quantifier", Parser.isRegexSafe("(a+)+"))

  // Star-plus nesting: (a*)+ — equally dangerous
  assertFalse("isRegexSafe: (a*)+", Parser.isRegexSafe("(a*)+"))

  // Plus-star nesting: (a+)* — dangerous
  assertFalse("isRegexSafe: (a+)*", Parser.isRegexSafe("(a+)*"))

  // Star-star nesting: (a*)* — dangerous
  assertFalse("isRegexSafe: (a*)*", Parser.isRegexSafe("(a*)*"))

  // Nested quantifier with optional: (a+)? — can still cause issues
  assertFalse("isRegexSafe: (a+)?", Parser.isRegexSafe("(a+)?"))

  // Overlapping alternation with quantifier: (a|a)+ — exponential paths
  assertFalse("isRegexSafe: (a|a)+", Parser.isRegexSafe("(a|a)+"))

  // More realistic overlapping: (ab|a)+ — the "a" prefix overlaps
  assertFalse("isRegexSafe: (ab|a)+", Parser.isRegexSafe("(ab|a)+"))

  // Overlapping alternation with star
  assertFalse("isRegexSafe: (x|xy)*", Parser.isRegexSafe("(x|xy)*"))

  // Complex nested quantifier embedded in larger pattern
  assertFalse("isRegexSafe: ^(a+)+$", Parser.isRegexSafe("^(a+)+$"))

  // Nested quantifier with character class
  assertFalse("isRegexSafe: ([a-z]+)+", Parser.isRegexSafe("([a-z]+)+"))
}

let testIsRegexSafeBoundaryPatterns = () => {
  Js.Console.log("\n-- isRegexSafe: Boundary Patterns --")

  // Non-capturing group with quantifier inside but not outside — safe
  assertTrue("isRegexSafe: (?:a+) no outer quantifier", Parser.isRegexSafe("(?:a+)"))

  // Group with quantifier inside followed by fixed text — may trigger
  // heuristic depending on how the regex looks structurally
  // This tests the heuristic's conservatism
  let pattern = "(a+)b"
  // No outer quantifier on the group, so this should be safe
  assertTrue("isRegexSafe: (a+)b no outer quantifier", Parser.isRegexSafe(pattern))
}

// ============================================================================
// SECTION 5: Integration — sanitisedStr in Full Route Parsers
// ============================================================================
//
// These tests verify that sanitisedStr integrates correctly with the full
// parser combinator chain (oneOf, andThen, map) in realistic route definitions.

// Route type for integration testing
type testRoute =
  | UserProfile(string)
  | BlogPost(string)
  | FilePath(string)
  | NotFound

let testSanitisedStrInRouter = () => {
  Js.Console.log("\n-- sanitisedStr: Full Router Integration --")

  let router = Parser.oneOf([
    Parser.s("user")->Parser.andThen(Parser.sanitisedStr)->Parser.map(((_, name)) => UserProfile(name)),
    Parser.s("blog")->Parser.andThen(Parser.sanitisedStr)->Parser.map(((_, slug)) => BlogPost(slug)),
    Parser.s("files")->Parser.andThen(Parser.sanitisedStr)->Parser.map(((_, path)) => FilePath(path)),
  ])

  // Normal routing works
  assertEq(
    "router+sanitised: /user/alice",
    Parser.parse(router, Url.fromString("/user/alice")),
    Some(UserProfile("alice")),
  )

  assertEq(
    "router+sanitised: /blog/my-post",
    Parser.parse(router, Url.fromString("/blog/my-post")),
    Some(BlogPost("my-post")),
  )

  assertEq(
    "router+sanitised: /files/report",
    Parser.parse(router, Url.fromString("/files/report")),
    Some(FilePath("report")),
  )

  // Traversal attack on file route — falls through to no match
  assertNone(
    "router+sanitised: /files/.. rejected",
    Parser.parse(router, Url.fromString("/files/..")),
  )

  // Unknown routes still fail normally
  assertNone(
    "router+sanitised: unknown route",
    Parser.parse(router, Url.fromString("/unknown/path")),
  )
}

// ============================================================================
// Run All Tests
// ============================================================================

let runAll = () => {
  Js.Console.log("\n========================================")
  Js.Console.log("  SANITISATION & ReDoS TESTS")
  Js.Console.log("========================================")

  passed := 0
  failed := 0

  // sanitisePath
  testSanitisePathNormalSegments()
  testSanitisePathTraversalRejection()
  testSanitisePathEdgeCases()

  // escapeHtml
  testEscapeHtmlSafeStrings()
  testEscapeHtmlXssPayloads()
  testEscapeHtmlSqlInjection()

  // sanitisedStr parser
  testSanitisedStrNormalRouting()
  testSanitisedStrXssProtection()
  testSanitisedStrTraversalRejection()
  testSanitisedStrVsStr()

  // isRegexSafe
  testIsRegexSafeSafePatterns()
  testIsRegexSafeDangerousPatterns()
  testIsRegexSafeBoundaryPatterns()

  // Integration
  testSanitisedStrInRouter()

  summary()

  Js.Console.log("\n========================================")
  Js.Console.log("  SANITISATION TESTS COMPLETE")
  Js.Console.log("========================================\n")
}

// Auto-run
let _ = runAll()
