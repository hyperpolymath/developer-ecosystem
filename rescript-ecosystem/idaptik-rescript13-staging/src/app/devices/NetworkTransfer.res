// SPDX-License-Identifier: PMPL-1.0-or-later
// Network Transfer  Bandwidth simulation with transfer queue and progress tracking

// Transfer state
type transferStatus = Pending | Active | Complete | Failed

type transfer = {
  id: int,
  sourceIp: string,
  destIp: string,
  fileName: string,
  totalBytes: float,
  mutable transferredBytes: float,
  bandwidthMBps: float,
  mutable status: transferStatus,
  mutable onProgress: option<float => unit>,
  mutable onComplete: option<unit => unit>,
}

// Global transfer queue
let nextId = ref(0)
let activeTransfers: dict<transfer> = Dict.make()

// Router traffic aggregation cache
let routerUpload: dict<float> = Dict.make()
let routerDownload: dict<float> = Dict.make()

// Start a new transfer
let startTransfer = (
  ~sourceIp: string,
  ~destIp: string,
  ~fileName: string,
  ~totalBytes: float,
  ~bandwidthMBps: float=1.0,
  ~onProgress: option<float => unit>=?,
  ~onComplete: option<unit => unit>=?,
  (),
): int => {
  let id = nextId.contents
  nextId := id + 1

  let t: transfer = {
    id,
    sourceIp,
    destIp,
    fileName,
    totalBytes,
    transferredBytes: 0.0,
    bandwidthMBps,
    status: Active,
    onProgress,
    onComplete,
  }

  Dict.set(activeTransfers, Int.toString(id), t)
  id
}

// Cancel a transfer
let cancelTransfer = (id: int): unit => {
  switch Dict.get(activeTransfers, Int.toString(id)) {
  | Some(t) => t.status = Failed
  | None => ()
  }
}

// Get transfer progress (0.0 to 1.0)
let getProgress = (id: int): float => {
  switch Dict.get(activeTransfers, Int.toString(id)) {
  | Some(t) =>
    if t.totalBytes > 0.0 {
      t.transferredBytes /. t.totalBytes
    } else {
      1.0
    }
  | None => 0.0
  }
}

// Update all active transfers (called every frame)
let updateTransfers = (deltaSeconds: float): unit => {
  // Reset router traffic counters
  Dict.toArray(routerUpload)->Array.forEach(((key, _)) => Dict.set(routerUpload, key, 0.0))
  Dict.toArray(routerDownload)->Array.forEach(((key, _)) => Dict.set(routerDownload, key, 0.0))

  // Process each active transfer
  let keysToRemove = []
  Dict.toArray(activeTransfers)->Array.forEach(((key, t)) => {
    switch t.status {
    | Active => {
        let bytesThisFrame = t.bandwidthMBps *. 1_000_000.0 *. deltaSeconds
        t.transferredBytes = Math.min(t.transferredBytes +. bytesThisFrame, t.totalBytes)

        // Accumulate router traffic (source = upload, dest = download)
        let currentUp = Dict.get(routerUpload, t.sourceIp)->Option.getOr(0.0)
        Dict.set(routerUpload, t.sourceIp, currentUp +. t.bandwidthMBps)
        let currentDown = Dict.get(routerDownload, t.destIp)->Option.getOr(0.0)
        Dict.set(routerDownload, t.destIp, currentDown +. t.bandwidthMBps)

        // Notify progress — SafeFloat.divOr guards against zero-byte transfers
        switch t.onProgress {
        | Some(cb) => cb(SafeFloat.divOr(t.transferredBytes, t.totalBytes, ~default=1.0))
        | None => ()
        }

        // Check completion
        if t.transferredBytes >= t.totalBytes {
          t.status = Complete
          switch t.onComplete {
          | Some(cb) => cb()
          | None => ()
          }
        }
      }
    | Complete | Failed => {
        let _ = Array.push(keysToRemove, key)
      }
    | Pending => ()
    }
  })

  // Clean up finished transfers
  keysToRemove->Array.forEach(key => {
    Dict.delete(activeTransfers, key)
  })
}

// Get aggregate traffic through a router IP (uploadMBps, downloadMBps)
let getRouterTraffic = (routerIp: string): (float, float) => {
  let up = Dict.get(routerUpload, routerIp)->Option.getOr(0.0)
  let down = Dict.get(routerDownload, routerIp)->Option.getOr(0.0)
  (up, down)
}

// Get count of active transfers
let activeCount = (): int => {
  let count = ref(0)
  Dict.valuesToArray(activeTransfers)->Array.forEach(t => {
    if t.status == Active {
      count := count.contents + 1
    }
  })
  count.contents
}
