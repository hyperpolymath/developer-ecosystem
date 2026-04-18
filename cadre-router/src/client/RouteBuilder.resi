// SPDX-License-Identifier: Apache-2.0
// RouteBuilder.resi - Bidirectional route definitions
//
// This module provides a way to define routes where parsing and serialization
// are guaranteed to be consistent. Define your route pattern once, and get
// both a parser and a toString function that match.
//
// Example:
// ```rescript
// // Define a bidirectional route
// let userRoute = RouteBuilder.(
//   lit("user") /> int() |> build(id => User(id), route =>
//     switch route { | User(id) => Some(id) | _ => None }
//   )
// )
//
// // Use it
// userRoute.parse(Url.fromString("/user/42"))  // => Some(User(42))
// userRoute.toString(User(42))                  // => "/user/42"
// ```

/**
 * A bidirectional route definition.
 * Contains both a parser and serializer that are guaranteed to be consistent.
 */
type t<'route> = {
  parse: Url.t => option<'route>,
  toString: 'route => option<string>,
}

/**
 * Segment builder - used to construct route patterns
 */
type segment<'a>

/**
 * Literal path segment (e.g., "user", "profile")
 */
let lit: string => segment<unit>

/**
 * String capture segment
 */
let str: unit => segment<string>

/**
 * Integer capture segment
 */
let int: unit => segment<int>

/**
 * Custom segment with bidirectional conversion
 */
let custom: (
  ~parse: string => option<'a>,
  ~serialize: 'a => string
) => segment<'a>

/**
 * Compose two segments: a /> b
 */
let andThen: (segment<'a>, segment<'b>) => segment<('a, 'b)>

/**
 * Compose two segments: a /> b (alias for andThen)
 */
let \"/>": (segment<'a>, segment<'b>) => segment<('a, 'b)>

/**
 * Match end of path
 */
let end_: segment<unit>

/**
 * Build a route from a segment pattern.
 *
 * @param toRoute - Convert parsed values to your route type
 * @param fromRoute - Extract values from route for serialization (return None if route doesn't match this pattern)
 */
let build: (
  segment<'a>,
  ~toRoute: 'a => 'route,
  ~fromRoute: 'route => option<'a>
) => t<'route>

/**
 * Combine multiple routes into one.
 * First matching route wins for parsing.
 * First route that returns Some for toString wins for serialization.
 */
let oneOf: array<t<'route>> => t<'route>

/**
 * Create a complete router module from a route definition.
 */
module Make: (Config: {
  type route
  let definition: t<route>
  let notFound: route
}) => {
  let parse: Url.t => Config.route
  let parseOption: Url.t => option<Config.route>
  let toString: Config.route => string
}
