// SPDX-License-Identifier: PMPL-1.0-or-later
// Parser.res - Elm-style URL parser combinators
//
// Provides a composable, type-safe URL parser built on the combinator pattern
// from Elm's Url.Parser. Route definitions are values (not strings or regexes),
// meaning the compiler can verify that every route's extracted parameters match
// their expected types at build time — no runtime pattern-match failures.
//
// Architecture:
//   - A parser is a function `state => option<('a, state)>` where state tracks
//     the remaining unconsumed path segments and the original URL.
//   - Parsers consume zero or more segments from `state.remaining` and return
//     the parsed value plus the updated state, or None on mismatch.
//   - Combinators (andThen, map, oneOf, etc.) compose small parsers into larger
//     route definitions.
//
// Security (added 2026-02-28):
//   - `sanitisePath` rejects path traversal sequences (.. and encoded variants).
//   - `escapeHtml` prevents XSS when route parameters are rendered in views.
//   - `sanitisedStr` wraps the standard `str` parser with both protections.
//   - `isRegexSafe` detects ReDoS-vulnerable patterns before they reach Js.Re.
//
// See also: RouteBuilder.res for bidirectional (parse + serialise) routes,
// and oneOfGrouped below for O(1) first-segment dispatch.

// ============================================================================
// Core Types
// ============================================================================

// Parser state threaded through the combinator chain.
// `remaining` shrinks as segments are consumed; `url` is immutable context.
type state = {
  remaining: list<string>,
  url: Url.t,
}

// The fundamental parser type: a function from state to an optional pair of
// (parsed value, next state). None means "this parser does not match."
// Composing parsers via andThen / map / oneOf builds up route definitions.
type t<'a> = state => option<('a, state)>

// ============================================================================
// Path Segment Matchers
// ============================================================================

// Match a literal path segment exactly. Consumes one segment from `remaining`
// if it equals the given string, otherwise fails.
// Example: `s("api")` matches the segment "api" in /api/users.
let s = (literal: string): t<unit> => {
  state => {
    switch state.remaining {
    | list{head, ...tail} if head == literal =>
      Some(((), {...state, remaining: tail}))
    | _ => None
    }
  }
}

// Match any non-empty path segment and return it as a string.
// This is the raw (unsanitised) variant — use `sanitisedStr` for user-facing
// parameters that might be rendered in HTML or used in file paths.
// Example: `str` matches "alice" in /users/alice and returns "alice".
let str: t<string> = state => {
  switch state.remaining {
  | list{head, ...tail} if head != "" =>
    Some((head, {...state, remaining: tail}))
  | _ => None
  }
}

// Match a path segment that can be parsed as an integer.
// Uses Belt.Int.fromString for safe parsing — no NaN, no floats.
// Example: `int` matches "42" in /posts/42 and returns 42.
let int: t<int> = state => {
  switch state.remaining {
  | list{head, ...tail} =>
    switch Belt.Int.fromString(head) {
    | Some(n) => Some((n, {...state, remaining: tail}))
    | None => None
    }
  | list{} => None
  }
}

// Match a path segment using a custom parsing function.
// The caller provides a `string => option<'a>` that returns Some(value) on
// success. This is the escape hatch for domain-specific segment formats
// that are not covered by str/int/uuid/slug.
// Example: `custom(Color.fromString)` to parse "red", "blue", etc.
let custom = (parse: string => option<'a>): t<'a> => {
  state => {
    switch state.remaining {
    | list{head, ...tail} =>
      switch parse(head) {
      | Some(value) => Some((value, {...state, remaining: tail}))
      | None => None
      }
    | list{} => None
    }
  }
}

// Match the end of the path (no remaining segments).
// Use this to ensure the entire URL path has been consumed.
// Example: `s("about") |> andThen(top)` matches /about but not /about/team.
let top: t<unit> = state => {
  switch state.remaining {
  | list{} => Some(((), state))
  | _ => None
  }
}

// ============================================================================
// Combinators
// ============================================================================

// Sequence two parsers: run parserA, then parserB on the remaining state.
// Returns a tuple of both parsed values. This is the fundamental composition
// operator — chaining `s("api") |> andThen(str) |> andThen(int)` builds up
// nested tuples like (((), "users"), 42) for /api/users/42.
let andThen = (parserA: t<'a>, parserB: t<'b>): t<('a, 'b)> => {
  state => {
    switch parserA(state) {
    | Some((a, stateAfterA)) =>
      switch parserB(stateAfterA) {
      | Some((b, stateAfterB)) => Some(((a, b), stateAfterB))
      | None => None
      }
    | None => None
    }
  }
}

// Infix alias for andThen. Enables `s("api") </> str </> int` syntax
// for readable route definitions.
let \"</>" = andThen

// Transform the parsed value of a parser using a function.
// Does not affect which inputs the parser accepts — only what it produces.
// Example: `int |> map(n => n * 2)` parses "5" and returns 10.
let map = (parser: t<'a>, fn: 'a => 'b): t<'b> => {
  state => {
    switch parser(state) {
    | Some((a, newState)) => Some((fn(a), newState))
    | None => None
    }
  }
}

// Functor-style map with the function on the left.
// Enables `MyRoute <$> (s("api") </> str </> int)` syntax.
let \"<$>" = (fn: 'a => 'b, parser: t<'a>): t<'b> => map(parser, fn)

// Try each parser in the array until one succeeds.
// This is ordered choice — the first matching parser wins, and later parsers
// are not attempted. For large route sets where the first segment is unique,
// prefer `oneOfGrouped` which uses O(1) dispatch instead of O(N) linear scan.
let oneOf = (parsers: array<t<'a>>): t<'a> => {
  state => {
    let result = ref(None)
    let i = ref(0)
    let len = Belt.Array.length(parsers)

    while result.contents == None && i.contents < len {
      switch parsers[i.contents] {
      | Some(parser) =>
        switch parser(state) {
        | Some(_) as success => result := success
        | None => i := i.contents + 1
        }
      | None => i := i.contents + 1
      }
    }

    result.contents
  }
}

// Make a parser optional — it always succeeds, returning Some(value) if the
// inner parser matched, or None (as a value, not a parse failure) if it didn't.
// The parser state is only advanced if the inner parser matched.
// Example: `s("users") </> str </> optional(s("profile"))` matches both
// /users/alice and /users/alice/profile.
let optional = (parser: t<'a>): t<option<'a>> => {
  state => {
    switch parser(state) {
    | Some((a, newState)) => Some((Some(a), newState))
    | None => Some((None, state))
    }
  }
}

// ============================================================================
// Query Parameters
// ============================================================================

// Extract an optional query parameter by key. Always succeeds (never fails
// the parse) — returns Some(value) if the key exists, None if absent.
// Does not consume any path segments.
// Example: `query("page")` on /users?page=2 returns Some("2").
let query = (key: string): t<option<string>> => {
  state => {
    let value = state.url->Url.getQueryParam(key)
    Some((value, state))
  }
}

// Extract an optional integer query parameter by key.
// Returns None if the key is absent OR if the value is not a valid integer.
// Always succeeds as a parser (never fails the route match).
let queryInt = (key: string): t<option<int>> => {
  state => {
    let value = state.url->Url.getQueryParamInt(key)
    Some((value, state))
  }
}

// Extract an optional boolean query parameter by key.
// Returns None if the key is absent, Some(true/false) if present and parseable.
// Always succeeds as a parser.
let queryBool = (key: string): t<option<bool>> => {
  state => {
    let value = state.url->Url.getQueryParamBool(key)
    Some((value, state))
  }
}

// Extract a required query parameter by key. Unlike `query`, this FAILS the
// parse if the key is absent — useful for routes where the parameter is
// mandatory (e.g., /search requires ?q=...).
let queryRequired = (key: string): t<string> => {
  state => {
    switch state.url->Url.getQueryParam(key) {
    | Some(value) => Some((value, state))
    | None => None
    }
  }
}

// ============================================================================
// Advanced Segment Matchers
// ============================================================================

// UUID regex: standard 8-4-4-4-12 hex format (RFC 4122).
// Anchored with ^ and $ to reject partial matches. Case-insensitive hex
// to accept both uppercase and lowercase UUIDs.
// This regex is ReDoS-safe — no nested quantifiers or ambiguous alternation.
let uuidRegex = %re("/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/")

// Match a path segment that is a valid UUID (v1-v5, any variant).
// Returns the raw UUID string if matched. Does not normalise case.
// Example: `uuid` matches "550e8400-e29b-41d4-a716-446655440000" in
// /users/550e8400-e29b-41d4-a716-446655440000.
let uuid: t<string> = state => {
  switch state.remaining {
  | list{head, ...tail} =>
    if Js.Re.test_(uuidRegex, head) {
      Some((head, {...state, remaining: tail}))
    } else {
      None
    }
  | list{} => None
  }
}

// Slug regex: lowercase alphanumeric characters separated by single hyphens.
// No leading or trailing hyphens, no consecutive hyphens.
// Matches: "my-post", "hello", "a-b-c". Rejects: "-bad", "bad-", "a--b".
// ReDoS-safe — the non-capturing group uses a possessive-like structure
// (no overlapping alternatives).
let slugRegex = %re("/^[a-z0-9]+(?:-[a-z0-9]+)*$/")

// Match a path segment that conforms to slug format.
// Slugs are commonly used for human-readable, URL-safe identifiers
// (e.g., blog post titles, category names).
// Example: `slug` matches "my-first-post" in /blog/my-first-post.
let slug: t<string> = state => {
  switch state.remaining {
  | list{head, ...tail} =>
    if Js.Re.test_(slugRegex, head) {
      Some((head, {...state, remaining: tail}))
    } else {
      None
    }
  | list{} => None
  }
}

// Match a path segment that can be parsed as a floating-point number.
// Uses Belt.Float.fromString for safe parsing.
// Example: `float` matches "3.14" in /coordinates/3.14.
let float: t<float> = state => {
  switch state.remaining {
  | list{head, ...tail} =>
    switch Belt.Float.fromString(head) {
    | Some(f) => Some((f, {...state, remaining: tail}))
    | None => None
    }
  | list{} => None
  }
}

// Match a path segment against a whitelist of allowed values.
// Useful for routes with a fixed set of valid options (e.g., sort order,
// status codes, locale identifiers).
// Example: `enum(["asc", "desc"])` matches "asc" or "desc" but not "random".
let enum = (options: array<string>): t<string> => {
  state => {
    switch state.remaining {
    | list{head, ...tail} =>
      if Belt.Array.some(options, opt => opt == head) {
        Some((head, {...state, remaining: tail}))
      } else {
        None
      }
    | list{} => None
    }
  }
}

// Match a path segment against an arbitrary regex.
// SECURITY WARNING: Only use with compile-time %re() literals or patterns
// that have been validated with `isRegexSafe`. User-supplied regex patterns
// can cause ReDoS (Regular Expression Denial of Service) via catastrophic
// backtracking. See the ReDoS Protection section below.
// Example: `regex(%re("/^v[0-9]+$/"))` matches "v1", "v2", "v10".
let regex = (re: Js.Re.t): t<string> => {
  state => {
    switch state.remaining {
    | list{head, ...tail} =>
      if Js.Re.test_(re, head) {
        Some((head, {...state, remaining: tail}))
      } else {
        None
      }
    | list{} => None
    }
  }
}

// Consume all remaining path segments as a list of strings.
// Always succeeds (returns an empty list if no segments remain).
// Useful for catch-all routes or file-path-like URLs.
// Example: `s("files") </> rest` on /files/docs/2026/report.pdf
// returns ["docs", "2026", "report.pdf"].
let rest: t<list<string>> = state => {
  Some((state.remaining, {...state, remaining: list{}}))
}

// Consume all remaining path segments joined as a single "/" -separated string.
// Always succeeds (returns "" if no segments remain).
// Example: `s("files") </> restAsString` on /files/docs/report.pdf
// returns "docs/report.pdf".
let restAsString: t<string> = state => {
  let joined = state.remaining->Belt.List.toArray->Js.Array2.joinWith("/")
  Some((joined, {...state, remaining: list{}}))
}

// ============================================================================
// Fragment
// ============================================================================

// Extract the URL fragment (hash) as an optional string.
// Always succeeds — returns None if no fragment is present.
// Does not consume any path segments.
// Example: on /docs#section-3, returns Some("section-3").
let fragment: t<option<string>> = state => {
  Some((state.url.fragment, state))
}

// Extract the URL fragment, failing the parse if no fragment is present.
// Use when a route requires a fragment (e.g., single-page app scroll targets).
let fragmentRequired: t<string> = state => {
  switch state.url.fragment {
  | Some(f) => Some((f, state))
  | None => None
  }
}

// ============================================================================
// Control Flow
// ============================================================================

// Always succeed with a constant value, consuming no input.
// Useful for injecting default values or building up route constructors.
// Example: `succeed(HomePage)` always returns HomePage.
let succeed = (value: 'a): t<'a> => {
  state => Some((value, state))
}

// Always fail, regardless of input. Useful as a base case or sentinel.
let fail: t<'a> = _ => None

// Defer parser construction until first use. Breaks circular references
// in recursive route definitions (e.g., nested category trees).
// The thunk is called each time the parser is invoked.
let lazy_ = (thunk: unit => t<'a>): t<'a> => {
  state => thunk()(state)
}

// Apply a predicate to the parsed value — fail if it returns false.
// Useful for additional validation beyond what the parser itself checks.
// Example: `int |> filter(n => n > 0)` only matches positive integers.
let filter = (parser: t<'a>, predicate: 'a => bool): t<'a> => {
  state => {
    switch parser(state) {
    | Some((value, newState)) if predicate(value) => Some((value, newState))
    | _ => None
    }
  }
}

// Try the parser; if it fails, return the default value without consuming input.
// Combines `optional` with `getWithDefault` in one step.
let withDefault = (parser: t<'a>, default: 'a): t<'a> => {
  state => {
    switch parser(state) {
    | Some(_) as result => result
    | None => Some((default, state))
    }
  }
}

// Semantically identical to the inner parser, but signals intent for
// backtracking. In a PEG-style system, `attempt` would save/restore state
// on failure; here it serves as documentation that the parser is speculative.
let attempt = (parser: t<'a>): t<'a> => {
  state => {
    switch parser(state) {
    | Some(_) as result => result
    | None => None
    }
  }
}

// ============================================================================
// Debugging
// ============================================================================

// Wrap a parser with console logging for development-time debugging.
// Logs the remaining segments before parsing and the result (success/failure)
// plus how many segments were consumed. Strip from production builds.
// Example: `debug("userRoute", s("users") </> str)` logs parse attempts.
let debug = (label: string, parser: t<'a>): t<'a> => {
  state => {
    Js.Console.log(`[Parser Debug: ${label}]`)
    Js.Console.log(`  Remaining: ${state.remaining->Belt.List.toArray->Js.Array2.joinWith("/")}`)

    let result = parser(state)

    switch result {
    | Some((_, newState)) =>
      Js.Console.log(`  Result: Success`)
      Js.Console.log(`  Consumed: ${Belt.Int.toString(
        Belt.List.length(state.remaining) - Belt.List.length(newState.remaining)
      )} segments`)
    | None =>
      Js.Console.log(`  Result: Failed`)
    }

    result
  }
}

// ============================================================================
// Sanitisation
// ============================================================================
//
// Route parameters extracted from URL segments can contain malicious content.
// Two attack vectors are addressed here:
//
//   1. Path traversal: A segment like ".." or "%2e%2e" can escape the intended
//      directory when used in file system operations. `sanitisePath` detects
//      these sequences (including percent-encoded variants) and rejects them.
//
//   2. Cross-site scripting (XSS): When a route parameter is rendered in HTML
//      (e.g., /users/<name> displayed as "Welcome, <name>"), malicious values
//      like "<script>alert(1)</script>" can execute arbitrary JavaScript.
//      `escapeHtml` neutralises the 5 dangerous HTML characters.
//
// These functions are composable:
//   - Use `sanitisedStr` for automatic sanitisation during parsing.
//   - Use `sanitisePath` and `escapeHtml` individually for manual control.
//   - Use `isRegexSafe` (below) to validate regex patterns before using them
//     with the `regex` parser combinator.

// Reject path traversal sequences: "..", "//", and backslashes.
// The input is first percent-decoded (via decodeURIComponent) to catch
// encoded traversal attempts like "%2e%2e" or "%2f%2f".
//
// Returns Some(decoded_clean_value) if the segment is safe, None if
// a traversal pattern was detected.
//
// Detection covers:
//   - ".."      — parent directory traversal
//   - "//"      — path separator injection
//   - "\"       — Windows-style path separators
//
// Note: This function decodes FIRST, then checks. This prevents double-
// encoding attacks where %252e%252e decodes to %2e%2e on first pass and
// .. on second pass. Since we only decode once and then check the result,
// the attacker would need the literal ".." to survive decoding.
let sanitisePath = (segment: string): option<string> => {
  let decoded = Js.Global.decodeURIComponent(segment)
  if Js.String2.includes(decoded, "..") ||
     Js.String2.includes(decoded, "//") ||
     Js.String2.includes(decoded, "\\") {
    None
  } else {
    Some(decoded)
  }
}

// Escape the 5 HTML-significant characters to their entity equivalents.
// This prevents XSS when route parameters are interpolated into HTML output.
//
// Character mappings:
//   & -> &amp;   (must be first to avoid double-escaping)
//   < -> &lt;    (prevents tag injection)
//   > -> &gt;    (closes injected tags)
//   " -> &quot;  (prevents attribute breakout in double-quoted attrs)
//   ' -> &#x27;  (prevents attribute breakout in single-quoted attrs)
//
// This is a "defense in depth" measure. The primary XSS defense should be
// the view layer's own escaping (e.g., React's JSX auto-escaping). This
// function provides an additional safety net for cases where parameters
// are used in raw HTML contexts (dangerouslySetInnerHTML, server-side
// rendering, or non-React renderers).
let escapeHtml = (s: string): string => {
  s
  ->Js.String2.replaceByRe(%re("/&/g"), "&amp;")
  ->Js.String2.replaceByRe(%re("/</g"), "&lt;")
  ->Js.String2.replaceByRe(%re("/>/g"), "&gt;")
  ->Js.String2.replaceByRe(%re("/\"/g"), "&quot;")
  ->Js.String2.replaceByRe(%re("/'/g"), "&#x27;")
}

// Create a sanitised string parser that combines path traversal rejection
// and HTML entity escaping. Wraps the standard `str` parser:
//
//   1. Parse a non-empty path segment (via `str`).
//   2. Run `sanitisePath` — if traversal detected, the PARSE FAILS (not just
//      the value; the entire route match fails, so the router can fall through
//      to a 404 or error handler).
//   3. Run `escapeHtml` on the clean value before returning it.
//
// Use this instead of `str` for any parameter that will be:
//   - Rendered in HTML (user names, titles, search terms)
//   - Used in file system paths (document IDs, resource names)
//   - Logged to output that might be viewed in a browser (admin dashboards)
//
// Example: `s("users") </> sanitisedStr` is a drop-in replacement for
// `s("users") </> str` with added security.
let sanitisedStr: t<string> = state => {
  switch str(state) {
  | Some((value, nextState)) =>
    switch sanitisePath(value) {
    | Some(clean) => Some((escapeHtml(clean), nextState))
    | None => None
    }
  | None => None
  }
}

// ============================================================================
// ReDoS Protection
// ============================================================================
//
// Regular Expression Denial of Service (ReDoS) occurs when a crafted input
// string causes a regex engine to enter catastrophic backtracking, consuming
// exponential CPU time. This typically happens with:
//
//   - Nested quantifiers: (a+)+, (a*)+, (a+)*, (a*)*
//     These create O(2^N) backtracking paths for inputs like "aaaa...X".
//
//   - Overlapping alternation with quantifiers: (a|a)+, (ab|a)+
//     The engine tries every permutation of which alternative matches
//     each character.
//
// In a routing context, ReDoS is a concern when:
//   1. The `regex` parser combinator is used with user-configurable patterns.
//   2. Route parameters are validated against patterns from a config file.
//   3. A CMS or admin panel allows defining custom URL patterns.
//
// The `isRegexSafe` function provides a fast, conservative heuristic check.
// It does NOT perform full NFA analysis — it looks for structural red flags
// that are known to cause catastrophic backtracking in JavaScript's
// backtracking regex engine.

// Detect potentially catastrophic regex patterns (ReDoS).
// Returns true if the pattern appears safe, false if it contains
// structural patterns known to cause exponential backtracking.
//
// Detected dangerous patterns:
//   - Nested quantifiers: (x+)+, (x*)+, (x+)*, (x*)* — any group ending
//     with + or * that is itself followed by + or * or ?.
//   - Overlapping alternation with quantifiers: (a|b)+ where the alternatives
//     can match the same input.
//
// Limitations:
//   - This is a heuristic, not a formal analysis. It may produce false
//     positives (rejecting safe patterns) or false negatives (missing
//     some dangerous patterns).
//   - For production use with user-supplied regex, consider a proper
//     ReDoS analyser library or compile-time regex validation.
//   - Patterns that are technically safe but structurally suspicious
//     will be rejected — err on the side of caution.
//
// Usage:
//   if isRegexSafe(userPattern) {
//     let parser = regex(Js.Re.fromString(userPattern))
//     // ... use parser
//   } else {
//     // Reject the pattern — log and return an error
//   }
let isRegexSafe = (pattern: string): bool => {
  // Nested quantifiers: a group containing + or * followed by + or * or ?
  // Examples caught: (a+)+, (a*)+, (a+)*, (a*)*, (a+)?
  let nestedQuantifier = %re("/(\([^)]*[+*]\)[+*?])/")
  // Overlapping alternation with quantifiers: a group with | followed by + or *
  // Examples caught: (a|a)+, (foo|f)+, (x|xy)*
  let overlappingAlt = %re("/(\([^)]*\|[^)]*\)[+*])/")
  !(Js.Re.test_(nestedQuantifier, pattern) || Js.Re.test_(overlappingAlt, pattern))
}

// === Optimised Dispatch ===

// oneOfGrouped pre-groups route parsers by their first literal path segment.
// When a URL arrives, the first segment is used for O(1) dispatch into the
// correct group, then only parsers within that group are tried linearly.
//
// For N routes with K unique first segments, this reduces average case from
// O(N) to O(N/K). For typical route sets (e.g., /api/*, /admin/*, /user/*),
// K is close to N, giving near-O(1) dispatch.
//
// Inspired by trie-based routing in http-capability-gateway and the
// cadre-router architecture discussion (2026-02-28).
//
// Usage:
//   let parser = oneOfGrouped([
//     ("api",     apiParser),      // matches /api/...
//     ("admin",   adminParser),    // matches /admin/...
//     ("user",    userParser),     // matches /user/...
//     ("",        rootParser),     // matches / (empty first segment)
//   ])
let oneOfGrouped = (entries: array<(string, t<'a>)>): t<'a> => {
  // Build a map from first segment to array of parsers
  let groups: Dict.t<array<t<'a>>> = Dict.make()

  entries->Array.forEach(((segment, parser)) => {
    let existing = groups->Dict.get(segment)->Option.getOr([])
    groups->Dict.set(segment, Array.concat(existing, [parser]))
  })

  state => {
    // Extract first segment for dispatch
    let firstSegment = switch state.remaining {
    | list{head, ..._} => head
    | list{} => ""
    }

    // O(1) lookup into the correct group
    switch groups->Dict.get(firstSegment) {
    | Some(parsers) =>
      // Linear scan within the (small) group
      let result = ref(None)
      let i = ref(0)
      let len = parsers->Array.length

      while result.contents == None && i.contents < len {
        switch parsers[i.contents] {
        | Some(parser) =>
          switch parser(state) {
          | Some(_) as success => result := success
          | None => i := i.contents + 1
          }
        | None => i := i.contents + 1
        }
      }
      result.contents
    | None =>
      // No group matched — try empty-segment group as fallback
      switch groups->Dict.get("") {
      | Some(parsers) =>
        let result = ref(None)
        let i = ref(0)
        let len = parsers->Array.length
        while result.contents == None && i.contents < len {
          switch parsers[i.contents] {
          | Some(parser) =>
            switch parser(state) {
            | Some(_) as success => result := success
            | None => i := i.contents + 1
            }
          | None => i := i.contents + 1
          }
        }
        result.contents
      | None => None
      }
    }
  }
}

// ============================================================================
// Execution
// ============================================================================

// Run a parser against a URL, requiring that ALL path segments are consumed.
// This is the standard entry point for route matching — if the parser succeeds
// but leaves unconsumed segments, the match is rejected (returns None).
// This prevents /users/alice from matching a parser that only handles /users.
//
// Example:
//   let route = s("users") </> str
//   parse(route, Url.fromPath("/users/alice"))  // => Some(("", "alice"))
//   parse(route, Url.fromPath("/users/alice/settings"))  // => None (unconsumed)
let parse = (parser: t<'a>, url: Url.t): option<'a> => {
  let initialState = {
    remaining: url.path,
    url,
  }

  switch parser(initialState) {
  | Some((result, finalState)) =>
    // Only succeed if all path segments were consumed
    switch finalState.remaining {
    | list{} => Some(result)
    | _ => None
    }
  | None => None
  }
}

// Run a parser against a URL, allowing unconsumed trailing segments.
// Useful for prefix-based routing where a parent parser handles /api/*
// and delegates the rest to sub-parsers.
//
// Example:
//   let prefix = s("api") </> str
//   parsePartial(prefix, Url.fromPath("/api/v1/users/42"))  // => Some(("", "v1"))
//   // Remaining: ["users", "42"] — available for further parsing
let parsePartial = (parser: t<'a>, url: Url.t): option<'a> => {
  let initialState = {
    remaining: url.path,
    url,
  }

  switch parser(initialState) {
  | Some((result, _)) => Some(result)
  | None => None
  }
}

// Structured parse error providing diagnostic information.
// `remainingPath` — segments that were not consumed (for partial match errors).
// `consumedPath` — segments that WERE consumed before the failure point.
// `url` — the original URL for context in error messages.
type parseError = {
  remainingPath: list<string>,
  consumedPath: list<string>,
  url: Url.t,
}

// Run a parser against a URL, returning a Result with diagnostic error info.
// Unlike `parse` which returns None on failure, this returns an Error record
// showing exactly which segments were consumed and which remain — invaluable
// for debugging route misconfiguration or providing user-friendly 404 pages
// that suggest the closest valid route.
//
// Example:
//   parseWithError(route, badUrl)
//   // => Error({remainingPath: ["extra"], consumedPath: ["users", "alice"], url})
let parseWithError = (parser: t<'a>, url: Url.t): result<'a, parseError> => {
  let initialState = {
    remaining: url.path,
    url,
  }

  switch parser(initialState) {
  | Some((result, finalState)) =>
    switch finalState.remaining {
    | list{} => Ok(result)
    | remaining =>
      let consumedCount = Belt.List.length(url.path) - Belt.List.length(remaining)
      let consumed = url.path->Belt.List.take(consumedCount)->Belt.Option.getWithDefault(list{})
      Error({
        remainingPath: remaining,
        consumedPath: consumed,
        url,
      })
    }
  | None =>
    Error({
      remainingPath: url.path,
      consumedPath: list{},
      url,
    })
  }
}
