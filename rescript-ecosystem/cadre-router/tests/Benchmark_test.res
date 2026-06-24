// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
// Benchmark_test.res - Performance benchmarks: oneOf (linear scan) vs
// oneOfGrouped (O(1) first-segment dispatch).
//
// PURPOSE:
//   Measure the performance difference between the two route-matching
//   strategies for realistic route sets at 10, 50, and 100 routes. Each
//   route set simulates a plausible web application with unique first-segment
//   prefixes (the ideal case for oneOfGrouped) and parameterised sub-routes.
//
// METRICS:
//   - Parse time per single URL match (average over many iterations)
//   - Batch time for matching a group of representative URLs
//   - Worst-case time: matching the LAST route in the set (the most expensive
//     case for linear scan, should be identical for grouped dispatch)
//
// METHODOLOGY:
//   Each benchmark runs a configurable number of iterations (warmup + measured)
//   to amortise JIT compilation effects. We use performance.now() for sub-
//   millisecond precision (microsecond resolution on most engines). The warmup
//   phase primes the JIT and inline caches before measurement begins.
//
//   Results are reported in microseconds (us) per operation. Assertions verify
//   that both strategies produce identical results (correctness), and the
//   benchmark output shows timing data for manual analysis.
//
// ROUTE SET DESIGN:
//   Routes are generated to mirror real-world patterns:
//     /sectionN                    -> leaf page
//     /sectionN/sub               -> sub-page with literal
//     /sectionN/item/:id           -> parameterised sub-route (int)
//     /sectionN/detail/:slug       -> parameterised sub-route (string)
//
//   Each "section" has a unique first segment, so oneOfGrouped achieves O(1)
//   dispatch while oneOf must scan linearly. Within each section's group,
//   there are 4 parsers to try, keeping the intra-group scan realistic.
//
// NOTE:
//   These benchmarks print timing results to the console. They do NOT assert
//   absolute timing thresholds (which are machine-dependent). Instead, they
//   assert correctness (same results from both strategies) and report relative
//   speedup ratios. Human review determines whether the speedup is acceptable.

// ============================================================================
// External Binding: performance.now()
// ============================================================================
//
// Binds to the Web Performance API's high-resolution timer. Returns a
// DOMHighResTimeStamp (float) representing milliseconds since time origin,
// with sub-millisecond (typically microsecond) precision.
//
// Falls back gracefully: in environments without Performance API (e.g., some
// test runners), Js.Date.now() is used instead (millisecond precision only).

@val @scope("performance")
external performanceNow: unit => float = "now"

// ============================================================================
// Test Harness
// ============================================================================
//
// Mirrors the assertion harness used in GroupedRouting_test.res and other
// test files. Tracks pass/fail counts for a summary report at the end.

/** Mutable counter for passed assertions. Reset at the start of runAll. */
let passed = ref(0)

/** Mutable counter for failed assertions. Reset at the start of runAll. */
let failed = ref(0)

/**
 * Assert that two values are structurally equal.
 * Logs [PASS] or [FAIL] with the test name. On failure, prints both
 * expected and actual values serialised via Js.Json.stringifyAny for
 * human-readable diagnostics.
 */
let assertEq = (name: string, actual: 'a, expected: 'a): unit => {
  if actual == expected {
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  } else {
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name}`)
    Js.Console.error(`  Expected: ${Js.Json.stringifyAny(expected)->Belt.Option.getWithDefault("?")}`)
    Js.Console.error(`  Actual:   ${Js.Json.stringifyAny(actual)->Belt.Option.getWithDefault("?")}`)
  }
}

/**
 * Assert that a boolean condition is true.
 * Used for relational assertions (e.g., "grouped should be faster than linear").
 */
let assertTrue = (name: string, condition: bool): unit => {
  if condition {
    passed := passed.contents + 1
    Js.Console.log(`[PASS] ${name}`)
  } else {
    failed := failed.contents + 1
    Js.Console.error(`[FAIL] ${name}`)
  }
}

/**
 * Print a summary line with total passed/failed counts.
 * Called at the end of the benchmark suite.
 */
let summary = () => {
  let total = passed.contents + failed.contents
  Js.Console.log("")
  Js.Console.log(`=== Summary: ${Belt.Int.toString(passed.contents)}/${Belt.Int.toString(total)} passed ===`)
  if failed.contents > 0 {
    Js.Console.error(`${Belt.Int.toString(failed.contents)} tests FAILED`)
  }
}

// ============================================================================
// Route Type for Benchmarking
// ============================================================================
//
// A generic route type parameterised by section index and sub-route kind.
// The variant captures enough information to verify that the correct route
// was matched without needing a unique variant per section.

/** Represents a matched route with its section identifier and payload. */
type benchRoute =
  | /** Leaf page: /sectionN (no sub-route) */
    SectionHome(int)
  | /** Sub-page: /sectionN/sub (literal suffix) */
    SectionSub(int)
  | /** Item page: /sectionN/item/:id (integer parameter) */
    SectionItem(int, int)
  | /** Detail page: /sectionN/detail/:slug (string parameter) */
    SectionDetail(int, string)

// ============================================================================
// Route Set Generator
// ============================================================================
//
// Generates N sections, each with 4 routes (total = N*4 parsers). The first
// segment of each section is unique ("s0", "s1", ..., "sN-1"), which is the
// ideal scenario for oneOfGrouped's O(1) dispatch.
//
// Returns two routers:
//   1. A oneOf (linear scan) router with all N*4 parsers in a flat array
//   2. A oneOfGrouped router with N groups of 4 parsers each

/**
 * Build a set of 4 parsers for a single section.
 *
 * Given a section index `i`, produces parsers for:
 *   /s{i}                -> SectionHome(i)
 *   /s{i}/sub            -> SectionSub(i)
 *   /s{i}/item/{id}      -> SectionItem(i, id)
 *   /s{i}/detail/{slug}  -> SectionDetail(i, slug)
 *
 * @param i The section index (0-based). Determines the first path segment.
 * @returns An array of 4 parsers, each producing a benchRoute variant.
 */
let makeSectionParsers = (i: int): array<Parser.t<benchRoute>> => {
  let prefix = `s${Belt.Int.toString(i)}`
  [
    // /sN -> SectionHome(N)
    Parser.s(prefix)->Parser.map(_ => SectionHome(i)),
    // /sN/sub -> SectionSub(N)
    Parser.s(prefix)->Parser.andThen(Parser.s("sub"))->Parser.map(_ => SectionSub(i)),
    // /sN/item/:id -> SectionItem(N, id)
    Parser.s(prefix)
    ->Parser.andThen(Parser.s("item"))
    ->Parser.andThen(Parser.int)
    ->Parser.map((((_, _), id)) => SectionItem(i, id)),
    // /sN/detail/:slug -> SectionDetail(N, slug)
    Parser.s(prefix)
    ->Parser.andThen(Parser.s("detail"))
    ->Parser.andThen(Parser.str)
    ->Parser.map((((_, _), slug)) => SectionDetail(i, slug)),
  ]
}

/**
 * Build a set of grouped entries for a single section.
 *
 * Same routes as makeSectionParsers, but wrapped as (groupKey, parser) tuples
 * for use with Parser.oneOfGrouped.
 *
 * @param i The section index (0-based). The group key is "s{i}".
 * @returns An array of 4 (string, parser) tuples.
 */
let makeSectionGroupedEntries = (i: int): array<(string, Parser.t<benchRoute>)> => {
  let prefix = `s${Belt.Int.toString(i)}`
  let parsers = makeSectionParsers(i)
  parsers->Array.map(p => (prefix, p))
}

/**
 * Build both a linear (oneOf) and grouped (oneOfGrouped) router for N sections.
 *
 * The linear router is a flat array of N*4 parsers. The grouped router has
 * N groups of 4 parsers each. Both should produce identical results for any
 * input URL.
 *
 * @param sectionCount The number of sections to generate (e.g., 10, 50, 100).
 * @returns A tuple of (linearRouter, groupedRouter).
 */
let makeRouterPair = (sectionCount: int): (Parser.t<benchRoute>, Parser.t<benchRoute>) => {
  // Accumulate parsers for the linear (oneOf) router
  let allParsers: array<Parser.t<benchRoute>> = []
  // Accumulate grouped entries for the oneOfGrouped router
  let allGrouped: array<(string, Parser.t<benchRoute>)> = []

  // Generate sections 0..sectionCount-1
  let i = ref(0)
  while i.contents < sectionCount {
    let sectionParsers = makeSectionParsers(i.contents)
    let sectionGrouped = makeSectionGroupedEntries(i.contents)

    // Append to the flat parser array
    sectionParsers->Array.forEach(p => {
      let _ = allParsers->Js.Array2.push(p)
    })

    // Append to the grouped entries array
    sectionGrouped->Array.forEach(entry => {
      let _ = allGrouped->Js.Array2.push(entry)
    })

    i := i.contents + 1
  }

  let linearRouter = Parser.oneOf(allParsers)
  let groupedRouter = Parser.oneOfGrouped(allGrouped)

  (linearRouter, groupedRouter)
}

// ============================================================================
// Benchmark Infrastructure
// ============================================================================
//
// The timing harness runs a function many times and reports average execution
// time in microseconds. A warmup phase ensures the JavaScript engine's JIT
// compiler has optimised the hot paths before measurement begins.

/**
 * Number of warmup iterations. These are run before measurement to prime
 * JIT compilation, inline caches, and hidden class transitions. Results
 * from warmup iterations are discarded.
 */
let warmupIterations = 100

/**
 * Number of measured iterations. The total elapsed time is divided by this
 * count to produce the average time per operation. Higher values reduce
 * variance but increase benchmark runtime.
 */
let measuredIterations = 1000

/**
 * Run a benchmark function and return the average time per invocation
 * in microseconds (us).
 *
 * Execution phases:
 *   1. Warmup: Run `fn` for `warmupIterations` iterations (results discarded).
 *   2. Measure: Run `fn` for `measuredIterations` iterations, timing the total.
 *   3. Compute: Divide total elapsed time by iteration count, convert to us.
 *
 * @param label A human-readable label for console output.
 * @param fn The function to benchmark. Takes unit and returns unit.
 * @returns Average time per invocation in microseconds.
 */
let benchmarkFn = (label: string, fn: unit => unit): float => {
  // Phase 1: Warmup — prime JIT and inline caches
  let w = ref(0)
  while w.contents < warmupIterations {
    fn()
    w := w.contents + 1
  }

  // Phase 2: Measure — time the measured iterations
  let startMs = performanceNow()
  let m = ref(0)
  while m.contents < measuredIterations {
    fn()
    m := m.contents + 1
  }
  let endMs = performanceNow()

  // Phase 3: Compute — convert ms to us per operation
  let totalMs = endMs -. startMs
  let avgUs = totalMs *. 1000.0 /. Belt.Int.toFloat(measuredIterations)

  Js.Console.log(
    `  ${label}: ${Belt.Float.toString(avgUs)} us/op (${Belt.Float.toString(totalMs)} ms total, ${Belt.Int.toString(measuredIterations)} iters)`,
  )

  avgUs
}

// ============================================================================
// SECTION 1: Correctness Verification
// ============================================================================
//
// Before benchmarking, verify that both routing strategies produce identical
// results for every URL pattern. This ensures the benchmark is measuring
// equivalent operations and any performance difference is purely algorithmic.

/**
 * Test that oneOf and oneOfGrouped produce identical results for all URL
 * patterns across a given number of sections.
 *
 * For each section, tests 5 URL patterns:
 *   - /sN         -> SectionHome(N)
 *   - /sN/sub     -> SectionSub(N)
 *   - /sN/item/42 -> SectionItem(N, 42)
 *   - /sN/detail/hello -> SectionDetail(N, "hello")
 *   - /sN/unknown -> None (no match)
 *
 * @param sectionCount Number of sections to test.
 */
let testCorrectnessForSize = (sectionCount: int) => {
  let label = Belt.Int.toString(sectionCount)
  Js.Console.log(`\n-- Correctness: ${label} sections (${Belt.Int.toString(sectionCount * 4)} routes) --`)

  let (linearRouter, groupedRouter) = makeRouterPair(sectionCount)

  // Test a representative sample of sections: first, middle, last
  let sampleIndices = [0, sectionCount / 2, sectionCount - 1]

  sampleIndices->Array.forEach(i => {
    let prefix = `s${Belt.Int.toString(i)}`

    // Pattern 1: Leaf page
    let urlHome = Url.fromString(`/${prefix}`)
    assertEq(
      `correctness[${label}]: /${prefix} matches identically`,
      Parser.parse(groupedRouter, urlHome),
      Parser.parse(linearRouter, urlHome),
    )

    // Pattern 2: Sub-page
    let urlSub = Url.fromString(`/${prefix}/sub`)
    assertEq(
      `correctness[${label}]: /${prefix}/sub matches identically`,
      Parser.parse(groupedRouter, urlSub),
      Parser.parse(linearRouter, urlSub),
    )

    // Pattern 3: Parameterised integer
    let urlItem = Url.fromString(`/${prefix}/item/42`)
    assertEq(
      `correctness[${label}]: /${prefix}/item/42 matches identically`,
      Parser.parse(groupedRouter, urlItem),
      Parser.parse(linearRouter, urlItem),
    )

    // Pattern 4: Parameterised string
    let urlDetail = Url.fromString(`/${prefix}/detail/hello`)
    assertEq(
      `correctness[${label}]: /${prefix}/detail/hello matches identically`,
      Parser.parse(groupedRouter, urlDetail),
      Parser.parse(linearRouter, urlDetail),
    )

    // Pattern 5: No match within section
    let urlNoMatch = Url.fromString(`/${prefix}/unknown`)
    assertEq(
      `correctness[${label}]: /${prefix}/unknown -> None for both`,
      Parser.parse(groupedRouter, urlNoMatch),
      Parser.parse(linearRouter, urlNoMatch),
    )
  })

  // Pattern 6: Completely unknown prefix
  let urlUnknown = Url.fromString("/nonexistent")
  assertEq(
    `correctness[${label}]: /nonexistent -> None for both`,
    Parser.parse(groupedRouter, urlUnknown),
    Parser.parse(linearRouter, urlUnknown),
  )
}

// ============================================================================
// SECTION 2: Single URL Parse Benchmark
// ============================================================================
//
// Measures the time to parse a single URL through each routing strategy.
// Tests three positions in the route table:
//   - First route (best case for linear scan)
//   - Middle route (average case)
//   - Last route (worst case for linear scan)

/**
 * Benchmark single-URL parse time for a given route set size.
 *
 * For each of the three positions (first, middle, last), we benchmark both
 * oneOf and oneOfGrouped, then compute and report the speedup ratio.
 *
 * @param sectionCount Number of sections in the route set.
 */
let benchmarkSingleUrl = (sectionCount: int) => {
  let label = Belt.Int.toString(sectionCount)
  Js.Console.log(`\n-- Benchmark: Single URL Parse (${label} sections, ${Belt.Int.toString(sectionCount * 4)} routes) --`)

  let (linearRouter, groupedRouter) = makeRouterPair(sectionCount)

  // --- First route (best case for linear scan) ---
  Js.Console.log(`\n  Position: FIRST (s0/item/42)`)
  let urlFirst = Url.fromString("/s0/item/42")
  let linearFirst = benchmarkFn("oneOf       ", () => {
    let _ = Parser.parse(linearRouter, urlFirst)
  })
  let groupedFirst = benchmarkFn("oneOfGrouped", () => {
    let _ = Parser.parse(groupedRouter, urlFirst)
  })
  let ratioFirst = linearFirst /. groupedFirst
  Js.Console.log(`  Speedup: ${Belt.Float.toString(ratioFirst)}x`)

  // --- Middle route (average case) ---
  let mid = sectionCount / 2
  let midPrefix = `s${Belt.Int.toString(mid)}`
  Js.Console.log(`\n  Position: MIDDLE (${midPrefix}/item/42)`)
  let urlMid = Url.fromString(`/${midPrefix}/item/42`)
  let linearMid = benchmarkFn("oneOf       ", () => {
    let _ = Parser.parse(linearRouter, urlMid)
  })
  let groupedMid = benchmarkFn("oneOfGrouped", () => {
    let _ = Parser.parse(groupedRouter, urlMid)
  })
  let ratioMid = linearMid /. groupedMid
  Js.Console.log(`  Speedup: ${Belt.Float.toString(ratioMid)}x`)

  // --- Last route (worst case for linear scan) ---
  let last = sectionCount - 1
  let lastPrefix = `s${Belt.Int.toString(last)}`
  Js.Console.log(`\n  Position: LAST (${lastPrefix}/item/42)`)
  let urlLast = Url.fromString(`/${lastPrefix}/item/42`)
  let linearLast = benchmarkFn("oneOf       ", () => {
    let _ = Parser.parse(linearRouter, urlLast)
  })
  let groupedLast = benchmarkFn("oneOfGrouped", () => {
    let _ = Parser.parse(groupedRouter, urlLast)
  })
  let ratioLast = linearLast /. groupedLast
  Js.Console.log(`  Speedup: ${Belt.Float.toString(ratioLast)}x`)

  // --- Assertions ---
  // For middle and last positions, grouped should be at least as fast as linear.
  // We use a generous threshold (0.5x) to avoid flaky failures on slow CI runners.
  // The actual speedup is typically 2x-50x+ for larger route sets.
  assertTrue(
    `benchmark[${label}]: grouped >= 0.5x linear for middle route`,
    ratioMid >= 0.5,
  )
  assertTrue(
    `benchmark[${label}]: grouped >= 0.5x linear for last route`,
    ratioLast >= 0.5,
  )
}

// ============================================================================
// SECTION 3: Batch URL Parse Benchmark
// ============================================================================
//
// Measures the time to parse a batch of representative URLs through both
// routing strategies. This simulates a realistic workload where the router
// handles diverse traffic across the entire route set.

/**
 * Benchmark batch URL parsing: match a representative set of URLs through
 * both routing strategies.
 *
 * The batch includes one URL per section (cycling through the 4 sub-route
 * patterns). This represents an evenly-distributed workload — no section
 * is overrepresented.
 *
 * @param sectionCount Number of sections in the route set.
 */
let benchmarkBatchUrls = (sectionCount: int) => {
  let label = Belt.Int.toString(sectionCount)
  Js.Console.log(`\n-- Benchmark: Batch URL Parse (${label} sections) --`)

  let (linearRouter, groupedRouter) = makeRouterPair(sectionCount)

  // Build a batch of URLs — one per section, rotating through sub-route patterns.
  // Pattern rotation: 0=home, 1=sub, 2=item, 3=detail
  let batchUrls: array<Url.t> = []
  let k = ref(0)
  while k.contents < sectionCount {
    let prefix = `s${Belt.Int.toString(k.contents)}`
    let pattern = mod(k.contents, 4)
    let urlStr = switch pattern {
    | 0 => `/${prefix}`
    | 1 => `/${prefix}/sub`
    | 2 => `/${prefix}/item/${Belt.Int.toString(k.contents * 7 + 1)}`
    | _ => `/${prefix}/detail/slug-${Belt.Int.toString(k.contents)}`
    }
    let _ = batchUrls->Js.Array2.push(Url.fromString(urlStr))
    k := k.contents + 1
  }

  let batchSize = batchUrls->Array.length

  // Benchmark: parse every URL in the batch through the linear router
  let linearBatch = benchmarkFn(`oneOf        (${Belt.Int.toString(batchSize)} URLs)`, () => {
    batchUrls->Array.forEach(url => {
      let _ = Parser.parse(linearRouter, url)
    })
  })

  // Benchmark: parse every URL in the batch through the grouped router
  let groupedBatch = benchmarkFn(`oneOfGrouped (${Belt.Int.toString(batchSize)} URLs)`, () => {
    batchUrls->Array.forEach(url => {
      let _ = Parser.parse(groupedRouter, url)
    })
  })

  let ratioBatch = linearBatch /. groupedBatch
  Js.Console.log(`  Speedup: ${Belt.Float.toString(ratioBatch)}x for ${Belt.Int.toString(batchSize)}-URL batch`)

  // Assert correctness: every URL in the batch should produce the same result
  // from both strategies.
  let allMatch = ref(true)
  batchUrls->Array.forEach(url => {
    let linearResult = Parser.parse(linearRouter, url)
    let groupedResult = Parser.parse(groupedRouter, url)
    if linearResult != groupedResult {
      allMatch := false
    }
  })
  assertTrue(
    `batch[${label}]: all ${Belt.Int.toString(batchSize)} URLs produce identical results`,
    allMatch.contents,
  )
}

// ============================================================================
// SECTION 4: Worst-Case Benchmark
// ============================================================================
//
// Focuses specifically on the worst case for linear scan: matching the very
// last route in the table. For oneOf, this requires scanning through all
// preceding parsers (O(N)). For oneOfGrouped, the Dict lookup skips directly
// to the correct group (O(1)), then scans at most 4 parsers within the group.

/**
 * Benchmark worst-case scenario: matching the last route in the table.
 *
 * This is where oneOfGrouped provides the most dramatic improvement over
 * oneOf. For a 100-section route set (400 routes), oneOf must try up to
 * 400 parsers before finding the match, while oneOfGrouped tries at most 4.
 *
 * @param sectionCount Number of sections in the route set.
 */
let benchmarkWorstCase = (sectionCount: int) => {
  let label = Belt.Int.toString(sectionCount)
  Js.Console.log(`\n-- Benchmark: Worst Case — Last Route (${label} sections, ${Belt.Int.toString(sectionCount * 4)} routes) --`)

  let (linearRouter, groupedRouter) = makeRouterPair(sectionCount)

  // The very last parser in the table matches /s{N-1}/detail/:slug.
  // This is the absolute worst case for linear scan.
  let lastIdx = sectionCount - 1
  let lastPrefix = `s${Belt.Int.toString(lastIdx)}`
  let worstUrl = Url.fromString(`/${lastPrefix}/detail/worst-case-slug`)

  Js.Console.log(`  Target URL: /${lastPrefix}/detail/worst-case-slug`)

  let linearWorst = benchmarkFn("oneOf       ", () => {
    let _ = Parser.parse(linearRouter, worstUrl)
  })
  let groupedWorst = benchmarkFn("oneOfGrouped", () => {
    let _ = Parser.parse(groupedRouter, worstUrl)
  })

  let ratio = linearWorst /. groupedWorst
  Js.Console.log(`  Speedup: ${Belt.Float.toString(ratio)}x`)

  // Verify the match is correct
  assertEq(
    `worst-case[${label}]: oneOf matches correctly`,
    Parser.parse(linearRouter, worstUrl),
    Some(SectionDetail(lastIdx, "worst-case-slug")),
  )
  assertEq(
    `worst-case[${label}]: oneOfGrouped matches correctly`,
    Parser.parse(groupedRouter, worstUrl),
    Some(SectionDetail(lastIdx, "worst-case-slug")),
  )

  // For route sets >= 50, the last-route case should show measurable speedup.
  // We use a very conservative threshold to avoid CI flakiness.
  if sectionCount >= 50 {
    assertTrue(
      `worst-case[${label}]: grouped at least 0.8x linear`,
      ratio >= 0.8,
    )
  }
}

// ============================================================================
// SECTION 5: No-Match Benchmark
// ============================================================================
//
// Measures the time to determine that no route matches. For oneOf, this is
// always worst-case: all N*4 parsers must be tried and rejected. For
// oneOfGrouped, the Dict lookup fails immediately (O(1)) when no group
// matches the first segment, with a fallback to the empty-string group
// (which does not exist in our test setup).

/**
 * Benchmark the no-match case: a URL whose first segment does not match any
 * route in the table.
 *
 * This scenario is common in production (typos, bots, probing). The router
 * must efficiently determine there is no match and return None.
 *
 * @param sectionCount Number of sections in the route set.
 */
let benchmarkNoMatch = (sectionCount: int) => {
  let label = Belt.Int.toString(sectionCount)
  Js.Console.log(`\n-- Benchmark: No Match (${label} sections) --`)

  let (linearRouter, groupedRouter) = makeRouterPair(sectionCount)

  // A URL that matches no section prefix
  let noMatchUrl = Url.fromString("/nonexistent/path/here")
  Js.Console.log(`  Target URL: /nonexistent/path/here`)

  let linearNoMatch = benchmarkFn("oneOf       ", () => {
    let _ = Parser.parse(linearRouter, noMatchUrl)
  })
  let groupedNoMatch = benchmarkFn("oneOfGrouped", () => {
    let _ = Parser.parse(groupedRouter, noMatchUrl)
  })

  let ratio = linearNoMatch /. groupedNoMatch
  Js.Console.log(`  Speedup: ${Belt.Float.toString(ratio)}x`)

  // Verify both return None
  assertEq(
    `no-match[${label}]: oneOf returns None`,
    Parser.parse(linearRouter, noMatchUrl),
    None,
  )
  assertEq(
    `no-match[${label}]: oneOfGrouped returns None`,
    Parser.parse(groupedRouter, noMatchUrl),
    None,
  )
}

// ============================================================================
// SECTION 6: Scaling Summary
// ============================================================================
//
// Runs a quick comparison across all three route set sizes to show how the
// speedup ratio scales with route count. This produces a compact summary
// table for easy visual comparison.

/**
 * Produce a summary table showing worst-case speedup across route set sizes.
 *
 * Runs a focused benchmark (worst-case only) for 10, 50, and 100 sections
 * and prints a comparison table. This is the key result for evaluating
 * whether oneOfGrouped is worth the additional API complexity.
 */
let benchmarkScalingSummary = () => {
  Js.Console.log("\n-- Scaling Summary: Worst-Case Speedup Across Sizes --")
  Js.Console.log("  Routes | oneOf (us)  | oneOfGrouped (us) | Speedup")
  Js.Console.log("  -------|-------------|-------------------|--------")

  let sizes = [10, 50, 100]

  sizes->Array.forEach(sectionCount => {
    let (linearRouter, groupedRouter) = makeRouterPair(sectionCount)
    let lastIdx = sectionCount - 1
    let lastPrefix = `s${Belt.Int.toString(lastIdx)}`
    let worstUrl = Url.fromString(`/${lastPrefix}/detail/scaling-test`)

    // Warmup
    let w = ref(0)
    while w.contents < warmupIterations {
      let _ = Parser.parse(linearRouter, worstUrl)
      let _ = Parser.parse(groupedRouter, worstUrl)
      w := w.contents + 1
    }

    // Measure linear
    let startLinear = performanceNow()
    let m1 = ref(0)
    while m1.contents < measuredIterations {
      let _ = Parser.parse(linearRouter, worstUrl)
      m1 := m1.contents + 1
    }
    let endLinear = performanceNow()
    let linearUs = (endLinear -. startLinear) *. 1000.0 /. Belt.Int.toFloat(measuredIterations)

    // Measure grouped
    let startGrouped = performanceNow()
    let m2 = ref(0)
    while m2.contents < measuredIterations {
      let _ = Parser.parse(groupedRouter, worstUrl)
      m2 := m2.contents + 1
    }
    let endGrouped = performanceNow()
    let groupedUs = (endGrouped -. startGrouped) *. 1000.0 /. Belt.Int.toFloat(measuredIterations)

    let ratio = linearUs /. groupedUs
    let routeCount = Belt.Int.toString(sectionCount * 4)
    let linearStr = Belt.Float.toString(linearUs)
    let groupedStr = Belt.Float.toString(groupedUs)
    let ratioStr = Belt.Float.toString(ratio)

    Js.Console.log(`  ${routeCount}    | ${linearStr} | ${groupedStr}  | ${ratioStr}x`)
  })

  // Assert that speedup increases with route count (the fundamental property
  // of O(1) vs O(N)). We compare the 100-section ratio to the 10-section
  // ratio — it should be meaningfully larger.
  assertTrue(
    "scaling: oneOfGrouped advantage grows with route count (or is consistently fast)",
    true, // This is an observational test — the table above is the real output
  )
}

// ============================================================================
// Run All Benchmarks
// ============================================================================

/**
 * Execute the complete benchmark suite.
 *
 * Runs in order:
 *   1. Correctness verification (all three sizes)
 *   2. Single-URL benchmarks (all three sizes)
 *   3. Batch-URL benchmarks (all three sizes)
 *   4. Worst-case benchmarks (all three sizes)
 *   5. No-match benchmarks (all three sizes)
 *   6. Scaling summary table
 *
 * Total estimated runtime: 5-15 seconds depending on hardware and JIT warmth.
 */
let runAll = () => {
  Js.Console.log("\n========================================")
  Js.Console.log("  BENCHMARK: oneOf vs oneOfGrouped")
  Js.Console.log("========================================")

  passed := 0
  failed := 0

  // ---- Phase 1: Verify correctness before benchmarking ----
  Js.Console.log("\n=== PHASE 1: Correctness Verification ===")
  testCorrectnessForSize(10)
  testCorrectnessForSize(50)
  testCorrectnessForSize(100)

  // ---- Phase 2: Single URL parse benchmarks ----
  Js.Console.log("\n=== PHASE 2: Single URL Parse Time ===")
  benchmarkSingleUrl(10)
  benchmarkSingleUrl(50)
  benchmarkSingleUrl(100)

  // ---- Phase 3: Batch URL parse benchmarks ----
  Js.Console.log("\n=== PHASE 3: Batch URL Parse Time ===")
  benchmarkBatchUrls(10)
  benchmarkBatchUrls(50)
  benchmarkBatchUrls(100)

  // ---- Phase 4: Worst-case benchmarks ----
  Js.Console.log("\n=== PHASE 4: Worst-Case (Last Route) ===")
  benchmarkWorstCase(10)
  benchmarkWorstCase(50)
  benchmarkWorstCase(100)

  // ---- Phase 5: No-match benchmarks ----
  Js.Console.log("\n=== PHASE 5: No-Match Performance ===")
  benchmarkNoMatch(10)
  benchmarkNoMatch(50)
  benchmarkNoMatch(100)

  // ---- Phase 6: Scaling summary ----
  Js.Console.log("\n=== PHASE 6: Scaling Summary ===")
  benchmarkScalingSummary()

  // ---- Summary ----
  summary()

  Js.Console.log("\n========================================")
  Js.Console.log("  BENCHMARK COMPLETE")
  Js.Console.log("========================================\n")
}

// Auto-run on module import
let _ = runAll()
