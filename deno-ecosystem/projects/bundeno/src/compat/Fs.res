// SPDX-License-Identifier: PMPL-1.0
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
// File system compatibility layer

let readTextFile = async (path: string): string => {
  if Bundeno.isDeno() {
    %raw(`await Deno.readTextFile(path)`)
  } else if Bundeno.isBun() {
    %raw(`await Bun.file(path).text()`)
  } else {
    Exn.raiseError("Unsupported runtime for readTextFile")
  }
}

let writeTextFile = async (path: string, content: string): unit => {
  if Bundeno.isDeno() {
    %raw(`await Deno.writeTextFile(path, content)`)
  } else if Bundeno.isBun() {
    %raw(`await Bun.write(path, content)`)
  } else {
    Exn.raiseError("Unsupported runtime for writeTextFile")
  }
}

let readFile = async (path: string): Js.TypedArray2.Uint8Array.t => {
  if Bundeno.isDeno() {
    %raw(`await Deno.readFile(path)`)
  } else if Bundeno.isBun() {
    %raw(`new Uint8Array(await Bun.file(path).arrayBuffer())`)
  } else {
    Exn.raiseError("Unsupported runtime for readFile")
  }
}

let writeFile = async (path: string, data: Js.TypedArray2.Uint8Array.t): unit => {
  if Bundeno.isDeno() {
    %raw(`await Deno.writeFile(path, data)`)
  } else if Bundeno.isBun() {
    %raw(`await Bun.write(path, data)`)
  } else {
    Exn.raiseError("Unsupported runtime for writeFile")
  }
}

let exists = async (path: string): bool => {
  if Bundeno.isDeno() {
    try {
      %raw(`await Deno.stat(path)`)
      true
    } catch {
    | _ => false
    }
  } else if Bundeno.isBun() {
    %raw(`await Bun.file(path).exists()`)
  } else {
    Exn.raiseError("Unsupported runtime for exists")
  }
}

let mkdir = async (path: string, ~recursive: bool=false): unit => {
  if Bundeno.isDeno() {
    %raw(`await Deno.mkdir(path, { recursive })`)
  } else if Bundeno.isBun() {
    %raw(`const { mkdir } = await import('node:fs/promises'); await mkdir(path, { recursive })`)
  } else {
    Exn.raiseError("Unsupported runtime for mkdir")
  }
}

let remove = async (path: string, ~recursive: bool=false): unit => {
  if Bundeno.isDeno() {
    %raw(`await Deno.remove(path, { recursive })`)
  } else if Bundeno.isBun() {
    %raw(`const { rm } = await import('node:fs/promises'); await rm(path, { recursive })`)
  } else {
    Exn.raiseError("Unsupported runtime for remove")
  }
}
