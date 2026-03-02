// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@uncurried

/**
 * Extended Result utilities for error handling.
 */

/** Map over the Ok value */
let map = (result: result<'a, 'e>, fn: 'a => 'b): result<'b, 'e> => {
  switch result {
  | Ok(value) => Ok(fn(value))
  | Error(err) => Error(err)
  }
}

/** Map over the Error value */
let mapError = (result: result<'a, 'e>, fn: 'e => 'f): result<'a, 'f> => {
  switch result {
  | Ok(value) => Ok(value)
  | Error(err) => Error(fn(err))
  }
}

/** Flat map (bind) for chaining Results */
let flatMap = (result: result<'a, 'e>, fn: 'a => result<'b, 'e>): result<'b, 'e> => {
  switch result {
  | Ok(value) => fn(value)
  | Error(err) => Error(err)
  }
}

/** Get the Ok value or a default */
let getOr = (result: result<'a, 'e>, default: 'a): 'a => {
  switch result {
  | Ok(value) => value
  | Error(_) => default
  }
}

/** Get the Ok value or compute a default from the error */
let getOrElse = (result: result<'a, 'e>, fn: 'e => 'a): 'a => {
  switch result {
  | Ok(value) => value
  | Error(err) => fn(err)
  }
}

/** Convert Option to Result */
let fromOption = (opt: option<'a>, error: 'e): result<'a, 'e> => {
  switch opt {
  | Some(value) => Ok(value)
  | None => Error(error)
  }
}

/** Convert Result to Option (discarding error) */
let toOption = (result: result<'a, 'e>): option<'a> => {
  switch result {
  | Ok(value) => Some(value)
  | Error(_) => None
  }
}

/** Check if Result is Ok */
let isOk = (result: result<'a, 'e>): bool => {
  switch result {
  | Ok(_) => true
  | Error(_) => false
  }
}

/** Check if Result is Error */
let isError = (result: result<'a, 'e>): bool => {
  switch result {
  | Ok(_) => false
  | Error(_) => true
  }
}

/** Combine two Results - both must be Ok */
let both = (r1: result<'a, 'e>, r2: result<'b, 'e>): result<('a, 'b), 'e> => {
  switch (r1, r2) {
  | (Ok(a), Ok(b)) => Ok((a, b))
  | (Error(e), _) => Error(e)
  | (_, Error(e)) => Error(e)
  }
}

/** Collect an array of Results into a Result of array */
let all = (results: array<result<'a, 'e>>): result<array<'a>, 'e> => {
  results->Array.reduce(Ok([]), (acc, result) => {
    switch (acc, result) {
    | (Ok(arr), Ok(value)) => Ok(arr->Array.concat([value]))
    | (Error(e), _) => Error(e)
    | (_, Error(e)) => Error(e)
    }
  })
}

/** Try a function that might throw, returning Result */
let tryCatch = (fn: unit => 'a, onError: exn => 'e): result<'a, 'e> => {
  try {
    Ok(fn())
  } catch {
  | e => Error(onError(e))
  }
}

/** Async version of tryCatch */
let tryCatchAsync = async (fn: unit => promise<'a>, onError: exn => 'e): result<'a, 'e> => {
  try {
    Ok(await fn())
  } catch {
  | e => Error(onError(e))
  }
}

/** Tap into Ok value without changing it */
let tap = (result: result<'a, 'e>, fn: 'a => unit): result<'a, 'e> => {
  switch result {
  | Ok(value) =>
    fn(value)
    Ok(value)
  | Error(err) => Error(err)
  }
}

/** Tap into Error value without changing it */
let tapError = (result: result<'a, 'e>, fn: 'e => unit): result<'a, 'e> => {
  switch result {
  | Ok(value) => Ok(value)
  | Error(err) =>
    fn(err)
    Error(err)
  }
}
