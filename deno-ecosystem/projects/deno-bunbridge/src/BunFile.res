// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
// BunFile - Bun.file() compatible interface

type t = {path: string}

let make = (path: string): t => {path: path}

let text = async (file: t): string => {
  await Deno.File.readTextFile(file.path)
}

let json = async (file: t): 'a => {
  let content = await text(file)
  JSON.parseExn(content)
}

let arrayBuffer = async (file: t): Js.TypedArray2.ArrayBuffer.t => {
  let bytes = await Deno.File.readFile(file.path)
  Js.TypedArray2.Uint8Array.buffer(bytes)
}

let size = async (file: t): int => {
  let stat = await Deno.Stat.stat(file.path)
  stat.size
}

let exists = async (file: t): bool => {
  try {
    let _ = await Deno.Stat.stat(file.path)
    true
  } catch {
  | _ => false
  }
}

let name = (file: t): string => {
  let parts = String.split(file.path, "/")
  switch Array.at(parts, -1) {
  | Some(n) => n
  | None => file.path
  }
}

// Bun.file() equivalent
let file = make
