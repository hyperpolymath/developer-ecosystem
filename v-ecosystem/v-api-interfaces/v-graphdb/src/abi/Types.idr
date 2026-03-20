-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-graphdb protocol.
-- Graph database query dialects, node/edge types, transaction states,
-- and result set structures.

module Types

import Data.List

||| Graph query dialect supported by the connector.
public export
data QueryDialect : Type where
  Cypher  : QueryDialect  -- Neo4j Cypher Query Language
  Gremlin : QueryDialect  -- Apache TinkerPop traversal language
  SPARQL  : QueryDialect  -- W3C SPARQL 1.1 query/update

||| Connection lifecycle state for graph database sessions.
public export
data ConnState : Type where
  Disconnected : ConnState
  Connecting   : ConnState
  Connected    : ConnState
  InTransaction : ConnState

||| Transaction lifecycle state.
public export
data TxState : Type where
  TxNone       : TxState  -- No transaction active
  TxActive     : TxState  -- Transaction in progress
  TxCommitted  : TxState  -- Successfully committed
  TxRolledBack : TxState  -- Rolled back (explicitly or on error)

||| A labelled vertex in the property graph.
public export
record Node where
  constructor MkNode
  nodeId     : String
  labels     : List String
  properties : List (String, String)

||| A directed, typed relationship between two nodes.
public export
record Edge where
  constructor MkEdge
  edgeId     : String
  relType    : String
  sourceId   : String
  targetId   : String
  properties : List (String, String)

||| A single column in a query result set.
public export
record Column where
  constructor MkColumn
  name  : String
  index : Nat

||| A row of string-valued cells in a query result set.
public export
record Row where
  constructor MkRow
  cells : List (String, String)

||| Complete result set returned by a graph query.
public export
record QueryResult where
  constructor MkQueryResult
  columns : List Column
  rows    : List Row
  count   : Nat
