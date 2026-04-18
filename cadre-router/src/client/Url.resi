// SPDX-License-Identifier: Apache-2.0
// Url.resi - Parsed URL representation for client-side routing

/**
 * Represents a parsed URL with path segments, query parameters, and fragment.
 *
 * Example: "/journey/abc123?tab=map#section"
 * => { path: ["journey", "abc123"], query: {"tab": "map"}, fragment: Some("section") }
 */
type t = {
  path: list<string>,
  query: Belt.Map.String.t<string>,
  fragment: option<string>,
}

/** Parse a URL string into components */
let fromString: string => t

/** Get current browser location as Url.t */
let fromLocation: unit => t

/** Serialize back to URL string */
let toString: t => string

/** Get a query parameter by key */
let getQueryParam: (t, string) => option<string>

/** Get a query parameter as int */
let getQueryParamInt: (t, string) => option<int>

/** Get a query parameter as bool ("true"/"false" or "1"/"0") */
let getQueryParamBool: (t, string) => option<bool>

/** Check if path is empty (root) */
let isRoot: t => bool

/** Get path as a string (without query/fragment) */
let pathToString: t => string
