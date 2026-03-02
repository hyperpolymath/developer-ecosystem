// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2026 Hyperpolymath
//
// Tauri_Os.resi - Interface for Tauri OS plugin bindings

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
let platform: unit => promise<platform>

/** Get the operating system architecture */
let arch: unit => promise<arch>

/** Get the operating system type/family */
let osType: unit => promise<osType>

/** Get the operating system version */
let version: unit => promise<string>

/** Get the locale (e.g., "en-US") */
let locale: unit => promise<Nullable.t<string>>

/** Get the hostname */
let hostname: unit => promise<Nullable.t<string>>

/** Get executable extension for the platform */
let exeExtension: unit => promise<string>

/** Get family (unix or windows) */
let family: unit => promise<string>

/** End-of-line character(s) for the OS */
let eol: unit => promise<string>

// ============================================================================
// Helper Functions
// ============================================================================

/** Check if running on desktop (Linux, macOS, Windows) */
let isDesktop: unit => promise<bool>

/** Check if running on mobile (iOS, Android) */
let isMobile: unit => promise<bool>

/** Check if running on macOS */
let isMacos: unit => promise<bool>

/** Check if running on Windows */
let isWindows: unit => promise<bool>

/** Check if running on Linux */
let isLinux: unit => promise<bool>

/** Check if running on iOS */
let isIos: unit => promise<bool>

/** Check if running on Android */
let isAndroid: unit => promise<bool>

/** Check if the OS is Unix-like */
let isUnix: unit => promise<bool>

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
let getOsInfo: unit => promise<osInfo>
