// SPDX-License-Identifier: PMPL-1.0-or-later
// Alib_Result.res - Extended result combinators implementation

type t<'a, 'e> = result<'a, 'e>

// =============================================================================
// BASIC COMBINATORS
// =============================================================================

@inline
let map = (result, fn) =>
  switch result {
  | Ok(value) => Ok(fn(value))
  | Error(e) => Error(e)
  }

@inline
let mapError = (result, fn) =>
  switch result {
  | Ok(value) => Ok(value)
  | Error(e) => Error(fn(e))
  }

@inline
let flatMap = (result, fn) =>
  switch result {
  | Ok(value) => fn(value)
  | Error(e) => Error(e)
  }

let bind = flatMap

// =============================================================================
// EARLY RETURN HELPERS
// =============================================================================

@inline
let guard = (condition, error) =>
  if condition {
    Ok()
  } else {
    Error(error)
  }

@inline
let requireSome = (option, error) =>
  switch option {
  | Some(value) => Ok(value)
  | None => Error(error)
  }

@inline
let requireNonEmpty = (str, error) =>
  if str !== "" {
    Ok(str)
  } else {
    Error(error)
  }

// =============================================================================
// RECOVERY & FALLBACKS
// =============================================================================

@inline
let getWithDefault = (result, default) =>
  switch result {
  | Ok(value) => value
  | Error(_) => default
  }

@inline
let recover = (result, fn) =>
  switch result {
  | Ok(value) => value
  | Error(e) => fn(e)
  }

@inline
let orElse = (first, second) =>
  switch first {
  | Ok(value) => Ok(value)
  | Error(_) => second
  }

// =============================================================================
// MULTIPLE RESULTS
// =============================================================================

@inline
let both = (result1, result2) =>
  switch (result1, result2) {
  | (Ok(a), Ok(b)) => Ok((a, b))
  | (Error(e), _) => Error(e)
  | (_, Error(e)) => Error(e)
  }

@inline
let all3 = (result1, result2, result3) =>
  switch (result1, result2, result3) {
  | (Ok(a), Ok(b), Ok(c)) => Ok((a, b, c))
  | (Error(e), _, _) => Error(e)
  | (_, Error(e), _) => Error(e)
  | (_, _, Error(e)) => Error(e)
  }

let allArray = (results) => {
  let rec loop = (results, acc, index) =>
    if index >= Array.length(results) {
      Ok(acc)
    } else {
      switch results[index] {
      | Ok(value) => loop(results, Array.concat(acc, [value]), index + 1)
      | Error(e) => Error(e)
      }
    }
  loop(results, [], 0)
}

// =============================================================================
// PREDICATES & INSPECTION
// =============================================================================

@inline
let isOk = (result) =>
  switch result {
  | Ok(_) => true
  | Error(_) => false
  }

@inline
let isError = (result) =>
  switch result {
  | Ok(_) => false
  | Error(_) => true
  }

let getExn = (result) =>
  switch result {
  | Ok(value) => value
  | Error(_) => Js.Exn.raiseError("Result.getExn called on Error")
  }

let getErrorExn = (result) =>
  switch result {
  | Ok(_) => Js.Exn.raiseError("Result.getErrorExn called on Ok")
  | Error(e) => e
  }

@inline
let toOption = (result) =>
  switch result {
  | Ok(value) => Some(value)
  | Error(_) => None
  }

// =============================================================================
// SIDE EFFECTS
// =============================================================================

@inline
let tap = (result, fn) => {
  switch result {
  | Ok(value) => fn(value)
  | Error(_) => ()
  }
  result
}

@inline
let tapError = (result, fn) => {
  switch result {
  | Ok(_) => ()
  | Error(e) => fn(e)
  }
  result
}

// =============================================================================
// INFIX OPERATORS
// =============================================================================

module Infix = {
  @inline
  let \"<$>" = (fn, result) => map(result, fn)

  @inline
  let \"=<<" = (fn, result) => flatMap(result, fn)

  @inline
  let \">>=" = (result, fn) => flatMap(result, fn)

  @inline
  let \"<|>" = (first, second) => orElse(first, second)
}
