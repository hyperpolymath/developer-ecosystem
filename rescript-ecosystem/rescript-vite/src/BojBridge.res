// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// BojBridge.res — Optional integration with BoJ (Bundle of Joy) server.
//
// When a BoJ server is running, rescript-vite can delegate build orchestration
// to the ssg-mcp cartridge for:
//   - Coordinated multi-target builds (SSR + client)
//   - Build cache sharing across projects
//   - Observability telemetry (build times, error rates)
//   - Fleet-wide dependency resolution
//
// This is entirely optional. If BoJ is not running, the plugin falls back
// to direct compiler invocation via RescriptCompiler.

// --- Fetch FFI (works in both Node 18+ and Deno) ---

type response

@val external fetch: (string, ~init: {..}=?) => promise<response> = "fetch"

@get external responseOk: response => bool = "ok"
@get external responseStatus: response => int = "status"
@send external responseText: response => promise<string> = "text"
@send external responseJson: response => promise<JSON.t> = "json"

/// BoJ connection state
type connectionState =
  | Disconnected
  | Connecting
  | Connected(string)  // session ID
  | Failed(string)     // error reason

/// BoJ build request sent to ssg-mcp cartridge
type buildRequest = {
  projectRoot: string,
  targets: array<string>,    // e.g., ["client", "ssr"]
  incremental: bool,
  changedFiles: array<string>,
  compilerFlags: array<string>,
}

/// BoJ build response
type buildResponse = {
  success: bool,
  changedOutputs: array<string>,
  diagnosticCount: int,
  cacheHits: int,
  durationMs: float,
}

/// Build event for telemetry
type buildEvent = {
  project: string,
  timestamp: float,
  success: bool,
  fileCount: int,
  diagnosticCount: int,
  durationMs: float,
  cacheHitRate: float,
}

/// BoJ bridge state
type t = {
  mutable state: connectionState,
  mutable endpoint: string,
  mutable events: array<buildEvent>,
}

/// Default BoJ MCP endpoint (ssg-mcp cartridge)
let defaultEndpoint = "http://localhost:7077/mcp/ssg"

/// Create a BoJ bridge instance
let make = (~endpoint: string=defaultEndpoint): t => {
  state: Disconnected,
  endpoint,
  events: [],
}

/// Check if BoJ is available by pinging the endpoint
let probe = async (bridge: t): bool => {
  bridge.state = Connecting
  try {
    let resp = await fetch(bridge.endpoint ++ "/health")
    if responseOk(resp) {
      let body = await responseText(resp)
      bridge.state = Connected(body)
      true
    } else {
      bridge.state = Failed("BoJ not healthy: " ++ Int.toString(responseStatus(resp)))
      false
    }
  } catch {
  | _ => {
      bridge.state = Failed("BoJ unreachable at " ++ bridge.endpoint)
      false
    }
  }
}

/// Check if currently connected
let isConnected = (bridge: t): bool => {
  switch bridge.state {
  | Connected(_) => true
  | _ => false
  }
}

/// Request a build via BoJ ssg-mcp cartridge
let requestBuild = async (bridge: t, request: buildRequest): option<buildResponse> => {
  if !isConnected(bridge) {
    None
  } else {
    try {
      let bodyStr = JSON.stringifyAny({
        "jsonrpc": "2.0",
        "method": "tools/call",
        "params": {
          "name": "ssg_build",
          "arguments": {
            "project_root": request.projectRoot,
            "targets": request.targets,
            "incremental": request.incremental,
            "changed_files": request.changedFiles,
            "compiler_flags": request.compilerFlags,
          },
        },
      })->Option.getOr("")

      let resp = await fetch(bridge.endpoint, ~init={
        "method": "POST",
        "headers": {"content-type": "application/json"},
        "body": bodyStr,
      })

      if responseOk(resp) {
        let json = await responseJson(resp)
        let result: buildResponse = json->Obj.magic
        // Record telemetry event
        Array.push(bridge.events, {
          project: request.projectRoot,
          timestamp: Date.now(),
          success: result.success,
          fileCount: Array.length(request.changedFiles),
          diagnosticCount: result.diagnosticCount,
          durationMs: result.durationMs,
          cacheHitRate: if result.diagnosticCount + result.cacheHits > 0 {
            Int.toFloat(result.cacheHits) /. Int.toFloat(result.diagnosticCount + result.cacheHits)
          } else {
            0.0
          },
        })->ignore
        Some(result)
      } else {
        None
      }
    } catch {
    | _ => None
    }
  }
}

/// Get recent build events (for observability)
let recentEvents = (bridge: t, ~limit: int=20): array<buildEvent> => {
  let len = Array.length(bridge.events)
  if len <= limit {
    bridge.events
  } else {
    Array.slice(bridge.events, ~start=len - limit, ~end=len)
  }
}

/// Disconnect from BoJ
let disconnect = (bridge: t): unit => {
  bridge.state = Disconnected
}
