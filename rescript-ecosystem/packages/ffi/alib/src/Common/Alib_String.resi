// SPDX-License-Identifier: PLMP-1.0-or-later
// Alib_String.resi - Interface for branded string types
// Philosophy: Parse, Don't Validate + Zero-Cost Abstractions

// Brand: Defines a named validation rule
module type Brand = {
  let name: string
  let validate: string => bool
}

// S: The signature exposed by Make functor
module type S = {
  // Branded type - opaque to prevent accidental mixing
  type t = private string

  // Error type for validation failures
  type error = InvalidFormat({name: string, input: string})

  // Parse: The boundary where validation happens
  // @inline ensures zero overhead after this point
  let parse: string => result<t, error>

  // Reveal: Safe unwrap back to string
  // Uses %identity for zero-cost cast
  external reveal: t => string = "%identity"
}

// Make: Create a branded string type with custom validation
module Make: (B: Brand) => (S with type t = private string)
