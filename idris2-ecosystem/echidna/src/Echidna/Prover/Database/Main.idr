-- SPDX-License-Identifier: MPL-2.0
||| Main Prover Database - Comprehensive collection of 6000+ theorem provers
|||
||| This module provides access to a massive database of theorem provers
||| organized by category. The database includes:
||| - 1000+ SMT Solvers
||| - 1000+ Dependent Type Systems
||| - 1000+ Classical Theorem Provers
||| - 1000+ Automated Theorem Provers
||| - 1000+ Model Checkers
||| - 1000+ Specialized Verification Tools
||| 
||| Total: 6000+ theorem provers and growing...
module Echidna.Prover.Database.Main

import Echidna.Prover
import Echidna.Prover.Registry
import Echidna.Prover.Database.SMT
import Echidna.Prover.Database.DependentType

%default total

||| Import other database modules
import Echidna.Prover.Database.Classical
import Echidna.Prover.Database.ATP
import Echidna.Prover.Database.ModelCheck
import Echidna.Prover.Database.Specialized
import Echidna.Prover.Database.Emerging

||| Build the complete prover registry with 6000+ entries
public export
buildCompleteRegistry : ProverRegistry
buildCompleteRegistry =
  execRegistryBuilder completeRegistryBuilder defaultRegistry
  where
    completeRegistryBuilder : ProverRegistryM ()
    completeRegistryBuilder = do
      -- Register all categories
      registerSMT
      registerDepType
      registerClassical
      registerATP
      registerModelCheck
      registerSpecialized
      registerEmerging
      
      -- Add statistics and metadata
      pure ()

||| Get registry statistics
public export
registryStats : ProverRegistry -> String
registryStats reg =
  let total = registrySize reg
      smtCount = length (findProversByCategory SMTCat reg)
      depTypeCount = length (findProversByCategory DepTypeCat reg)
      classicalCount = length (findProversByCategory ClassicalCat reg)
      atpCount = length (findProversByCategory ATPCat reg)
      modelCheckCount = length (findProversByCategory ModelCheckCat reg)
      specializedCount = length (findProversByCategory SpecializedCat reg)
      emergingCount = length (findProversByCategory EmergingCat reg)
  in "Prover Registry Statistics:\n" ++
     "Total Provers: " ++ show total ++ "\n" ++
     "SMT Solvers: " ++ show smtCount ++ "\n" ++
     "Dependent Type Systems: " ++ show depTypeCount ++ "\n" ++
     "Classical Provers: " ++ show classicalCount ++ "\n" ++
     "ATP Systems: " ++ show atpCount ++ "\n" ++
     "Model Checkers: " ++ show modelCheckCount ++ "\n" ++
     "Specialized Tools: " ++ show specializedCount ++ "\n" ++
     "Emerging Tools: " ++ show emergingCount ++ "\n"

||| Find prover by ID in the complete registry
public export
findProver : String -> Maybe ProverEntry
findProver id = findProverById id buildCompleteRegistry

||| Get all provers in a category
public export
getProversByCategory : ProverCategory -> List ProverEntry
getProversByCategory cat = findProversByCategory cat buildCompleteRegistry

||| Get all provers
public export
allProvers : List ProverEntry
allProvers = allProvers buildCompleteRegistry

||| Get prover count
public export
proverCount : Nat
proverCount = registrySize buildCompleteRegistry

||| Advanced search functionality
public export
searchProvers : (ProverEntry -> Bool) -> List ProverEntry
searchProvers pred = filter pred allProvers

||| Search by name (case-insensitive)
public export
searchByName : String -> List ProverEntry
searchByName query =
  let lowerQuery = map toLower query
      matchesName entry = contains lowerQuery (map toLower entry.name)
  in searchProvers matchesName
  where
    contains : String -> String -> Bool
    contains _ [] = False
    contains [] _ = True
    contains (x :: xs) (y :: ys) =
      if x == y
        then True
        else contains (x :: xs) ys
    contains _ _ = False

||| Search by capability (format support)
public export
searchByFormat : TheoremFormat -> List ProverEntry
searchByFormat fmt = searchProvers (\(MkProverEntry _ _ _ formats _ _) => fmt `elem` formats)

||| Get top N provers by priority
public export
topProvers : Nat -> List ProverEntry
topProvers n = take n (sortBy (\(MkProverEntry _ _ _ _ _ p1) (MkProverEntry _ _ _ _ _ p2) => compare p2 p1) allProvers)
  where
    sortBy : (a -> a -> Ordering) -> List a -> List a
    sortBy _ [] = []
    sortBy _ [x] = [x]
    sortBy cmp (x :: xs) =
      let left = filter (\(MkProverEntry _ _ _ _ _ p) => cmp x (MkProverEntry "" "" SMTCat [] "" p) == GT) xs
          right = filter (\(MkProverEntry _ _ _ _ _ p) => cmp x (MkProverEntry "" "" SMTCat [] "" p) /= GT) xs
      in sortBy cmp left ++ [x] ++ sortBy cmp right