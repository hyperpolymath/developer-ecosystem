// SPDX-License-Identifier: AGPL-3.0-or-later
// Runtime detection for Deno/Bun/Browser environments

type runtime =
  | Deno
  | Bun
  | Browser
  | Unknown

type runtimeInfo = {
  runtime: runtime,
  version: option<string>,
  permissions: bool, // true if runtime uses permission model
}

// Check if Deno global exists
let hasDeno: unit => bool = %raw(`
  function() { return typeof globalThis.Deno === 'object' && globalThis.Deno !== null }
`)

// Check if Bun global exists
let hasBun: unit => bool = %raw(`
  function() { return typeof globalThis.Bun === 'object' && globalThis.Bun !== null }
`)

// Check if window exists (browser)
let hasWindow: unit => bool = %raw(`
  function() { return typeof window === 'object' && window !== null }
`)

// Get Deno version
let getDenoVersion: unit => option<string> = %raw(`
  function() {
    try { return globalThis.Deno?.version?.deno || null }
    catch { return null }
  }
`)

// Get Bun version
let getBunVersion: unit => option<string> = %raw(`
  function() {
    try { return globalThis.Bun?.version || null }
    catch { return null }
  }
`)

let detect = (): runtime => {
  if hasDeno() {
    Deno
  } else if hasBun() {
    Bun
  } else if hasWindow() {
    Browser
  } else {
    Unknown
  }
}

let getInfo = (): runtimeInfo => {
  let runtime = detect()
  {
    runtime,
    version: switch runtime {
    | Deno => getDenoVersion()
    | Bun => getBunVersion()
    | Browser | Unknown => None
    },
    permissions: switch runtime {
    | Deno => true // Deno uses explicit permissions
    | Bun | Browser | Unknown => false
    },
  }
}

let toString = (rt: runtime): string => {
  switch rt {
  | Deno => "deno"
  | Bun => "bun"
  | Browser => "browser"
  | Unknown => "unknown"
  }
}

let fromString = (s: string): runtime => {
  switch s->Js.String2.toLowerCase {
  | "deno" => Deno
  | "bun" => Bun
  | "browser" => Browser
  | _ => Unknown
  }
}

// Runtime capability checks
module Capabilities = {
  let hasFileSystem = (): bool => {
    switch detect() {
    | Deno | Bun => true
    | Browser | Unknown => false
    }
  }

  let hasNetwork = (): bool => {
    switch detect() {
    | Deno | Bun | Browser => true
    | Unknown => false
    }
  }

  let hasNativeModules = (): bool => {
    switch detect() {
    | Bun => true // Bun has native module support
    | Deno | Browser | Unknown => false
    }
  }

  let hasWebAssembly = (): bool => {
    // All modern runtimes support WASM
    switch detect() {
    | Deno | Bun | Browser => true
    | Unknown => false
    }
  }
}
