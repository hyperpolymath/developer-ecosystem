# SPDX-License-Identifier: PMPL-1.0-or-later

"""
Data structures used throughout stdlib-merger.
"""

# ============================================================================
# Core Data Structures
# ============================================================================

"""
    SourceLocation

Location in source code (file path, line number, column).
"""
struct SourceLocation
    file::String
    line::Int
    column::Int
    end_line::Int
    end_column::Int
end

SourceLocation(file::String, line::Int, column::Int) =
    SourceLocation(file, line, column, line, column)

"""
    Type

Represents a type in any language (with optional type parameters).
"""
struct Type
    name::String
    params::Vector{Type}  # For generic types: List<String> -> Type("List", [Type("String")])
end

Type(name::String) = Type(name, Type[])

"""
    Param

Function parameter with name, type, and optional default value.
"""
struct Param
    name::String
    type::Type
    default::Union{Nothing, Any}
end

Param(name::String, type::Type) = Param(name, type, nothing)

"""
    FunctionSignature

Represents a function signature extracted from source code.
"""
struct FunctionSignature
    name::String
    module_path::String
    params::Vector{Param}
    return_type::Type
    docstring::String
    examples::Vector{String}
    source_location::SourceLocation
    metadata::Dict{String, Any}  # Language-specific metadata
end

function FunctionSignature(name::String, module_path::String, params::Vector{Param}, return_type::Type)
    FunctionSignature(
        name,
        module_path,
        params,
        return_type,
        "",  # docstring
        String[],  # examples
        SourceLocation("", 0, 0),  # source_location
        Dict{String, Any}()  # metadata
    )
end

"""
    Module

Represents a module in a stdlib (collection of functions).
"""
struct Module
    name::String
    path::String
    functions::Vector{FunctionSignature}
    submodules::Vector{Module}
    docstring::String
    source_location::SourceLocation
end

Module(name::String, path::String) =
    Module(name, path, FunctionSignature[], Module[], "", SourceLocation("", 0, 0))

"""
    StdLib

Represents a complete standard library for a language.
"""
struct StdLib
    language::Symbol  # :elixir, :rust, :haskell
    path::String
    modules::Dict{String, Module}
    functions::Vector{FunctionSignature}  # All functions across all modules
    metadata::Dict{String, Any}
end

StdLib(language::Symbol, path::String) =
    StdLib(language, path, Dict{String, Module}(), FunctionSignature[], Dict{String, Any}())

# ============================================================================
# Pattern Matching Data Structures
# ============================================================================

"""
    Cluster

Group of functions with similar names (intermediate result in matching).
"""
struct Cluster
    functions::Vector{FunctionSignature}
    centroid_name::String
    avg_distance::Float64
end

"""
    Pattern

Represents a common operation found across multiple stlibs.
"""
struct Pattern
    id::String
    name::String  # e.g., "string_split"
    implementations::Dict{Symbol, FunctionSignature}  # :elixir => func, :rust => func
    similarity_score::Float64
    is_universal::Bool  # true if exists in ALL stlibs
    category::String  # e.g., "string", "collection", "file_io", "time"
    metadata::Dict{String, Any}
end

function Pattern(id::String, name::String, implementations::Dict{Symbol, FunctionSignature}, similarity_score::Float64)
    Pattern(
        id,
        name,
        implementations,
        similarity_score,
        length(implementations) >= 3,  # Universal if in all 3+ stlibs
        "uncategorized",
        Dict{String, Any}()
    )
end

# ============================================================================
# Ranking Data Structures
# ============================================================================

"""
    Criterion

A single quality criterion with its weight and scoring function.
"""
struct Criterion
    weight::Float64  # 0.0 - 1.0
    scoring_method::Function  # FunctionSignature -> Float64
end

"""
    QualityCriteria

Collection of all quality criteria used for ranking.
"""
struct QualityCriteria
    api_clarity::Criterion
    performance::Criterion
    error_handling::Criterion
    unicode_support::Criterion
    memory_safety::Criterion
    composability::Criterion
end

"""
    Ranking

Result of ranking all implementations for a pattern.
"""
struct Ranking
    pattern::Pattern
    scores::Dict{Symbol, Float64}  # :elixir => 8.5, :rust => 7.8
    best_language::Symbol
    best_implementation::FunctionSignature
    justification::String  # Why this implementation was chosen
end

# ============================================================================
# Output Data Structures
# ============================================================================

"""
    Translation

Represents code translated from one language to another.
"""
struct Translation
    source_language::Symbol
    target_language::Symbol
    source_code::String
    target_code::String
    confidence::Float64  # 0.0 - 1.0
    warnings::Vector{String}
end

"""
    ExtractedModule

Module extracted to aggregate-library.
"""
struct ExtractedModule
    pattern::Pattern
    ranking::Ranking
    translation::Union{Nothing, Translation}
    output_path::String
    code::String
end

"""
    StrippedStdLib

Original stdlib with extracted functions removed.
"""
struct StrippedStdLib
    original::StdLib
    removed_functions::Vector{FunctionSignature}
    added_imports::Vector{String}
    output_path::String
end

"""
    MergeResult

Complete result of running the merge pipeline.
"""
struct MergeResult
    patterns::Vector{Pattern}
    rankings::Vector{Ranking}
    extracted_modules::Vector{ExtractedModule}
    stripped_stlibs::Vector{StrippedStdLib}
    reports::Dict{String, String}  # report_name => file_path
    statistics::Dict{String, Any}
end

# ============================================================================
# Configuration Data Structures
# ============================================================================

"""
    MatchingConfig

Configuration for pattern matching.
"""
struct MatchingConfig
    name_similarity_threshold::Float64
    semantic_similarity_threshold::Float64
    require_all_stlibs::Bool
end

"""
    ExtractionConfig

Configuration for code extraction.
"""
struct ExtractionConfig
    target_language::Symbol
    normalize_api::Bool
    add_docstrings::Bool
    preserve_comments::Bool
end

"""
    LLMConfig

Configuration for LLM API calls.
"""
struct LLMConfig
    provider::String  # "anthropic", "openai", etc.
    model::String
    api_key_env::String
    max_retries::Int
    timeout_seconds::Int
end

"""
    OutputConfig

Configuration for output generation.
"""
struct OutputConfig
    generate_reports::Bool
    verbose::Bool
    dry_run::Bool
end

"""
    MergerConfig

Complete configuration for stdlib-merger.
"""
struct MergerConfig
    quality_criteria::QualityCriteria
    matching::MatchingConfig
    extraction::ExtractionConfig
    llm::LLMConfig
    output::OutputConfig
    cache_dir::String
    parallel::Bool
end

# ============================================================================
# Helper Functions
# ============================================================================

"""
    format_signature(func::FunctionSignature)::String

Format a function signature as a readable string.
"""
function format_signature(func::FunctionSignature)::String
    params_str = join(["$(p.name): $(p.type.name)" for p in func.params], ", ")
    return "$(func.name)($(params_str)) -> $(func.return_type.name)"
end

"""
    full_name(func::FunctionSignature)::String

Get the fully qualified name of a function.
"""
function full_name(func::FunctionSignature)::String
    return "$(func.module_path).$(func.name)"
end

"""
    is_result_type(t::Type)::Bool

Check if a type represents a Result/Either pattern.
"""
function is_result_type(t::Type)::Bool
    return t.name in ["Result", "Either", "{:ok, val} | {:error, reason}"]
end

"""
    is_maybe_type(t::Type)::Bool

Check if a type represents a Maybe/Option pattern.
"""
function is_maybe_type(t::Type)::Bool
    return t.name in ["Maybe", "Option", "nil"]
end

# ============================================================================
# Display Methods
# ============================================================================

Base.show(io::IO, loc::SourceLocation) =
    print(io, "$(loc.file):$(loc.line):$(loc.column)")

Base.show(io::IO, t::Type) =
    print(io, t.name, isempty(t.params) ? "" : "<$(join(t.params, ", "))>")

Base.show(io::IO, p::Param) =
    print(io, "$(p.name): $(p.type)", p.default === nothing ? "" : " = $(p.default)")

Base.show(io::IO, func::FunctionSignature) =
    print(io, format_signature(func))

Base.show(io::IO, pattern::Pattern) =
    print(io, "Pattern($(pattern.name), $(length(pattern.implementations)) impls, score=$(pattern.similarity_score))")

Base.show(io::IO, ranking::Ranking) =
    print(io, "Ranking($(ranking.pattern.name), best=$(ranking.best_language))")
