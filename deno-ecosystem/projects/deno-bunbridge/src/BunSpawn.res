// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
// BunSpawn - Bun.spawn() compatible interface

type spawnOptions = {
  cwd?: string,
  env?: Dict.t<string>,
  stdin?: string,
  stdout?: string,
  stderr?: string,
}

type spawnSyncResult = {
  exitCode: int,
  stdout: Js.TypedArray2.Uint8Array.t,
  stderr: Js.TypedArray2.Uint8Array.t,
}

let spawnSync = (cmd: array<string>, ~options: spawnOptions={}): spawnSyncResult => {
  let program = Array.getUnsafe(cmd, 0)
  let args = Array.sliceToEnd(cmd, ~start=1)

  let denoOptions: Deno.Command.options = {
    args: args,
    cwd: ?options.cwd,
    env: ?options.env,
    stdin: "null",
    stdout: "piped",
    stderr: "piped",
  }

  let command = Deno.Command.make(program, denoOptions)
  let output = Deno.Command.outputSync(command)

  {
    exitCode: output.code,
    stdout: output.stdout,
    stderr: output.stderr,
  }
}
