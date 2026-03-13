-- SPDX-License-Identifier: MPL-2.0
||| Aspect tagging system for proof categorization
|||
||| Aspects provide intelligent categorization and analysis of proofs,
||| allowing for semantic search and organization of mathematical knowledge.
module Echidna.Aspect

import Data.List

%default total

||| Mathematical domain categories
public export
data MathDomain
  = Algebra
  | Analysis
  | Topology
  | NumberTheory
  | SetTheory
  | CategoryTheory
  | Logic
  | Combinatorics
  | Geometry
  | ProbabilityTheory
  | ComputerScience
  | TypeTheory

public export
Show MathDomain where
  show Algebra = "algebra"
  show Analysis = "analysis"
  show Topology = "topology"
  show NumberTheory = "number-theory"
  show SetTheory = "set-theory"
  show CategoryTheory = "category-theory"
  show Logic = "logic"
  show Combinatorics = "combinatorics"
  show Geometry = "geometry"
  show ProbabilityTheory = "probability"
  show ComputerScience = "computer-science"
  show TypeTheory = "type-theory"

||| Proof technique categories
public export
data ProofTechnique
  = Induction
  | Coinduction
  | Contradiction
  | Construction
  | CaseAnalysis
  | Recursion
  | Automation
  | Rewriting
  | Reflection
  | Tactics

public export
Show ProofTechnique where
  show Induction = "induction"
  show Coinduction = "coinduction"
  show Contradiction = "contradiction"
  show Construction = "construction"
  show CaseAnalysis = "case-analysis"
  show Recursion = "recursion"
  show Automation = "automation"
  show Rewriting = "rewriting"
  show Reflection = "reflection"
  show Tactics = "tactics"

||| Complexity level
public export
data Complexity
  = Trivial      -- Can be solved by simplification
  | Elementary   -- Basic reasoning required
  | Intermediate -- Multiple steps, some insight needed
  | Advanced     -- Significant mathematical insight
  | Research     -- Open problem or novel result

public export
Show Complexity where
  show Trivial = "trivial"
  show Elementary = "elementary"
  show Intermediate = "intermediate"
  show Advanced = "advanced"
  show Research = "research"

||| An aspect tag for a proof
public export
data Aspect
  = Domain MathDomain
  | Technique ProofTechnique
  | ComplexityLevel Complexity
  | Keyword String
  | RelatedTo String  -- Reference to another theorem
  | RequiresAxiom String
  | Custom String String  -- key-value pair

public export
Show Aspect where
  show (Domain d) = "domain:" ++ show d
  show (Technique t) = "technique:" ++ show t
  show (ComplexityLevel c) = "complexity:" ++ show c
  show (Keyword k) = "keyword:" ++ k
  show (RelatedTo r) = "related:" ++ r
  show (RequiresAxiom a) = "axiom:" ++ a
  show (Custom k v) = k ++ ":" ++ v

||| Collection of aspects for a proof
public export
record AspectSet where
  constructor MkAspectSet
  domains : List MathDomain
  techniques : List ProofTechnique
  complexity : Maybe Complexity
  keywords : List String
  relations : List String
  axioms : List String
  custom : List (String, String)

||| Empty aspect set
public export
emptyAspects : AspectSet
emptyAspects = MkAspectSet [] [] Nothing [] [] [] []

||| Add a domain to an aspect set
public export
withDomain : MathDomain -> AspectSet -> AspectSet
withDomain d as = { domains $= (d ::) } as

||| Add a technique to an aspect set
public export
withTechnique : ProofTechnique -> AspectSet -> AspectSet
withTechnique t as = { techniques $= (t ::) } as

||| Set complexity level
public export
withComplexity : Complexity -> AspectSet -> AspectSet
withComplexity c as = { complexity := Just c } as

||| Add a keyword
public export
withKeyword : String -> AspectSet -> AspectSet
withKeyword k as = { keywords $= (k ::) } as

||| Convert aspect set to list of aspects
public export
toAspectList : AspectSet -> List Aspect
toAspectList as =
  map Domain as.domains ++
  map Technique as.techniques ++
  maybe [] (\c => [ComplexityLevel c]) as.complexity ++
  map Keyword as.keywords ++
  map RelatedTo as.relations ++
  map RequiresAxiom as.axioms ++
  map (uncurry Custom) as.custom

||| Infer aspects from theorem text (placeholder for neural inference)
public export
inferAspects : String -> IO AspectSet
