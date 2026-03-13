// SPDX-License-Identifier: PMPL-1.0
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
// bundeno - Runtime compatibility layer for Deno and Bun

let version = "0.1.0"

type runtime =
  | Deno
  | Bun
  | Node
  | Browser
  | Unknown

let detectRuntime = (): runtime => {
  if %raw(`typeof globalThis.Deno !== "undefined"`) {
    Deno
  } else if %raw(`typeof globalThis.Bun !== "undefined"`) {
    Bun
  } else if %raw(`typeof process !== "undefined" && process.versions && process.versions.node`) {
    Node
  } else if %raw(`typeof window !== "undefined"`) {
    Browser
  } else {
    Unknown
  }
}

let currentRuntime = detectRuntime()

let isDeno = () => currentRuntime == Deno
let isBun = () => currentRuntime == Bun
let isNode = () => currentRuntime == Node
let isBrowser = () => currentRuntime == Browser

let runtimeName = (runtime: runtime): string => {
  switch runtime {
  | Deno => "deno"
  | Bun => "bun"
  | Node => "node"
  | Browser => "browser"
  | Unknown => "unknown"
  }
}
