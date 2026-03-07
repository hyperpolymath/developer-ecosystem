# SPDX-License-Identifier: PMPL-1.0-or-later

# stdlib-merger Architecture

**Author:** Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>
**Date:** 2026-02-01

## Overview

stdlib-merger is a tool that automates the extraction of common patterns from multiple language standard libraries, creating a merged aggregate-library with best-of-breed implementations.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     CLI Entry Point (cli.jl)                    │
│  Commands: merge, analyze, rank, extract, strip, report         │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                    Orchestrator (orchestrator.jl)                │
│  Coordinates pipeline: parse → analyze → rank → extract → strip │
└───┬────────┬────────┬────────┬────────┬────────────────────────┘
    │        │        │        │        │
    │        │        │        │        │
┌───▼──┐ ┌───▼──┐ ┌──▼───┐ ┌──▼────┐ ┌▼──────┐
│Parser│ │Matcher│ │Ranker│ │Extract│ │Stripper│
│      │ │       │ │      │ │       │ │        │
└───┬──┘ └───┬──┘ └──┬───┘ └──┬────┘ └┬───────┘
    │        │       │        │        │
    │        │       │        │        │
┌───▼────────▼───────▼────────▼────────▼─────────────────────────┐
│                    Data Layer (models.jl)                        │
│  StdLib, Module, Function, Pattern, Ranking, Translation        │
└──────────────────────────────────────────────────────────────────┘
```

---

## Component Architecture

### 1. Parser Module (`src/parser.jl`)

**Responsibility:** Extract function signatures and metadata from stdlib source files

**Inputs:**
- Stdlib paths (Elixir, Rust, Haskell source directories)
- Language type (elixir, rust, haskell)

**Outputs:**
- `StdLib` struct containing all modules and functions

**Sub-components:**

```julia
module Parser
    export parse_stdlib, parse_module, parse_function

    # Language-specific parsers
    include("parsers/elixir_parser.jl")
    include("parsers/rust_parser.jl")
    include("parsers/haskell_parser.jl")

    """
    Parse a stdlib directory and extract all functions.
    """
    function parse_stdlib(path::String, lang::Symbol)::StdLib
        if lang == :elixir
            return ElixirParser.parse(path)
        elseif lang == :rust
            return RustParser.parse(path)
        elseif lang == :haskell
            return HaskellParser.parse(path)
        else
            error("Unsupported language: $lang")
        end
    end
end
```

**Key Data Structures:**

```julia
struct FunctionSignature
    name::String
    module_path::String
    params::Vector{Param}
    return_type::Type
    docstring::String
    examples::Vector{String}
    source_location::SourceLocation
end

struct Param
    name::String
    type::Type
    default::Union{Nothing, Any}
end

struct StdLib
    language::Symbol
    path::String
    modules::Dict{String, Module}
    functions::Vector{FunctionSignature}
end
```

---

### 2. Matcher Module (`src/matcher.jl`)

**Responsibility:** Identify semantically similar functions across stlibs

**Inputs:**
- Multiple `StdLib` structs (one per language)

**Outputs:**
- `Pattern` structs representing common operations

**Algorithm:**

```julia
module Matcher
    export find_patterns, match_functions

    """
    Find common patterns across N stlibs using multi-stage matching.
    """
    function find_patterns(stlibs::Vector{StdLib})::Vector{Pattern}
        patterns = Pattern[]

        # Stage 1: Name-based clustering
        name_clusters = cluster_by_name(stlibs)

        # Stage 2: Semantic similarity (LLM-based)
        for cluster in name_clusters
            semantic_score = compute_semantic_similarity(cluster)
            if semantic_score > SEMANTIC_THRESHOLD
                pattern = create_pattern(cluster)
                push!(patterns, pattern)
            end
        end

        # Stage 3: Type-based validation
        patterns = filter(p -> validate_types(p), patterns)

        return patterns
    end

    """
    Cluster functions by name similarity using Levenshtein distance.
    """
    function cluster_by_name(stlibs::Vector{StdLib})::Vector{Cluster}
        # Build function name index
        all_functions = vcat([s.functions for s in stlibs]...)

        # Compute pairwise name distances
        distances = compute_name_distances(all_functions)

        # Hierarchical clustering
        clusters = hierarchical_cluster(distances, DISTANCE_THRESHOLD)

        return clusters
    end

    """
    Compute semantic similarity using LLM API.
    """
    function compute_semantic_similarity(cluster::Cluster)::Float64
        # Extract docstrings from all functions in cluster
        docstrings = [f.docstring for f in cluster.functions]

        # Ask LLM: "Are these functions semantically equivalent?"
        prompt = build_similarity_prompt(docstrings)
        response = call_llm_api(prompt)

        # Parse confidence score from response
        score = parse_confidence(response)

        return score
    end
end
```

**Key Data Structures:**

```julia
struct Pattern
    id::String
    name::String  # e.g., "string_split"
    implementations::Dict{Symbol, FunctionSignature}  # :elixir => func, :rust => func
    similarity_score::Float64
    is_universal::Bool  # true if exists in ALL stlibs
end

struct Cluster
    functions::Vector{FunctionSignature}
    centroid_name::String
    avg_distance::Float64
end
```

---

### 3. Ranker Module (`src/ranker.jl`)

**Responsibility:** Score implementations and choose the best one for each pattern

**Inputs:**
- `Pattern` structs with multiple implementations

**Outputs:**
- `Ranking` structs with best implementation selected

**Scoring Algorithm:**

```julia
module Ranker
    export rank_implementations, score_implementation

    """
    Rank all implementations for a pattern and choose the best.
    """
    function rank_implementations(pattern::Pattern)::Ranking
        scores = Dict{Symbol, Float64}()

        for (lang, impl) in pattern.implementations
            score = score_implementation(impl, pattern)
            scores[lang] = score
        end

        # Choose best implementation
        best_lang = argmax(scores)
        best_impl = pattern.implementations[best_lang]

        return Ranking(
            pattern = pattern,
            scores = scores,
            best_language = best_lang,
            best_implementation = best_impl
        )
    end

    """
    Score a single implementation based on quality criteria.
    """
    function score_implementation(impl::FunctionSignature, pattern::Pattern)::Float64
        criteria = load_quality_criteria()

        scores = [
            score_api_clarity(impl) * criteria.api_clarity.weight,
            score_performance(impl) * criteria.performance.weight,
            score_error_handling(impl) * criteria.error_handling.weight,
            score_unicode_support(impl, pattern) * criteria.unicode_support.weight,
            score_memory_safety(impl) * criteria.memory_safety.weight,
            score_composability(impl) * criteria.composability.weight
        ]

        return sum(scores)
    end

    """
    Score API clarity using LLM analysis of signature and docstring.
    """
    function score_api_clarity(impl::FunctionSignature)::Float64
        prompt = """
        Rate the API clarity of this function on a scale of 0-10:

        Name: $(impl.name)
        Signature: $(format_signature(impl))
        Documentation: $(impl.docstring)

        Consider:
        - Function name clarity
        - Parameter naming
        - Return type clarity
        - Documentation quality

        Respond with only a number between 0 and 10.
        """

        response = call_llm_api(prompt)
        score = parse(Float64, strip(response))

        return score / 10.0  # Normalize to 0-1
    end

    """
    Score error handling based on return type.
    """
    function score_error_handling(impl::FunctionSignature)::Float64
        return_type = impl.return_type

        # Result/Either pattern: 1.0
        if is_result_type(return_type) || is_either_type(return_type)
            return 1.0
        end

        # Maybe/Option pattern: 0.7
        if is_maybe_type(return_type) || is_option_type(return_type)
            return 0.7
        end

        # Throws exceptions: 0.3
        if has_exception_annotation(impl)
            return 0.3
        end

        # No error handling: 0.0
        return 0.0
    end
end
```

**Key Data Structures:**

```julia
struct Ranking
    pattern::Pattern
    scores::Dict{Symbol, Float64}  # :elixir => 8.5, :rust => 7.8, :haskell => 9.2
    best_language::Symbol
    best_implementation::FunctionSignature
    justification::String  # Why this implementation was chosen
end

struct QualityCriteria
    api_clarity::Criterion
    performance::Criterion
    error_handling::Criterion
    unicode_support::Criterion
    memory_safety::Criterion
    composability::Criterion
end

struct Criterion
    weight::Float64  # 0.0 - 1.0
    scoring_method::Function
end
```

---

### 4. Extractor Module (`src/extractor.jl`)

**Responsibility:** Generate aggregate-library modules from best implementations

**Inputs:**
- `Ranking` structs with best implementations selected

**Outputs:**
- Generated Elixir module files in `aggregate-library/lib/`

**Translation Pipeline:**

```julia
module Extractor
    export extract_module, translate_code

    """
    Extract a pattern to an aggregate-library module.
    """
    function extract_module(ranking::Ranking, output_dir::String)
        best_impl = ranking.best_implementation
        best_lang = ranking.best_language

        # If already in target language (Elixir), copy directly
        if best_lang == :elixir
            code = read_source(best_impl.source_location)
        else
            # Translate from source language to Elixir
            code = translate_code(best_impl, best_lang, :elixir)
        end

        # Normalize API (make it consistent with aggregate-library style)
        code = normalize_api(code, ranking.pattern)

        # Add module header
        code = add_module_header(code, ranking)

        # Write to output
        module_path = joinpath(output_dir, "$(ranking.pattern.name).ex")
        write(module_path, code)

        return module_path
    end

    """
    Translate code from one language to another using AST transformation.
    """
    function translate_code(impl::FunctionSignature, from::Symbol, to::Symbol)::String
        if from == :rust && to == :elixir
            return RustToElixir.translate(impl)
        elseif from == :haskell && to == :elixir
            return HaskellToElixir.translate(impl)
        else
            error("Unsupported translation: $from -> $to")
        end
    end
end
```

**Translation Sub-modules:**

```julia
# src/translators/rust_to_elixir.jl
module RustToElixir
    export translate

    function translate(impl::FunctionSignature)::String
        # Parse Rust code to AST
        rust_ast = parse_rust(impl.source_location)

        # Transform Rust AST to Elixir AST
        elixir_ast = transform_ast(rust_ast)

        # Generate Elixir code from AST
        elixir_code = generate_elixir(elixir_ast)

        return elixir_code
    end

    """
    Transform Rust AST nodes to Elixir AST nodes.
    """
    function transform_ast(rust_node::RustAST)::ElixirAST
        if rust_node isa RustFunction
            return ElixirFunction(
                name = rust_node.name,
                params = map(transform_param, rust_node.params),
                body = transform_body(rust_node.body)
            )
        elseif rust_node isa RustMatch
            # Rust match -> Elixir case
            return ElixirCase(
                expr = transform_ast(rust_node.expr),
                clauses = map(transform_clause, rust_node.arms)
            )
        else
            # ... handle other node types
        end
    end
end
```

---

### 5. Stripper Module (`src/stripper.jl`)

**Responsibility:** Remove extracted functions from original stlibs

**Inputs:**
- Original `StdLib` structs
- List of extracted `Pattern` structs

**Outputs:**
- Modified stdlib source files with extracted functions removed
- Import statements added to aggregate-library

**Algorithm:**

```julia
module Stripper
    export strip_stdlib, remove_function, add_imports

    """
    Strip extracted patterns from a stdlib.
    """
    function strip_stdlib(stdlib::StdLib, patterns::Vector{Pattern}, output_dir::String)
        # For each module in stdlib
        for (module_path, mod) in stdlib.modules
            # Find functions to remove
            functions_to_remove = find_extracted_functions(mod, patterns)

            if isempty(functions_to_remove)
                # No changes needed, copy as-is
                copy_module(mod, output_dir)
            else
                # Remove functions and add imports
                modified_code = remove_functions(mod, functions_to_remove)
                modified_code = add_aggregate_imports(modified_code, patterns)

                # Write modified module
                write_module(modified_code, output_dir, module_path)
            end
        end
    end

    """
    Remove functions from module source code using AST manipulation.
    """
    function remove_functions(mod::Module, functions::Vector{FunctionSignature})::String
        # Parse module to AST
        ast = parse_module(mod.source_location)

        # Remove function definitions
        for func in functions
            ast = remove_function_def(ast, func)
        end

        # Generate code from modified AST
        code = generate_code(ast)

        return code
    end

    """
    Add import statements for aggregate-library.
    """
    function add_aggregate_imports(code::String, patterns::Vector{Pattern})::String
        imports = String[]

        for pattern in patterns
            module_name = "AggregateLibrary.$(titlecase(pattern.name))"
            push!(imports, "alias $module_name")
        end

        # Insert imports after module definition
        code = insert_imports(code, imports)

        return code
    end
end
```

---

### 6. Reporter Module (`src/reporter.jl`)

**Responsibility:** Generate documentation and reports

**Outputs:**
- `COMPOSITION-GUIDE.md`
- `MIGRATION-GUIDE.md`
- `SIMILARITY-REPORT.md`
- `RANKING-REPORT.md`

```julia
module Reporter
    export generate_composition_guide, generate_migration_guide, generate_reports

    """
    Generate COMPOSITION-GUIDE.md with formula and best-of-breed selection.
    """
    function generate_composition_guide(patterns::Vector{Pattern}, rankings::Vector{Ranking})
        guide = """
        # Aggregate Library Composition Guide

        ## Formula

        aggregate-library = (common elements of phronesis stdlib ∩ Rust stdlib ∩ Haskell stdlib)
                          ∪ (compiler utilities)

        ## Best-of-Breed Selection

        | Pattern | Best From | Why |
        |---------|-----------|-----|
        """

        for ranking in rankings
            guide *= format_ranking_row(ranking)
        end

        # ... add more sections

        write("COMPOSITION-GUIDE.md", guide)
    end

    """
    Generate MIGRATION-GUIDE.md with before/after examples.
    """
    function generate_migration_guide(stdlib::StdLib, patterns::Vector{Pattern})
        guide = """
        # Migration Guide

        This guide shows how to migrate from the original stdlib to aggregate-library.

        ## Before (Original Stdlib)

        ## After (Using aggregate-library)

        ## Import Changes
        """

        # ... generate migration examples

        write("MIGRATION-GUIDE.md", guide)
    end
end
```

---

## Data Flow

```
Input Stlibs
    │
    ▼
┌───────────────────────────────────────────────────┐
│ 1. PARSE                                          │
│                                                   │
│ Phronesis: 42 modules, 180 functions              │
│ Rust:      87 modules, 1200+ functions            │
│ Haskell:   65 modules, 800+ functions             │
└───────────────────┬───────────────────────────────┘
                    │
                    ▼
┌───────────────────────────────────────────────────┐
│ 2. MATCH                                          │
│                                                   │
│ Found 67 potential patterns                       │
│ Matched 42 patterns across all three stlibs       │
│ (25 patterns in only 2 stlibs - excluded)         │
└───────────────────┬───────────────────────────────┘
                    │
                    ▼
┌───────────────────────────────────────────────────┐
│ 3. RANK                                           │
│                                                   │
│ Phronesis best: 18 patterns                       │
│ Rust best:      12 patterns                       │
│ Haskell best:   12 patterns                       │
└───────────────────┬───────────────────────────────┘
                    │
                    ▼
┌───────────────────────────────────────────────────┐
│ 4. EXTRACT                                        │
│                                                   │
│ Generated 42 modules (1200 lines)                 │
│ Translated Rust patterns to Elixir               │
│ Translated Haskell patterns to Elixir            │
│ Copied Phronesis patterns directly               │
└───────────────────┬───────────────────────────────┘
                    │
                    ▼
┌───────────────────────────────────────────────────┐
│ 5. STRIP                                          │
│                                                   │
│ Stripped phronesis stdlib: 42 functions removed   │
│ Stripped rust stdlib:      12 functions removed   │
│ Stripped haskell stdlib:   12 functions removed   │
│ Added aggregate-library imports                   │
└───────────────────┬───────────────────────────────┘
                    │
                    ▼
                Output
      ┌──────────────┴──────────────┐
      │                             │
      ▼                             ▼
aggregate-library/            stripped_stlibs/
├── result.ex                 ├── phronesis/
├── collections.ex            ├── rust/
├── file_io.ex                └── haskell/
└── time.ex
```

---

## Configuration System

```yaml
# config/merger.yaml
quality_criteria:
  api_clarity:
    weight: 0.30
  performance:
    weight: 0.20
  error_handling:
    weight: 0.25
  unicode_support:
    weight: 0.15
  memory_safety:
    weight: 0.05
  composability:
    weight: 0.05

matching:
  name_similarity_threshold: 0.7
  semantic_similarity_threshold: 0.8
  require_all_stlibs: true  # Pattern must exist in ALL stlibs

extraction:
  target_language: elixir
  normalize_api: true
  add_docstrings: true

stripping:
  add_imports: true
  remove_empty_modules: true
  preserve_comments: true
```

---

## External Dependencies

### Julia Packages

```toml
# Project.toml
[deps]
HTTP = "0.9"          # For LLM API calls
JSON3 = "1.13"        # JSON parsing
YAML = "0.4"          # Config files
StringDistances = "0.11"  # Levenshtein distance
TreeSitter = "0.2"    # AST parsing (Rust, Haskell)
MLStyle = "0.4"       # Pattern matching for AST transformation

[compat]
julia = "1.9"
```

### External Services

- **LLM API** (Claude API) - For semantic similarity analysis
- **Tree-sitter grammars** - For parsing Rust and Haskell source

---

## Error Handling

```julia
# Define custom error types
struct ParseError <: Exception
    stdlib::String
    file::String
    message::String
end

struct TranslationError <: Exception
    from_lang::Symbol
    to_lang::Symbol
    function_name::String
    message::String
end

struct QualityError <: Exception
    pattern::String
    message::String
end

# Error recovery strategies
function safe_parse(path::String, lang::Symbol)
    try
        return parse_stdlib(path, lang)
    catch e
        if e isa ParseError
            @warn "Failed to parse $(e.file): $(e.message)"
            # Return partial results
            return StdLib(lang, path, Dict(), [])
        else
            rethrow(e)
        end
    end
end
```

---

## Testing Strategy

```julia
# test/test_parser.jl
@testset "Parser Tests" begin
    # Test Elixir parser
    elixir_stdlib = parse_stdlib("fixtures/elixir_stdlib", :elixir)
    @test length(elixir_stdlib.functions) > 0

    # Test Rust parser
    rust_stdlib = parse_stdlib("fixtures/rust_stdlib", :rust)
    @test length(rust_stdlib.functions) > 0
end

# test/test_matcher.jl
@testset "Matcher Tests" begin
    # Test name clustering
    functions = load_test_functions()
    clusters = cluster_by_name(functions)
    @test length(clusters) > 0

    # Test semantic matching (mock LLM)
    pattern = find_pattern_for_cluster(clusters[1])
    @test pattern.similarity_score > 0.8
end

# test/test_ranker.jl
@testset "Ranker Tests" begin
    # Test quality scoring
    impl = load_test_implementation()
    score = score_implementation(impl, test_pattern)
    @test 0.0 <= score <= 1.0
end

# Integration tests
@testset "End-to-End Tests" begin
    # Run full pipeline on test fixtures
    result = merge_stlibs(
        ["fixtures/elixir_stdlib", "fixtures/rust_stdlib", "fixtures/haskell_stdlib"],
        output_dir = "test_output"
    )

    @test isdir("test_output/aggregate-library")
    @test isfile("test_output/COMPOSITION-GUIDE.md")
end
```

---

## Performance Considerations

### Optimization Strategies

1. **Parallel Processing**
   - Parse stlibs in parallel (one thread per stdlib)
   - Compute similarity scores in parallel (one thread per cluster)

2. **Caching**
   - Cache LLM API responses (semantic similarity scores)
   - Cache parsed ASTs

3. **Incremental Updates**
   - Only re-parse changed files
   - Re-use previous similarity scores when possible

```julia
# Use threads for parallel parsing
function parse_stlibs_parallel(paths::Vector{String}, langs::Vector{Symbol})
    tasks = [@spawn parse_stdlib(path, lang) for (path, lang) in zip(paths, langs)]
    return fetch.(tasks)
end

# Cache LLM responses
const LLM_CACHE = Dict{String, String}()

function call_llm_api_cached(prompt::String)::String
    if haskey(LLM_CACHE, prompt)
        return LLM_CACHE[prompt]
    end

    response = call_llm_api(prompt)
    LLM_CACHE[prompt] = response
    return response
end
```

---

## Extensibility Points

### Adding New Languages

To add support for a new language:

1. Create parser: `src/parsers/newlang_parser.jl`
2. Implement `parse_stdlib(path, :newlang)::StdLib`
3. Add translation: `src/translators/newlang_to_elixir.jl`
4. Update config: `config/languages.yaml`

### Custom Quality Criteria

To add new quality criteria:

1. Define scoring function: `score_new_criterion(impl::FunctionSignature)::Float64`
2. Add to config: `config/merger.yaml`
3. Update `QualityCriteria` struct

### Custom Output Formats

To generate output in different languages:

1. Implement translator: `src/translators/elixir_to_rust.jl`
2. Update extractor: `extract_module(..., target_lang = :rust)`

---

## Summary

**Modular Architecture:**
- Parser → Matcher → Ranker → Extractor → Stripper
- Each component is independent and testable

**Configurable:**
- Quality criteria weights
- Similarity thresholds
- Translation rules

**Extensible:**
- Easy to add new languages
- Custom quality criteria
- Alternative output formats

**Robust:**
- Error handling and recovery
- Comprehensive testing
- Caching for performance

Would you like me to proceed with implementing any specific component?
