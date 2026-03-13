// SPDX-License-Identifier: PMPL-1.0
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
// Process and environment compatibility layer

let cwd = (): string => {
  if Bundeno.isDeno() {
    %raw(`Deno.cwd()`)
  } else if Bundeno.isBun() {
    %raw(`process.cwd()`)
  } else {
    Exn.raiseError("Unsupported runtime for cwd")
  }
}

let chdir = (dir: string): unit => {
  if Bundeno.isDeno() {
    %raw(`Deno.chdir(dir)`)
  } else if Bundeno.isBun() {
    %raw(`process.chdir(dir)`)
  } else {
    Exn.raiseError("Unsupported runtime for chdir")
  }
}

let env = (): Dict.t<string> => {
  if Bundeno.isDeno() {
    %raw(`Object.fromEntries(Deno.env.toObject ? Object.entries(Deno.env.toObject()) : Object.entries(Deno.env))`)
  } else if Bundeno.isBun() {
    %raw(`process.env`)
  } else {
    Exn.raiseError("Unsupported runtime for env")
  }
}

let getEnv = (key: string): option<string> => {
  if Bundeno.isDeno() {
    %raw(`Deno.env.get(key) ?? null`)
  } else if Bundeno.isBun() {
    %raw(`process.env[key] ?? null`)
  } else {
    None
  }
}

let setEnv = (key: string, value: string): unit => {
  if Bundeno.isDeno() {
    %raw(`Deno.env.set(key, value)`)
  } else if Bundeno.isBun() {
    %raw(`process.env[key] = value`)
  } else {
    Exn.raiseError("Unsupported runtime for setEnv")
  }
}

let args = (): array<string> => {
  if Bundeno.isDeno() {
    %raw(`Deno.args`)
  } else if Bundeno.isBun() {
    %raw(`Bun.argv.slice(2)`)
  } else {
    []
  }
}

let exit = (code: int): unit => {
  if Bundeno.isDeno() {
    %raw(`Deno.exit(code)`)
  } else if Bundeno.isBun() {
    %raw(`process.exit(code)`)
  } else {
    Exn.raiseError("Unsupported runtime for exit")
  }
}

type spawnResult = {
  exitCode: int,
  stdout: Js.TypedArray2.Uint8Array.t,
  stderr: Js.TypedArray2.Uint8Array.t,
}

let spawnSync = (cmd: array<string>): spawnResult => {
  if Bundeno.isDeno() {
    let program = Array.getUnsafe(cmd, 0)
    let args = Array.sliceToEnd(cmd, ~start=1)
    %raw(`
      const command = new Deno.Command(program, { args, stdout: "piped", stderr: "piped" });
      const output = command.outputSync();
      ({ exitCode: output.code, stdout: output.stdout, stderr: output.stderr })
    `)
  } else if Bundeno.isBun() {
    %raw(`
      const proc = Bun.spawnSync(cmd, { stdout: "pipe", stderr: "pipe" });
      ({ exitCode: proc.exitCode, stdout: new Uint8Array(proc.stdout), stderr: new Uint8Array(proc.stderr) })
    `)
  } else {
    Exn.raiseError("Unsupported runtime for spawnSync")
  }
}
