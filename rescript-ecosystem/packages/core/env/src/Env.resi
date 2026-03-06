// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Hyperpolymath

/**
 * Type-safe environment variable access for ReScript.
 */

exception MissingEnvVar(string)

/** Get an environment variable, returns None if not set */
let get: string => option<string>

/** Get an environment variable with a default value */
let getOr: (string, string) => string

/** Get an environment variable, throws MissingEnvVar if not set */
let getExn: string => string

/** Set an environment variable */
let set: (string, string) => unit

/** Delete an environment variable */
let delete: string => unit

/** Get all environment variables as a dictionary */
let all: unit => Dict.t<string>

/** Check if an environment variable is set */
let has: string => bool

/** Get an environment variable as an integer */
let getInt: string => option<int>

/** Get an environment variable as a float */
let getFloat: string => option<float>

/** Get an environment variable as a boolean (true/false/1/0/yes/no/on/off) */
let getBool: string => option<bool>

/** Check if running in development mode */
let isDevelopment: unit => bool

/** Check if running in production mode */
let isProduction: unit => bool

/** Check if running in test mode */
let isTest: unit => bool
