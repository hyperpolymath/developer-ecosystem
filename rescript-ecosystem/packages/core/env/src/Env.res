// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@uncurried

/**
 * Type-safe environment variable access for ReScript.
 * Works with Deno, Bun, and Node.js runtimes.
 */

/** Get an environment variable, returns None if not set */
@val @scope(("Deno", "env"))
external denoGet: string => option<string> = "get"

/** Set an environment variable */
@val @scope(("Deno", "env"))
external denoSet: (string, string) => unit = "set"

/** Delete an environment variable */
@val @scope(("Deno", "env"))
external denoDelete: string => unit = "delete"

/** Get all environment variables as an object */
@val @scope(("Deno", "env"))
external denoToObject: unit => Dict.t<string> = "toObject"

/** Check if running in Deno */
@val @scope("globalThis")
external denoExists: option<{..}> = "Deno"

/** Node.js process.env */
@val @scope("process")
external nodeEnv: Dict.t<string> = "env"

/** Check if running in Node */
@val @scope("globalThis")
external processExists: option<{..}> = "process"

/**
 * Get an environment variable.
 * Returns None if the variable is not set.
 */
let get = (name: string): option<string> => {
  switch denoExists {
  | Some(_) => denoGet(name)
  | None =>
    switch processExists {
    | Some(_) => nodeEnv->Dict.get(name)
    | None => None
    }
  }
}

/**
 * Get an environment variable with a default value.
 * Returns the default if the variable is not set.
 */
let getOr = (name: string, default: string): string => {
  get(name)->Option.getOr(default)
}

/**
 * Get an environment variable, throwing if not set.
 * Use this for required configuration.
 */
exception MissingEnvVar(string)

let getExn = (name: string): string => {
  switch get(name) {
  | Some(value) => value
  | None => raise(MissingEnvVar(name))
  }
}

/**
 * Set an environment variable.
 */
let set = (name: string, value: string): unit => {
  switch denoExists {
  | Some(_) => denoSet(name, value)
  | None =>
    switch processExists {
    | Some(_) => nodeEnv->Dict.set(name, value)
    | None => ()
    }
  }
}

/**
 * Delete an environment variable.
 */
let delete = (name: string): unit => {
  switch denoExists {
  | Some(_) => denoDelete(name)
  | None =>
    switch processExists {
    | Some(_) => nodeEnv->Dict.delete(name)
    | None => ()
    }
  }
}

/**
 * Get all environment variables as a dictionary.
 */
let all = (): Dict.t<string> => {
  switch denoExists {
  | Some(_) => denoToObject()
  | None =>
    switch processExists {
    | Some(_) => nodeEnv
    | None => Dict.make()
    }
  }
}

/**
 * Check if an environment variable is set.
 */
let has = (name: string): bool => {
  get(name)->Option.isSome
}

/**
 * Get an environment variable as an integer.
 * Returns None if not set or not a valid integer.
 */
let getInt = (name: string): option<int> => {
  get(name)->Option.flatMap(Int.fromString(_, ~radix=10))
}

/**
 * Get an environment variable as a float.
 * Returns None if not set or not a valid float.
 */
let getFloat = (name: string): option<float> => {
  get(name)->Option.flatMap(Float.fromString)
}

/**
 * Get an environment variable as a boolean.
 * Recognises: "true", "1", "yes", "on" as true
 * Recognises: "false", "0", "no", "off" as false
 * Returns None if not set or not a recognised boolean value.
 */
let getBool = (name: string): option<bool> => {
  get(name)->Option.flatMap(value => {
    let lower = value->String.toLowerCase
    switch lower {
    | "true" | "1" | "yes" | "on" => Some(true)
    | "false" | "0" | "no" | "off" => Some(false)
    | _ => None
    }
  })
}

/**
 * Check if running in development mode.
 * Checks NODE_ENV, DENO_ENV, or ENV for "development" or "dev".
 */
let isDevelopment = (): bool => {
  let env = getOr("NODE_ENV", getOr("DENO_ENV", getOr("ENV", "production")))
  env == "development" || env == "dev"
}

/**
 * Check if running in production mode.
 * Checks NODE_ENV, DENO_ENV, or ENV for "production" or "prod".
 */
let isProduction = (): bool => {
  let env = getOr("NODE_ENV", getOr("DENO_ENV", getOr("ENV", "production")))
  env == "production" || env == "prod"
}

/**
 * Check if running in test mode.
 * Checks NODE_ENV, DENO_ENV, or ENV for "test".
 */
let isTest = (): bool => {
  let env = getOr("NODE_ENV", getOr("DENO_ENV", getOr("ENV", "")))
  env == "test"
}
