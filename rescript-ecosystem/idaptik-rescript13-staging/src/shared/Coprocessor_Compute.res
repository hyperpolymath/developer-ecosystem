// SPDX-License-Identifier: PMPL-1.0-or-later
// Coprocessor_Compute.res  Pure number-crunching coprocessor backends.
//
// Consolidates four stateless arithmetic backends into one file:
//   Maths   — sqrt, pow, gcd, mod, prime, factor, fib, rand
//   Vector  — add, dot, scale, norm, compare, sort (max n=256)
//   Tensor  — matmul, transpose, trace, adjacency (max 16×16)
//   Physics — distance, signal, thermal, cablesag, power
//
// All operations are pure integer arithmetic with no mutable state.
// Results are deterministic except Maths:rand (which delegates to Math.random).
//
// Each domain is a nested module with its own Backend sub-module.
// Registration: Coprocessor_Compute.Maths.Backend.make() etc.

open Coprocessor

// ===========================================================================
// Maths — Higher-mathematics coprocessor backend
// ===========================================================================

module Maths = {
  // Safe upper bound for pow results.  ReScript compiles to JavaScript where
  // integers are 32-bit in bitwise context but floats otherwise; clamping at
  // 2^30 keeps results safely within the positive 31-bit range used throughout
  // the coprocessor framework.
  let intMax = 1073741823 // 2^30 - 1

  // sqrt — floor(√n).
  let cmdSqrt = (data: array<int>): executionResult => {
    let n = switch Array.get(data, 0) { | Some(v) if v >= 0 => v | _ => 0 }
    let result = Float.toInt(Math.floor(Math.sqrt(Float.fromInt(n))))
    {
      status:  0,
      data:    [result],
      metrics: {computeUnits: 20, memoryBytes: 16, energyJoules: 0.002, latencyMs: 0.05},
      message: Some(`Maths: sqrt(${Int.toString(n)})=${Int.toString(result)}`),
    }
  }

  // pow — floor(base ^ exp), clamped to intMax.
  let cmdPow = (data: array<int>): executionResult => {
    let base = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    let exp  = switch Array.get(data, 1) { | Some(v) if v >= 0 => v | _ => 0 }
    let raw  = Math.pow(Float.fromInt(base), ~exp=Float.fromInt(exp))
    let result =
      if raw > Float.fromInt(intMax) {intMax}
      else if raw < 0.0 {0}
      else {Float.toInt(Math.floor(raw))}
    {
      status:  0,
      data:    [result],
      metrics: {computeUnits: 30, memoryBytes: 16, energyJoules: 0.003, latencyMs: 0.1},
      message: Some(`Maths: pow(${Int.toString(base)},${Int.toString(exp)})=${Int.toString(result)}`),
    }
  }

  // gcd — Euclidean greatest common divisor.
  // Works on absolute values to tolerate negative inputs.
  let rec euclidGcd = (a: int, b: int): int =>
    if b == 0 {a} else {euclidGcd(b, mod(a, b))}

  let cmdGcd = (data: array<int>): executionResult => {
    let a = switch Array.get(data, 0) { | Some(v) => abs(v) | None => 0 }
    let b = switch Array.get(data, 1) { | Some(v) => abs(v) | None => 0 }
    let result = if a == 0 && b == 0 {0} else {euclidGcd(a, b)}
    {
      status:  0,
      data:    [result],
      metrics: {computeUnits: 15, memoryBytes: 16, energyJoules: 0.0015, latencyMs: 0.05},
      message: Some(`Maths: gcd(${Int.toString(a)},${Int.toString(b)})=${Int.toString(result)}`),
    }
  }

  // mod — non-negative modulo.
  let cmdMod = (data: array<int>): executionResult => {
    let dividend = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    let divisor  = switch Array.get(data, 1) { | Some(v) => v | None => 1 }
    if divisor == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Maths: mod divisor must not be zero")}
    } else {
      let raw    = mod(dividend, divisor)
      let result = if raw < 0 {raw + abs(divisor)} else {raw}
      {
        status:  0,
        data:    [result],
        metrics: {computeUnits: 10, memoryBytes: 8, energyJoules: 0.001, latencyMs: 0.02},
        message: Some(`Maths: mod(${Int.toString(dividend)},${Int.toString(divisor)})=${Int.toString(result)}`),
      }
    }
  }

  // prime — trial division primality test.
  let isPrime = (n: int): bool => {
    if n < 2 {false}
    else if n == 2 {true}
    else if mod(n, 2) == 0 {false}
    else {
      let limit  = Float.toInt(Math.floor(Math.sqrt(Float.fromInt(n))))
      let result = ref(true)
      let d      = ref(3)
      while d.contents <= limit && result.contents {
        if mod(n, d.contents) == 0 {result := false}
        d := d.contents + 2
      }
      result.contents
    }
  }

  let cmdPrime = (data: array<int>): executionResult => {
    let n      = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    let result = if isPrime(n) {1} else {0}
    let cost   = max(10, Float.toInt(Math.sqrt(Float.fromInt(abs(n)))))
    {
      status:  0,
      data:    [result],
      metrics: {computeUnits: cost, memoryBytes: 16, energyJoules: Float.fromInt(cost) *. 0.0001, latencyMs: Float.fromInt(cost) *. 0.002},
      message: Some(`Maths: prime(${Int.toString(n)})=${if result == 1 {"true"} else {"false"}}`),
    }
  }

  // factor — prime factorisation by trial division.
  // Capped at n ≤ 65535 to prevent runaway computation in-game.
  let primeFactors = (n: int): array<int> => {
    let factors = ref([])
    let rem     = ref(n)
    let d       = ref(2)
    while d.contents * d.contents <= rem.contents {
      while mod(rem.contents, d.contents) == 0 {
        factors := Array.concat(factors.contents, [d.contents])
        rem     := rem.contents / d.contents
      }
      d := d.contents + 1
    }
    if rem.contents > 1 {
      factors := Array.concat(factors.contents, [rem.contents])
    }
    factors.contents
  }

  let cmdFactor = (data: array<int>): executionResult => {
    let n = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    if n < 2 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some(`Maths: factor requires n ≥ 2, got ${Int.toString(n)}`)}
    } else if n > 65535 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some(`Maths: factor capped at n ≤ 65535 to bound runtime, got ${Int.toString(n)}`)}
    } else {
      let factors = primeFactors(n)
      let cost    = max(20, Float.toInt(Math.sqrt(Float.fromInt(n))))
      {
        status:  0,
        data:    factors,
        metrics: {computeUnits: cost, memoryBytes: Array.length(factors) * 4, energyJoules: Float.fromInt(cost) *. 0.0002, latencyMs: Float.fromInt(cost) *. 0.005},
        message: Some(`Maths: factor(${Int.toString(n)}) → ${Int.toString(Array.length(factors))} factors`),
      }
    }
  }

  // fib — iterative Fibonacci.
  // Capped at n=46: fib(46)=1836311903, which fits in a 31-bit signed int.
  let cmdFib = (data: array<int>): executionResult => {
    let n = switch Array.get(data, 0) {
    | Some(v) if v >= 0 && v <= 46 => v
    | Some(v) if v > 46 => 46
    | _ => 0
    }
    let result =
      if n == 0 {0}
      else if n == 1 {1}
      else {
        let a = ref(0)
        let b = ref(1)
        for _ in 2 to n {
          let next = a.contents + b.contents
          a := b.contents
          b := next
        }
        b.contents
      }
    {
      status:  0,
      data:    [result],
      metrics: {computeUnits: max(5, n), memoryBytes: 16, energyJoules: Float.fromInt(n) *. 0.0001, latencyMs: Float.fromInt(n) *. 0.001},
      message: Some(`Maths: fib(${Int.toString(n)})=${Int.toString(result)}`),
    }
  }

  // rand — pseudo-random integer in [0, max).
  let cmdRand = (data: array<int>): executionResult => {
    let maxVal = switch Array.get(data, 0) {
    | Some(v) if v >= 1 => v
    | _ => 100
    }
    let result = Float.toInt(Math.floor(Math.random() *. Float.fromInt(maxVal)))
    {
      status:  0,
      data:    [result],
      metrics: {computeUnits: 5, memoryBytes: 8, energyJoules: 0.0005, latencyMs: 0.01},
      message: Some(`Maths: rand(${Int.toString(maxVal)})=${Int.toString(result)}`),
    }
  }

  module Backend = {
    let id          = "maths-native"
    let domain      = Domain.Maths
    let description = "Integer maths: sqrt, pow, gcd, mod, prime, factor, fib, rand"

    let execute = (cmd: string, data: array<int>): promise<executionResult> => {
      let result = switch cmd {
      | "sqrt"   => cmdSqrt(data)
      | "pow"    => cmdPow(data)
      | "gcd"    => cmdGcd(data)
      | "mod"    => cmdMod(data)
      | "prime"  => cmdPrime(data)
      | "factor" => cmdFactor(data)
      | "fib"    => cmdFib(data)
      | "rand"   => cmdRand(data)
      | _ =>
        {
          status:  400,
          data:    [],
          metrics: emptyMetrics,
          message: Some(`Maths: unknown command "${cmd}". Valid: sqrt pow gcd mod prime factor fib rand`),
        }
      }
      Promise.resolve(result)
    }

    let isAccelerated = () => false

    let make = (): backend => {
      {
        id,
        domain,
        description,
        stats:        {totalCompute: 0, totalMemory: 0, totalEnergy: 0.0, totalCalls: 0},
        execute,
        isAccelerated,
      }
    }
  }
}

// ===========================================================================
// Vector — SIMD-style vector arithmetic coprocessor backend
// ===========================================================================

module Vector = {
  // Maximum vector length.  Larger inputs return 413.
  let maxN = 256

  // Validate the vector length header and return it, or an error result.
  let parseN = (data: array<int>, caller: string): result<int, executionResult> => {
    switch Array.get(data, 0) {
    | None =>
      Error({status: 400, data: [], metrics: emptyMetrics,
             message: Some(`Vector: ${caller} requires data[0]=n (vector length)`)})
    | Some(n) if n <= 0 || n > maxN =>
      Error({status: 413, data: [], metrics: emptyMetrics,
             message: Some(`Vector: ${caller} n=${Int.toString(n)} out of range (1–${Int.toString(maxN)})`)})
    | Some(n) => Ok(n)
    }
  }

  // Extract a single vector of length n starting at offset `off`.
  let extractVec = (data: array<int>, off: int, n: int): array<int> =>
    Array.fromInitializer(~length=n, i =>
      switch Array.get(data, off + i) { | Some(v) => v | None => 0 }
    )

  // Euclidean norm as float.
  let normF = (vec: array<int>): float =>
    Math.sqrt(Array.reduce(vec, 0.0, (acc, v) => acc +. Float.fromInt(v * v)))

  // Scaled metrics: cost proportional to vector length.
  let vecMetrics = (n: int, cuPerElem: int, jPerElem: float, latMs: float): resourceMetrics => {
    computeUnits: n * cuPerElem,
    memoryBytes:  n * 8,
    energyJoules: Float.fromInt(n) *. jPerElem,
    latencyMs:    latMs,
  }

  // add — element-wise addition.
  let cmdAdd = (data: array<int>): executionResult => {
    switch parseN(data, "add") {
    | Error(e) => e
    | Ok(n) =>
      let a = extractVec(data, 1,     n)
      let b = extractVec(data, 1 + n, n)
      let result = Array.fromInitializer(~length=n, i => {
        let ai = switch Array.get(a, i) { | Some(v) => v | None => 0 }
        let bi = switch Array.get(b, i) { | Some(v) => v | None => 0 }
        ai + bi
      })
      {
        status:  0,
        data:    result,
        metrics: vecMetrics(n, 5, 0.001, 0.5),
        message: Some(`Vector: add n=${Int.toString(n)}`),
      }
    }
  }

  // dot — inner product of two vectors.
  let cmdDot = (data: array<int>): executionResult => {
    switch parseN(data, "dot") {
    | Error(e) => e
    | Ok(n) =>
      let a = extractVec(data, 1,     n)
      let b = extractVec(data, 1 + n, n)
      let dot = Array.mapWithIndex(a, (ai, i) => {
        let bi = switch Array.get(b, i) { | Some(v) => v | None => 0 }
        ai * bi
      })->Array.reduce(0, (acc, x) => acc + x)
      {
        status:  0,
        data:    [dot],
        metrics: vecMetrics(n, 8, 0.002, 1.0),
        message: Some(`Vector: dot n=${Int.toString(n)} result=${Int.toString(dot)}`),
      }
    }
  }

  // scale — multiply each element by scalar.
  let cmdScale = (data: array<int>): executionResult => {
    switch parseN(data, "scale") {
    | Error(e) => e
    | Ok(n) =>
      let scalar = switch Array.get(data, 1) { | Some(s) => s | None => 1 }
      let vec    = extractVec(data, 2, n)
      let result = Array.map(vec, v => v * scalar)
      {
        status:  0,
        data:    result,
        metrics: vecMetrics(n, 3, 0.001, 0.3),
        message: Some(`Vector: scale n=${Int.toString(n)} scalar=${Int.toString(scalar)}`),
      }
    }
  }

  // norm — integer floor of Euclidean magnitude.
  let cmdNorm = (data: array<int>): executionResult => {
    switch parseN(data, "norm") {
    | Error(e) => e
    | Ok(n) =>
      let vec = extractVec(data, 1, n)
      let mag = Float.toInt(Math.floor(normF(vec)))
      {
        status:  0,
        data:    [mag],
        metrics: vecMetrics(n, 6, 0.001, 0.5),
        message: Some(`Vector: norm n=${Int.toString(n)} |v|=${Int.toString(mag)}`),
      }
    }
  }

  // compare — cosine similarity of two vectors, scaled to integer 0–1000.
  let cmdCompare = (data: array<int>): executionResult => {
    switch parseN(data, "compare") {
    | Error(e) => e
    | Ok(n) =>
      let a = extractVec(data, 1,     n)
      let b = extractVec(data, 1 + n, n)
      let dotF =
        Array.mapWithIndex(a, (ai, i) => {
          let bi = switch Array.get(b, i) { | Some(v) => v | None => 0 }
          Float.fromInt(ai * bi)
        })->Array.reduce(0.0, (acc, x) => acc +. x)
      let nA = normF(a)
      let nB = normF(b)
      let sim =
        if nA < 0.0001 || nB < 0.0001 {0.0}
        else {
          let raw = dotF /. (nA *. nB) *. 1000.0
          if raw > 1000.0 {1000.0} else if raw < -1000.0 {-1000.0} else {raw}
        }
      let simInt = Float.toInt(Math.floor(sim))
      {
        status:  0,
        data:    [simInt],
        metrics: vecMetrics(n, 10, 0.002, 1.0),
        message: Some(`Vector: compare n=${Int.toString(n)} similarity=${Int.toString(simInt)}`),
      }
    }
  }

  // sort — ascending sort of vector elements.
  let cmdSort = (data: array<int>): executionResult => {
    switch parseN(data, "sort") {
    | Error(e) => e
    | Ok(n) =>
      let vec    = extractVec(data, 1, n)
      let sorted = Array.toSorted(vec, (a, b) => (a - b :> float))
      {
        status:  0,
        data:    sorted,
        metrics: {computeUnits: n * n, memoryBytes: n * 8,
                  energyJoules: Float.fromInt(n) *. 0.003,
                  latencyMs:    Float.fromInt(n) *. 0.1},
        message: Some(`Vector: sort n=${Int.toString(n)}`),
      }
    }
  }

  module Backend = {
    let id          = "vector-integer"
    let domain      = Domain.Vector
    let description = "Integer vector ops: add, dot, scale, norm, cosine compare, sort (max n=256)"

    let execute = (cmd: string, data: array<int>): promise<executionResult> => {
      let result = switch cmd {
      | "add"     => cmdAdd(data)
      | "dot"     => cmdDot(data)
      | "scale"   => cmdScale(data)
      | "norm"    => cmdNorm(data)
      | "compare" => cmdCompare(data)
      | "sort"    => cmdSort(data)
      | _ =>
        {
          status:  400,
          data:    [],
          metrics: emptyMetrics,
          message: Some(`Vector: unknown command "${cmd}". Valid: add dot scale norm compare sort`),
        }
      }
      Promise.resolve(result)
    }

    let isAccelerated = () => false

    let make = (): backend => {
      {
        id,
        domain,
        description,
        stats:        {totalCompute: 0, totalMemory: 0, totalEnergy: 0.0, totalCalls: 0},
        execute,
        isAccelerated,
      }
    }
  }
}

// ===========================================================================
// Tensor — Matrix operations coprocessor backend
// ===========================================================================

module Tensor = {
  // Maximum dimension for any single matrix axis.
  let maxDim = 16

  // Retrieve an element from a flat row-major matrix.
  let matGet = (flat: array<int>, cols: int, row: int, col: int): int =>
    switch Array.get(flat, row * cols + col) { | Some(v) => v | None => 0 }

  // Validate a single dimension value against maxDim.
  let checkDim = (name: string, v: int): option<executionResult> =>
    if v <= 0 || v > maxDim {
      Some({
        status:  413,
        data:    [],
        metrics: emptyMetrics,
        message: Some(`Tensor: ${name}=${Int.toString(v)} out of range (1–${Int.toString(maxDim)})`),
      })
    } else {None}

  // matmul — A(rows×inner) × B(inner×cols) = C(rows×cols).
  let cmdMatmul = (data: array<int>): executionResult => {
    let rows  = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    let cols  = switch Array.get(data, 1) { | Some(v) => v | None => 0 }
    let inner = switch Array.get(data, 2) { | Some(v) => v | None => 0 }
    switch (checkDim("rows", rows), checkDim("cols", cols), checkDim("inner", inner)) {
    | (Some(e), _, _) | (_, Some(e), _) | (_, _, Some(e)) => e
    | (None, None, None) =>
      let aSize   = rows * inner
      let bSize   = inner * cols
      let aOff    = 3
      let bOff    = 3 + aSize
      let aFlat   = Array.slice(data, ~start=aOff, ~end=aOff + aSize)
      let bFlat   = Array.slice(data, ~start=bOff, ~end=bOff + bSize)
      let cFlat   = Array.fromInitializer(~length=rows * cols, i => {
        let row = i / cols
        let col = mod(i, cols)
        let sum = ref(0)
        for k in 0 to inner - 1 {
          sum := sum.contents + matGet(aFlat, inner, row, k) * matGet(bFlat, cols, k, col)
        }
        sum.contents
      })
      let cu = rows * cols * inner
      {
        status:  0,
        data:    cFlat,
        metrics: {
          computeUnits: cu,
          memoryBytes:  (aSize + bSize + rows * cols) * 4,
          energyJoules: 0.1,
          latencyMs:    2.0,
        },
        message: Some(`Tensor: matmul ${Int.toString(rows)}×${Int.toString(inner)} × ${Int.toString(inner)}×${Int.toString(cols)} → ${Int.toString(rows)}×${Int.toString(cols)}`),
      }
    }
  }

  // transpose — swap rows and columns of a matrix.
  let cmdTranspose = (data: array<int>): executionResult => {
    let rows = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    let cols = switch Array.get(data, 1) { | Some(v) => v | None => 0 }
    switch (checkDim("rows", rows), checkDim("cols", cols)) {
    | (Some(e), _) | (_, Some(e)) => e
    | (None, None) =>
      let flat  = Array.slice(data, ~start=2, ~end=2 + rows * cols)
      let trans = Array.fromInitializer(~length=cols * rows, idx => {
        let j = idx / rows
        let i = mod(idx, rows)
        matGet(flat, cols, i, j)
      })
      {
        status:  0,
        data:    trans,
        metrics: {
          computeUnits: rows * cols,
          memoryBytes:  rows * cols * 8,
          energyJoules: 0.02,
          latencyMs:    0.5,
        },
        message: Some(`Tensor: transpose ${Int.toString(rows)}×${Int.toString(cols)} → ${Int.toString(cols)}×${Int.toString(rows)}`),
      }
    }
  }

  // trace — sum of the main diagonal of a square n×n matrix.
  let cmdTrace = (data: array<int>): executionResult => {
    let n = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    switch checkDim("n", n) {
    | Some(e) => e
    | None =>
      let flat  = Array.slice(data, ~start=1, ~end=1 + n * n)
      let trace = ref(0)
      for i in 0 to n - 1 {
        trace := trace.contents + matGet(flat, n, i, i)
      }
      {
        status:  0,
        data:    [trace.contents],
        metrics: {computeUnits: n, memoryBytes: n * n * 4, energyJoules: 0.005, latencyMs: 0.1},
        message: Some(`Tensor: trace n=${Int.toString(n)} = ${Int.toString(trace.contents)}`),
      }
    }
  }

  // adjacency — convert directed edge list to n×n adjacency matrix.
  let cmdAdjacency = (data: array<int>): executionResult => {
    let n = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    switch checkDim("n", n) {
    | Some(e) => e
    | None =>
      let dataLen = Array.length(data)
      let edgeData = Array.slice(data, ~start=1, ~end=dataLen)
      let edgeLen  = Array.length(edgeData)
      let flat     = Array.make(~length=n * n, 0)
      let k = ref(0)
      while k.contents + 1 < edgeLen {
        let src = switch Array.get(edgeData, k.contents)     { | Some(v) => v | None => -1 }
        let dst = switch Array.get(edgeData, k.contents + 1) { | Some(v) => v | None => -1 }
        if src >= 0 && src < n && dst >= 0 && dst < n {
          Array.set(flat, src * n + dst, 1)
        }
        k := k.contents + 2
      }
      let edgeCount = edgeLen / 2
      {
        status:  0,
        data:    flat,
        metrics: {
          computeUnits: n * n + edgeCount,
          memoryBytes:  n * n * 4,
          energyJoules: 0.05,
          latencyMs:    1.0,
        },
        message: Some(`Tensor: adjacency n=${Int.toString(n)} edges=${Int.toString(edgeCount)}`),
      }
    }
  }

  module Backend = {
    let id          = "tensor-matrix"
    let domain      = Domain.Tensor
    let description = "Matrix ops: matmul, transpose, trace, adjacency (max 16×16)"

    let execute = (cmd: string, data: array<int>): promise<executionResult> => {
      let result = switch cmd {
      | "matmul"    => cmdMatmul(data)
      | "transpose" => cmdTranspose(data)
      | "trace"     => cmdTrace(data)
      | "adjacency" => cmdAdjacency(data)
      | _ =>
        {
          status:  400,
          data:    [],
          metrics: emptyMetrics,
          message: Some(`Tensor: unknown command "${cmd}". Valid: matmul transpose trace adjacency`),
        }
      }
      Promise.resolve(result)
    }

    let isAccelerated = () => false

    let make = (): backend => {
      {
        id,
        domain,
        description,
        stats:        {totalCompute: 0, totalMemory: 0, totalEnergy: 0.0, totalCalls: 0},
        execute,
        isAccelerated,
      }
    }
  }
}

// ===========================================================================
// Physics — Hardware simulation coprocessor backend
// ===========================================================================

module Physics = {
  // distance — Euclidean distance × 100 (integer fixed-point).
  let cmdDistance = (data: array<int>): executionResult => {
    let x1 = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    let y1 = switch Array.get(data, 1) { | Some(v) => v | None => 0 }
    let x2 = switch Array.get(data, 2) { | Some(v) => v | None => 0 }
    let y2 = switch Array.get(data, 3) { | Some(v) => v | None => 0 }
    let dx  = x2 - x1
    let dy  = y2 - y1
    let d100 = Float.toInt(Math.floor(Math.sqrt(Float.fromInt(dx * dx + dy * dy)) *. 100.0))
    {
      status:  0,
      data:    [d100],
      metrics: {computeUnits: 20, memoryBytes: 16, energyJoules: 0.005, latencyMs: 0.5},
      message: Some(`Physics: distance (${Int.toString(x1)},${Int.toString(y1)})→(${Int.toString(x2)},${Int.toString(y2)}) = ${Int.toString(d100)} (×100)`),
    }
  }

  // signal — Signal strength after free-space attenuation.
  let cmdSignal = (data: array<int>): executionResult => {
    let power       = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    let distance    = switch Array.get(data, 1) { | Some(v) => abs(v) | None => 0 }
    let attenuation = switch Array.get(data, 2) { | Some(v) => abs(v) | None => 0 }
    if Array.length(data) < 3 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Physics: signal requires [power, distance, attenuation]")}
    } else {
      let loss     = distance * attenuation / 100
      let strength = if power > loss {power - loss} else {0}
      {
        status:  0,
        data:    [strength],
        metrics: {computeUnits: 30, memoryBytes: 16, energyJoules: 0.008, latencyMs: 1.0},
        message: Some(`Physics: signal power=${Int.toString(power)} loss=${Int.toString(loss)} → ${Int.toString(strength)}`),
      }
    }
  }

  // thermal — Temperature rise under sustained power load.
  let cmdThermal = (data: array<int>): executionResult => {
    let watts       = switch Array.get(data, 0) { | Some(v) => abs(v) | None => 0 }
    let duration    = switch Array.get(data, 1) { | Some(v) => abs(v) | None => 0 }
    let heatCap     = switch Array.get(data, 2) { | Some(v) => v | None => 0 }
    if Array.length(data) < 3 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Physics: thermal requires [watts, duration, heatCapacity]")}
    } else if heatCap <= 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Physics: thermal heatCapacity must be > 0")}
    } else {
      let temp = watts * duration / heatCap
      {
        status:  0,
        data:    [temp],
        metrics: {computeUnits: 25, memoryBytes: 16, energyJoules: 0.006, latencyMs: 0.5},
        message: Some(`Physics: thermal ${Int.toString(watts)}W × ${Int.toString(duration)}s / C=${Int.toString(heatCap)} → ΔT=${Int.toString(temp)}`),
      }
    }
  }

  // cablesag — Catenary sag approximation for cable routing visualisation.
  let cmdCablesag = (data: array<int>): executionResult => {
    let length  = switch Array.get(data, 0) { | Some(v) => abs(v) | None => 0 }
    let weight  = switch Array.get(data, 1) { | Some(v) => abs(v) | None => 0 }
    let tension = switch Array.get(data, 2) { | Some(v) => v | None => 0 }
    if Array.length(data) < 3 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Physics: cablesag requires [length, weight, tension]")}
    } else if tension <= 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Physics: cablesag tension must be > 0")}
    } else {
      let sag = weight * length * length / (8 * tension)
      {
        status:  0,
        data:    [sag],
        metrics: {computeUnits: 15, memoryBytes: 8, energyJoules: 0.003, latencyMs: 0.3},
        message: Some(`Physics: cablesag L=${Int.toString(length)} W=${Int.toString(weight)} T=${Int.toString(tension)} → sag=${Int.toString(sag)}`),
      }
    }
  }

  // power — Power calculation with circuit-breaker safety assessment.
  let cmdPower = (data: array<int>): executionResult => {
    let voltage = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    let current = switch Array.get(data, 1) { | Some(v) => v | None => 0 }
    if Array.length(data) < 2 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Physics: power requires [voltage, current]")}
    } else {
      let watts = voltage * current
      let safe  = if watts < 1500 {1} else {0}
      {
        status:  0,
        data:    [watts, safe],
        metrics: {computeUnits: 10, memoryBytes: 8, energyJoules: 0.002, latencyMs: 0.1},
        message: Some(`Physics: power ${Int.toString(voltage)}V × ${Int.toString(current)}A = ${Int.toString(watts)}W (${if safe == 1 {"SAFE"} else {"OVERLOAD"}})`),
      }
    }
  }

  module Backend = {
    let id          = "physics-hardware"
    let domain      = Domain.Physics
    let description = "Hardware physics: distance, signal, thermal, cablesag, power (ADR-0008/0010)"

    let execute = (cmd: string, data: array<int>): promise<executionResult> => {
      let result = switch cmd {
      | "distance" => cmdDistance(data)
      | "signal"   => cmdSignal(data)
      | "thermal"  => cmdThermal(data)
      | "cablesag" => cmdCablesag(data)
      | "power"    => cmdPower(data)
      | _ =>
        {
          status:  400,
          data:    [],
          metrics: emptyMetrics,
          message: Some(`Physics: unknown command "${cmd}". Valid: distance signal thermal cablesag power`),
        }
      }
      Promise.resolve(result)
    }

    let isAccelerated = () => false

    let make = (): backend => {
      {
        id,
        domain,
        description,
        stats:        {totalCompute: 0, totalMemory: 0, totalEnergy: 0.0, totalCalls: 0},
        execute,
        isAccelerated,
      }
    }
  }
}
