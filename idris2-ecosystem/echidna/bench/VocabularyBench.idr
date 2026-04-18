-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2024 ECHIDNA Project
--
-- VocabularyBench.idr — Performance benchmarks for ECHIDNA vocabulary system
--
-- Measures throughput and latency of core vocabulary operations:
--   1. Term lookup (exact match)
--   2. Term search (partial match)
--   3. Category filtering
--   4. Theorem analysis
--   5. Prover recommendation
--
-- Run with: idris2 --exec VocabularyBench.idr
--
-- These benchmarks establish baselines for CI regression detection.

module VocabularyBench

import Echidna.Vocabulary
import Echidna.Vocabulary.Generator
import Echidna.Prover.Types
import Echidna.Prover.Registry
import Echidna.Enhanced
import Data.List
import Data.String
import Data.Time
import System

%default total

-- ===========================================================================
-- Benchmark infrastructure
-- ===========================================================================

||| Number of iterations for benchmarks
ITERS : Nat
ITERS = 1000

||| Benchmark result record
record BenchResult where
  constructor MkBenchResult
  name : String
  iterations : Nat
  totalMs : Double
  nsPerIter : Double
  itersPerSec : Double

||| Run a benchmark and return results
bench : String -> Nat -> (() -> a) -> BenchResult
bench name iters fn = 
  let -- Warmup
      _ = map (\(MkVocabEntry term _ _ _ _ _ _) => fn ()) (take 100 (generateMathTerms ++ generateCSTerms))
      
      -- Actual benchmark
      start = getCurrentTime
      results = map (\(MkVocabEntry term _ _ _ _ _ _) => fn ()) (take iters (generateMathTerms ++ generateCSTerms))
      end = getCurrentTime
      totalMs = timeDiffMs start end
      nsPerIter = (totalMs * 1000000.0) / fromIntegral iters
      itersPerSec = fromIntegral iters / (totalMs / 1000.0)
  in MkBenchResult name iters totalMs nsPerIter itersPerSec
  where
    getCurrentTime : Double
    getCurrentTime = prim__current_time_ms
    
    timeDiffMs : Double -> Double -> Double
    timeDiffMs start end = end - start

||| Print benchmark result
printResult : BenchResult -> IO ()
printResult r = 
  let ns = printf "%.1f" r.nsPerIter
      throughput = printf "%.3f" (r.itersPerSec / 1000000.0)
  in putStrLn $ padEnd 50 r.name ++ padStart 12 ns ++ " ns/iter  (" ++ throughput ++ " M/s)"
  where
    padEnd : Nat -> String -> String
    padEnd n s = s ++ replicate (n - length s) ' '
    
    padStart : Nat -> String -> String
    padStart n s = replicate (n - length s) ' ' ++ s

-- ===========================================================================
-- Benchmark subjects — Test vocabulary and system
-- ===========================================================================

||| Test vocabulary with realistic size
benchVocab : Vocabulary
benchVocab = generateCompleteVocabulary

||| Test enhanced system
benchSystem : EnhancedProverSystem
benchSystem = defaultEnhancedSystem

||| Benchmark: Term lookup by exact name
benchTermLookup : () -> Maybe VocabEntry
benchTermLookup () = findTerm "polynomial" benchVocab

||| Benchmark: Term search (partial match)
benchTermSearch : () -> List VocabEntry
benchTermSearch () = searchTerms "poly" benchVocab

||| Benchmark: Category filtering
benchCategoryFilter : () -> List VocabEntry
benchCategoryFilter () = findByCategory MathCat benchVocab

||| Benchmark: Theorem analysis (simple)
benchTheoremAnalysisSimple : () -> EnhancedTheorem
benchTheoremAnalysisSimple () = enhanceTheorem "For all x, x + 0 = x" benchSystem

||| Benchmark: Theorem analysis (complex)
benchTheoremAnalysisComplex : () -> EnhancedTheorem
benchTheoremAnalysisComplex () = enhanceTheorem "Prove that the derivative of sin(x) is cos(x) and show that this implies the integral of cos(x) is sin(x) plus a constant" benchSystem

||| Benchmark: Prover recommendation
benchProverRecommendation : () -> Maybe ProverEntry
benchProverRecommendation () =
  let theorem = enhanceTheorem "SMT-LIB: (assert (= (+ x 0) x))" benchSystem
  in selectBestProver theorem benchSystem.provers

||| Benchmark: Natural language interpretation
benchNaturalLanguage : () -> Either String EnhancedTheorem
benchNaturalLanguage () = interpretNaturalLanguage "The sum of any number and its additive inverse equals zero" benchSystem

-- ===========================================================================
-- Run all benchmarks
-- ===========================================================================

||| Main benchmark runner
main : IO ()
main = do
  putStrLn ""
  putStrLn "ECHIDNA Vocabulary System Benchmarks"
  putStrLn "========================================"
  putStrLn $ "Iterations: " ++ show ITERS
  putStrLn ""
  putStrLn $ padEnd 50 "Benchmark" ++ padStart 12 "Time" ++ "  Throughput"
  putStrLn $ "-" ++ replicate 76 '-'
  
  let results = [
        bench "term_lookup (exact match)" ITERS benchTermLookup,
        bench "term_search (partial match)" ITERS benchTermSearch,
        bench "category_filter (math terms)" ITERS benchCategoryFilter,
        bench "theorem_analysis (simple)" ITERS benchTheoremAnalysisSimple,
        bench "theorem_analysis (complex)" ITERS benchTheoremAnalysisComplex,
        bench "prover_recommendation" ITERS benchProverRecommendation,
        bench "natural_language_interpret" ITERS benchNaturalLanguage
      ]
  
  mapM_ printResult results
  
  putStrLn ""
  putStrLn "Baseline notes:"
  putStrLn "  - term_lookup: Single hash table lookup cost"
  putStrLn "  - term_search: String search across all terms"
  putStrLn "  - category_filter: Indexed category lookup"
  putStrLn "  - theorem_analysis: Vocabulary extraction + category suggestion"
  putStrLn "  - prover_recommendation: Category-based prover selection"
  putStrLn "  - natural_language_interpret: Full NLP pipeline"
  putStrLn ""
  
  -- Calculate and display vocabulary statistics
  let vocabStats = vocabStats benchVocab
      systemStats = enhancedSystemStats benchSystem
  in do
    putStrLn "System Statistics:"
    putStrLn vocabStats
    putStrLn systemStats