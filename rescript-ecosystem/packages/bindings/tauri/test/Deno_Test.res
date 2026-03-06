// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Deno_Test.res - ReScript bindings for Deno's test runner

open RescriptCore

/** Test options */
type testOptions = {
  name: string,
  ignore?: bool,
  only?: bool,
  sanitizeOps?: bool,
  sanitizeResources?: bool,
  sanitizeExit?: bool,
}

/** Test context passed to test functions */
type testContext = {step: (string, unit => promise<unit>) => promise<unit>}

/** Register a test with Deno */
@val @scope("Deno")
external test: (string, unit => promise<unit>) => unit = "test"

/** Register a test with options */
@val @scope("Deno")
external testWithOptions: (testOptions, unit => promise<unit>) => unit = "test"

/** Register a test with context (for subtests) */
@val @scope("Deno")
external testWithContext: (string, testContext => promise<unit>) => unit = "test"

// ============================================================================
// Assertion Helpers
// ============================================================================

module Assert = {
  /** Assert condition is true */
  let isTrue = (condition: bool, ~msg: string="Expected true") => {
    if !condition {
      Exn.raiseError(msg)
    }
  }

  /** Assert condition is false */
  let isFalse = (condition: bool, ~msg: string="Expected false") => {
    if condition {
      Exn.raiseError(msg)
    }
  }

  /** Assert values are equal */
  let equals = (actual: 'a, expected: 'a, ~msg: string="Values not equal") => {
    if actual != expected {
      Exn.raiseError(msg)
    }
  }

  /** Assert values are not equal */
  let notEquals = (actual: 'a, expected: 'a, ~msg: string="Values should not be equal") => {
    if actual == expected {
      Exn.raiseError(msg)
    }
  }

  /** Assert option is Some */
  let isSome = (opt: option<'a>, ~msg: string="Expected Some, got None") => {
    switch opt {
    | Some(_) => ()
    | None => Exn.raiseError(msg)
    }
  }

  /** Assert option is None */
  let isNone = (opt: option<'a>, ~msg: string="Expected None, got Some") => {
    switch opt {
    | Some(_) => Exn.raiseError(msg)
    | None => ()
    }
  }

  /** Assert result is Ok */
  let isOk = (res: result<'a, 'e>, ~msg: string="Expected Ok, got Error") => {
    switch res {
    | Ok(_) => ()
    | Error(_) => Exn.raiseError(msg)
    }
  }

  /** Assert result is Error */
  let isError = (res: result<'a, 'e>, ~msg: string="Expected Error, got Ok") => {
    switch res {
    | Ok(_) => Exn.raiseError(msg)
    | Error(_) => ()
    }
  }

  /** Assert array has expected length */
  let hasLength = (arr: array<'a>, expected: int, ~msg: string="Array length mismatch") => {
    let actual = Array.length(arr)
    if actual != expected {
      Exn.raiseError(`${msg}: expected ${Int.toString(expected)}, got ${Int.toString(actual)}`)
    }
  }

  /** Assert string contains substring */
  let contains = (str: string, substr: string, ~msg: string="String does not contain expected substring") => {
    if !String.includes(str, substr) {
      Exn.raiseError(msg)
    }
  }

  /** Assert function throws */
  let throws = (fn: unit => 'a, ~msg: string="Expected function to throw") => {
    try {
      let _ = fn()
      Exn.raiseError(msg)
    } catch {
    | _ => ()
    }
  }

  /** Assert async function throws */
  let throwsAsync = async (fn: unit => promise<'a>, ~msg: string="Expected async function to throw") => {
    try {
      let _ = await fn()
      Exn.raiseError(msg)
    } catch {
    | _ => ()
    }
  }

  /** Fail unconditionally */
  let fail = (msg: string) => {
    Exn.raiseError(msg)
  }
}

// ============================================================================
// Test Helpers
// ============================================================================

/** Skip a test */
let skip = (name: string, _fn: unit => promise<unit>) => {
  testWithOptions({name, ignore: true}, async () => ())
}

/** Run only this test */
let only = (name: string, fn: unit => promise<unit>) => {
  testWithOptions({name, only: true}, fn)
}

/** Group related tests */
let describe = (groupName: string, tests: array<(string, unit => promise<unit>)>) => {
  Array.forEach(tests, ((name, fn)) => {
    test(`${groupName} > ${name}`, fn)
  })
}
