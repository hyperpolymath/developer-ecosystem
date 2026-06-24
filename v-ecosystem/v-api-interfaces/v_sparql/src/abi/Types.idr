-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-sparql protocol.
-- SPARQL types: query forms, result formats.

module Types

||| SPARQL query form.
public export
data SparqlQueryType : Type where
  SelectQuery : SparqlQueryType
  Construct   : SparqlQueryType
  Ask         : SparqlQueryType
  Describe    : SparqlQueryType

||| Result serialisation format.
public export
data ResultFormat : Type where
  JSON : ResultFormat
  XML  : ResultFormat
  CSV  : ResultFormat
  TSV  : ResultFormat

||| SPARQL endpoint.
public export
record SparqlEndpoint where
  constructor MkSparqlEndpoint
  name      : String
  url       : String
  authToken : String
  timeoutMs : Nat
