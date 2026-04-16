// SPDX-License-Identifier: PMPL-1.0-or-later
// Coprocessor.res  High-performance execution framework

module Domain = {
  type t =
    | IO        // Async I/O, filesystem, network
    | Vector    // SIMD-style vector arithmetic
    | Tensor    // Multi-dimensional array ops (ML/Neural)
    | Graphics  // GPU rendering and shader execution
    | Physics   // Collision detection, rigid body dynamics
    | Maths     // High-precision or complex mathematical functions
    | Quantum   // Quantum circuit simulation or QPU bridge
    | Crypto    // Post-quantum cryptography, hashing, signatures
    | Audio     // DSP, synthesis, spatial audio
    | Neural    // Inference and training backends
    
  let toString = (d: t): string => {
    switch d {
    | IO => "IO"
    | Vector => "Vector"
    | Tensor => "Tensor"
    | Graphics => "Graphics"
    | Physics => "Physics"
    | Maths => "Maths"
    | Quantum => "Quantum"
    | Crypto => "Crypto"
    | Audio => "Audio"
    | Neural => "Neural"
    }
  }
}

// --- Resource Awareness ---

type resourceMetrics = {
  computeUnits: int,    // CPU/GPU cycles or equivalent
  memoryBytes: int,     // Memory peak usage
  energyJoules: float,  // Simulated energy consumption
  latencyMs: float,     // Real-time execution delay
}

type executionResult = {
  status: int, // 0 = Success, non-zero = Error code
  data: array<int>,
  metrics: resourceMetrics,
  message: option<string>,
}

type resourceStats = {
  mutable totalCompute: int,
  mutable totalMemory: int,
  mutable totalEnergy: float,
  mutable totalCalls: int,
}

type backend = {
  id: string,
  domain: Domain.t,
  description: string,
  stats: resourceStats,
  execute: (string, array<int>) => promise<executionResult>,
  isAccelerated: unit => bool,
}

// --- Global Registry ---

let backends: dict<backend> = Dict.make()

let register = (b: backend): unit => {
  Dict.set(backends, b.id, b)
  Console.log(`Coprocessor: Registered backend "${b.id}" for domain ${Domain.toString(b.domain)}`)
}

let get = (id: string): option<backend> => {
  Dict.get(backends, id)
}

let listByDomain = (d: Domain.t): array<backend> => {
  Dict.valuesToArray(backends)->Array.filter(b => b.domain == d)
}

// --- Power Integration ---

let powerConsumer: ref<option<(string, float) => unit>> = ref(None)

let setPowerConsumer = (handler: (string, float) => unit): unit => {
  powerConsumer := Some(handler)
}

let reportPowerUsage = (deviceIp: string, joules: float): unit => {
  switch powerConsumer.contents {
  | Some(handler) => handler(deviceIp, joules)
  | None => ()
  }
}

// --- Default Stub Backends ---
// NOTE: initDefaults() is NOT called in production. Real backends are
// registered by Coprocessor_Backends.initAll() from the consolidated files
// (Coprocessor_Security.res, Coprocessor_Compute.res, Coprocessor_IO.res).
// These stubs exist only for isolated testing without full backend init.

let emptyMetrics = {
  computeUnits: 0,
  memoryBytes: 0,
  energyJoules: 0.0,
  latencyMs: 0.0,
}

let createStub = (id: string, domain: Domain.t, description: string): backend => {
  {
    id,
    domain,
    description,
    stats: {
      totalCompute: 0,
      totalMemory: 0,
      totalEnergy: 0.0,
      totalCalls: 0,
    },
    execute: (cmd, _data) => {
      Promise.resolve({
        status: 0,
        data: [],
        metrics: {
          computeUnits: 10,
          memoryBytes: 1024,
          energyJoules: 0.01,
          latencyMs: 1.0,
        },
        message: Some(`Stub ${Domain.toString(domain)}: Received command "${cmd}"`),
      })
    },
    isAccelerated: () => false,
  }
}

let initDefaults = (): unit => {
  register(createStub("io-fallback", IO, "Standard JS async I/O"))
  register(createStub("vector-soft", Vector, "Software-emulated vector ops"))
  register(createStub("tensor-soft", Tensor, "Software-emulated tensor ops"))
  register(createStub("graphics-canvas", Graphics, "Standard 2D Canvas backend"))
  register(createStub("physics-soft", Physics, "Software physics engine"))
  register(createStub("maths-js", Maths, "Native JS Math library"))
  register(createStub("quantum-sim", Quantum, "Classical simulation of quantum circuits"))
  register(createStub("crypto-js", Crypto, "Standard JS Crypto API"))
  register(createStub("audio-web", Audio, "Web Audio API fallback"))
  register(createStub("neural-soft", Neural, "CPU-based neural inference"))
}
