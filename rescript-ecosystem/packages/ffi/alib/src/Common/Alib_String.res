// SPDX-License-Identifier: PLMP-1.0-or-later
// Alib_String.res - Implementation of branded string types
// Philosophy: Parse, Don't Validate + Zero-Cost Abstractions

module type Brand = {
  let name: string
  let validate: string => bool
}

module type S = {
  type t = private string
  type error = InvalidFormat({name: string, input: string})
  let parse: string => result<t, error>
  external reveal: t => string = "%identity"
}

module Make = (B: Brand): (S with type t = private string) => {
  // CRITICAL: Type is just string at runtime
  // The `private` keyword ensures type safety at compile time
  // but has ZERO runtime representation
  type t = string

  // Error type for validation failures
  type error = InvalidFormat({name: string, input: string})

  // Parse: The ONLY place validation happens
  // @inline directive ensures this compiles to:
  //   1. Call B.validate (one regex test)
  //   2. Branch on result
  //   3. Return Ok or Error
  // NO function call overhead after inlining
  @inline
  let parse = (input: string): result<t, error> => {
    if B.validate(input) {
      // SAFE: We just validated, so cast is sound
      Ok(input)
    } else {
      Error(InvalidFormat({name: B.name, input: input}))
    }
  }

  // Reveal: Safe unwrap back to string
  // %identity is a ZERO-COST cast - literally nothing at runtime
  // Type system guarantees input was validated
  @inline
  external reveal: t => string = "%identity"
}

// Example instantiations (for documentation/testing)
// Users will define these in their own code

module Email = Make({
  let name = "Email"
  let validate = (s) => %re("/^[^\s@]+@[^\s@]+\.[^\s@]+$/")->Js.Re.test_(s)
})

module Slug = Make({
  let name = "Slug"
  let validate = (s) => %re("/^[a-z0-9]+(?:-[a-z0-9]+)*$/")->Js.Re.test_(s)
})

module Url = Make({
  let name = "Url"
  let validate = (s) => %re("/^https?:\/\/.+/")->Js.Re.test_(s)
})

module NonEmptyString = Make({
  let name = "NonEmptyString"
  let validate = (s) => s !== ""
})
