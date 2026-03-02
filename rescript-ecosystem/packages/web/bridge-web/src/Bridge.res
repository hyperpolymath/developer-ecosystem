// SPDX-License-Identifier: PMPL-1.0 OR PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2024 Hyperpolymath

/**
 * Bridge - A minimal input → output transformation module.
 * Demonstrates the core pattern: receive input, transform, emit output.
 */

/** Result type for bridge operations */
type bridgeResult<'a> = Ok('a) | Error(string)

/** Bridge configuration */
type config = {
  name: string,
  version: string,
}

/** Default configuration */
let defaultConfig: config = {
  name: "bridge",
  version: "0.1.0",
}

/** Transform input string to output with bridge metadata */
let transform = (input: string): string => {
  `[bridge] ${input}`
}

/** Transform with result wrapper for error handling */
let transformSafe = (input: string): bridgeResult<string> => {
  if input == "" {
    Error("Input cannot be empty")
  } else {
    Ok(transform(input))
  }
}

/** Compose two transformations */
let compose = (f: string => string, g: string => string): (string => string) => {
  (input: string) => g(f(input))
}

/** Identity transform - returns input unchanged */
let identity = (input: string): string => input

/** Uppercase transform - binds to JavaScript String.toUpperCase */
@send external toUpperCase: string => string = "toUpperCase"
let uppercase = (input: string): string => input->toUpperCase

/** Prefix transform factory */
let prefix = (pre: string): (string => string) => {
  (input: string) => `${pre}${input}`
}

/** Suffix transform factory */
let suffix = (suf: string): (string => string) => {
  (input: string) => `${input}${suf}`
}

/** Get bridge info */
let info = (config: config): string => {
  `${config.name} v${config.version}`
}
