// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
// Deno FFI bindings for deno-bunbridge

type arrayBuffer

@val external denoVersion: string = "Deno.version.deno"

module File = {
  @val external readTextFile: string => promise<string> = "Deno.readTextFile"
  @val external readFile: string => promise<Js.TypedArray2.Uint8Array.t> = "Deno.readFile"
  @val external writeTextFile: (string, string) => promise<unit> = "Deno.writeTextFile"
  @val external writeFile: (string, Js.TypedArray2.Uint8Array.t) => promise<unit> = "Deno.writeFile"
}

module Stat = {
  type t = {
    size: int,
    isFile: bool,
    isDirectory: bool,
  }

  @val external stat: string => promise<t> = "Deno.stat"
}

module Command = {
  type options = {
    args?: array<string>,
    cwd?: string,
    env?: Dict.t<string>,
    stdin?: string,
    stdout?: string,
    stderr?: string,
  }

  type output = {
    code: int,
    stdout: Js.TypedArray2.Uint8Array.t,
    stderr: Js.TypedArray2.Uint8Array.t,
  }

  @new external make: (string, options) => 'command = "Deno.Command"
  @send external outputSync: 'command => output = "outputSync"
  @send external spawn: 'command => 'process = "spawn"
}

module Serve = {
  type options = {
    port?: int,
    hostname?: string,
  }

  type server = {shutdown: unit => unit}

  @val external serve: (options, Request.t => promise<Response.t>) => server = "Deno.serve"
}
