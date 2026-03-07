# SPDX-License-Identifier: MIT OR AGPL-3.0-or-later
# SPDX-FileCopyrightText: 2025 Hyperpolymath

# Entry Schema for aggregate-library (aLib) Common Library
# Defines the contract for operation specifications
# https://nickel-lang.org/

let Category = [|
  'arithmetic,
  'comparison,
  'logical,
  'string,
  'collection,
  'conditional
|] in

let BaseType = [|
  'Number,
  'String,
  'Boolean
|] in

# Type representation supporting generics and functions
let Type = {
  base
    | doc "Base type or generic parameter name"
    | String,

  generic
    | doc "Generic type parameter (e.g., 'A', 'B', 'T')"
    | optional
    | String,

  collection_of
    | doc "For Collection[T], the element type"
    | optional
    | String,

  function
    | doc "For Function[A -> B], input and output types"
    | optional
    | { input | String, output | String },
} in

let Signature = {
  inputs
    | doc "List of input parameter types"
    | Array Type,

  output
    | doc "Return type of the operation"
    | Type,
} in

let Parameter = {
  name
    | doc "Parameter name"
    | String,

  description
    | doc "Description of the parameter"
    | String,
} in

let Property = {
  name
    | doc "Property name (e.g., Commutative, Associative)"
    | String,

  expression
    | doc "Formal expression of the property"
    | String,
} in

let TestCase = {
  input
    | doc "Input values for the test case"
    | Dyn,  # Flexible to support various input formats

  output
    | doc "Expected output value"
    | Dyn,

  description
    | doc "Description of what the test case verifies"
    | String,
} in

let Semantics = {
  purpose
    | doc "What the operation computes"
    | String,

  parameters
    | doc "Description of each input parameter"
    | Array Parameter,

  return_value
    | doc "Description of what is returned"
    | String,

  properties
    | doc "Mathematical properties (optional)"
    | optional
    | Array Property,

  edge_cases
    | doc "Behavior for special inputs (optional)"
    | optional
    | Array String,
} in

# Provenance tracking for data lineage and attribution
let Contributor = {
  name
    | doc "Contributor name or identifier"
    | String,

  role
    | doc "Role in creating/maintaining the entry (author, reviewer, editor)"
    | optional
    | String,

  contact
    | doc "Contact URI (email, GitHub profile, etc.)"
    | optional
    | String,
} in

let Provenance = {
  source_file
    | doc "Relative path to the source specification file"
    | String,

  repository
    | doc "Source repository URL"
    | String,

  license
    | doc "SPDX license identifier"
    | String,

  contributors
    | doc "List of contributors to this entry"
    | Array Contributor,

  created_at
    | doc "ISO 8601 date when the entry was created"
    | String,

  modified_at
    | doc "ISO 8601 date when the entry was last modified"
    | String,

  commit_hash
    | doc "Git commit hash of the source (optional)"
    | optional
    | String,

  upstream
    | doc "Upstream source if derived from another project (optional)"
    | optional
    | String,

  derivation
    | doc "How this entry was derived (manual, generated, extracted)"
    | default = "manual"
    | String,
} in

# Main Entry schema - the contract for each operation specification
let Entry = {
  name
    | doc "Unique operation name (e.g., 'add', 'map', 'filter')"
    | String,

  category
    | doc "Category this operation belongs to"
    | Category,

  signature
    | doc "Type signature of the operation"
    | Signature,

  signature_string
    | doc "Human-readable signature (e.g., 'add: Number, Number -> Number')"
    | String,

  semantics
    | doc "Behavioral semantics of the operation"
    | Semantics,

  test_cases
    | doc "Executable test cases demonstrating behavior"
    | Array TestCase,

  provenance
    | doc "Data lineage and attribution information"
    | Provenance,

  # Metadata
  version
    | doc "Schema version for forward compatibility"
    | default = "1.0.0"
    | String,
} in

# Export the schema
{
  Entry,
  Category,
  Type,
  Signature,
  Parameter,
  Property,
  TestCase,
  Semantics,
  Contributor,
  Provenance,

  # Schema metadata
  schema_version = "1.1.0",
  schema_name = "aLib Entry Schema",

  # Validation helper - validates an entry conforms to the schema
  validate_entry = fun entry => entry | Entry,

  # Category list for enumeration
  categories = [
    "arithmetic",
    "comparison",
    "logical",
    "string",
    "collection",
    "conditional",
  ],
}
