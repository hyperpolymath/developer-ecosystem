// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// RescriptCompiler.res — Bridge to the ReScript compiler process.
//
// Spawns `rescript build` (or watch mode) as a child process,
// parses compiler output for errors/warnings, and reports changed files.

/// Compiler diagnostic severity
type severity = Error | Warning

/// A single compiler diagnostic from rescript build output
type diagnostic = {
  file: string,
  line: int,
  column: int,
  endLine: int,
  endColumn: int,
  severity: severity,
  message: string,
}

/// Result of a build invocation
type buildResult = {
  success: bool,
  diagnostics: array<diagnostic>,
  changedFiles: array<string>,
  durationMs: float,
}

/// Configuration for the compiler bridge
type config = {
  /// Working directory (project root)
  cwd: string,
  /// Path to rescript binary (auto-detected if not set)
  rescriptBin: option<string>,
  /// Whether to use Deno to run rescript (deno run -A npm:rescript)
  useDeno: bool,
  /// Extra compiler flags
  compilerFlags: array<string>,
  /// Callback for diagnostics as they stream in
  onDiagnostic: option<diagnostic => unit>,
  /// Callback for changed files (for HMR)
  onFileChanged: option<string => unit>,
}

let defaultConfig = (cwd: string): config => {
  cwd,
  rescriptBin: None,
  useDeno: false,
  compilerFlags: [],
  onDiagnostic: None,
  onFileChanged: None,
}

// --- FFI to child_process / Deno.Command ---

type childProcess
type readable

@module("node:child_process")
external spawn: (string, array<string>, {..}) => childProcess = "spawn"

@send external kill: childProcess => unit = "kill"
@get external stdout: childProcess => readable = "stdout"
@get external stderr: childProcess => readable = "stderr"

// We use %raw for event binding since @as phantoms are tricky with @send
let onProcessData: (readable, string => unit) => unit = %raw(`
  function(stream, cb) { stream.on("data", function(d) { cb(String(d)); }); }
`)

let onProcessClose: (childProcess, int => unit) => unit = %raw(`
  function(proc, cb) { proc.on("close", cb); }
`)

// Performance timing
@val external performanceNow: unit => float = "performance.now"

/// Strip ANSI escape codes from a string
let stripAnsi = (s: string): string => s->String.replaceRegExp(%re("/\x1b\[[0-9;]*m/g"), "")

/// Match a file:line:col pattern, returns (file, line, col, endCol) or None
let matchFileLoc: string => option<(string, int, int, int)> = %raw(`
  function(s) {
    var m = s.match(/^\s+(.+\.resi?):(\d+):(\d+)(?:-(\d+))?/);
    if (!m) return undefined;
    return [m[1], parseInt(m[2], 10), parseInt(m[3], 10), m[4] ? parseInt(m[4], 10) : parseInt(m[3], 10)];
  }
`)

/// Match a file being compiled/built
let matchCompiledFile: string => option<string> = %raw(`
  function(s) {
    var m = s.match(/(?:Building|Compiling)\s+(.+\.res)/i);
    return m ? m[1] : undefined;
  }
`)

/// Parse a single error/warning from rescript compiler output.
/// ReScript error format:
///   [1;31mWe've found a bug for you![0m
///   path/to/File.res:42:10-55
///   ...message...
let parseDiagnostics = (output: string): array<diagnostic> => {
  let lines = output->String.split("\n")
  let diagnostics: array<diagnostic> = []
  let i = ref(0)

  while i.contents < Array.length(lines) {
    let line = lines->Array.getUnsafe(i.contents)
    let clean = stripAnsi(line)

    switch matchFileLoc(clean) {
    | Some((file, lineNum, col, endCol)) => {
        // Look back for severity
        let sev = if i.contents > 0 {
          let prev = lines->Array.getUnsafe(i.contents - 1)
          if prev->String.includes("bug for you") || prev->String.includes("Error") {
            Error
          } else {
            Warning
          }
        } else {
          Error
        }

        // Gather message lines (skip blanks, stop at next diagnostic)
        let msgLines: array<string> = []
        let j = ref(i.contents + 1)
        let done = ref(false)
        while j.contents < Array.length(lines) && !done.contents {
          let msgLine = lines->Array.getUnsafe(j.contents)
          let msgClean = stripAnsi(msgLine)
          if matchFileLoc(msgClean)->Option.isSome {
            done := true
          } else if msgClean->String.includes("We've found a bug") || msgClean->String.includes("Warning number") {
            done := true
          } else {
            if String.trim(msgClean)->String.length > 0 {
              Array.push(msgLines, String.trim(msgClean))->ignore
            }
            j := j.contents + 1
          }
        }

        Array.push(diagnostics, {
          file,
          line: lineNum,
          column: col,
          endLine: lineNum,
          endColumn: endCol,
          severity: sev,
          message: Array.join(msgLines, "\n"),
        })->ignore
        i := j.contents
      }
    | None => i := i.contents + 1
    }
  }

  diagnostics
}

/// Detect changed .res.js files from compiler output
let parseChangedFiles = (output: string): array<string> => {
  let lines = output->String.split("\n")
  let changed: array<string> = []

  Array.forEach(lines, line => {
    let clean = stripAnsi(line)
    switch matchCompiledFile(clean) {
    | Some(file) => {
        let jsFile = file ++ ".js"
        Array.push(changed, jsFile)->ignore
      }
    | None => ()
    }
  })

  changed
}

/// Run a one-shot build and return the result
let build = (config: config): promise<buildResult> => {
  Promise.make((resolve, _reject) => {
    let startTime = performanceNow()
    let (cmd, args) = if config.useDeno {
      ("deno", ["run", "-A", "npm:rescript", "build"]->Array.concat(config.compilerFlags))
    } else {
      let bin = config.rescriptBin->Option.getOr("npx")
      let baseArgs = if bin === "npx" {
        ["rescript", "build"]
      } else {
        ["build"]
      }
      (bin, baseArgs->Array.concat(config.compilerFlags))
    }

    let outputBuf = ref("")
    let errorBuf = ref("")

    let proc = spawn(cmd, args, {"cwd": config.cwd, "shell": true})

    onProcessData(proc->stdout, chunk => {
      outputBuf := outputBuf.contents ++ chunk
    })

    onProcessData(proc->stderr, chunk => {
      errorBuf := errorBuf.contents ++ chunk
    })

    onProcessClose(proc, code => {
      let allOutput = outputBuf.contents ++ errorBuf.contents
      let diagnostics = parseDiagnostics(allOutput)
      let changedFiles = parseChangedFiles(allOutput)
      let duration = performanceNow() -. startTime

      // Fire individual diagnostic callbacks
      switch config.onDiagnostic {
      | Some(cb) => Array.forEach(diagnostics, cb)
      | None => ()
      }

      // Fire changed file callbacks
      switch config.onFileChanged {
      | Some(cb) => Array.forEach(changedFiles, cb)
      | None => ()
      }

      resolve({
        success: code === 0,
        diagnostics,
        changedFiles,
        durationMs: duration,
      })
    })
  })
}

/// A handle to a running watch-mode compiler process
type watchHandle = {
  process: childProcess,
  mutable stopped: bool,
}

/// Start the compiler in watch mode. Returns a handle to stop it.
let watch = (config: config): watchHandle => {
  let (cmd, args) = if config.useDeno {
    ("deno", ["run", "-A", "npm:rescript", "build", "-w"]->Array.concat(config.compilerFlags))
  } else {
    let bin = config.rescriptBin->Option.getOr("npx")
    let baseArgs = if bin === "npx" {
      ["rescript", "build", "-w"]
    } else {
      ["build", "-w"]
    }
    (bin, baseArgs->Array.concat(config.compilerFlags))
  }

  let proc = spawn(cmd, args, {"cwd": config.cwd, "shell": true})

  onProcessData(proc->stderr, chunk => {
    let diagnostics = parseDiagnostics(chunk)
    switch config.onDiagnostic {
    | Some(cb) => Array.forEach(diagnostics, cb)
    | None => ()
    }
  })

  onProcessData(proc->stdout, chunk => {
    let changed = parseChangedFiles(chunk)
    switch config.onFileChanged {
    | Some(cb) => Array.forEach(changed, cb)
    | None => ()
    }
  })

  {process: proc, stopped: false}
}

/// Stop a running watch-mode compiler
let stop = (handle: watchHandle): unit => {
  if !handle.stopped {
    handle.process->kill
    handle.stopped = true
  }
}
