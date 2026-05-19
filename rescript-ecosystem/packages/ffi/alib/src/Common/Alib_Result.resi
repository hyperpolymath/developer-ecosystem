// SPDX-License-Identifier: PMPL-1.0-or-later
// Alib_Result.resi - Extended result combinators
// Philosophy: Make early-return patterns ergonomic without syntax extensions

// Re-export Belt.Result for convenience
type t<'a, 'e> = result<'a, 'e>

// =============================================================================
// BASIC COMBINATORS (Standard functional programming)
// =============================================================================

// Map the Ok value, leave Error unchanged
let map: (t<'a, 'e>, 'a => 'b) => t<'b, 'e>

// Map the Error value, leave Ok unchanged
let mapError: (t<'a, 'e>, 'e => 'f) => t<'a, 'f>

// Chain result-returning functions (flatMap/bind)
let flatMap: (t<'a, 'e>, 'a => t<'b, 'e>) => t<'b, 'e>

// Alias for flatMap (monadic bind)
let bind: (t<'a, 'e>, 'a => t<'b, 'e>) => t<'b, 'e>

// =============================================================================
// EARLY RETURN HELPERS (Works with rescript-early-return)
// =============================================================================

// Guard: Early return if condition is false
// Usage: %return.error(Result.guard(isValid(x), "invalid"))
let guard: (bool, 'e) => t<unit, 'e>

// Require: Early return if option is None
// Usage: %return.error(Result.requireSome(maybeValue, "missing"))
let requireSome: (option<'a>, 'e) => t<'a, 'e>

// Require non-empty string
let requireNonEmpty: (string, 'e) => t<string, 'e>

// =============================================================================
// RECOVERY & FALLBACKS
// =============================================================================

// Recover from error with default value
let getWithDefault: (t<'a, 'e>, 'a) => 'a

// Recover from error with function
let recover: (t<'a, 'e>, 'e => 'a) => 'a

// Try alternative if first result is Error
let orElse: (t<'a, 'e>, t<'a, 'e>) => t<'a, 'e>

// =============================================================================
// MULTIPLE RESULTS
// =============================================================================

// Combine two results into tuple (both must be Ok)
let both: (t<'a, 'e>, t<'b, 'e>) => t<('a, 'b), 'e>

// Combine three results into tuple
let all3: (t<'a, 'e>, t<'b, 'e>, t<'c, 'e>) => t<('a, 'b, 'c), 'e>

// Convert array of results to result of array (all must be Ok)
let allArray: array<t<'a, 'e>> => t<array<'a>, 'e>

// =============================================================================
// PREDICATES & INSPECTION
// =============================================================================

let isOk: t<'a, 'e> => bool
let isError: t<'a, 'e> => bool

// Get Ok value or raise exception (use sparingly!)
let getExn: t<'a, 'e> => 'a

// Get Error value or raise exception
let getErrorExn: t<'a, 'e> => 'e

// Convert to option (discard error)
let toOption: t<'a, 'e> => option<'a>

// =============================================================================
// SIDE EFFECTS
// =============================================================================

// Tap: Run side effect on Ok value, return original result
let tap: (t<'a, 'e>, 'a => unit) => t<'a, 'e>

// TapError: Run side effect on Error value, return original result
let tapError: (t<'a, 'e>, 'e => unit) => t<'a, 'e>

// =============================================================================
// INFIX OPERATORS (Optional, enable with: open Alib.Result.Infix)
// =============================================================================

module Infix: {
  // Map: result->map(fn) becomes result |> (fn <$>)
  let \"<$>": ('a => 'b, t<'a, 'e>) => t<'b, 'e>

  // FlatMap: result->flatMap(fn) becomes result |> (fn =<<)
  let \"=<<": ('a => t<'b, 'e>, t<'a, 'e>) => t<'b, 'e>

  // FlatMap (flipped): result >>= fn
  let \">>=": (t<'a, 'e>, 'a => t<'b, 'e>) => t<'b, 'e>

  // OrElse: result1 <|> result2
  let \"<|>": (t<'a, 'e>, t<'a, 'e>) => t<'a, 'e>
}
