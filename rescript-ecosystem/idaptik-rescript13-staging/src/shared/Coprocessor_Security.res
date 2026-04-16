// SPDX-License-Identifier: PMPL-1.0-or-later
// Coprocessor_Security.res  Security and analysis coprocessor backends.
//
// Consolidates five backends that serve the security gameplay loop:
//   Crypto   — hash, keygen, XOR cipher, sign/verify, probabilistic crack
//   Neural   — classify, predict, anomaly, fingerprint, evade
//   Quantum  — shor (unlimited factor), grover (amplified search), qrng, entangle
//   Audio    — analyse, filter, detect, compare (DSP signal analysis)
//   Graphics — noise, scramble/unscramble (Fisher-Yates), blend
//
// Crypto, Neural, Audio, and Graphics are stateless.
// Quantum has one session-scoped ref (entangleCounter).
//
// Each domain is a nested module with its own Backend sub-module.
// Registration: Coprocessor_Security.Crypto.Backend.make() etc.

open Coprocessor

// ===========================================================================
// Crypto — Game-simulation cryptography coprocessor backend
// ===========================================================================

module Crypto = {
  // XOR-fold an array of ints into a single int.
  let xorFold = (arr: array<int>): int =>
    Array.reduce(arr, 0, (acc, x) => Int.Bitwise.lxor(acc, x))

  // Decompose an int into a 4-byte big-endian array.
  let intTo4Bytes = (n: int): array<int> => [
    Int.Bitwise.land(Int.Bitwise.lsr(n, 24), 0xFF),
    Int.Bitwise.land(Int.Bitwise.lsr(n, 16), 0xFF),
    Int.Bitwise.land(Int.Bitwise.lsr(n,  8), 0xFF),
    Int.Bitwise.land(n, 0xFF),
  ]

  // One LCG step: a=1664525, c=1013904223, truncated to 31 bits.
  let lcgStep = (seed: int): (int, int) => {
    let next = Int.Bitwise.land(seed * 1664525 + 1013904223, 0x7FFFFFFF)
    (next, Int.Bitwise.land(next, 0xFF))
  }

  // Generate `count` bytes from an LCG seeded with `seed`.
  let lcgBytes = (seed: int, count: int): array<int> => {
    let buf = Array.make(~length=count, 0)
    let s = ref(seed)
    for i in 0 to count - 1 {
      let (next, byte) = lcgStep(s.contents)
      s := next
      Array.set(buf, i, byte)
    }
    buf
  }

  // XOR two arrays together, cycling `key` if shorter than `msg`.
  let xorWithKey = (msg: array<int>, key: array<int>): array<int> => {
    let kLen = Array.length(key)
    if kLen == 0 {
      msg
    } else {
      msg->Array.mapWithIndex((byte, i) => {
        let keyByte = switch Array.get(key, mod(i, kLen)) {
        | Some(b) => b
        | None    => 0
        }
        Int.Bitwise.lxor(byte, keyByte)
      })
    }
  }

  // hash — XOR-fold input to a 4-byte digest.
  let cmdHash = (data: array<int>): executionResult => {
    let digest = xorFold(data)
    {
      status:  0,
      data:    intTo4Bytes(digest),
      metrics: {computeUnits: 80, memoryBytes: 64, energyJoules: 0.008, latencyMs: 0.2},
      message: Some(`Crypto: hash digest=0x${Int.toString(digest)}`),
    }
  }

  // keygen — LCG-seeded key byte generation.
  let cmdKeygen = (data: array<int>): executionResult => {
    let seed  = switch Array.get(data, 0) { | Some(s) => s | None => 42 }
    let count = switch Array.get(data, 1) {
    | Some(n) if n > 0 && n <= 256 => n
    | _ => 16
    }
    let key = lcgBytes(seed, count)
    {
      status:  0,
      data:    key,
      metrics: {computeUnits: 300, memoryBytes: count, energyJoules: 0.03, latencyMs: 0.5},
      message: Some(`Crypto: keygen seed=${Int.toString(seed)} count=${Int.toString(count)}`),
    }
  }

  // encrypt / decrypt — XOR stream cipher (symmetric).
  let cmdXorCipher = (cmd: string, data: array<int>): executionResult => {
    let totalLen = Array.length(data)
    switch Array.get(data, 0) {
    | None =>
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some(`Crypto: ${cmd} requires data[0]=key_length`)}
    | Some(kLen) if kLen < 0 || 1 + kLen > totalLen =>
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some(`Crypto: ${cmd} key_length=${Int.toString(kLen)} out of range`)}
    | Some(kLen) =>
      let key = Array.slice(data, ~start=1, ~end=1 + kLen)
      let msg = Array.slice(data, ~start=1 + kLen, ~end=totalLen)
      let out = xorWithKey(msg, key)
      let msgLen = Array.length(msg)
      {
        status:  0,
        data:    out,
        metrics: {
          computeUnits: 200 + msgLen * 2,
          memoryBytes:  msgLen * 2,
          energyJoules: 0.02  +. Float.fromInt(msgLen) *. 0.0002,
          latencyMs:    0.3   +. Float.fromInt(msgLen) *. 0.01,
        },
        message: Some(`Crypto: ${cmd} processed ${Int.toString(msgLen)} bytes`),
      }
    }
  }

  // sign — Append a 2-byte XOR checksum to the message.
  let cmdSign = (data: array<int>): executionResult => {
    let cs    = xorFold(data)
    let csLo  = Int.Bitwise.land(cs, 0xFF)
    let csHi  = Int.Bitwise.land(Int.Bitwise.lsr(cs, 8), 0xFF)
    let signed = Array.concat(data, [csLo, csHi])
    {
      status:  0,
      data:    signed,
      metrics: {computeUnits: 120, memoryBytes: Array.length(signed), energyJoules: 0.012, latencyMs: 0.3},
      message: Some(`Crypto: sign checksum=0x${Int.toString(cs)}`),
    }
  }

  // verify — Check the 2-byte checksum appended by sign.
  let cmdVerify = (data: array<int>): executionResult => {
    let len = Array.length(data)
    if len < 2 {
      {status: 400, data: [0], metrics: emptyMetrics,
       message: Some("Crypto: verify needs at least 2 bytes (body + 2-byte checksum)")}
    } else {
      let body     = Array.slice(data, ~start=0, ~end=len - 2)
      let expected = xorFold(body)
      let csLo = switch Array.get(data, len - 2) { | Some(b) => b | None => 0 }
      let csHi = switch Array.get(data, len - 1) { | Some(b) => b | None => 0 }
      let stored = Int.Bitwise.lor(csLo, Int.Bitwise.lsl(csHi, 8))
      let valid  = expected == stored
      {
        status:  0,
        data:    [if valid {1} else {0}],
        metrics: {computeUnits: 150, memoryBytes: 32, energyJoules: 0.015, latencyMs: 0.4},
        message: Some(`Crypto: verify ${if valid {"PASS"} else {"FAIL"}}`),
      }
    }
  }

  // crack — Probabilistic hash reversal (simulates brute-force cracking).
  let cmdCrack = (data: array<int>): executionResult => {
    let target   = switch Array.get(data, 0) { | Some(t) => t | None => 0 }
    let strength = switch Array.get(data, 1) {
    | Some(s) if s >= 0 && s <= 9 => s
    | _ => 3
    }
    let compute  = 1000 + strength * 700
    let energy   = 0.1  +. Float.fromInt(strength) *. 0.15
    let latency  = Float.fromInt(strength) *. 50.0
    let roll      = Math.random()
    let threshold = Float.fromInt(strength) /. 10.0
    if roll < threshold {
      let crackedKey = Int.Bitwise.lxor(target, strength)
      {
        status:  0,
        data:    [crackedKey],
        metrics: {computeUnits: compute, memoryBytes: 4096, energyJoules: energy, latencyMs: latency},
        message: Some(`Crypto: crack SUCCESS key=0x${Int.toString(crackedKey)} strength=${Int.toString(strength)}`),
      }
    } else {
      {
        status:  0,
        data:    [],
        metrics: {computeUnits: compute, memoryBytes: 2048, energyJoules: energy *. 0.8, latencyMs: latency *. 0.8},
        message: Some(`Crypto: crack FAILED strength=${Int.toString(strength)}`),
      }
    }
  }

  module Backend = {
    let id          = "crypto-xor-sim"
    let domain      = Domain.Crypto
    let description = "Game-simulation crypto: hash, keygen, XOR cipher, sign/verify, probabilistic crack"

    let execute = (cmd: string, data: array<int>): promise<executionResult> => {
      let result = switch cmd {
      | "hash"    => cmdHash(data)
      | "keygen"  => cmdKeygen(data)
      | "encrypt" => cmdXorCipher("encrypt", data)
      | "decrypt" => cmdXorCipher("decrypt", data)
      | "sign"    => cmdSign(data)
      | "verify"  => cmdVerify(data)
      | "crack"   => cmdCrack(data)
      | _ =>
        {
          status:  400,
          data:    [],
          metrics: emptyMetrics,
          message: Some(`Crypto: unknown command "${cmd}". Valid: hash keygen encrypt decrypt sign verify crack`),
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
// Neural — Pattern recognition and anomaly detection backend
// ===========================================================================

module Neural = {
  let numClasses = 8

  let className = (id: int): string =>
    switch id {
    | 0 => "Laptop"
    | 1 => "Desktop"
    | 2 => "Server"
    | 3 => "Router"
    | 4 => "Firewall"
    | 5 => "Switch"
    | 6 => "Camera"
    | 7 => "IoT"
    | _ => "Unknown"
    }

  let classScore = (c: int, features: array<int>): int =>
    features->Array.mapWithIndex((f, i) => {
      let w = Int.Bitwise.land(Int.Bitwise.lxor(c * 31 + i * 17, c * i + 7), 7) - 3
      f * w
    })->Array.reduce(0, (acc, x) => acc + x)

  let classify = (features: array<int>): (int, int) => {
    let scores = Array.fromInitializer(~length=numClasses, c => classScore(c, features))
    let bestClass = ref(0)
    let bestScore = ref(switch Array.get(scores, 0) { | Some(v) => v | None => 0 })
    scores->Array.forEachWithIndex((s, c) => {
      if s > bestScore.contents {
        bestClass := c
        bestScore := s
      }
    })
    let totalScore = Array.reduce(scores, 0, (acc, s) => acc + s)
    let otherMean  =
      if numClasses <= 1 {0}
      else {(totalScore - bestScore.contents) / (numClasses - 1)}
    let margin = bestScore.contents - otherMean
    let confidence = min(1000, max(0, margin * 5))
    (bestClass.contents, confidence)
  }

  let cmdClassify = (data: array<int>): executionResult => {
    let n = switch Array.get(data, 0) { | Some(v) if v > 0 => v | _ => Array.length(data) }
    let features = Array.slice(data, ~start=1, ~end=1 + n)
    if Array.length(features) == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Neural: classify requires at least 1 feature")}
    } else {
      let (classId, confidence) = classify(features)
      {
        status:  0,
        data:    [classId, confidence],
        metrics: {computeUnits: 800, memoryBytes: 512, energyJoules: 0.15, latencyMs: 10.0},
        message: Some(`Neural: classify → ${className(classId)} (confidence=${Int.toString(confidence)})`),
      }
    }
  }

  // predict — linear regression on a numeric sequence
  let linearFit = (pts: array<int>): (float, float) => {
    let n  = Array.length(pts)
    let nF = Float.fromInt(n)
    let sumX  = Float.fromInt(n * (n - 1) / 2)
    let sumX2 = Float.fromInt(n * (n - 1) * (2 * n - 1) / 6)
    let sumY  = Array.reduce(pts, 0.0, (acc, v) => acc +. Float.fromInt(v))
    let sumXY =
      pts->Array.mapWithIndex((v, i) => Float.fromInt(i) *. Float.fromInt(v))
      ->Array.reduce(0.0, (acc, x) => acc +. x)
    let denom = nF *. sumX2 -. sumX *. sumX
    if denom < 0.0001 && denom > -0.0001 {
      (0.0, sumY /. nF)
    } else {
      let slope     = (nF *. sumXY -. sumX *. sumY) /. denom
      let intercept = (sumY -. slope *. sumX) /. nF
      (slope, intercept)
    }
  }

  let computeR2 = (pts: array<int>, slope: float, intercept: float): float => {
    let n    = Array.length(pts)
    let nF   = Float.fromInt(n)
    let sumY = Array.reduce(pts, 0.0, (acc, v) => acc +. Float.fromInt(v))
    let mean = sumY /. nF
    let ssTot =
      Array.reduce(pts, 0.0, (acc, v) => {
        let d = Float.fromInt(v) -. mean
        acc +. d *. d
      })
    let ssRes =
      pts->Array.mapWithIndex((v, i) => {
        let yHat = slope *. Float.fromInt(i) +. intercept
        let d    = Float.fromInt(v) -. yHat
        d *. d
      })->Array.reduce(0.0, (acc, x) => acc +. x)
    if ssTot < 0.0001 {1.0}
    else {
      let r2 = 1.0 -. ssRes /. ssTot
      if r2 < 0.0 {0.0} else {r2}
    }
  }

  let cmdPredict = (data: array<int>): executionResult => {
    let len = Array.length(data)
    if len == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Neural: predict requires at least 1 value")}
    } else if len == 1 {
      let v = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
      {status: 0, data: [v, 0], metrics: emptyMetrics,
       message: Some("Neural: predict (single-point → no regression, confidence=0)")}
    } else {
      let window = if len < 5 {len} else {5}
      let pts    = Array.slice(data, ~start=len - window, ~end=len)
      let (slope, intercept) = linearFit(pts)
      let r2         = computeR2(pts, slope, intercept)
      let predicted  = Float.toInt(Math.floor(slope *. Float.fromInt(window) +. intercept))
      let confidence = Float.toInt(Math.floor(r2 *. 1000.0))
      {
        status:  0,
        data:    [predicted, confidence],
        metrics: {computeUnits: 600, memoryBytes: 256, energyJoules: 0.12, latencyMs: 8.0},
        message: Some(`Neural: predict next=${Int.toString(predicted)} confidence=${Int.toString(confidence)}`),
      }
    }
  }

  // anomaly — statistical outlier detection on the last element
  let cmdAnomaly = (data: array<int>): executionResult => {
    let n = switch Array.get(data, 0) { | Some(v) if v > 0 => v | _ => 0 }
    let values = Array.slice(data, ~start=1, ~end=1 + n)
    let len    = Array.length(values)
    if len == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Neural: anomaly requires data[0]=n and n > 0 values")}
    } else {
      let nF       = Float.fromInt(len)
      let sum      = Array.reduce(values, 0, (acc, v) => acc + v)
      let mean     = Float.fromInt(sum) /. nF
      let variance =
        Array.reduce(values, 0.0, (acc, v) => {
          let d = Float.fromInt(v) -. mean
          acc +. d *. d
        }) /. nF
      let stddev  = Math.sqrt(variance)
      let lastVal = switch Array.get(values, len - 1) { | Some(v) => v | None => 0 }
      let devF    = if Float.fromInt(lastVal) >= mean
                    {Float.fromInt(lastVal) -. mean}
                    else {mean -. Float.fromInt(lastVal)}
      let deviation  = Float.toInt(Math.floor(devF))
      let isAnomaly  = devF > 2.0 *. stddev
      {
        status:  0,
        data:    [if isAnomaly {1} else {0}, deviation],
        metrics: {computeUnits: 500, memoryBytes: len * 4, energyJoules: 0.10, latencyMs: 6.0},
        message: Some(`Neural: anomaly last=${Int.toString(lastVal)} mean=${Int.toString(Float.toInt(Math.floor(mean)))} σ=${Int.toString(Float.toInt(Math.floor(stddev)))} anomaly=${if isAnomaly {"YES"} else {"no"}}`),
      }
    }
  }

  // fingerprint — heuristic protocol identification from traffic bytes
  let countInRange = (arr: array<int>, lo: int, hi: int): int =>
    Array.filter(arr, v => v >= lo && v <= hi)->Array.length

  let fingerprint = (sample: array<int>): (int, int) => {
    let total = Array.length(sample)
    if total == 0 {(0, 0)}
    else {
      let printable = countInRange(sample, 32, 126)
      let control   = countInRange(sample, 0,  31)
      let compact   = countInRange(sample, 0,  63)
      let highByte  = countInRange(sample, 200, 255)
      let pPrint    = Float.fromInt(printable) /. Float.fromInt(total)
      let pControl  = Float.fromInt(control)   /. Float.fromInt(total)
      let pCompact  = Float.fromInt(compact)   /. Float.fromInt(total)
      let pHigh     = Float.fromInt(highByte)  /. Float.fromInt(total)
      let httpScore  = Float.toInt(pPrint   *. 1000.0)
      let sshScore   = Float.toInt(pControl *. 900.0)
      let dnsScore   = Float.toInt(if total < 60 {pCompact *. 850.0} else {0.0})
      let smtpScore  = Float.toInt(pHigh    *. 800.0)
      let ftpScore   = Float.toInt(if pPrint > 0.3 && pPrint < 0.8 {500.0} else {0.0})
      let scores     = [httpScore, sshScore, dnsScore, smtpScore, ftpScore]
      let best       = ref(0)
      let bestScore  = ref(switch Array.get(scores, 0) { | Some(v) => v | None => 0 })
      scores->Array.forEachWithIndex((s, idx) => {
        if s > bestScore.contents { best := idx; bestScore := s }
      })
      if bestScore.contents < 200 {
        (0, 300)
      } else {
        (best.contents + 1, min(1000, bestScore.contents))
      }
    }
  }

  let protocolName = (id: int): string =>
    switch id {
    | 1 => "HTTP"
    | 2 => "SSH"
    | 3 => "DNS"
    | 4 => "SMTP"
    | 5 => "FTP"
    | _ => "UNKNOWN"
    }

  let cmdFingerprint = (data: array<int>): executionResult => {
    if Array.length(data) == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Neural: fingerprint requires at least 1 traffic sample byte")}
    } else {
      let (protocolId, confidence) = fingerprint(data)
      {
        status:  0,
        data:    [protocolId, confidence],
        metrics: {computeUnits: 700, memoryBytes: Array.length(data) * 2, energyJoules: 0.13, latencyMs: 9.0},
        message: Some(`Neural: fingerprint → ${protocolName(protocolId)} (confidence=${Int.toString(confidence)})`),
      }
    }
  }

  // evade — randomised behaviour modification to avoid pattern matching
  let cmdEvade = (data: array<int>): executionResult => {
    let patternId  = switch Array.get(data, 0) { | Some(p) => p | None => 0 }
    let behaviour  = Array.slice(data, ~start=1, ~end=Array.length(data))
    let bLen       = Array.length(behaviour)
    if bLen == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Neural: evade requires [patternId, b0..bN] with at least one behaviour byte")}
    } else {
      let modified = behaviour->Array.mapWithIndex((b, i) => {
        let noisePart  = Float.toInt(Math.random() *. 255.0)
        let structPart = Int.Bitwise.land(patternId * 31 + i * 13 + 7, 0xFF)
        let mask       = Int.Bitwise.land(noisePart + structPart, 0xFF)
        Int.Bitwise.lxor(b, mask)
      })
      {
        status:  0,
        data:    modified,
        metrics: {computeUnits: 900, memoryBytes: bLen * 4, energyJoules: 0.18, latencyMs: 12.0},
        message: Some(`Neural: evade patternId=${Int.toString(patternId)} modified ${Int.toString(bLen)} bytes`),
      }
    }
  }

  module Backend = {
    let id          = "neural-heuristic"
    let domain      = Domain.Neural
    let description = "Game-simulation neural: classify, predict, anomaly, fingerprint, evade"

    let execute = (cmd: string, data: array<int>): promise<executionResult> => {
      let result = switch cmd {
      | "classify"    => cmdClassify(data)
      | "predict"     => cmdPredict(data)
      | "anomaly"     => cmdAnomaly(data)
      | "fingerprint" => cmdFingerprint(data)
      | "evade"       => cmdEvade(data)
      | _ =>
        {
          status:  400,
          data:    [],
          metrics: emptyMetrics,
          message: Some(`Neural: unknown command "${cmd}". Valid: classify predict anomaly fingerprint evade`),
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
// Quantum — Quantum-circuit simulation coprocessor backend
// ===========================================================================

module Quantum = {
  // Monotonically increasing entanglement ID (session-scoped).
  let entangleCounter: ref<int> = ref(0)

  // Factor n by trial division without the 65535 cap.
  let shorFactors = (n: int): array<int> => {
    let factors = ref([])
    let rem     = ref(n)
    let d       = ref(2)
    while d.contents * d.contents <= rem.contents {
      while rem.contents > 0 && mod(rem.contents, d.contents) == 0 {
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

  let cmdShor = (data: array<int>): executionResult => {
    let n = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    if n < 2 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some(`Quantum: shor requires n ≥ 2, got ${Int.toString(n)}`)}
    } else if n > 1000000000 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some(`Quantum: shor capped at n ≤ 10^9, got ${Int.toString(n)}`)}
    } else {
      let factors = shorFactors(n)
      let cost    = max(50, Float.toInt(Math.sqrt(Float.fromInt(abs(n)))))
      {
        status:  0,
        data:    factors,
        metrics: {
          computeUnits: 5000 + cost * 5,
          memoryBytes:  Array.length(factors) * 8,
          energyJoules: 1.0 +. Float.fromInt(cost) *. 0.001,
          latencyMs:    100.0 +. Float.fromInt(cost) *. 0.1,
        },
        message: Some(`Quantum: shor(${Int.toString(n)}) → ${Int.toString(Array.length(factors))} factors`),
      }
    }
  }

  let cmdGrover = (data: array<int>): executionResult => {
    let targetHash = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    let keyspace   = switch Array.get(data, 1) { | Some(v) if v >= 1 => v | _ => 1000 }
    let thresholdRaw = Math.sqrt(1000.0 /. Float.fromInt(keyspace))
    let threshold    = if thresholdRaw > 1.0 {1.0} else {thresholdRaw}
    let roll = Math.random()
    let cost = 3000 + keyspace / 2
    if roll < threshold {
      let crackedKey = Int.Bitwise.lxor(targetHash, Int.Bitwise.land(keyspace, 0xFF))
      {
        status:  0,
        data:    [1, crackedKey],
        metrics: {
          computeUnits: cost,
          memoryBytes:  512,
          energyJoules: 0.8,
          latencyMs:    80.0,
        },
        message: Some(`Quantum: grover SUCCESS key=0x${Int.toString(crackedKey)} keyspace=${Int.toString(keyspace)}`),
      }
    } else {
      {
        status:  0,
        data:    [0],
        metrics: {
          computeUnits: cost,
          memoryBytes:  256,
          energyJoules: 0.6,
          latencyMs:    60.0,
        },
        message: Some(`Quantum: grover FAILED keyspace=${Int.toString(keyspace)} (threshold=${Float.toString(threshold)})`),
      }
    }
  }

  let cmdQrng = (data: array<int>): executionResult => {
    let count = switch Array.get(data, 0) {
    | Some(v) if v > 0 && v <= 256 => v
    | Some(v) if v > 256 => 256
    | _ => 1
    }
    let values = Array.fromInitializer(~length=count, _ =>
      Float.toInt(Math.floor(Math.random() *. 256.0))
    )
    {
      status:  0,
      data:    values,
      metrics: {
        computeUnits: count * 100,
        memoryBytes:  count * 4,
        energyJoules: Float.fromInt(count) *. 0.05,
        latencyMs:    10.0,
      },
      message: Some(`Quantum: qrng count=${Int.toString(count)}`),
    }
  }

  let cmdEntangle = (data: array<int>): executionResult => {
    let a = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
    let b = switch Array.get(data, 1) { | Some(v) => v | None => 0 }
    entangleCounter := entangleCounter.contents + 1
    let id = entangleCounter.contents
    {
      status:  0,
      data:    [id],
      metrics: {computeUnits: 2000, memoryBytes: 256, energyJoules: 0.5, latencyMs: 50.0},
      message: Some(`Quantum: entangle a=${Int.toString(a)} b=${Int.toString(b)} → id=${Int.toString(id)}`),
    }
  }

  module Backend = {
    let id          = "quantum-sim"
    let domain      = Domain.Quantum
    let description = "Quantum simulation: shor (unlimited factor), grover (amplified search), qrng, entangle"

    let execute = (cmd: string, data: array<int>): promise<executionResult> => {
      let result = switch cmd {
      | "shor"     => cmdShor(data)
      | "grover"   => cmdGrover(data)
      | "qrng"     => cmdQrng(data)
      | "entangle" => cmdEntangle(data)
      | "crack" =>
        let target   = switch Array.get(data, 0) { | Some(v) => v | None => 0 }
        let strength = switch Array.get(data, 1) { | Some(v) if v >= 0 => v | _ => 4 }
        let keyspace = max(1, 10 - strength) * 10
        cmdGrover([target, keyspace])
      | _ =>
        {
          status:  400,
          data:    [],
          metrics: emptyMetrics,
          message: Some(`Quantum: unknown command "${cmd}". Valid: shor grover qrng entangle`),
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
// Audio — DSP signal analysis coprocessor backend
// ===========================================================================

module Audio = {
  let maxSamples = 256

  // analyse — find the dominant (most frequent) level and peak amplitude.
  let cmdAnalyse = (data: array<int>): executionResult => {
    let n       = switch Array.get(data, 0) { | Some(v) if v > 0 => v | _ => 0 }
    let samples = Array.slice(data, ~start=1, ~end=1 + n)
    let len     = Array.length(samples)
    if len == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Audio: analyse requires data[0]=n > 0 and n samples")}
    } else {
      let buckets = Array.make(~length=256, 0)
      let peak    = ref(0)
      samples->Array.forEach(s => {
        let idx = Int.Bitwise.land(abs(s), 0xFF)
        let cur = switch Array.get(buckets, idx) { | Some(v) => v | None => 0 }
        Array.set(buckets, idx, cur + 1)
        if s > peak.contents { peak := s }
      })
      let dominant  = ref(0)
      let maxCount  = ref(0)
      buckets->Array.forEachWithIndex((count, level) => {
        if count > maxCount.contents {
          maxCount := count
          dominant := level
        }
      })
      {
        status:  0,
        data:    [dominant.contents, peak.contents],
        metrics: {computeUnits: 150, memoryBytes: len * 2, energyJoules: 0.03, latencyMs: 2.0},
        message: Some(`Audio: analyse dominant=${Int.toString(dominant.contents)} peak=${Int.toString(peak.contents)}`),
      }
    }
  }

  // filter — symmetric moving-average low-pass filter.
  let cmdFilter = (data: array<int>): executionResult => {
    let n       = switch Array.get(data, 0) { | Some(v) if v > 0 => v | _ => 0 }
    let cutoff  = switch Array.get(data, 1) { | Some(v) if v >= 1 => v | _ => 1 }
    let samples = Array.slice(data, ~start=2, ~end=2 + n)
    let len     = Array.length(samples)
    if len == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Audio: filter requires [n, cutoff, ...samples] with n > 0")}
    } else {
      let halfW  = cutoff / 2
      let result = Array.fromInitializer(~length=len, i => {
        let lo    = if i - halfW < 0 {0} else {i - halfW}
        let hi    = if i + halfW >= len {len - 1} else {i + halfW}
        let count = hi - lo + 1
        let sum   = ref(0)
        for k in lo to hi {
          sum := sum.contents + switch Array.get(samples, k) { | Some(v) => v | None => 0 }
        }
        sum.contents / count
      })
      {
        status:  0,
        data:    result,
        metrics: {
          computeUnits: len * 3,
          memoryBytes:  len * 4,
          energyJoules: 0.02,
          latencyMs:    1.0,
        },
        message: Some(`Audio: filter n=${Int.toString(len)} cutoff=${Int.toString(cutoff)} halfW=${Int.toString(halfW)}`),
      }
    }
  }

  // detect — threshold crossing detection.
  let cmdDetect = (data: array<int>): executionResult => {
    let n         = switch Array.get(data, 0) { | Some(v) if v > 0 => v | _ => 0 }
    let threshold = switch Array.get(data, 1) { | Some(v) => v | None => 0 }
    let samples   = Array.slice(data, ~start=2, ~end=2 + n)
    let len       = Array.length(samples)
    if len == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Audio: detect requires [n, threshold, ...samples] with n > 0")}
    } else {
      let peakIdx = ref(len)
      let found   = ref(false)
      samples->Array.forEachWithIndex((s, i) => {
        if !found.contents && s > threshold {
          peakIdx := i
          found   := true
        }
      })
      {
        status:  0,
        data:    [if found.contents {1} else {0}, peakIdx.contents],
        metrics: {computeUnits: 100, memoryBytes: len * 2, energyJoules: 0.02, latencyMs: 1.0},
        message: Some(`Audio: detect threshold=${Int.toString(threshold)} signal=${if found.contents {"YES at " ++ Int.toString(peakIdx.contents)} else {"NO"}}`),
      }
    }
  }

  // compare — absolute-difference similarity between two equal-length signals.
  let cmdCompare = (data: array<int>): executionResult => {
    let n  = switch Array.get(data, 0) { | Some(v) if v > 0 => v | _ => 0 }
    let a  = Array.slice(data, ~start=1, ~end=1 + n)
    let b  = Array.slice(data, ~start=1 + n, ~end=1 + n + n)
    let la = Array.length(a)
    let lb = Array.length(b)
    if la == 0 || lb == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Audio: compare requires [n, ...a(n), ...b(n)] with n > 0")}
    } else {
      let len      = if la < lb {la} else {lb}
      let totalDiff =
        Array.fromInitializer(~length=len, i => {
          let ai = switch Array.get(a, i) { | Some(v) => v | None => 0 }
          let bi = switch Array.get(b, i) { | Some(v) => v | None => 0 }
          abs(ai - bi)
        })->Array.reduce(0, (acc, d) => acc + d)
      let avgDiff   = if len == 0 {0} else {totalDiff / len}
      let similarity = 1000 - (if avgDiff > 1000 {1000} else {avgDiff})
      {
        status:  0,
        data:    [similarity],
        metrics: {
          computeUnits: len * 5,
          memoryBytes:  len * 8,
          energyJoules: 0.03,
          latencyMs:    2.0,
        },
        message: Some(`Audio: compare n=${Int.toString(len)} similarity=${Int.toString(similarity)}`),
      }
    }
  }

  module Backend = {
    let id          = "audio-dsp-sim"
    let domain      = Domain.Audio
    let description = "Audio DSP: analyse (dominant level + peak), filter (moving avg), detect (threshold), compare (similarity)"

    let execute = (cmd: string, data: array<int>): promise<executionResult> => {
      let result = switch cmd {
      | "analyse" => cmdAnalyse(data)
      | "filter"  => cmdFilter(data)
      | "detect"  => cmdDetect(data)
      | "compare" => cmdCompare(data)
      | _ =>
        {
          status:  400,
          data:    [],
          metrics: emptyMetrics,
          message: Some(`Audio: unknown command "${cmd}". Valid: analyse filter detect compare`),
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
// Graphics — Visual effects coprocessor backend
// ===========================================================================

module Graphics = {
  let maxPixels = 4096

  // LCG primitive (local copy — avoids cross-module dependency with Crypto).
  let lcgStep = (seed: int): (int, int) => {
    let next = Int.Bitwise.land(seed * 1664525 + 1013904223, 0x7FFFFFFF)
    (next, Int.Bitwise.land(next, 0xFF))
  }

  // Fisher-Yates swap helper.
  let swapAt = (arr: array<int>, i: int, j: int): unit => {
    let tmp = switch Array.get(arr, i) { | Some(v) => v | None => 0 }
    Array.set(arr, i, switch Array.get(arr, j) { | Some(v) => v | None => 0 })
    Array.set(arr, j, tmp)
  }

  // Derive the Fisher-Yates swap sequence for `len` elements seeded by `seed`.
  let deriveSwapJs = (seed: int, len: int): array<int> => {
    let js = Array.make(~length=max(0, len - 1), 0)
    let s  = ref(seed)
    for k in 0 to len - 2 {
      let i       = len - 1 - k
      let (next, _) = lcgStep(s.contents)
      s          := next
      let j       = mod(next, i + 1)
      Array.set(js, k, j)
    }
    js
  }

  // noise — LCG-seeded pixel noise pattern.
  let cmdNoise = (data: array<int>): executionResult => {
    let width  = switch Array.get(data, 0) { | Some(v) if v > 0 => v | _ => 1 }
    let height = switch Array.get(data, 1) { | Some(v) if v > 0 => v | _ => 1 }
    let seed   = switch Array.get(data, 2) { | Some(v) => v | None => 0 }
    let pixels = width * height
    if pixels > maxPixels {
      {status: 413, data: [], metrics: emptyMetrics,
       message: Some(`Graphics: noise ${Int.toString(width)}×${Int.toString(height)}=${Int.toString(pixels)} pixels exceeds cap of ${Int.toString(maxPixels)}`)}
    } else {
      let s   = ref(seed)
      let buf = Array.fromInitializer(~length=pixels, _ => {
        let (next, byte) = lcgStep(s.contents)
        s := next
        byte
      })
      {
        status:  0,
        data:    buf,
        metrics: {
          computeUnits: pixels,
          memoryBytes:  pixels * 2,
          energyJoules: 0.2,
          latencyMs:    16.0,
        },
        message: Some(`Graphics: noise ${Int.toString(width)}×${Int.toString(height)} seed=${Int.toString(seed)}`),
      }
    }
  }

  // scramble — Fisher-Yates shuffle of the input array.
  let cmdScramble = (data: array<int>): executionResult => {
    let n    = switch Array.get(data, 0) { | Some(v) if v > 0 => v | _ => 0 }
    let seed = switch Array.get(data, 1) { | Some(v) => v | None => 0 }
    let elems = Array.slice(data, ~start=2, ~end=2 + n)
    let len   = Array.length(elems)
    if len == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Graphics: scramble requires [n, seed, ...data] with n > 0")}
    } else {
      let swapJs = deriveSwapJs(seed, len)
      let result = Array.slice(elems, ~start=0, ~end=len)
      for k in 0 to len - 2 {
        let i = len - 1 - k
        let j = switch Array.get(swapJs, k) { | Some(v) => v | None => 0 }
        swapAt(result, i, j)
      }
      {
        status:  0,
        data:    result,
        metrics: {
          computeUnits: len * 2,
          memoryBytes:  len * 8,
          energyJoules: 0.05,
          latencyMs:    3.0,
        },
        message: Some(`Graphics: scramble n=${Int.toString(len)} seed=${Int.toString(seed)}`),
      }
    }
  }

  // unscramble — exact inverse of scramble given the same n and seed.
  let cmdUnscramble = (data: array<int>): executionResult => {
    let n    = switch Array.get(data, 0) { | Some(v) if v > 0 => v | _ => 0 }
    let seed = switch Array.get(data, 1) { | Some(v) => v | None => 0 }
    let elems = Array.slice(data, ~start=2, ~end=2 + n)
    let len   = Array.length(elems)
    if len == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Graphics: unscramble requires [n, seed, ...data] with n > 0")}
    } else {
      let swapJs = deriveSwapJs(seed, len)
      let result = Array.slice(elems, ~start=0, ~end=len)
      for k in len - 2 downto 0 {
        let i = len - 1 - k
        let j = switch Array.get(swapJs, k) { | Some(v) => v | None => 0 }
        swapAt(result, i, j)
      }
      {
        status:  0,
        data:    result,
        metrics: {
          computeUnits: len * 2,
          memoryBytes:  len * 8,
          energyJoules: 0.05,
          latencyMs:    3.0,
        },
        message: Some(`Graphics: unscramble n=${Int.toString(len)} seed=${Int.toString(seed)}`),
      }
    }
  }

  // blend — linear interpolation between two arrays.
  let cmdBlend = (data: array<int>): executionResult => {
    let n     = switch Array.get(data, 0) { | Some(v) if v > 0 => v | _ => 0 }
    let ratio = switch Array.get(data, 1) {
    | Some(v) if v < 0    => 0
    | Some(v) if v > 1000 => 1000
    | Some(v) => v
    | None    => 500
    }
    let a = Array.slice(data, ~start=2, ~end=2 + n)
    let b = Array.slice(data, ~start=2 + n, ~end=2 + n + n)
    let la = Array.length(a)
    let lb = Array.length(b)
    if la == 0 || lb == 0 {
      {status: 400, data: [], metrics: emptyMetrics,
       message: Some("Graphics: blend requires [n, ratio, ...a(n), ...b(n)] with n > 0")}
    } else {
      let len    = if la < lb {la} else {lb}
      let result = Array.fromInitializer(~length=len, i => {
        let ai = switch Array.get(a, i) { | Some(v) => v | None => 0 }
        let bi = switch Array.get(b, i) { | Some(v) => v | None => 0 }
        (ai * (1000 - ratio) + bi * ratio) / 1000
      })
      {
        status:  0,
        data:    result,
        metrics: {
          computeUnits: len * 2,
          memoryBytes:  len * 12,
          energyJoules: 0.03,
          latencyMs:    2.0,
        },
        message: Some(`Graphics: blend n=${Int.toString(len)} ratio=${Int.toString(ratio)}/1000`),
      }
    }
  }

  module Backend = {
    let id          = "graphics-effects"
    let domain      = Domain.Graphics
    let description = "Visual effects: noise (LCG, ≤4096 pixels), scramble/unscramble (Fisher-Yates), blend (integer lerp)"

    let execute = (cmd: string, data: array<int>): promise<executionResult> => {
      let result = switch cmd {
      | "noise"       => cmdNoise(data)
      | "scramble"    => cmdScramble(data)
      | "unscramble"  => cmdUnscramble(data)
      | "blend"       => cmdBlend(data)
      | _ =>
        {
          status:  400,
          data:    [],
          metrics: emptyMetrics,
          message: Some(`Graphics: unknown command "${cmd}". Valid: noise scramble unscramble blend`),
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
