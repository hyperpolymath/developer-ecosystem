// SPDX-License-Identifier: PMPL-1.0-or-later
// Alib_Compat_Js.res - Compatibility layer for Js module

// This module provides type-safe wrappers for common Js module operations

open Alib_String

// =============================================================================
// Js.String compatibility with branded types
// =============================================================================

module String = {
  // Validate and return branded Email
  let parseEmail = (str: string): result<Email.t, Email.error> => {
    Email.parse(str)
  }

  // Validate and return branded Slug
  let parseSlug = (str: string): result<Slug.t, Slug.error> => {
    Slug.parse(str)
  }

  // Validate and return branded Url
  let parseUrl = (str: string): result<Url.t, Url.error> => {
    Url.parse(str)
  }

  // Non-empty string validation
  let parseNonEmpty = (str: string): result<NonEmptyString.t, NonEmptyString.error> => {
    NonEmptyString.parse(str)
  }
}

// =============================================================================
// Js.Json compatibility
// =============================================================================

module Json = {
  // Parse JSON string to branded type (safe wrapper)
  let decodeEmail = (json: Js.Json.t): result<Email.t, string> => {
    switch Js.Json.classify(json) {
    | JSONString(str) =>
        switch Email.parse(str) {
        | Ok(email) => Ok(email)
        | Error(InvalidFormat({name, input: _})) =>
            Error(`Invalid ${name} in JSON`)
        }
    | _ => Error("Expected string in JSON")
    }
  }

  // Similar for other branded types
  let decodeSlug = (json: Js.Json.t): result<Slug.t, string> => {
    switch Js.Json.classify(json) {
    | JSONString(str) =>
        switch Slug.parse(str) {
        | Ok(slug) => Ok(slug)
        | Error(InvalidFormat({name, input: _})) =>
            Error(`Invalid ${name} in JSON`)
        }
    | _ => Error("Expected string in JSON")
    }
  }
}
