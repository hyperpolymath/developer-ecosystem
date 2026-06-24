-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-semweb protocol.
-- Semantic Web types: RDF formats, OWL profiles, SHACL.

module Types

||| RDF serialisation format.
public export
data RdfFormat : Type where
  Turtle   : RdfFormat
  NTriples : RdfFormat
  JSONLD   : RdfFormat
  RDFXML   : RdfFormat
  TriG     : RdfFormat

||| OWL reasoning profile.
public export
data OwlProfile : Type where
  OWL_EL   : OwlProfile
  OWL_QL   : OwlProfile
  OWL_RL   : OwlProfile
  OWL_DL   : OwlProfile
  OWL_Full : OwlProfile

||| RDF graph.
public export
record RdfGraph where
  constructor MkRdfGraph
  name        : String
  format      : RdfFormat
  tripleCount : Nat
