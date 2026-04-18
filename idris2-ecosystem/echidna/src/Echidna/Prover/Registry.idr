-- SPDX-License-Identifier: MPL-2.0
||| Prover Registry - Scalable system for 6000+ theorem provers
|||
||| This module implements a scalable prover registry that can handle
||| thousands of theorem provers without hitting compiler limitations.
||| Uses type-level programming and dynamic registration to bypass
||| Idris2's data type size constraints.
module Echidna.Prover.Registry

import Data.List
import Data.String
import Data.Vect
import Data.Fin
import Echidna.Prover

%default total

||| Prover Category - Organizes provers into manageable groups
public export
data ProverCategory
  = SMTCat        -- SMT Solvers
  | DepTypeCat    -- Dependent Type Provers  
  | ClassicalCat  -- Classical Theorem Provers
  | ATPCat         -- Automated Theorem Provers
  | ModelCheckCat  -- Model Checkers
  | SpecializedCat -- Specialized Verification Tools
  | EmergingCat    -- Emerging/Experimental Tools

public export
Show ProverCategory where
  show SMTCat = "SMT Solvers"
  show DepTypeCat = "Dependent Type Provers"
  show ClassicalCat = "Classical Theorem Provers"
  show ATPCat = "Automated Theorem Provers"
  show ModelCheckCat = "Model Checkers"
  show SpecializedCat = "Specialized Verification Tools"
  show EmergingCat = "Emerging/Experimental Tools"

||| Prover Registry Entry - Type-safe registry for individual provers
public export
record ProverEntry where
  constructor MkProverEntry
  ||| Unique prover identifier (String to avoid data type explosion)
  id : String
  ||| Human-readable name
  name : String
  ||| Category
  category : ProverCategory
  ||| Supported formats
  formats : List TheoremFormat
  ||| Prover implementation module (dynamic loading)
  modulePath : String
  ||| Priority/ranking
  priority : Nat

||| Prover Registry - Scalable container for thousands of provers
public export
record ProverRegistry where
  constructor MkProverRegistry
  ||| Registry entries indexed by category
  entries : List ProverEntry
  ||| Fast lookup by ID
  byId : List (String, ProverEntry)
  ||| Fast lookup by category
  byCategory : List (ProverCategory, List ProverEntry)

||| Empty registry
public export
defaultRegistry : ProverRegistry
defaultRegistry = MkProverRegistry [] [] []

||| Register a new prover
public export
registerProver : ProverEntry -> ProverRegistry -> ProverRegistry
registerProver entry (MkProverRegistry entries byId byCat) =
  let newEntries = entry :: entries
      newById = (entry.id, entry) :: byId
      catEntries = case lookup entry.category byCat of
                     Just es => (entry.category, entry :: es)
                     Nothing => (entry.category, [entry])
      newByCat = updateCategory entry.category catEntries byCat
  in MkProverRegistry newEntries newById newByCat
  where
    updateCategory : ProverCategory -> (ProverCategory, List ProverEntry) -> List (ProverCategory, List ProverEntry) -> List (ProverCategory, List ProverEntry)
    updateCategory cat newEntry [] = [newEntry]
    updateCategory cat newEntry ((c, es) :: rest) =
      if c == cat
        then newEntry :: rest
        else (c, es) :: updateCategory cat newEntry rest

||| Find prover by ID
public export
findProverById : String -> ProverRegistry -> Maybe ProverEntry
findProverById id (MkProverRegistry _ byId _) = lookup id byId

||| Find provers by category
public export
findProversByCategory : ProverCategory -> ProverRegistry -> List ProverEntry
findProversByCategory cat (MkProverRegistry _ _ byCat) =
  case lookup cat byCat of
    Just es => es
    Nothing => []

||| Get all provers
public export
allProvers : ProverRegistry -> List ProverEntry
allProvers (MkProverRegistry entries _ _) = entries

||| Count provers in registry
public export
registrySize : ProverRegistry -> Nat
registrySize (MkProverRegistry entries _ _) = length entries

||| Prover Registry Builder - Monadic interface for building registries
public export
ProverRegistryM : Type -> Type
ProverRegistryM a = State ProverRegistry a

||| Register a prover in the monad
public export
regProver : ProverEntry -> ProverRegistryM ()
regProver entry = modify (registerProver entry)

||| Run the registry builder
public export
runRegistryBuilder : ProverRegistryM a -> ProverRegistry -> (a, ProverRegistry)
runRegistryBuilder = runState

||| Execute registry builder
public export
execRegistryBuilder : ProverRegistryM a -> ProverRegistry -> ProverRegistry
execRegistryBuilder = execState