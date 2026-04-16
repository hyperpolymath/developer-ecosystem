// SPDX-License-Identifier: PMPL-1.0-or-later
// Coprocessor_Backends.res  Coprocessor backend registry and initialisation.
//
// Registers ALL 10 coprocessor backends from 3 consolidated files:
//
//   Coprocessor_Security.res — Crypto, Neural, Quantum, Audio, Graphics
//   Coprocessor_Compute.res  — Maths, Vector, Tensor, Physics
//   Coprocessor_IO.res       — IO (per-device virtual filesystem, stateful)
//
// Registration order matters: Kernel.execute uses
// `listByDomain(...)->Array.get(0)`, which returns the first backend
// inserted for a domain.  All backends are inserted once — no domain
// has more than one registered backend in normal operation.
//
// Coprocessor.initDefaults() is intentionally NOT called.  It registers
// legacy fallback stubs (named "crypto-js", "io-fallback", etc.) that
// would shadow real backends depending on Dict iteration order.

// ---------------------------------------------------------------------------
// Initialisation
// ---------------------------------------------------------------------------

let initAll = (): unit => {
  // --- Tier A: core gameplay backends ---
  Coprocessor.register(Coprocessor_Security.Crypto.Backend.make())
  Coprocessor.register(Coprocessor_IO.Backend.make())
  Coprocessor.register(Coprocessor_Compute.Maths.Backend.make())

  // --- Tier B: enrichment backends ---
  Coprocessor.register(Coprocessor_Compute.Vector.Backend.make())
  Coprocessor.register(Coprocessor_Security.Neural.Backend.make())
  Coprocessor.register(Coprocessor_Compute.Physics.Backend.make())

  // --- Tier C: flavour backends ---
  Coprocessor.register(Coprocessor_Security.Quantum.Backend.make())
  Coprocessor.register(Coprocessor_Security.Audio.Backend.make())
  Coprocessor.register(Coprocessor_Compute.Tensor.Backend.make())
  Coprocessor.register(Coprocessor_Security.Graphics.Backend.make())
}
