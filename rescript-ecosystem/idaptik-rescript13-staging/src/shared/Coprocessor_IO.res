// SPDX-License-Identifier: PMPL-1.0-or-later
// Coprocessor_IO.res  Per-device virtual filesystem coprocessor backend.
//
// Implements the IO domain for the IDApTIK coprocessor framework.
// Each hacked device gets an isolated in-memory key-value filesystem.
// Paths are ASCII strings; file contents are int arrays.  No disk
// persistence — the filesystem lives for the game session and is
// reset when the device reboots (see CoprocessorManager.reset).
//
// Supported commands (invoked via SEND io:<cmd>):
//
//   write  — Store content at a path.
//            Data: [path bytes...] ++ [0] ++ [content bytes...]
//            (null byte 0 separates path from content)
//            Output: [] on success
//
//   read   — Retrieve content from a path.
//            Data: [path bytes...]
//            Output: content bytes, or status 404 if not found
//
//   list   — List all live paths under a prefix.
//            Data: [prefix bytes...]  (empty = list everything)
//            Output: path strings concatenated, each null-terminated
//
//   delete — Remove a path (tombstone — space not reclaimed).
//            Data: [path bytes...]
//            Output: [] on success, status 404 if not found
//
//   stat   — Return file size as a 2-byte big-endian int.
//            Data: [path bytes...]
//            Output: [size_hi, size_lo], [0, 0] if not found
//
// Path encoding convention:
//   VM programs encode file paths as ASCII codepoint arrays (1–127).
//   A zero byte (0) in the data array is the path/content separator
//   for the write command; it also terminates path arrays for other
//   commands (trailing data after 0 is ignored).
//
// Device isolation:
//   The backend.execute signature has no deviceId parameter (it is
//   defined by the Coprocessor.backend type).  Kernel_IO.handleIO
//   therefore calls executeForDevice(deviceId, cmd, data) directly,
//   bypassing backend.execute.  The backend.execute stub calls
//   executeForDevice with a fallback id and should not be reached
//   in normal game play.
//
// Deletion semantics:
//   @rescript/core provides no Dict.delete.  Deleted paths are
//   recorded in a module-level `deletedPaths` tombstone dict keyed
//   by "deviceId\x00path".  A write to a previously deleted path
//   clears its tombstone.

open Coprocessor

// ---------------------------------------------------------------------------
// Per-device filesystem state
// ---------------------------------------------------------------------------

// Two-level dict: deviceId → (filePath → content).
// Lazily populated on first access per device.
let filesystems: dict<dict<array<int>>> = Dict.make()

// Tombstone set for deleted paths.
// Key format: deviceId ++ "\x00" ++ filePath.
// Value true = deleted; false (or absent) = live.
let deletedPaths: dict<bool> = Dict.make()

// Retrieve (or lazily create) the file dict for a device.
let getFs = (deviceId: string): dict<array<int>> =>
  switch Dict.get(filesystems, deviceId) {
  | Some(fs) => fs
  | None =>
    let fs = Dict.make()
    Dict.set(filesystems, deviceId, fs)
    fs
  }

// Build the tombstone lookup key for a (device, path) pair.
let tombKey = (deviceId: string, path: string): string =>
  deviceId ++ "\x00" ++ path

// Return true if a path has been tombstoned on this device.
let isTombstoned = (deviceId: string, path: string): bool =>
  switch Dict.get(deletedPaths, tombKey(deviceId, path)) {
  | Some(true) => true
  | _          => false
  }

// Mark a path as deleted.
let tombstone = (deviceId: string, path: string): unit =>
  Dict.set(deletedPaths, tombKey(deviceId, path), true)

// Clear a tombstone so a subsequent write is visible again.
let clearTombstone = (deviceId: string, path: string): unit =>
  Dict.set(deletedPaths, tombKey(deviceId, path), false)

// ---------------------------------------------------------------------------
// Data encoding helpers
// ---------------------------------------------------------------------------

// Decode ASCII path bytes (1–127) from the start of a data array.
// Stops at the first zero byte or end of array.  Non-ASCII bytes
// (128–255) are silently skipped to tolerate encoding noise.
let decodePath = (data: array<int>): string => {
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

// Encode an ASCII string back to an int array of codepoints.
// Used to build the output of the list command.
let encodePath = (s: string): array<int> => {
  let len = String.length(s)
  Array.fromInitializer(~length=len, i =>
    Int.Bitwise.land(Float.toInt(String.charCodeAt(s, i)), 0x7F)
  )
}

// Find the index of the first zero byte in a data array.
// Returns None if no zero byte is present.
let findNull = (data: array<int>): option<int> => {
  let found = ref(None)
  data->Array.forEachWithIndex((b, i) => {
    if b == 0 && Option.isNone(found.contents) {
      found := Some(i)
    }
  })
  found.contents
}

// Split data at the first zero byte into (path_bytes, content_bytes).
// If no zero byte is found, content_bytes is [].
let splitAtNull = (data: array<int>): (array<int>, array<int>) => {
  let totalLen = Array.length(data)
  switch findNull(data) {
  | None     => (data, [])
  | Some(ix) =>
    let pathPart    = Array.slice(data, ~start=0, ~end=ix)
    let contentPart = Array.slice(data, ~start=ix + 1, ~end=totalLen)
    (pathPart, contentPart)
  }
}

// ---------------------------------------------------------------------------
// Command implementations
// ---------------------------------------------------------------------------

// write — store content bytes at a path (creates or overwrites).
// Data: [path bytes...] ++ [0] ++ [content bytes...]
let cmdWrite = (deviceId: string, data: array<int>): executionResult => {
  let (pathBytes, content) = splitAtNull(data)
  let path = decodePath(pathBytes)
  if String.length(path) == 0 {
    {status: 400, data: [], metrics: emptyMetrics,
     message: Some("IO: write requires a non-empty path before the null separator")}
  } else {
    let fs         = getFs(deviceId)
    let contentLen = Array.length(content)
    Dict.set(fs, path, content)
    clearTombstone(deviceId, path)
    {
      status:  0,
      data:    [],
      metrics: {
        computeUnits: 50 + contentLen,
        memoryBytes:  contentLen,
        energyJoules: 0.005 +. Float.fromInt(contentLen) *. 0.00001,
        latencyMs:    1.0   +. Float.fromInt(contentLen) *. 0.001,
      },
      message: Some(`IO: write "${path}" (${Int.toString(contentLen)} bytes)`),
    }
  }
}

// read — retrieve content bytes for a path.
// Data: [path bytes...]
let cmdRead = (deviceId: string, data: array<int>): executionResult => {
  let path = decodePath(data)
  if String.length(path) == 0 {
    {status: 400, data: [], metrics: emptyMetrics,
     message: Some("IO: read requires a non-empty path")}
  } else if isTombstoned(deviceId, path) {
    {status: 404, data: [], metrics: emptyMetrics,
     message: Some(`IO: read "${path}" not found (deleted)`)}
  } else {
    let fs = getFs(deviceId)
    switch Dict.get(fs, path) {
    | None =>
      {status: 404, data: [], metrics: emptyMetrics,
       message: Some(`IO: read "${path}" not found`)}
    | Some(content) =>
      let contentLen = Array.length(content)
      {
        status:  0,
        data:    content,
        metrics: {
          computeUnits: 30 + contentLen,
          memoryBytes:  contentLen,
          energyJoules: 0.003 +. Float.fromInt(contentLen) *. 0.000005,
          latencyMs:    0.5   +. Float.fromInt(contentLen) *. 0.0005,
        },
        message: Some(`IO: read "${path}" (${Int.toString(contentLen)} bytes)`),
      }
    }
  }
}

// list — return all live paths under a prefix as null-terminated ASCII.
// Data: [prefix bytes...]  (empty data = no filter, list everything)
// Output: path1\0path2\0...pathN\0  encoded as int array.
let cmdList = (deviceId: string, data: array<int>): executionResult => {
  let prefix = decodePath(data)
  let fs     = getFs(deviceId)
  let paths  =
    Dict.keysToArray(fs)
    ->Array.filter(p =>
      !isTombstoned(deviceId, p) &&
      (String.length(prefix) == 0 || String.startsWith(p, prefix))
    )
  // Encode each path as ASCII bytes followed by a null terminator.
  let encoded =
    paths
    ->Array.map(p => Array.concat(encodePath(p), [0]))
    ->Array.reduce([], (acc, chunk) => Array.concat(acc, chunk))
  {
    status:  0,
    data:    encoded,
    metrics: {
      computeUnits: 20 + Array.length(paths) * 5,
      memoryBytes:  Array.length(encoded),
      energyJoules: 0.002,
      latencyMs:    0.2,
    },
    message: Some(`IO: list prefix="${prefix}" found ${Int.toString(Array.length(paths))} entries`),
  }
}

// delete — tombstone a path (does not reclaim memory).
// Data: [path bytes...]
let cmdDelete = (deviceId: string, data: array<int>): executionResult => {
  let path = decodePath(data)
  if String.length(path) == 0 {
    {status: 400, data: [], metrics: emptyMetrics,
     message: Some("IO: delete requires a non-empty path")}
  } else {
    let fs = getFs(deviceId)
    let live =
      switch Dict.get(fs, path) {
      | Some(_) => !isTombstoned(deviceId, path)
      | None    => false
      }
    if live {
      tombstone(deviceId, path)
      {
        status:  0,
        data:    [],
        metrics: {computeUnits: 20, memoryBytes: 0, energyJoules: 0.002, latencyMs: 0.3},
        message: Some(`IO: delete "${path}" removed`),
      }
    } else {
      {status: 404, data: [], metrics: emptyMetrics,
       message: Some(`IO: delete "${path}" not found`)}
    }
  }
}

// stat — return file size as a 2-byte big-endian pair.
// Data: [path bytes...]
// Output: [size_hi, size_lo], or [0, 0] if not found / deleted.
let cmdStat = (deviceId: string, data: array<int>): executionResult => {
  let path = decodePath(data)
  if String.length(path) == 0 {
    {status: 400, data: [0, 0], metrics: emptyMetrics,
     message: Some("IO: stat requires a non-empty path")}
  } else {
    let size =
      if isTombstoned(deviceId, path) {
        0
      } else {
        let fs = getFs(deviceId)
        switch Dict.get(fs, path) {
        | None          => 0
        | Some(content) => Array.length(content)
        }
      }
    let sizeHi = Int.Bitwise.land(Int.Bitwise.lsr(size, 8), 0xFF)
    let sizeLo = Int.Bitwise.land(size, 0xFF)
    {
      status:  0,
      data:    [sizeHi, sizeLo],
      metrics: {computeUnits: 10, memoryBytes: 0, energyJoules: 0.001, latencyMs: 0.1},
      message: Some(`IO: stat "${path}" size=${Int.toString(size)} bytes`),
    }
  }
}

// ---------------------------------------------------------------------------
// Device-aware entry point (called by Kernel_IO)
// ---------------------------------------------------------------------------

// Kernel_IO.handleIO calls this directly instead of backend.execute so that
// the deviceId (required for filesystem isolation) is available.
// This is the correct call path for all game code.
let executeForDevice = (
  deviceId: string,
  cmd:      string,
  data:     array<int>,
): promise<executionResult> => {
  let result = switch cmd {
  | "write"  => cmdWrite(deviceId, data)
  | "read"   => cmdRead(deviceId, data)
  | "list"   => cmdList(deviceId, data)
  | "delete" => cmdDelete(deviceId, data)
  | "stat"   => cmdStat(deviceId, data)
  | _ =>
    {
      status:  400,
      data:    [],
      metrics: emptyMetrics,
      message: Some(`IO: unknown command "${cmd}". Valid: write read list delete stat`),
    }
  }
  Promise.resolve(result)
}

// ---------------------------------------------------------------------------
// Backend
// ---------------------------------------------------------------------------

module Backend = {
  let id          = "io-virtual-fs"
  let domain      = Domain.IO
  let description = "Per-device in-memory virtual filesystem; isolated by deviceId"

  // Fallback execute — satisfies the backend type contract.
  // In practice, Kernel_IO calls executeForDevice directly.
  // This path is only reached if someone calls backend.execute outside
  // the kernel (e.g. unit tests or a future non-kernel caller).
  let execute = (cmd: string, data: array<int>): promise<executionResult> =>
    executeForDevice("__unknown__", cmd, data)

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
