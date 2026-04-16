// SPDX-License-Identifier: PMPL-1.0-or-later
// Kernel_IO.res  IO domain kernel handler with per-device sandbox enforcement.
//
// Wraps Coprocessor_IO.executeForDevice with a path-sandbox check before
// dispatching.  Each device may only access paths within its own sandbox
// root: "/sandbox/<deviceId>/".  Attempts to read or write outside this
// prefix are rejected with status 403 (Forbidden).
//
// Why bypass backend.execute here:
//   The Coprocessor.backend.execute type signature is (string, array<int>)
//   — no deviceId parameter.  The IO backend needs a deviceId to isolate
//   each device's virtual filesystem.  Rather than threading deviceId
//   through an out-of-band channel, Kernel_IO calls
//   Coprocessor_IO.executeForDevice(deviceId, cmd, data) directly.
//
// Path decoding:
//   Paths arrive as ASCII int arrays in `data` (same encoding used by
//   Coprocessor_IO).  The kernel decodes just enough of the path to
//   perform the sandbox check; the full decode is repeated inside
//   Coprocessor_IO (no shared mutable state, so this is safe).
//
// Commands routed through this handler:
//   write, read, list, delete, stat   — all IO commands
//
// Commands that bypass the sandbox check (none currently):
//   — future "system" commands could whitelist specific paths here

open Coprocessor

// ---------------------------------------------------------------------------
// Sandbox enforcement
// ---------------------------------------------------------------------------

// Decode ASCII path bytes from the start of a data array.
// Stops at the first zero byte (null separator between path and content
// in the write command) or at end of array.
// Mirrors the logic in Coprocessor_IO.decodePath — kept here to avoid
// importing implementation details from the backend module.
let decodePathForCheck = (data: array<int>): string => {
  let buf  = ref("")
  let stop = ref(false)
  data->Array.forEach(b => {
    if !stop.contents {
      if b == 0 {
        stop := true
      } else if b > 0 && b < 128 {
        buf := buf.contents ++ String.fromCharCode(b)
      }
    }
  })
  buf.contents
}

// Return true if `path` is within the device's sandbox root.
// The sandbox root is "/sandbox/<deviceId>/" (directory) or exactly
// "/sandbox/<deviceId>" (the root itself).
// An empty path is also allowed — it means "no path given" and the
// backend will return a 400 error on its own.
let inSandbox = (deviceId: string, path: string): bool => {
  let root = "/sandbox/" ++ deviceId
  String.length(path) == 0 ||
  path == root ||
  String.startsWith(path, root ++ "/")
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

// Handle an IO domain call for the given device.
//
// Flow:
//   1. Decode path from data for sandbox check (write: before the null sep)
//   2. Reject with 403 if path is outside the device sandbox
//   3. Dispatch to Coprocessor_IO.executeForDevice with the deviceId
let handleIO = (
  deviceId: string,
  cmd:      string,
  data:     array<int>,
): promise<executionResult> => {
  // Decode path for the sandbox check.
  // For write, data is [path\0content...]; decodePath stops at the null,
  // so we get just the path portion.  For all other commands, data IS
  // the path.  Either way, this gives the correct path to check.
  let path = decodePathForCheck(data)

  if !inSandbox(deviceId, path) {
    Promise.resolve({
      status:  403,
      data:    [],
      metrics: emptyMetrics,
      message: Some(
        `IO kernel: path "${path}" is outside sandbox for device ${deviceId}. ` ++
        `Paths must be under /sandbox/${deviceId}/.`,
      ),
    })
  } else {
    // Delegate to the device-aware backend entry point.
    Coprocessor_IO.executeForDevice(deviceId, cmd, data)
  }
}
