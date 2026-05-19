// SPDX-License-Identifier: PMPL-1.0-or-later
// Alib_Option.res - Extended option utilities implementation

type t<'a> = option<'a>

// =============================================================================
// BASIC COMBINATORS
// =============================================================================

@inline
let map = (option, fn) =>
  switch option {
  | Some(value) => Some(fn(value))
  | None => None
  }

@inline
let flatMap = (option, fn) =>
  switch option {
  | Some(value) => fn(value)
  | None => None
  }

let bind = flatMap

// =============================================================================
// EARLY RETURN HELPERS
// =============================================================================

@inline
let guard = (condition) =>
  if condition {
    Some()
  } else {
    None
  }

@inline
let require = (condition, value) =>
  if condition {
    Some(value)
  } else {
    None
  }

// =============================================================================
// RECOVERY & FALLBACKS
// =============================================================================

@inline
let getWithDefault = (option, default) =>
  switch option {
  | Some(value) => value
  | None => default
  }

@inline
let orElse = (first, second) =>
  switch first {
  | Some(value) => Some(value)
  | None => second
  }

// =============================================================================
// PREDICATES
// =============================================================================

@inline
let isSome = (option) =>
  switch option {
  | Some(_) => true
  | None => false
  }

@inline
let isNone = (option) =>
  switch option {
  | Some(_) => false
  | None => true
  }

let getExn = (option) =>
  switch option {
  | Some(value) => value
  | None => Js.Exn.raiseError("Option.getExn called on None")
  }

// =============================================================================
// CONVERSIONS
// =============================================================================

@inline
let toResult = (option, error) =>
  switch option {
  | Some(value) => Ok(value)
  | None => Error(error)
  }

@inline
let fromResult = (result) =>
  switch result {
  | Ok(value) => Some(value)
  | Error(_) => None
  }

// =============================================================================
// SIDE EFFECTS
// =============================================================================

@inline
let tap = (option, fn) => {
  switch option {
  | Some(value) => fn(value)
  | None => ()
  }
  option
}

// =============================================================================
// INFIX OPERATORS
// =============================================================================

module Infix = {
  @inline
  let \"<$>" = (fn, option) => map(option, fn)

  @inline
  let \"=<<" = (fn, option) => flatMap(option, fn)

  @inline
  let \">>=" = (option, fn) => flatMap(option, fn)

  @inline
  let \"<|>" = (first, second) => orElse(first, second)
}
