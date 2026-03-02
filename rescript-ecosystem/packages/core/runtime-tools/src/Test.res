// SPDX-License-Identifier: AGPL-3.0-or-later
// Runtime-aware test runner abstraction

type testResult = {
  name: string,
  passed: bool,
  duration: float,
  error: option<string>,
}

type testSuite = {
  name: string,
  tests: array<testResult>,
  passed: int,
  failed: int,
  duration: float,
}

// Test function signature
type testFn = unit => promise<unit>
type testDef = {name: string, fn: testFn}

// Deno test bindings
module DenoTest = {
  type testContext

  @scope("Deno") @val
  external test: (string, unit => promise<unit>) => unit = "test"

  @scope("Deno") @val
  external testWithOptions: ({"name": string, "fn": unit => promise<unit>, "ignore": bool}) => unit =
    "test"
}

// Bun test bindings
module BunTest = {
  @module("bun:test") external test: (string, unit => promise<unit>) => unit = "test"
  @module("bun:test") external describe: (string, unit => unit) => unit = "describe"
  @module("bun:test") external expect: 'a => 'expect = "expect"
  @module("bun:test") external beforeAll: (unit => promise<unit>) => unit = "beforeAll"
  @module("bun:test") external afterAll: (unit => promise<unit>) => unit = "afterAll"
}

// Assertion helpers (runtime-agnostic)
module Assert = {
  exception AssertionError(string)

  let equal = (actual: 'a, expected: 'a, ~message: string=""): unit => {
    if actual != expected {
      let msg = message == "" ? "Values are not equal" : message
      raise(AssertionError(msg))
    }
  }

  let notEqual = (actual: 'a, expected: 'a, ~message: string=""): unit => {
    if actual == expected {
      let msg = message == "" ? "Values should not be equal" : message
      raise(AssertionError(msg))
    }
  }

  let isTrue = (value: bool, ~message: string=""): unit => {
    if !value {
      let msg = message == "" ? "Expected true" : message
      raise(AssertionError(msg))
    }
  }

  let isFalse = (value: bool, ~message: string=""): unit => {
    if value {
      let msg = message == "" ? "Expected false" : message
      raise(AssertionError(msg))
    }
  }

  let throws = (fn: unit => 'a, ~message: string=""): unit => {
    let threw = try {
      let _ = fn()
      false
    } catch {
    | _ => true
    }
    if !threw {
      let msg = message == "" ? "Expected function to throw" : message
      raise(AssertionError(msg))
    }
  }

  let rejects = async (fn: unit => promise<'a>, ~message: string=""): unit => {
    let rejected = try {
      let _ = await fn()
      false
    } catch {
    | _ => true
    }
    if !rejected {
      let msg = message == "" ? "Expected promise to reject" : message
      raise(AssertionError(msg))
    }
  }
}

// Unified test registration
let test = (name: string, fn: testFn): unit => {
  switch Detect.detect() {
  | Detect.Deno => DenoTest.test(name, fn)
  | Detect.Bun => BunTest.test(name, fn)
  | _ => Js.Console.error(`Test "${name}" skipped - unsupported runtime`)
  }
}

// Test with options
let testSkip = (name: string, fn: testFn): unit => {
  switch Detect.detect() {
  | Detect.Deno => DenoTest.testWithOptions({"name": name, "fn": fn, "ignore": true})
  | Detect.Bun =>
    // Bun uses test.skip but we'll just log
    Js.Console.log(`⏭️ Skipping: ${name}`)
  | _ => ()
  }
}

// Suite builder for organizing tests
module Suite = {
  type t = {
    name: string,
    mutable tests: array<testDef>,
    mutable beforeAll: option<testFn>,
    mutable afterAll: option<testFn>,
  }

  let make = (name: string): t => {
    name,
    tests: [],
    beforeAll: None,
    afterAll: None,
  }

  let addTest = (suite: t, name: string, fn: testFn): t => {
    suite.tests = suite.tests->Js.Array2.concat([{name, fn}])
    suite
  }

  let setBeforeAll = (suite: t, fn: testFn): t => {
    suite.beforeAll = Some(fn)
    suite
  }

  let setAfterAll = (suite: t, fn: testFn): t => {
    suite.afterAll = Some(fn)
    suite
  }

  let run = async (suite: t): testSuite => {
    let startTime = Js.Date.now()
    let results: array<testResult> = []
    let passed = ref(0)
    let failed = ref(0)

    // Run beforeAll if exists
    switch suite.beforeAll {
    | Some(fn) =>
      try {
        await fn()
      } catch {
      | _ => Js.Console.error("beforeAll failed")
      }
    | None => ()
    }

    // Run each test
    for i in 0 to suite.tests->Js.Array2.length - 1 {
      let testDef = suite.tests[i]
      switch testDef {
      | Some({name, fn}) => {
          let testStart = Js.Date.now()
          let result = try {
            await fn()
            passed := passed.contents + 1
            {
              name,
              passed: true,
              duration: Js.Date.now() -. testStart,
              error: None,
            }
          } catch {
          | Assert.AssertionError(msg) => {
              failed := failed.contents + 1
              {
                name,
                passed: false,
                duration: Js.Date.now() -. testStart,
                error: Some(msg),
              }
            }
          | Js.Exn.Error(e) => {
              failed := failed.contents + 1
              {
                name,
                passed: false,
                duration: Js.Date.now() -. testStart,
                error: Js.Exn.message(e),
              }
            }
          | _ => {
              failed := failed.contents + 1
              {
                name,
                passed: false,
                duration: Js.Date.now() -. testStart,
                error: Some("Unknown error"),
              }
            }
          }
          let _ = results->Js.Array2.push(result)
        }
      | None => ()
      }
    }

    // Run afterAll if exists
    switch suite.afterAll {
    | Some(fn) =>
      try {
        await fn()
      } catch {
      | _ => Js.Console.error("afterAll failed")
      }
    | None => ()
    }

    {
      name: suite.name,
      tests: results,
      passed: passed.contents,
      failed: failed.contents,
      duration: Js.Date.now() -. startTime,
    }
  }

  let printResults = (suite: testSuite): unit => {
    Js.Console.log(`\n📋 ${suite.name}`)
    Js.Console.log(`${"─"->Js.String2.repeat(40)}`)

    suite.tests->Js.Array2.forEach(result => {
      let icon = result.passed ? "✅" : "❌"
      let time = result.duration->Js.Float.toFixedWithPrecision(~digits=2)
      Js.Console.log(`  ${icon} ${result.name} (${time}ms)`)
      switch result.error {
      | Some(err) => Js.Console.log(`     └─ ${err}`)
      | None => ()
      }
    })

    let total = suite.passed + suite.failed
    let pct =
      total > 0
        ? ((suite.passed->Belt.Int.toFloat /. total->Belt.Int.toFloat) *. 100.0)
            ->Js.Float.toFixedWithPrecision(~digits=1)
        : "0.0"
    Js.Console.log(`\n  ${suite.passed->Belt.Int.toString}/${total->Belt.Int.toString} passed (${pct}%)`)
    Js.Console.log(`  Total time: ${suite.duration->Js.Float.toFixedWithPrecision(~digits=2)}ms\n`)
  }
}
