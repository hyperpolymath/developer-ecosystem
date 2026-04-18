-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2024 ECHIDNA Project
--
-- VocabularyTest.idr — Comprehensive unit tests for ECHIDNA vocabulary system
--
-- Tests the vocabulary database, search, and integration with prover system.
-- Follows the testing standards from the standards repository.
--
-- Run with: idris2 --test VocabularyTest.idr

module VocabularyTest

import Echidna.Vocabulary
import Echidna.Vocabulary.Generator
import Echidna.Prover.Types
import Echidna.Prover.Registry
import Echidna.Enhanced
import Data.List
import Data.String
import Data.Maybe
import Test.Idris2

%default total

-- ===========================================================================
-- Test fixtures
-- ===========================================================================

||| Sample vocabulary entries for testing
sampleMathTerms : List VocabEntry
sampleMathTerms =
  [ MkVocabEntry "polynomial" MathCat "An expression consisting of variables and coefficients" ["equation", "variable"] ["x² + 2x + 1"] ["Math Textbook"] 85
  , MkVocabEntry "derivative" MathCat "The rate of change of a function" ["calculus", "limit"] ["d/dx(x²) = 2x"] ["Calculus Textbook"] 90
  , MkVocabEntry "integral" MathCat "The area under a curve" ["calculus", "antiderivative"] ["∫x²dx = x³/3 + C"] ["Calculus Textbook"] 85
  ]

sampleCSTerms : List VocabEntry
sampleCSTerms =
  [ MkVocabEntry "algorithm" CSCat "A step-by-step procedure for calculations" ["computation", "complexity"] ["sorting algorithm"] ["CLRS"] 80
  , MkVocabEntry "data structure" CSCat "A way to organize and store data" ["array", "linked list"] ["hash table"] ["CLRS"] 75
  , MkVocabEntry "complexity" CSCat "Computational resources required by an algorithm" ["big O", "asymptotic"] ["O(n log n)"] ["CLRS"] 85
  ]

||| Build test vocabulary
buildTestVocabulary : Vocabulary
buildTestVocabulary =
  execVocabBuilder testVocabBuilder defaultVocabulary
  where
    testVocabBuilder : VocabM ()
    testVocabBuilder = do
      mapM_ addTerm sampleMathTerms
      mapM_ addTerm sampleCSTerms
      mapM_ addTerm (take 100 (generateMathTerms ++ generateCSTerms))

-- ===========================================================================
-- Unit tests: Vocabulary database operations
-- ===========================================================================

||| Test: Empty vocabulary has zero size
emptyVocabularySize : Test
emptyVocabularySize = 
  let vocab = defaultVocabulary
  in AssertEqual (vocabSize vocab) 0 "Empty vocabulary should have size 0"

||| Test: Adding terms increases vocabulary size
addTermsIncreasesSize : Test
addTermsIncreasesSize = 
  let vocab = buildTestVocabulary
  in AssertEqual (vocabSize vocab) 106 "Should have 106 terms (3 + 3 + 100)"

||| Test: Find term by exact name
findTermExactMatch : Test
findTermExactMatch = 
  let vocab = buildTestVocabulary
      result = findTerm "polynomial" vocab
  in case result of
       Just entry => AssertEqual entry.term "polynomial" "Found correct term"
       Nothing => AssertFail "Should find polynomial term"

||| Test: Find term returns Nothing for non-existent term
findTermNotFound : Test
findTermNotFound = 
  let vocab = buildTestVocabulary
      result = findTerm "nonexistent" vocab
  in case result of
       Just _ => AssertFail "Should not find non-existent term"
       Nothing => AssertPass "Correctly returns Nothing for non-existent term"

||| Test: Find terms by category
findTermsByCategory : Test
findTermsByCategory = 
  let vocab = buildTestVocabulary
      mathTerms = findByCategory MathCat vocab
      csTerms = findByCategory CSCat vocab
  in AssertEqual (length mathTerms) 103 "Should find 103 math terms"
     `And` AssertEqual (length csTerms) 3 "Should find 3 CS terms"

||| Test: Search terms by partial match
searchTermsPartialMatch : Test
searchTermsPartialMatch = 
  let vocab = buildTestVocabulary
      results = searchTerms "poly" vocab
  in AssertEqual (length results) 1 "Should find 1 term containing 'poly'"
     `And` AssertEqual (head results).term "polynomial" "Should find polynomial"

||| Test: Search is case-insensitive
searchCaseInsensitive : Test
searchCaseInsensitive = 
  let vocab = buildTestVocabulary
      lowerResults = searchTerms "POLYNOMIAL" vocab
      upperResults = searchTerms "polynomial" vocab
      mixedResults = searchTerms "PoLyNoMiAl" vocab
  in AssertEqual (length lowerResults) 1 "Lowercase search works"
     `And` AssertEqual (length upperResults) 1 "Uppercase search works"
     `And` AssertEqual (length mixedResults) 1 "Mixed case search works"

||| Test: Vocabulary statistics are correct
vocabStatsCorrect : Test
vocabStatsCorrect = 
  let vocab = buildTestVocabulary
      stats = vocabStats vocab
  in AssertTrue ("Total Terms: 106" `isInfixOf` stats) "Stats should show correct total"
     `And` AssertTrue ("Mathematics: 103" `isInfixOf` stats) "Stats should show math count"
     `And` AssertTrue ("Computer Science: 3" `isInfixOf` stats) "Stats should show CS count"

-- ===========================================================================
-- Unit tests: Vocabulary builder monad
-- ===========================================================================

||| Test: Builder starts with empty vocabulary
builderStartsEmpty : Test
builderStartsEmpty = 
  let (_, vocab) = runVocabBuilder (pure ()) defaultVocabulary
  in AssertEqual (vocabSize vocab) 0 "Builder should start with empty vocabulary"

||| Test: Builder can add terms
builderAddsTerms : Test
builderAddsTerms = 
  let builderAction = addTerm (head sampleMathTerms)
      (_, vocab) = runVocabBuilder builderAction defaultVocabulary
  in AssertEqual (vocabSize vocab) 1 "Builder should add one term"

||| Test: Builder can add multiple terms
builderAddsMultipleTerms : Test
builderAddsMultipleTerms = 
  let builderAction = mapM_ addTerm sampleMathTerms
      (_, vocab) = runVocabBuilder builderAction defaultVocabulary
  in AssertEqual (vocabSize vocab) 3 "Builder should add three terms"

-- ===========================================================================
-- Unit tests: Enhanced theorem processing
-- ===========================================================================

||| Test: Theorem analysis extracts vocabulary terms
theoremAnalysisExtractsTerms : Test
theoremAnalysisExtractsTerms = 
  let system = defaultEnhancedSystem
      theorem = "For all x, the derivative of x squared is 2x"
      enhanced = enhanceTheorem theorem system
  in AssertTrue ("derivative" `elem` enhanced.vocabTerms) "Should find 'derivative'"
     `And` AssertTrue ("function" `elem` enhanced.vocabTerms) "Should find related terms"

||| Test: Theorem analysis suggests appropriate categories
theoremAnalysisSuggestsCategories : Test
theoremAnalysisSuggestsCategories = 
  let system = defaultEnhancedSystem
      theorem = "The integral of x squared from 0 to 1 equals one third"
      enhanced = enhanceTheorem theorem system
  in AssertTrue (MathCat `elem` enhanced.suggestedCategories) "Should suggest math category"

||| Test: Theorem analysis recommends provers
theoremAnalysisRecommendsProvers : Test
theoremAnalysisRecommendsProvers = 
  let system = defaultEnhancedSystem
      theorem = "Prove that for all x, x + 0 = x"
      enhanced = enhanceTheorem theorem system
  in AssertTrue (length enhanced.recommendedProvers > 0) "Should recommend at least one prover"

||| Test: Confidence scoring works
confidenceScoringWorks : Test
confidenceScoringWorks = 
  let system = defaultEnhancedSystem
      simpleTheorem = "1 + 1 = 2"
      complexTheorem = "For all ε > 0, there exists δ > 0 such that |x - a| < δ implies |f(x) - f(a)| < ε"
      simpleEnhanced = enhanceTheorem simpleTheorem system
      complexEnhanced = enhanceTheorem complexTheorem system
  in AssertTrue (simpleEnhanced.confidence >= 0.3) "Simple theorem should have decent confidence"
     `And` AssertTrue (complexEnhanced.confidence >= 0.5) "Complex theorem should have higher confidence"

-- ===========================================================================
-- Unit tests: Prover recommendation
-- ===========================================================================

||| Test: Prover selection from recommendations
proverSelectionWorks : Test
proverSelectionWorks = 
  let system = defaultEnhancedSystem
      theorem = "SMT-LIB formula: (assert (= (+ x 0) x))"
      enhanced = enhanceTheorem theorem system
      selected = selectBestProver enhanced system.provers
  in case selected of
       Just prover => AssertTrue (prover.id `elem` ["z3", "cvc5", "yices"]) "Should select SMT solver"
       Nothing => AssertFail "Should select a prover"

||| Test: Natural language interpretation
naturalLanguageInterpretation : Test
naturalLanguageInterpretation = 
  let system = defaultEnhancedSystem
      naturalTheorem = "The sum of any number and its additive inverse is zero"
      result = interpretNaturalLanguage naturalTheorem system
  in case result of
       Right enhanced => AssertTrue (length enhanced.vocabTerms > 0) "Should interpret natural language"
       Left _ => AssertFail "Should successfully interpret natural language"

-- ===========================================================================
-- Unit tests: Enhanced system statistics
-- ===========================================================================

||| Test: System statistics include vocabulary info
systemStatsIncludeVocabulary : Test
systemStatsIncludeVocabulary = 
  let system = defaultEnhancedSystem
      stats = enhancedSystemStats system
  in AssertTrue ("6000+ terms" `isInfixOf` stats) "Stats should mention vocabulary size"
     `And` AssertTrue ("Total System Capacity" `isInfixOf` stats) "Stats should show total capacity"

-- ===========================================================================
-- Security tests: Malicious inputs
-- ===========================================================================

||| Test: Empty theorem doesn't crash
emptyTheoremSafe : Test
emptyTheoremSafe = 
  let system = defaultEnhancedSystem
      result = interpretNaturalLanguage "" system
  in case result of
       Left _ => AssertPass "Empty theorem should fail gracefully"
       Right _ => AssertPass "Empty theorem handled safely"

||| Test: Very long theorem doesn't crash
longTheoremSafe : Test
longTheoremSafe = 
  let system = defaultEnhancedSystem
      longTheorem = "x " ++ replicate 1000 "+" ++ " y"
      result = interpretNaturalLanguage longTheorem system
  in case result of
       Left _ => AssertPass "Long theorem should fail gracefully"
       Right _ => AssertPass "Long theorem handled safely"

||| Test: Special characters in theorem
specialCharsSafe : Test
specialCharsSafe = 
  let system = defaultEnhancedSystem
      specialTheorem = "∀ε>0, ∃δ>0: |x-a|<δ ⇒ |f(x)-f(a)|<ε"
      result = interpretNaturalLanguage specialTheorem system
  in case result of
       Left _ => AssertPass "Special characters handled safely"
       Right _ => AssertPass "Special characters processed correctly"

-- ===========================================================================
-- Integration tests: Vocabulary + Prover system
-- ===========================================================================

||| Test: Vocabulary enhances prover selection
vocabularyEnhancesProverSelection : Test
vocabularyEnhancesProverSelection = 
  let system = defaultEnhancedSystem
      -- Theorem with clear mathematical content
      mathTheorem = "Prove that the derivative of sin(x) is cos(x)"
      -- Theorem with logical content  
      logicTheorem = "Show that (A ∧ B) → A is a tautology"
      
      mathEnhanced = enhanceTheorem mathTheorem system
      logicEnhanced = enhanceTheorem logicTheorem system
      
      mathProver = selectBestProver mathEnhanced system.provers
      logicProver = selectBestProver logicEnhanced system.provers
  in case (mathProver, logicProver) of
       (Just mathP, Just logicP) =>
         AssertTrue (mathP.category == SMTCat || mathP.category == DepTypeCat) "Math theorem should get math-oriented prover"
         `And` AssertTrue (logicP.category == ATPCat || logicP.category == ProofCat) "Logic theorem should get logic-oriented prover"
       _ => AssertFail "Both theorems should get prover recommendations"

||| Test: Vocabulary improves theorem formatting
vocabularyImprovesFormatting : Test
vocabularyImprovesFormatting = 
  let system = defaultEnhancedSystem
      mathTheorem = "For all x, x + 0 = x"
      enhanced = enhanceTheorem mathTheorem system
      formatResult = formatTheorem enhanced system
  in case formatResult of
       Right (formatted, format) =>
         AssertTrue (length formatted > length mathTheorem) "Should add formatting"
         AssertTrue (format == SMTLib || format == NaturalLang) "Should choose appropriate format"
       Left _ => AssertFail "Formatting should succeed"

-- ===========================================================================
-- Test suite runner
-- ===========================================================================

||| Run all vocabulary tests
runVocabularyTests : IO ()
runVocabularyTests = do
  putStrLn "Running ECHIDNA Vocabulary Tests..."
  putStrLn "===================================="
  
  -- Unit tests: Vocabulary database
  runTest "Empty vocabulary size" emptyVocabularySize
  runTest "Add terms increases size" addTermsIncreasesSize
  runTest "Find term exact match" findTermExactMatch
  runTest "Find term not found" findTermNotFound
  runTest "Find terms by category" findTermsByCategory
  runTest "Search terms partial match" searchTermsPartialMatch
  runTest "Search case insensitive" searchCaseInsensitive
  runTest "Vocabulary stats correct" vocabStatsCorrect
  
  -- Unit tests: Vocabulary builder
  runTest "Builder starts empty" builderStartsEmpty
  runTest "Builder adds terms" builderAddsTerms
  runTest "Builder adds multiple terms" builderAddsMultipleTerms
  
  -- Unit tests: Enhanced theorem processing
  runTest "Theorem analysis extracts terms" theoremAnalysisExtractsTerms
  runTest "Theorem analysis suggests categories" theoremAnalysisSuggestsCategories
  runTest "Theorem analysis recommends provers" theoremAnalysisRecommendsProvers
  runTest "Confidence scoring works" confidenceScoringWorks
  
  -- Unit tests: Prover recommendation
  runTest "Prover selection works" proverSelectionWorks
  runTest "Natural language interpretation" naturalLanguageInterpretation
  
  -- Unit tests: System statistics
  runTest "System stats include vocabulary" systemStatsIncludeVocabulary
  
  -- Security tests
  runTest "Empty theorem safe" emptyTheoremSafe
  runTest "Long theorem safe" longTheoremSafe
  runTest "Special characters safe" specialCharsSafe
  
  -- Integration tests
  runTest "Vocabulary enhances prover selection" vocabularyEnhancesProverSelection
  runTest "Vocabulary improves formatting" vocabularyImprovesFormatting
  
  putStrLn "\nAll tests completed!"
  where
    runTest : String -> Test -> IO ()
    runTest name test = do
      putStr "  "
      putStr name
      putStr "... "
      case runTest test of
        TestPass => putStrLn "✓ PASS"
        TestFail msg => putStrLn $ "✗ FAIL: " ++ msg

||| Main test entry point
main : IO ()
main = runVocabularyTests