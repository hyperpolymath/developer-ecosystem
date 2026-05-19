// SPDX-License-Identifier: PMPL-1.0-or-later
// Alib_Compat_Belt.res - Compatibility layer for Belt migration

// This module helps migrate from Belt to Alib by providing drop-in replacements
// with improved type safety via branded types

open Alib_String

// =============================================================================
// Belt.Result compatibility
// =============================================================================

module Result = {
  // Belt.Result API surface that works with Alib.Result
  let map = Alib_Result.map
  let flatMap = Alib_Result.flatMap
  let getWithDefault = Alib_Result.getWithDefault
  let isOk = Alib_Result.isOk
  let isError = Alib_Result.isError

  // Additional Alib features
  let guard = Alib_Result.guard
  let requireSome = Alib_Result.requireSome
  let both = Alib_Result.both
}

// =============================================================================
// Belt.Option compatibility
// =============================================================================

module Option = {
  // Belt.Option API surface that works with Alib.Option
  let map = Alib_Option.map
  let flatMap = Alib_Option.flatMap
  let getWithDefault = Alib_Option.getWithDefault
  let isSome = Alib_Option.isSome
  let isNone = Alib_Option.isNone

  // Additional Alib features
  let guard = Alib_Option.guard
  let toResult = Alib_Option.toResult
}

// =============================================================================
// Migration helpers
// =============================================================================

// Convert Belt.Result patterns to Alib.Result with branded types
module Migration = {
  // Example: Migrate string validation to branded Email
  let stringToEmail = (str: string): result<Email.t, Email.error> => {
    Email.parse(str)
  }

  // Example: Migrate string validation to branded Slug
  let stringToSlug = (str: string): result<Slug.t, Slug.error> => {
    Slug.parse(str)
  }
}
