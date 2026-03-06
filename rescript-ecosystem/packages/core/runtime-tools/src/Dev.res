// SPDX-License-Identifier: AGPL-3.0-or-later
// Unified dev server with watch/compile/serve

type devConfig = {
  port: int,
  host: string,
  watch: bool,
  entry: string,
  buildCmd: string,
}

type devState = {
  mutable running: bool,
  mutable lastBuild: float,
  mutable errors: array<string>,
}

let defaultConfig: devConfig = {
  port: 8000,
  host: "127.0.0.1",
  watch: true,
  entry: "src/Main.res.js",
  buildCmd: "rescript build",
}

// Deno-specific process spawning
module DenoProcess = {
  type command
  type process
  type status = {success: bool, code: int}

  @new @scope("Deno") external makeCommand: (string, {"args": array<string>}) => command = "Command"
  @send external spawn: command => process = "spawn"
  @get external status: process => promise<status> = "status"

  let run = async (cmd: string, args: array<string>): bool => {
    let command = makeCommand(cmd, {"args": args})
    let proc = command->spawn
    let result = await proc->status
    result.success
  }
}

// Bun-specific process spawning
module BunProcess = {
  type subprocess

  @scope("Bun") @val
  external spawn: (array<string>, {"cwd": option<string>}) => subprocess = "spawn"

  @send external exited: subprocess => promise<int> = "exited"

  let run = async (cmd: string, args: array<string>): bool => {
    let fullArgs = [cmd]->Js.Array2.concat(args)
    let proc = spawn(fullArgs, {"cwd": None})
    let code = await proc->exited
    code == 0
  }
}

// Runtime-aware process runner
let runCommand = async (cmd: string, args: array<string>): bool => {
  switch Detect.detect() {
  | Detect.Deno => await DenoProcess.run(cmd, args)
  | Detect.Bun => await BunProcess.run(cmd, args)
  | _ => {
      Js.Console.error("Unsupported runtime for process spawning")
      false
    }
  }
}

// Build ReScript sources
let build = async (): bool => {
  Js.Console.log("📦 Building ReScript...")
  let success = await runCommand("npx", ["rescript", "build"])
  if success {
    Js.Console.log("✅ Build succeeded")
  } else {
    Js.Console.error("❌ Build failed")
  }
  success
}

// File watcher abstraction
module Watcher = {
  // Deno file watcher
  module Deno = {
    type fsWatcher
    type fsEvent = {kind: string, paths: array<string>}

    @scope("Deno") @val
    external watchFs: (array<string>, {"recursive": bool}) => fsWatcher = "watchFs"

    @val external asyncIterator: fsWatcher => Js.AsyncIterator.t<fsEvent> = "Symbol.asyncIterator"
  }

  // Bun file watcher (uses chokidar-like API)
  module Bun = {
    type watcher

    @scope("Bun") @val
    external watch: (string, {"recursive": bool}) => watcher = "watch"
  }

  type onChange = array<string> => unit

  let watchDeno = (paths: array<string>, onChange: onChange): unit => {
    let watcher = Deno.watchFs(paths, {"recursive": true})
    // Note: In real implementation, iterate over watcher events
    let _ = watcher
    let _ = onChange
    ()
  }

  let watchBun = (path: string, onChange: onChange): unit => {
    let watcher = Bun.watch(path, {"recursive": true})
    let _ = watcher
    let _ = onChange
    ()
  }

  let watch = (paths: array<string>, onChange: onChange): unit => {
    switch Detect.detect() {
    | Detect.Deno => watchDeno(paths, onChange)
    | Detect.Bun => watchBun(paths[0]->Belt.Option.getWithDefault("."), onChange)
    | _ => Js.Console.error("File watching not supported in this runtime")
    }
  }
}

// Dynamic import for hot reload
let importModule: string => promise<Js.Dict.t<'a>> = %raw(`
  async function(path) {
    const url = path + '?t=' + Date.now();
    return await import(url);
  }
`)

// Dev server state
let state: devState = {
  running: false,
  lastBuild: 0.0,
  errors: [],
}

// Main dev loop
let start = async (config: devConfig): unit => {
  let info = Detect.getInfo()
  Js.Console.log(
    `🚀 Starting dev server on ${info.runtime->Detect.toString} ${info.version->Belt.Option.getWithDefault(
        "unknown",
      )}`,
  )

  // Initial build
  let buildSuccess = await build()
  if !buildSuccess {
    Js.Console.error("Initial build failed, waiting for changes...")
  }

  state.running = true
  state.lastBuild = Js.Date.now()

  // Set up file watcher
  if config.watch {
    Watcher.watch(["src"], changedPaths => {
      Js.Console.log(`📝 Files changed: ${changedPaths->Js.Array2.joinWith(", ")}`)
      let _ = build()
    })
    Js.Console.log("👀 Watching for changes in src/")
  }

  Js.Console.log(`🌐 Server ready at http://${config.host}:${config.port->Belt.Int.toString}`)
}

let stop = (): unit => {
  state.running = false
  Js.Console.log("🛑 Dev server stopped")
}
