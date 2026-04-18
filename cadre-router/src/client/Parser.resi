// SPDX-License-Identifier: Apache-2.0
// Parser.resi - Elm-style URL parser combinators

/**
 * Parser state: remaining path segments and the URL for query access
 */
type state = {
  remaining: list<string>,
  url: Url.t,
}

/**
 * A parser that consumes path segments and produces a value of type 'a.
 * Returns None if parsing fails.
 */
type t<'a> = state => option<('a, state)>

// === Path Segment Matchers ===

/** Match a literal path segment. Fails if segment doesn't match. */
let s: string => t<unit>

/** Capture any non-empty string segment */
let str: t<string>

/** Capture an integer segment. Fails if not a valid integer. */
let int: t<int>

/** Custom segment parser. Use for typed IDs like JourneyId.t */
let custom: (string => option<'a>) => t<'a>

/** Match end of path (no more segments). Use to ensure exact match. */
let top: t<unit>

// === Combinators ===

/** Sequential composition: match A then B */
let andThen: (t<'a>, t<'b>) => t<('a, 'b)>

/** Operator form of andThen: parserA </> parserB */
let \"</>": (t<'a>, t<'b>) => t<('a, 'b)>

/** Transform parser result */
let map: (t<'a>, 'a => 'b) => t<'b>

/** Operator form: fn <$> parser (applicative-style) */
let \"<$>": ('a => 'b, t<'a>) => t<'b>

/** Try alternatives in order until one succeeds */
let oneOf: array<t<'a>> => t<'a>

/** Optional: succeed with None if parser fails */
let optional: t<'a> => t<option<'a>>

// === Query Parameters ===

/** Parse optional query parameter */
let query: string => t<option<string>>

/** Parse optional query parameter as int */
let queryInt: string => t<option<int>>

/** Parse optional query parameter as bool */
let queryBool: string => t<option<bool>>

/** Parse required query parameter (fails if missing) */
let queryRequired: string => t<string>

// === Advanced Segment Matchers ===

/**
 * Match a UUID segment (8-4-4-4-12 hex format).
 * Example: "550e8400-e29b-41d4-a716-446655440000"
 */
let uuid: t<string>

/**
 * Match a URL-safe slug (lowercase alphanumeric + hyphens).
 * Example: "my-blog-post-title"
 */
let slug: t<string>

/**
 * Match a float/decimal number.
 * Example: "3.14", "-42.5", "100"
 */
let float: t<float>

/**
 * Match one of a fixed set of strings (enum-like).
 * Example: enum(["asc", "desc"]) matches "asc" or "desc"
 */
let enum: array<string> => t<string>

/**
 * Match using a regular expression.
 * Returns the full match if successful.
 * Example: regex(%re"/^[a-z]{2,3}$/") for language codes
 */
let regex: Js.Re.t => t<string>

/**
 * Capture all remaining path segments as a list.
 * Useful for catch-all routes like /files/path/to/file.txt
 */
let rest: t<list<string>>

/**
 * Capture all remaining path segments joined as a string.
 * Example: /files/a/b/c.txt -> "a/b/c.txt"
 */
let restAsString: t<string>

// === Fragment ===

/** Parse the URL fragment (hash). Returns None if no fragment. */
let fragment: t<option<string>>

/** Parse required fragment (fails if no fragment). */
let fragmentRequired: t<string>

// === Control Flow ===

/** Always succeed with the given value, consuming nothing. */
let succeed: 'a => t<'a>

/** Always fail. */
let fail: t<'a>

/** Lazy parser - for recursive route definitions. */
let lazy_: (unit => t<'a>) => t<'a>

/**
 * Conditional parser - only parse if predicate is true.
 * Example: filter(int, n => n > 0) for positive integers
 */
let filter: (t<'a>, 'a => bool) => t<'a>

/**
 * Parse with a fallback value if parser fails.
 * Example: withDefault(int, 1) returns 1 if no int found
 */
let withDefault: (t<'a>, 'a) => t<'a>

/**
 * Try parser, but don't consume input on failure (backtracking).
 */
let attempt: t<'a> => t<'a>

// === Debugging ===

/**
 * Debug helper - logs parser state and result.
 * Only for development, remove in production.
 */
let debug: (string, t<'a>) => t<'a>

// === Execution ===

/** Run parser against a URL. Returns Some if successful and all path consumed. */
let parse: (t<'a>, Url.t) => option<'a>

/** Run parser, allowing unconsumed path segments */
let parsePartial: (t<'a>, Url.t) => option<'a>

/**
 * Parse with detailed error information.
 * Returns either the result or error info about where parsing failed.
 */
type parseError = {
  remainingPath: list<string>,
  consumedPath: list<string>,
  url: Url.t,
}

let parseWithError: (t<'a>, Url.t) => result<'a, parseError>
