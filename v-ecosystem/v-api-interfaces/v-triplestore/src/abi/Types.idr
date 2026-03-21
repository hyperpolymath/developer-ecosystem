-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-triplestore protocol.
-- RDF 1.1 term types, SPARQL query forms, and result structures
-- for SPARQL 1.1 Protocol (W3C Recommendation) endpoints.

module Types

import Data.List

||| RDF term kind as defined in the RDF 1.1 Concepts specification.
public export
data TermKind : Type where
  IRI       : TermKind   -- Named resource identified by an IRI
  BlankNode : TermKind   -- Anonymous resource with local scope
  Literal   : TermKind   -- Literal value with optional language/datatype

||| SPARQL query form (section 2 of SPARQL 1.1 Query Language).
public export
data QueryForm : Type where
  Select   : QueryForm   -- Tabular variable bindings
  Construct : QueryForm  -- RDF graph construction
  Ask      : QueryForm   -- Boolean existence test
  Describe : QueryForm   -- Resource description

||| SPARQL Update operation type.
public export
data UpdateOp : Type where
  InsertData : UpdateOp   -- Add explicit triples
  DeleteData : UpdateOp   -- Remove explicit triples
  LoadGraph  : UpdateOp   -- Load RDF from URL
  ClearGraph : UpdateOp   -- Remove all triples from a graph

||| An RDF term (subject, predicate, or object position).
public export
record Term where
  constructor MkTerm
  kind     : TermKind
  value    : String       -- IRI, blank node label, or lexical form
  lang     : String       -- Language tag (empty if not applicable)
  datatype : String       -- Datatype IRI (empty if not applicable)

||| An RDF triple (subject-predicate-object statement).
public export
record Triple where
  constructor MkTriple
  subject   : Term
  predicate : Term
  object    : Term

||| A single row of variable bindings from a SELECT result.
public export
record BindingRow where
  constructor MkBindingRow
  values : List (String, Term)

||| Result of a SPARQL SELECT query.
public export
record SelectResult where
  constructor MkSelectResult
  variables : List String
  rows      : List BindingRow
