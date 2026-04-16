// SPDX-License-Identifier: PMPL-1.0-or-later
// CoprocessorBridge.res  Terminal ↔ Coprocessor integration layer.
//
// Provides the `send`, `recv`, and `coproc` terminal commands for dispatching
// and collecting coprocessor results from within the in-game terminal.
//
// ──────────────────────────────────────────────────────────────────────────
// SEND <domain>:<cmd> [int ...]
//   Dispatch an async coprocessor operation on the currently-hacked device.
//   Returns immediately with a dispatch confirmation; the result is buffered
//   and retrieved on the next RECV call.
//
//   Supported domain prefixes (case-insensitive):
//     crypto  io  maths  vector  neural  physics  quantum  audio  tensor  graphics
//
//   Examples:
//     send crypto:hash 72 101 108 108 111       # hash [72,101,108,108,111]
//     send maths:factor 97531                    # prime-factorise 97531
//     send quantum:shor 10403                    # Shor factorisation of 10403
//     send vector:dot 3 1 2 3 4 5 6             # dot product of [1,2,3]·[4,5,6]
//     send io:write 47 115 98 120 47 0 65 66    # write /sbx/<device>/\0 AB
//
// ──────────────────────────────────────────────────────────────────────────
// RECV
//   Drain all resolved coprocessor results for the active device.
//   Prints status, data payload, message, and resource cost of each result.
//   Clears the buffer after printing.
//   Returns a notice if no ops have resolved yet.
//
// ──────────────────────────────────────────────────────────────────────────
// COPROC
//   Display a resource-usage summary (compute / memory / energy) for the
//   active device.  Equivalent to the KernelMonitor HUD in text form.
//
// ──────────────────────────────────────────────────────────────────────────
// Architecture:
//   Each device maintains an output buffer — a mutable array of formatted
//   result strings keyed by device ID (the device's IP address).
//   When a SEND resolves, the Promise.then callback appends the formatted
//   result.  RECV drains the buffer atomically and returns all entries.
//   CoprocessorManager.setup is called on the first SEND to a device so
//   that the KernelMonitor HUD can display bars immediately.
//
// All public functions are safe to call from synchronous Terminal command
// handlers; async dispatch is fire-and-forget (result flows to the buffer).

open Coprocessor

// ---------------------------------------------------------------------------
// Per-device output buffer
// ---------------------------------------------------------------------------

// Resolved coprocessor results waiting to be read by RECV, keyed by device ID.
// Populated asynchronously by Promise.then callbacks after each SEND dispatch.
let outputBuffers: dict<ref<array<string>>> = Dict.make()

// Retrieve or lazily create the result buffer for a device.
// All SEND and RECV calls for a device share the same buffer reference.
let getBuffer = (deviceId: string): ref<array<string>> => {
  switch Dict.get(outputBuffers, deviceId) {
  | Some(b) => b
  | None =>
    let b = ref([])
    Dict.set(outputBuffers, deviceId, b)
    b
  }
}

// Append one formatted result string to the device's output buffer.
// Called from the async Promise.then callback after each coprocessor op resolves.
let appendResult = (deviceId: string, text: string): unit => {
  let buf = getBuffer(deviceId)
  buf := Array.concat(buf.contents, [text])
}

// ---------------------------------------------------------------------------
// Domain name parsing
// ---------------------------------------------------------------------------

// Map a lower-cased domain name string to the Domain.t variant.
// Returns None for unrecognised names so callers can emit a helpful error.
let parseDomain = (name: string): option<Domain.t> => {
  switch String.toLowerCase(name) {
  | "crypto"   => Some(Domain.Crypto)
  | "io"       => Some(Domain.IO)
  | "maths"    => Some(Domain.Maths)
  | "vector"   => Some(Domain.Vector)
  | "neural"   => Some(Domain.Neural)
  | "physics"  => Some(Domain.Physics)
  | "quantum"  => Some(Domain.Quantum)
  | "audio"    => Some(Domain.Audio)
  | "tensor"   => Some(Domain.Tensor)
  | "graphics" => Some(Domain.Graphics)
  | _          => None
  }
}

// ---------------------------------------------------------------------------
// Result formatting
// ---------------------------------------------------------------------------

// Format an executionResult as a human-readable terminal block.
// Non-zero status codes are labelled as errors with their numeric code.
// Costs are reported as: compute-units / memory-bytes / energy-joules.
let formatResult = (domain: string, cmd: string, result: executionResult): string => {
  let statusTag = if result.status == 0 {
    "[OK]"
  } else {
    `[ERR ${Int.toString(result.status)}]`
  }
  let dataStr = if Array.length(result.data) == 0 {
    "(empty)"
  } else {
    let ints = Array.map(result.data, v => Int.toString(v))
    "[" ++ Array.join(ints, ", ") ++ "]"
  }
  let msgStr = switch result.message {
  | Some(m) => `\n  msg : ${m}`
  | None    => ""
  }
  `${statusTag} ${domain}:${cmd}` ++
  `\n  data: ${dataStr}${msgStr}` ++
  `\n  cost: ${Int.toString(result.metrics.computeUnits)} cu / ` ++
  `${Int.toString(result.metrics.memoryBytes)} B / ` ++
  `${Float.toFixed(result.metrics.energyJoules, ~digits=3)} J`
}

// ---------------------------------------------------------------------------
// Command: SEND
// ---------------------------------------------------------------------------

// Handle the terminal `send` command.
//
// Parameters:
//   deviceId — IP address of the hacked device (empty string if no active device)
//   spec     — "<domain>:<cmd>" token from the terminal (e.g. "crypto:hash")
//   dataArgs — remaining terminal tokens; each must parse as a decimal integer
//
// Returns a synchronous dispatch-confirmation string.  The async result is
// appended to the device's output buffer via Promise.then and collected by RECV.
let handleSend = (deviceId: string, spec: string, dataArgs: array<string>): string => {
  if String.length(deviceId) == 0 {
    "send: no device attached — open a terminal on a hacked device first"
  } else if String.length(spec) == 0 {
    "send: usage: send <domain>:<cmd> [int ...]\n" ++
    "  domains: crypto  io  maths  vector  neural  physics  quantum  audio  tensor  graphics"
  } else {
    // Parse "domain:cmd" — split on the first colon only.
    // This allows cmd names like "io:write" without colliding on embedded colons.
    let colonIdx = String.indexOf(spec, ":")
    if colonIdx < 0 {
      `send: invalid spec "${spec}" — expected "<domain>:<cmd>" e.g. "crypto:hash"`
    } else {
      let domainStr = String.slice(spec, ~start=0, ~end=colonIdx)
      let cmdStr    = String.sliceToEnd(spec, ~start=colonIdx + 1)
      if String.length(cmdStr) == 0 {
        `send: missing command after ":" in "${spec}" — e.g. "crypto:hash"`
      } else {
        switch parseDomain(domainStr) {
        | None =>
          `send: unknown domain "${domainStr}".\n` ++
          `  Valid domains: crypto  io  maths  vector  neural  physics  quantum  audio  tensor  graphics`
        | Some(domain) =>
          // Parse integer data arguments — reject on the first non-integer.
          let badArg = Array.find(dataArgs, s => Int.fromString(s) == None)
          switch badArg {
          | Some(bad) =>
            `send: non-integer argument "${bad}" — all data values must be decimal integers`
          | None =>
            let data   = Array.filterMap(dataArgs, s => Int.fromString(s))
            let domStr = Domain.toString(domain)
            // Enrol the device in resource accounting on first contact so that
            // the KernelMonitor HUD can display bars before any op resolves.
            CoprocessorManager.setup(deviceId)
            // Dispatch asynchronously.  The resolved result is formatted and
            // appended to the device's buffer for retrieval by RECV.
            let _ = CoprocessorManager.call(deviceId, domain, cmdStr, data)->Promise.then(result => {
              appendResult(deviceId, formatResult(domStr, cmdStr, result))
              Promise.resolve()
            })
            // Build a concise data preview for the confirmation line.
            let dataPreview = if Array.length(data) == 0 {
              "(no data)"
            } else if Array.length(data) <= 6 {
              let strs = Array.map(data, v => Int.toString(v))
              "[" ++ Array.join(strs, ", ") ++ "]"
            } else {
              let prefix = Array.slice(data, ~start=0, ~end=6)
              let prefixStrs = Array.map(prefix, v => Int.toString(v))
              "[" ++ Array.join(prefixStrs, ", ") ++
              " ... +" ++ Int.toString(Array.length(data) - 6) ++ " more]"
            }
            `Dispatched ${domStr}:${cmdStr} on ${deviceId}\n` ++
            `  data: ${dataPreview}\n` ++
            `  Use RECV to collect the result.`
          }
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Command: RECV
// ---------------------------------------------------------------------------

// Handle the terminal `recv` command.
//
// Drains all resolved coprocessor results for `deviceId` and returns them
// as a single string separated by horizontal rules.  Clears the buffer
// atomically after reading.  Returns a notice if no results are pending.
let handleRecv = (deviceId: string): string => {
  if String.length(deviceId) == 0 {
    "recv: no device attached"
  } else {
    let buf = getBuffer(deviceId)
    if Array.length(buf.contents) == 0 {
      "recv: no pending results — run SEND first, then RECV after a moment"
    } else {
      let results = buf.contents
      buf := []   // drain the buffer atomically
      let count = Array.length(results)
      `recv: ${Int.toString(count)} result(s) from ${deviceId}\n` ++
      "─────────────────────────────\n" ++
      Array.join(results, "\n─────────────────────────────\n")
    }
  }
}

// ---------------------------------------------------------------------------
// Command: COPROC
// ---------------------------------------------------------------------------

// Return a formatted resource-usage summary for `deviceId`.
// Delegates to Kernel.getDeviceReport, which reports compute / memory /
// energy utilisation with percentages and raw values.
let getDeviceStatus = (deviceId: string): string => {
  if String.length(deviceId) == 0 {
    "coproc: no device attached"
  } else {
    Kernel.getDeviceReport(deviceId)
  }
}
