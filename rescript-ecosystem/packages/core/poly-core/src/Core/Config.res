// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

@@uncurried

/**
 * Configuration loading and validation utilities.
 */

/** Configuration source */
type source =
  | Env
  | File(string)
  | Object(Dict.t<JSON.t>)

/** Configuration error */
type configError =
  | MissingKey(string)
  | InvalidType(string, string)
  | ValidationFailed(string, string)

exception ConfigError(configError)

/** Convert error to string */
let errorToString = (error: configError): string => {
  switch error {
  | MissingKey(key) => `Missing required configuration key: ${key}`
  | InvalidType(key, expected) => `Invalid type for key '${key}': expected ${expected}`
  | ValidationFailed(key, reason) => `Validation failed for key '${key}': ${reason}`
  }
}

/** Configuration builder */
type t = {
  data: Dict.t<JSON.t>,
  prefix: string,
}

/** Create config from environment variables */
let fromEnv = (~prefix: string=""): t => {
  // Get all env vars (Deno)
  @val @scope(("Deno", "env")) external toObject: unit => Dict.t<string> = "toObject"

  let envVars = try {
    toObject()
  } catch {
  | _ => Dict.make()
  }

  let data = Dict.make()
  envVars->Dict.forEachWithKey((value, key) => {
    let shouldInclude = prefix == "" || key->String.startsWith(prefix)
    if shouldInclude {
      let normalizedKey = if prefix != "" {
        key->String.sliceToEnd(~start=String.length(prefix))
      } else {
        key
      }
      data->Dict.set(normalizedKey, JSON.Encode.string(value))
    }
  })

  {data, prefix}
}

/** Create config from JSON object */
let fromObject = (obj: Dict.t<JSON.t>): t => {
  {data: obj, prefix: ""}
}

/** Get a required string */
let getString = (config: t, key: string): string => {
  switch config.data->Dict.get(key) {
  | Some(JSON.String(s)) => s
  | Some(_) => raise(ConfigError(InvalidType(key, "string")))
  | None => raise(ConfigError(MissingKey(key)))
  }
}

/** Get an optional string */
let getStringOpt = (config: t, key: string): option<string> => {
  switch config.data->Dict.get(key) {
  | Some(JSON.String(s)) => Some(s)
  | _ => None
  }
}

/** Get a string with default */
let getStringOr = (config: t, key: string, default: string): string => {
  getStringOpt(config, key)->Option.getOr(default)
}

/** Get a required int */
let getInt = (config: t, key: string): int => {
  switch config.data->Dict.get(key) {
  | Some(JSON.Number(n)) => Float.toInt(n)
  | Some(JSON.String(s)) =>
    switch Int.fromString(s, ~radix=10) {
    | Some(i) => i
    | None => raise(ConfigError(InvalidType(key, "int")))
    }
  | Some(_) => raise(ConfigError(InvalidType(key, "int")))
  | None => raise(ConfigError(MissingKey(key)))
  }
}

/** Get an optional int */
let getIntOpt = (config: t, key: string): option<int> => {
  switch config.data->Dict.get(key) {
  | Some(JSON.Number(n)) => Some(Float.toInt(n))
  | Some(JSON.String(s)) => Int.fromString(s, ~radix=10)
  | _ => None
  }
}

/** Get an int with default */
let getIntOr = (config: t, key: string, default: int): int => {
  getIntOpt(config, key)->Option.getOr(default)
}

/** Get a required bool */
let getBool = (config: t, key: string): bool => {
  switch config.data->Dict.get(key) {
  | Some(JSON.Boolean(b)) => b
  | Some(JSON.String("true" | "1" | "yes")) => true
  | Some(JSON.String("false" | "0" | "no")) => false
  | Some(_) => raise(ConfigError(InvalidType(key, "bool")))
  | None => raise(ConfigError(MissingKey(key)))
  }
}

/** Get an optional bool */
let getBoolOpt = (config: t, key: string): option<bool> => {
  switch config.data->Dict.get(key) {
  | Some(JSON.Boolean(b)) => Some(b)
  | Some(JSON.String("true" | "1" | "yes")) => Some(true)
  | Some(JSON.String("false" | "0" | "no")) => Some(false)
  | _ => None
  }
}

/** Get a bool with default */
let getBoolOr = (config: t, key: string, default: bool): bool => {
  getBoolOpt(config, key)->Option.getOr(default)
}

/** Get a required float */
let getFloat = (config: t, key: string): float => {
  switch config.data->Dict.get(key) {
  | Some(JSON.Number(n)) => n
  | Some(JSON.String(s)) =>
    switch Float.fromString(s) {
    | Some(f) => f
    | None => raise(ConfigError(InvalidType(key, "float")))
    }
  | Some(_) => raise(ConfigError(InvalidType(key, "float")))
  | None => raise(ConfigError(MissingKey(key)))
  }
}

/** Get an optional float */
let getFloatOpt = (config: t, key: string): option<float> => {
  switch config.data->Dict.get(key) {
  | Some(JSON.Number(n)) => Some(n)
  | Some(JSON.String(s)) => Float.fromString(s)
  | _ => None
  }
}

/** Merge two configs (second takes precedence) */
let merge = (base: t, override: t): t => {
  let merged = Dict.make()
  base.data->Dict.forEachWithKey((v, k) => merged->Dict.set(k, v))
  override.data->Dict.forEachWithKey((v, k) => merged->Dict.set(k, v))
  {data: merged, prefix: base.prefix}
}

/** Check if a key exists */
let has = (config: t, key: string): bool => {
  config.data->Dict.get(key)->Option.isSome
}

/** Get all keys */
let keys = (config: t): array<string> => {
  config.data->Dict.keysToArray
}
