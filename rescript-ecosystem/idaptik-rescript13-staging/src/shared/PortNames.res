// SPDX-License-Identifier: PMPL-1.0-or-later
// PortNames.res  Well-known VM I/O port names
//
// Conventions for port names used by SEND/RECV instructions.
// Both the VM and game components reference these constants
// to ensure port names match at integration boundaries.

// --- System ports (always available) ---
let console = "console"       // Terminal text output
let display = "display"       // HUD/overlay messages
let audio = "audio"           // Trigger sound effects
let alert = "alert"           // Security alert system

// --- Network device ports ---
let firewall = "firewall"     // Firewall ACL control
let router = "router"         // Routing table manipulation
let switch_ = "switch"        // Switch port configuration
let server = "server"         // Server service interaction
let camera = "camera"         // Camera feed / disable

// --- Hardware ports (ADR-0012 wiring challenges) ---
let patchPanel = "patch"      // Patch panel wiring
let powerSupply = "power"     // Power management
let fibreHub = "fibre"        // Fibre optic splicing
let phoneSystem = "pbx"       // PBX / comms system

// --- Control suffixes ---
// Append to device port for specific channels:
//   ":in"    VM reads from device (RECV)
//   ":out"   VM writes to device (SEND)
//   ":ctrl"  Control commands (lock, unlock, reboot)

let inputSuffix = ":in"
let outputSuffix = ":out"
let controlSuffix = ":ctrl"

// Build a full port name with suffix
let withInput = (port: string): string => port ++ inputSuffix
let withOutput = (port: string): string => port ++ outputSuffix
let withControl = (port: string): string => port ++ controlSuffix

// --- Co-op ports (multiplayer) ---
let coopSync = "coop:sync"    // State synchronisation
let coopChat = "coop:chat"    // Player-to-player messages
let coopItem = "coop:item"    // Item passing between players

// --- Coprocessor ports ---
// Convention: the port name is the domain prefix only (e.g. "crypto").
// The CoprocessorBridge splits "domain:command" from the SEND port name to
// determine which domain and command to dispatch. These constants are the
// domain prefix half; the command suffix is appended by the VM program.
//
// Example VM program:
//   SEND crypto:hash x     → send value of register x to crypto, command "hash"
//   RECV crypto:hash y     → receive first result byte into register y
//
// Multi-value protocol: SEND multiple values, then SEND -1 as a flush signal
// to trigger execution. Result values are queued for successive RECV calls.
let cpCrypto = "crypto"       // Cryptography: hash, crack, encrypt, decrypt, sign, verify, keygen
let cpVector = "vector"       // Vector arithmetic: add, dot, scale, norm, compare, sort
let cpMaths = "maths"         // Higher maths: sqrt, pow, gcd, mod, prime, factor, fib, rand
let cpIO = "io"               // Virtual filesystem: read, write, list, delete, stat
let cpNeural = "neural"       // Pattern recognition: classify, predict, anomaly, fingerprint, evade
let cpQuantum = "quantum"     // Quantum ops: shor, grover, qrng, entangle
let cpPhysics = "physics"     // Hardware sim: distance, signal, thermal, cablesag, power
let cpAudio = "audio"         // Signal analysis: analyse, filter, detect, compare
let cpTensor = "tensor"       // Matrix ops: matmul, transpose, trace, adjacency
let cpGraphics = "graphics"   // Visual effects: noise, scramble, unscramble, blend

// All coprocessor domain prefixes as an array.
// Used by CoprocessorBridge to determine whether a SEND port targets a coprocessor.
let coprocessorDomains = [
  cpCrypto, cpVector, cpMaths, cpIO, cpNeural,
  cpQuantum, cpPhysics, cpAudio, cpTensor, cpGraphics,
]

// Test whether a port name targets a coprocessor domain.
// Matches both bare domain names ("crypto") and domain:command pairs ("crypto:hash").
let isCoprocessorPort = (port: string): bool => {
  let _prefix = switch String.split(port, ":")->Array.get(0) {
  | Some(p) => p
  | None => port
  }
  coprocessorDomains->Array.some(domain => String.startsWith(port, domain))
}
