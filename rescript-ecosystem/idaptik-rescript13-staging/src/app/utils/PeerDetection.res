// SPDX-License-Identifier: PMPL-1.0-or-later
// 
// PeerDetection  Cross-instance detection for IDApTIK
// 
//
// Detects whether the other IDApTIK instance (Browser  Tauri) is
// running on a local port. Uses the /__idaptik_health endpoint
// served by the Vite dev server middleware (see vite.config.js).
//
// Port scheme:
//   Browser ports: 8080, 18080, 28080, 38080, 48080, 58080
//   Tauri ports:   8008, 18008, 28008, 38008, 48008, 58008
//
// Communication approach: simple HTTP fetch (REST). This is ideal
// for local desktop testing because:
//   - No extra server infrastructure needed
//   - Works with the existing Vite dev server
//   - Zero configuration  just start both instances
//   - For real co-op multiplayer, the Phoenix WebSocket backend
//     (already scaffolded) would be used instead
//
// Usage:
//   PeerDetection.checkForPeer()
//   ->Promise.then(result => { ... })
//
//   PeerDetection.startPolling(~onPeerFound, ~onPeerLost)
//   PeerDetection.stopPolling()
// 

//  Types 

// Result of a peer detection check
type peerStatus =
  | PeerFound({mode: string, port: int})
  | NoPeerFound

//  Raw JS helpers 

// Fetch a single health endpoint with a short timeout.
// Returns a promise resolving to {mode, port} or null.
let checkPortRaw: int => promise<option<(string, int)>> = %raw(`
  function(port) {
    var url = "http://127.0.0.1:" + port + "/__idaptik_health";
    var controller = new AbortController();
    var timer = setTimeout(function() { controller.abort(); }, 2000);
    return fetch(url, { signal: controller.signal, mode: "cors" })
      .then(function(res) {
        clearTimeout(timer);
        if (!res.ok) return null;
        return res.json();
      })
      .then(function(data) {
        if (data && data.idaptik) {
          return [data.mode || "unknown", data.port || port];
        }
        return null;
      })
      .catch(function() {
        clearTimeout(timer);
        return null;
      });
  }
`)

// Read the IDAPTIK_MODE env var injected by Vite's define config.
// Falls back to "browser" if not set (e.g. plain deno task dev).
let getMode: unit => string = %raw(`
  function() {
    try { return import.meta.env.IDAPTIK_MODE || "browser"; }
    catch(e) { return "browser"; }
  }
`)

// Read the IDAPTIK_PORT env var injected by Vite's define config.
// Uses Number.isNaN() explicitly to guard against NaN (parseInt returns NaN
// for non-numeric input; falsy coercion via || would also wrongly override
// a legitimately-set port of 0, so explicit NaN check is safer).
let getPort: unit => int = %raw(`
  function() {
    try {
      var p = parseInt(import.meta.env.IDAPTIK_PORT);
      return Number.isNaN(p) ? 8080 : p;
    }
    catch(e) { return 8080; }
  }
`)

//  Port candidates 

// Generate the list of candidate ports for a given base port.
// Base 8080  [8080, 18080, 28080, 38080, 48080, 58080]
// Base 8008  [8008, 18008, 28008, 38008, 48008, 58008]
let getCandidatePorts = (basePort: int): array<int> => {
  [
    basePort,
    10000 + basePort,
    20000 + basePort,
    30000 + basePort,
    40000 + basePort,
    50000 + basePort,
  ]
}

// Get the peer's candidate ports based on our mode.
// If we're browser (8080 family), peer is Tauri (8008 family) and vice versa.
let getPeerCandidatePorts = (): array<int> => {
  let ourMode = getMode()
  if ourMode == "browser" {
    getCandidatePorts(8008)
  } else {
    getCandidatePorts(8080)
  }
}

//  Main detection function 

// Check all peer candidate ports for a running IDApTIK instance.
// Returns the first found peer, or NoPeerFound.
// All ports are checked in parallel for speed (2s timeout each).
let checkForPeer = (): promise<peerStatus> => {
  let candidates = getPeerCandidatePorts()

  // Check all candidate ports in parallel
  let checks = Array.map(candidates, port => checkPortRaw(port))

  Promise.all(checks)->Promise.then(results => {
    // Find the first successful result
    let found = Array.find(results, result => Option.isSome(result))
    switch found {
    | Some(Some((mode, port))) => Promise.resolve(PeerFound({mode, port}))
    | _ => Promise.resolve(NoPeerFound)
    }
  })
}

//  Polling 

// Internal state for the polling interval
let pollingIntervalId: ref<option<intervalId>> = ref(None)
let lastPeerStatus: ref<peerStatus> = ref(NoPeerFound)

// Start polling for a peer instance every N milliseconds.
// Calls onPeerFound when a peer appears, onPeerLost when it disappears.
let startPolling = (
  ~intervalMs: int=5000,
  ~onPeerFound: (~mode: string, ~port: int) => unit,
  ~onPeerLost: unit => unit,
): unit => {
  // Stop any existing polling
  switch pollingIntervalId.contents {
  | Some(id) => clearInterval(id)
  | None => ()
  }

  let poll = () => {
    let _ = checkForPeer()->Promise.then(status => {
      switch (lastPeerStatus.contents, status) {
      | (NoPeerFound, PeerFound({mode, port})) => {
          // Peer just appeared  notify caller
          lastPeerStatus := status
          onPeerFound(~mode, ~port)
        }
      | (PeerFound(_), NoPeerFound) => {
          // Peer just disappeared  notify caller
          lastPeerStatus := status
          onPeerLost()
        }
      | _ => // No state change  don't spam callbacks
        ()
      }
      Promise.resolve()
    })
  }

  // Run the first check immediately, then start the interval
  poll()
  pollingIntervalId := Some(setInterval(poll, intervalMs))
}

// Stop polling for peer instances.
let stopPolling = (): unit => {
  switch pollingIntervalId.contents {
  | Some(id) => {
      clearInterval(id)
      pollingIntervalId := None
    }
  | None => ()
  }
}

//  Human-readable helpers 

// Get a human-readable label for the peer's mode.
// "browser"  "Web version", "tauri"  "Tauri version"
let peerLabel = (mode: string): string => {
  if mode == "tauri" {
    "Tauri version"
  } else {
    "Web version"
  }
}

// Format a peer detection result as a display string.
// e.g. "Tauri version detected on port 8008"
// e.g. "No other version found"
let formatStatus = (status: peerStatus): string => {
  switch status {
  | PeerFound({mode, port}) => `${peerLabel(mode)} detected on port ${Int.toString(port)}`
  | NoPeerFound => "No other version found"
  }
}
