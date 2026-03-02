// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Os.res - ReScript bindings for @tauri-apps/plugin-os

open RescriptCore

// ============================================================================
// OS Types
// ============================================================================

/** Platform type */
type platform =
  | @as("linux") Linux
  | @as("darwin") Darwin
  | @as("ios") Ios
  | @as("freebsd") Freebsd
  | @as("dragonfly") Dragonfly
  | @as("netbsd") Netbsd
  | @as("openbsd") Openbsd
  | @as("solaris") Solaris
  | @as("android") Android
  | @as("windows") Windows

/** Architecture type */
type arch =
  | @as("x86") X86
  | @as("x86_64") X86_64
  | @as("arm") Arm
  | @as("aarch64") Aarch64
  | @as("mips") Mips
  | @as("mips64") Mips64
  | @as("powerpc") Powerpc
  | @as("powerpc64") Powerpc64
  | @as("riscv64") Riscv64
  | @as("s390x") S390x
  | @as("sparc64") Sparc64

/** OS type (family) */
type osType =
  | @as("linux") LinuxType
  | @as("darwin") DarwinType
  | @as("windows") WindowsType
  | @as("ios") IosType
  | @as("android") AndroidType

// ============================================================================
// OS Information Functions
// ============================================================================

/** Get the operating system platform */
@module("@tauri-apps/plugin-os")
external platform: unit => promise<platform> = "platform"

/** Get the operating system architecture */
@module("@tauri-apps/plugin-os")
external arch: unit => promise<arch> = "arch"

/** Get the operating system type/family */
@module("@tauri-apps/plugin-os")
external osType: unit => promise<osType> = "type"

/** Get the operating system version */
@module("@tauri-apps/plugin-os")
external version: unit => promise<string> = "version"

/** Get the locale (e.g., "en-US") */
@module("@tauri-apps/plugin-os")
external locale: unit => promise<Nullable.t<string>> = "locale"

/** Get the hostname */
@module("@tauri-apps/plugin-os")
external hostname: unit => promise<Nullable.t<string>> = "hostname"

/** Get the OS release version */
@module("@tauri-apps/plugin-os")
external exeExtension: unit => promise<string> = "exeExtension"

/** Get family (unix or windows) */
@module("@tauri-apps/plugin-os")
external family: unit => promise<string> = "family"

/** End-of-line character(s) for the OS */
@module("@tauri-apps/plugin-os")
external eol: unit => promise<string> = "eol"

// ============================================================================
// Helper Functions
// ============================================================================

/** Check if running on desktop (Linux, macOS, Windows) */
let isDesktop = async () => {
  let p = await platform()
  switch p {
  | Linux | Darwin | Windows | Freebsd | Dragonfly | Netbsd | Openbsd | Solaris => true
  | Ios | Android => false
  }
}

/** Check if running on mobile (iOS, Android) */
let isMobile = async () => {
  let p = await platform()
  switch p {
  | Ios | Android => true
  | _ => false
  }
}

/** Check if running on macOS */
let isMacos = async () => {
  let p = await platform()
  p == Darwin
}

/** Check if running on Windows */
let isWindows = async () => {
  let p = await platform()
  p == Windows
}

/** Check if running on Linux */
let isLinux = async () => {
  let p = await platform()
  p == Linux
}

/** Check if running on iOS */
let isIos = async () => {
  let p = await platform()
  p == Ios
}

/** Check if running on Android */
let isAndroid = async () => {
  let p = await platform()
  p == Android
}

/** Check if the OS is Unix-like */
let isUnix = async () => {
  let f = await family()
  f == "unix"
}

// ============================================================================
// System Info Bundle
// ============================================================================

/** Complete OS information */
type osInfo = {
  platform: platform,
  arch: arch,
  osType: osType,
  version: string,
  family: string,
  hostname: Nullable.t<string>,
  locale: Nullable.t<string>,
}

/** Get all OS information at once */
let getOsInfo = async () => {
  let p = await platform()
  let a = await arch()
  let t = await osType()
  let v = await version()
  let f = await family()
  let h = await hostname()
  let l = await locale()

  {
    platform: p,
    arch: a,
    osType: t,
    version: v,
    family: f,
    hostname: h,
    locale: l,
  }
}
