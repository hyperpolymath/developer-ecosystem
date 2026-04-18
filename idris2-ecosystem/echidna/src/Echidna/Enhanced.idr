-- SPDX-License-Identifier: MPL-2.0
||| Enhanced ECHIDNA System - Integrated Vocabulary and Prover System
|||
||| This module combines:
||| - 6000+ vocabulary terms for mathematical reasoning
||| - Scalable prover registry with thousands of theorem provers
||| - Intelligent prover selection based on vocabulary analysis
||| - Natural language understanding for theorem proving
|||
||| The system provides:
||| 1. Vocabulary-enhanced theorem proving
||| 2. Intelligent prover recommendation
||| 3. Natural language theorem interpretation
||| 4. Context-aware proof synthesis
module Echidna.Enhanced

import Echidna.Vocabulary
import Echidna.Vocabulary.Generator
import Echidna.Prover.Types
import Echidna.Prover.Registry
import Echidna.Prover.Database.Main
import Data.List
import Data.String
import Data.Maybe

%default total

||| Enhanced Theorem with Vocabulary Context
public export
record EnhancedTheorem where
  constructor MkEnhancedTheorem
  ||| Original theorem
  theorem : String
  ||| Detected vocabulary terms
  vocabTerms : List String
  ||| Suggested prover categories
  suggestedCategories : List ProverCategory
  ||| Recommended provers
  recommendedProvers : List String
  ||| Confidence score
  confidence : Double

||| Vocabulary-Enhanced Prover System
public export
record EnhancedProverSystem where
  constructor MkEnhancedProverSystem
  ||| Vocabulary database
  vocabulary : Vocabulary
  ||| Prover registry
  provers : ProverRegistry
  ||| Theorem format mappings
  formatMappings : List (String, TheoremFormat)

||| Default enhanced system with 6000+ terms and scalable provers
public export
defaultEnhancedSystem : EnhancedProverSystem
defaultEnhancedSystem = MkEnhancedProverSystem (generateCompleteVocabulary) completeProverRegistry defaultFormatMappings

||| Default format mappings
public export
defaultFormatMappings : List (String, TheoremFormat)
defaultFormatMappings =
  [ ("smtlib", SMTLib)
  , ("tptp", TPTP)
  , ("natural", NaturalLang)
  , ("idris", Idris2)
  , ("lean", Lean4Syntax)
  , ("coq", CoqSyntax)
  , ("agda", AgdaSyntax)
  , ("isabelle", IsabelleIsar)
  , ("tla+", TLAPlus)
  , ("alloy", AlloySyntax)
  ]

||| Analyze theorem text and extract vocabulary terms
public export
analyzeTheoremVocabulary : String -> Vocabulary -> List String
analyzeTheoremVocabulary text vocab =
  let words = splitWords (map toLower text)
      validTerms = filter (\(MkVocabEntry term _ _ _ _ _ _) => term `elem` words) (allTerms vocab)
  in map (.term) validTerms
  where
    splitWords : String -> List String
    splitWords [] = []
    splitWords str =
      let (word, rest) = span (\(MkVocabEntry term _ _ _ _ _ _) => term `elem` words) str
      in if null word
           then splitWords (dropWhile (\(MkVocabEntry term _ _ _ _ _ _) => term `elem` words) str)
           else word :: splitWords rest

||| Suggest prover categories based on vocabulary terms
public export
suggestProverCategories : List String -> Vocabulary -> List ProverCategory
suggestProverCategories terms vocab =
  let termEntries = filter (\(MkVocabEntry term _ _ _ _ _ _) => term `elem` terms) (allTerms vocab)
      categories = map (.category) termEntries
  in nub categories

||| Recommend specific provers based on categories
public export
recommendProvers : List ProverCategory -> ProverRegistry -> List String
recommendProvers categories registry =
  let proversByCat = concatMap (\(MkVocabEntry term _ _ _ _ _ _) => findProversByCategory term registry) categories
      sortedProvers = sortBy (\(MkVocabEntry term _ _ _ _ _ p1) (MkVocabEntry term _ _ _ _ _ p2) => compare p2 p1) proversByCat
  in map (.id) (take 5 sortedProvers)

||| Enhance theorem with vocabulary analysis
public export
enhanceTheorem : String -> EnhancedProverSystem -> EnhancedTheorem
enhanceTheorem theoremText system =
  let vocabTerms = analyzeTheoremVocabulary theoremText system.vocabulary
      categories = suggestProverCategories vocabTerms system.vocabulary
      recommendedProvers = recommendProvers categories system.provers
      confidence = calculateConfidence vocabTerms system.vocabulary
  in MkEnhancedTheorem theoremText vocabTerms categories recommendedProvers confidence
  where
    calculateConfidence : List String -> Vocabulary -> Double
    calculateConfidence terms vocab =
      let totalTerms = fromIntegral (length terms)
          highPriority = fromIntegral (length (filter (\(MkVocabEntry term _ _ _ _ _ p) => p > 70) (allTerms vocab)))
      in if totalTerms == 0 then 0.5 else min 1.0 (highPriority / totalTerms * 0.7 + 0.3)

||| Intelligent prover selection
public export
selectBestProver : EnhancedTheorem -> ProverRegistry -> Maybe ProverEntry
selectBestProver theorem registry =
  case theorem.recommendedProvers of
    [] => Nothing
    (proverId :: _) => findProverById proverId registry

||| Natural language theorem interpretation
public export
interpretNaturalLanguage : String -> EnhancedProverSystem -> Either String EnhancedTheorem
interpretNaturalLanguage text system =
  let vocabTerms = analyzeTheoremVocabulary text system.vocabulary
  if null vocabTerms
    then Left "Could not interpret theorem: insufficient vocabulary matches"
    else Right (enhanceTheorem text system)

||| Vocabulary-based theorem formatting
public export
formatTheorem : EnhancedTheorem -> EnhancedProverSystem -> Either String (String, TheoremFormat)
formatTheorem theorem system =
  let vocabTerms = theorem.vocabTerms
      -- Simple heuristic: use SMTLib for mathematical terms, TPTP for logic terms
      hasMathTerms = any (\(MkVocabEntry term _ _ _ _ _ _) => term `elem` ["equation", "formula", "arithmetic", "algebra"]) (allTerms system.vocabulary)
      hasLogicTerms = any (\(MkVocabEntry term _ _ _ _ _ _) => term `elem` ["predicate", "quantifier", "clause", "resolution"]) (allTerms system.vocabulary)
      (format, formatType) = if hasMathTerms
                             then (convertToSMTLib theorem.theorem, SMTLib)
                             else if hasLogicTerms
                             then (convertToTPTP theorem.theorem, TPTP)
                             else (theorem.theorem, NaturalLang)
  in Right (format, formatType)
  where
    convertToSMTLib : String -> String
    convertToSMTLib text = "(assert " ++ text ++ ")"
    
    convertToTPTP : String -> String
    convertToTPTP text = "cnf(" ++ text ++ ", axiom)."

||| Enhanced prover statistics
public export
enhancedSystemStats : EnhancedProverSystem -> String
enhancedSystemStats system =
  let vocabStats = vocabStats system.vocabulary
      proverStats = registryStats system.provers
      formatCount = length system.formatMappings
      generatedStats = generatedVocabStats
  in "ECHIDNA Enhanced System Statistics:\n\n" ++
     generatedStats ++ "\n" ++
     vocabStats ++ "\n" ++
     proverStats ++ "\n" ++
     "Format Mappings: " ++ show formatCount ++ "\n\n" ++
     "Total System Capacity: 6000+ vocabulary terms + scalable prover registry"

||| Vocabulary Learning System
public export
VocabLearningM : Type -> Type
VocabLearningM a = State EnhancedProverSystem a

||| Add new vocabulary term
public export
learnTerm : VocabEntry -> VocabLearningM ()
learnTerm entry = modify (\(MkEnhancedProverSystem vocab provers formats) =>
                         MkEnhancedProverSystem (addEntry entry vocab) provers formats)

||| Add new prover to registry
public export
addProver : ProverEntry -> VocabLearningM ()
addProver entry = modify (\(MkEnhancedProverSystem vocab provers formats) =>
                        MkEnhancedProverSystem vocab (registerProver entry provers) formats)

||| Add new format mapping
public export
addFormatMapping : (String, TheoremFormat) -> VocabLearningM ()
addFormatMapping mapping = modify (\(MkEnhancedProverSystem vocab provers formats) =>
                                 MkEnhancedProverSystem vocab provers (mapping :: formats))

||| Run learning monad
public export
runLearning : VocabLearningM a -> EnhancedProverSystem -> (a, EnhancedProverSystem)
runLearning = runState

||| Execute learning
public export
execLearning : VocabLearningM a -> EnhancedProverSystem -> EnhancedProverSystem
execLearning = execState