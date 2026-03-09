// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// VitePluginRescript.res — Vite plugin for first-class ReScript support.
//
// Usage in vite.config.js:
//   import rescriptPlugin from "rescript-vite"
//   export default { plugins: [rescriptPlugin()] }
//
// Usage with BoJ:
//   import rescriptPlugin from "rescript-vite"
//   export default { plugins: [rescriptPlugin({ boj: true })] }
//
// Features:
//   - Automatic ReScript compiler spawning (build + watch)
//   - HMR for .res files via .res.js output tracking
//   - Error overlay integration (diagnostics → Vite overlay)
//   - Optional BoJ ssg-mcp build orchestration
//   - Deno-compatible (uses Deno runner when detected)

/// Plugin options
type options = {
  /// Enable BoJ ssg-mcp integration (default: false, auto-probes)
  boj: option<bool>,
  /// BoJ endpoint (default: http://localhost:7077/mcp/ssg)
  bojEndpoint: option<string>,
  /// Use Deno to run rescript (default: auto-detect)
  useDeno: option<bool>,
  /// Path to rescript binary
  rescriptBin: option<string>,
  /// Extra compiler flags
  compilerFlags: option<array<string>>,
  /// Log level: "silent" | "info" | "verbose"
  logLevel: option<string>,
}

/// Internal plugin state
type pluginState = {
  mutable config: option<ViteTypes.resolvedConfig>,
  mutable watchHandle: option<RescriptCompiler.watchHandle>,
  mutable bojBridge: option<BojBridge.t>,
  mutable pendingHmrFiles: array<string>,
  mutable lastBuildSuccess: bool,
  mutable diagnostics: array<RescriptCompiler.diagnostic>,
}

// --- Filesystem helpers ---

@module("node:path") external resolve: (string, string) => string = "resolve"
@module("node:path") external relative: (string, string) => string = "relative"
@module("node:fs") external existsSync: string => bool = "existsSync"

// --- Logging ---

let log = (level: string, prefix: string, msg: string): unit => {
  if level !== "silent" {
    Console.log(`[rescript-vite] ${prefix} ${msg}`)
  }
}

let logInfo = (level: string, msg: string) => log(level, "\x1b[36mℹ\x1b[0m", msg)
let logOk = (level: string, msg: string) => log(level, "\x1b[32m✓\x1b[0m", msg)
let logWarn = (level: string, msg: string) => log(level, "\x1b[33m⚠\x1b[0m", msg)
let logErr = (level: string, msg: string) => log(level, "\x1b[31m✗\x1b[0m", msg)

// --- Deno detection ---

let isDeno = (): bool => {
  %raw(`typeof Deno !== "undefined"`)
}

/// Send diagnostics to the Vite error overlay
let sendOverlayError = (server: ViteTypes.viteDevServer, diagnostic: RescriptCompiler.diagnostic): unit => {
  let payload: JSON.t = Obj.magic({
    "type": "error",
    "err": {
      "message": diagnostic.message,
      "stack": "",
      "id": diagnostic.file,
      "frame": `${diagnostic.file}:${Int.toString(diagnostic.line)}:${Int.toString(diagnostic.column)}`,
      "plugin": "rescript-vite",
      "loc": {
        "file": diagnostic.file,
        "line": diagnostic.line,
        "column": diagnostic.column,
      },
    },
  })
  server.ws.send(payload)
}

/// Clear the error overlay
let clearOverlay = (server: ViteTypes.viteDevServer): unit => {
  let payload: JSON.t = Obj.magic({"type": "update", "updates": []})
  server.ws.send(payload)
}

/// Create the Vite plugin
let make = (~options: option<options>=None): ViteTypes.plugin => {
  let opts: options = options->Option.getOr({
    boj: None,
    bojEndpoint: None,
    useDeno: None,
    rescriptBin: None,
    compilerFlags: None,
    logLevel: None,
  })

  let logLevel = opts.logLevel->Option.getOr("info")
  let useDeno = opts.useDeno->Option.getOr(isDeno())

  let state: pluginState = {
    config: None,
    watchHandle: None,
    bojBridge: None,
    pendingHmrFiles: [],
    lastBuildSuccess: true,
    diagnostics: [],
  }

  {
    name: "rescript-vite",
    enforce: Some("pre"),

    configResolved: Some(resolvedConfig => {
      state.config = Some(resolvedConfig)
      logInfo(logLevel, `Project root: ${resolvedConfig.root}`)
      logInfo(logLevel, `Mode: ${resolvedConfig.command} (${resolvedConfig.mode})`)
    }),

    buildStart: Some(async () => {
      let root = switch state.config {
      | Some(c) => c.root
      | None => "."
      }

      // --- BoJ probe ---
      let wantBoj = opts.boj->Option.getOr(false)
      if wantBoj {
        let bridge = BojBridge.make(
          ~endpoint=opts.bojEndpoint->Option.getOr(BojBridge.defaultEndpoint),
        )
        let connected = await BojBridge.probe(bridge)
        if connected {
          state.bojBridge = Some(bridge)
          logOk(logLevel, "BoJ ssg-mcp connected — build orchestration delegated")
        } else {
          logWarn(logLevel, "BoJ not available — falling back to direct compiler")
        }
      }

      // --- Compiler ---
      let compilerConfig = {
        ...RescriptCompiler.defaultConfig(root),
        useDeno,
        rescriptBin: opts.rescriptBin,
        compilerFlags: opts.compilerFlags->Option.getOr([]),
        onDiagnostic: Some(d => {
          Array.push(state.diagnostics, d)->ignore
          let sevStr = switch d.severity {
          | Error => "error"
          | Warning => "warning"
          }
          if sevStr === "error" {
            logErr(logLevel, `${d.file}:${Int.toString(d.line)} — ${d.message}`)
            state.lastBuildSuccess = false
          } else if logLevel === "verbose" {
            logWarn(logLevel, `${d.file}:${Int.toString(d.line)} — ${d.message}`)
          }
        }),
        onFileChanged: Some(file => {
          Array.push(state.pendingHmrFiles, file)->ignore
        }),
      }

      let config = switch state.config {
      | Some(c) => c
      | None => {root: ".", command: "build", mode: "production"}
      }

      if config.command === "serve" {
        // Dev mode — start watch
        logInfo(logLevel, "Starting ReScript compiler in watch mode...")
        let handle = RescriptCompiler.watch(compilerConfig)
        state.watchHandle = Some(handle)
        logOk(logLevel, "ReScript watch mode active")
      } else {
        // Production build — one-shot
        logInfo(logLevel, "Running ReScript build...")

        switch state.bojBridge {
        | Some(bridge) => {
            // Delegate to BoJ
            let result = await BojBridge.requestBuild(bridge, {
              projectRoot: root,
              targets: ["client"],
              incremental: false,
              changedFiles: [],
              compilerFlags: opts.compilerFlags->Option.getOr([]),
            })
            switch result {
            | Some(r) => {
                state.lastBuildSuccess = r.success
                if r.success {
                  logOk(logLevel, `BoJ build complete (${Float.toString(r.durationMs)}ms, ${Int.toString(r.cacheHits)} cache hits)`)
                } else {
                  logErr(logLevel, `BoJ build failed (${Int.toString(r.diagnosticCount)} errors)`)
                }
              }
            | None => {
                logWarn(logLevel, "BoJ build request failed — falling back to direct compiler")
                let result = await RescriptCompiler.build(compilerConfig)
                state.lastBuildSuccess = result.success
                if result.success {
                  logOk(logLevel, `Build complete (${Float.toString(result.durationMs)}ms)`)
                } else {
                  logErr(logLevel, `Build failed (${Int.toString(Array.length(result.diagnostics))} errors)`)
                }
              }
            }
          }
        | None => {
            let result = await RescriptCompiler.build(compilerConfig)
            state.lastBuildSuccess = result.success
            if result.success {
              logOk(logLevel, `Build complete (${Float.toString(result.durationMs)}ms)`)
            } else {
              logErr(logLevel, `Build failed (${Int.toString(Array.length(result.diagnostics))} errors)`)
            }
          }
        }
      }
    }),

    handleHotUpdate: Some(ctx => {
      let file = ctx.file

      // Only handle .res file changes
      if file->String.endsWith(".res") || file->String.endsWith(".resi") {
        logInfo(logLevel, `File changed: ${file}`)

        // The compiler watch process handles recompilation.
        // We need to find the corresponding .res.js module in Vite's module graph.
        let jsFile = file ++ ".js"
        let modules = ctx.server.moduleGraph.getModulesByFile(jsFile)

        switch modules {
        | Some(mods) if Array.length(mods) > 0 => {
            // Clear any previous error overlay if build succeeded
            if state.lastBuildSuccess {
              clearOverlay(ctx.server)
            }

            // Send diagnostics to overlay if there are errors
            let errors = state.diagnostics->Array.filter(d => d.severity === Error)
            if Array.length(errors) > 0 {
              // Send first error to overlay
              switch Array.get(errors, 0) {
              | Some(err) => sendOverlayError(ctx.server, err)
              | None => ()
              }
            }

            // Clear accumulated diagnostics for next cycle
            state.diagnostics = []

            // Return affected modules for HMR
            Some(mods)
          }
        | _ => {
            // Module not in graph yet — trigger full reload
            logInfo(logLevel, `Full reload for ${file} (not in module graph)`)
            None
          }
        }
      } else {
        // Not a ReScript file — let other plugins handle it
        None
      }
    }),

    buildEnd: Some(() => {
      // Report final diagnostics summary
      let errorCount = state.diagnostics->Array.filter(d => d.severity === Error)->Array.length
      let warnCount = state.diagnostics->Array.filter(d => d.severity === Warning)->Array.length
      if errorCount > 0 {
        logErr(logLevel, `${Int.toString(errorCount)} errors, ${Int.toString(warnCount)} warnings`)
      } else if warnCount > 0 {
        logWarn(logLevel, `${Int.toString(warnCount)} warnings`)
      } else {
        logOk(logLevel, "No issues")
      }
    }),

    closeBundle: Some(() => {
      // Stop the watch-mode compiler
      switch state.watchHandle {
      | Some(handle) => {
          RescriptCompiler.stop(handle)
          logInfo(logLevel, "ReScript watch mode stopped")
        }
      | None => ()
      }

      // Disconnect BoJ
      switch state.bojBridge {
      | Some(bridge) => {
          BojBridge.disconnect(bridge)
          logInfo(logLevel, "BoJ disconnected")
        }
      | None => ()
      }
    }),
  }
}

/// Default export — create plugin with default options
let default = make(~options=None)
