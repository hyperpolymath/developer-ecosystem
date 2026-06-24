-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Idris2 ABI type definitions for the v-nesy protocol.
-- NeSy types: reasoning modes, knowledge representations.

module Types

import Data.List

||| Neurosymbolic reasoning mode.
public export
data ReasoningMode : Type where
  NeuralOnly   : ReasoningMode
  SymbolicOnly : ReasoningMode
  Hybrid       : ReasoningMode
  NeuralGuided : ReasoningMode

||| Knowledge representation type.
public export
data KnowledgeType : Type where
  Ontology       : KnowledgeType
  Rules          : KnowledgeType
  Embeddings     : KnowledgeType
  KnowledgeGraph : KnowledgeType

||| Knowledge source.
public export
record KnowledgeSource where
  constructor MkKnowledgeSource
  name       : String
  sourceType : KnowledgeType
  uri        : String

||| NeSy pipeline.
public export
record NesyPipeline where
  constructor MkNesyPipeline
  name       : String
  mode       : ReasoningMode
  knowledge  : List KnowledgeSource
  confidence : Double
