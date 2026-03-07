# SPDX-License-Identifier: PMPL-1.0-or-later

"""
Ranker module for scoring implementations and choosing the best.
"""
module Ranker

export rank_implementations
export score_api_clarity, score_performance, score_error_handling
export score_unicode_support, score_memory_safety, score_composability

include("models.jl")

"""
    rank_implementations(pattern::Pattern, criteria::QualityCriteria)::Ranking

Rank all implementations for a pattern and choose the best.

# Arguments
- `pattern::Pattern` - Pattern with multiple implementations
- `criteria::QualityCriteria` - Quality criteria with weights

# Returns
- `Ranking` - Ranked implementations with best chosen
"""
function rank_implementations(pattern::Pattern,
                             criteria::QualityCriteria)::Ranking
    scores = Dict{Symbol, Float64}()

    for (lang, impl) in pattern.implementations
        score = score_implementation(impl, pattern, criteria)
        scores[lang] = score
    end

    # Choose best implementation
    best_lang = argmax(scores)
    best_impl = pattern.implementations[best_lang]

    # Generate justification
    justification = generate_justification(best_lang, best_impl, scores, criteria)

    return Ranking(
        pattern,
        scores,
        best_lang,
        best_impl,
        justification
    )
end

"""
Score a single implementation based on quality criteria.
"""
function score_implementation(impl::FunctionSignature,
                             pattern::Pattern,
                             criteria::QualityCriteria)::Float64
    scores = [
        criteria.api_clarity.scoring_method(impl) * criteria.api_clarity.weight,
        criteria.performance.scoring_method(impl) * criteria.performance.weight,
        criteria.error_handling.scoring_method(impl) * criteria.error_handling.weight,
        criteria.unicode_support.scoring_method(impl) * criteria.unicode_support.weight,
        criteria.memory_safety.scoring_method(impl) * criteria.memory_safety.weight,
        criteria.composability.scoring_method(impl) * criteria.composability.weight
    ]

    # Normalize by total weight
    total_weight = criteria.api_clarity.weight +
                  criteria.performance.weight +
                  criteria.error_handling.weight +
                  criteria.unicode_support.weight +
                  criteria.memory_safety.weight +
                  criteria.composability.weight

    return sum(scores) / total_weight
end

# ============================================================================
# Scoring Functions
# ============================================================================

"""
Score API clarity (how clear and intuitive is the API?).
"""
function score_api_clarity(impl::FunctionSignature)::Float64
    score = 0.0

    # Function name clarity (shorter, clearer names score higher)
    name_len = length(impl.name)
    if name_len < 10
        score += 0.3
    elseif name_len < 20
        score += 0.2
    else
        score += 0.1
    end

    # Parameter naming (clear parameter names)
    if all(p -> length(p.name) > 1 && !occursin(r"^_", p.name), impl.params)
        score += 0.2
    end

    # Documentation quality
    if length(impl.docstring) > 50
        score += 0.3
    elseif length(impl.docstring) > 0
        score += 0.1
    end

    # Has examples
    if !isempty(impl.examples)
        score += 0.2
    end

    return min(1.0, score)
end

"""
Score performance (based on language and implementation patterns).
"""
function score_performance(impl::FunctionSignature)::Float64
    lang = impl.metadata["language"]

    # Language-based performance scores (rough approximation)
    if lang == :rust
        return 0.9  # Rust generally fastest
    elseif lang == :elixir
        return 0.7  # Elixir good performance (BEAM VM)
    elseif lang == :haskell
        return 0.6  # Haskell can be fast but depends on GHC optimization
    else
        return 0.5
    end
end

"""
Score error handling (how well does it handle errors?).
"""
function score_error_handling(impl::FunctionSignature)::Float64
    return_type = impl.return_type

    # Result/Either pattern: 1.0
    if is_result_type(return_type)
        return 1.0
    end

    # Maybe/Option pattern: 0.7
    if is_maybe_type(return_type)
        return 0.7
    end

    # Check docstring for exception mentions
    if occursin(r"(raises?|throws?|error)", lowercase(impl.docstring))
        return 0.3  # Throws exceptions
    end

    # No error handling visible: 0.5
    return 0.5
end

"""
Score Unicode support (for string operations).
"""
function score_unicode_support(impl::FunctionSignature)::Float64
    lang = impl.metadata["language"]

    # Check if function name suggests string operation
    name_lower = lowercase(impl.name)
    is_string_op = occursin(r"(string|str|text|char|split|trim|upper|lower)", name_lower)

    if !is_string_op
        return 0.5  # Not applicable, neutral score
    end

    # Language-based Unicode support
    if lang == :elixir
        return 1.0  # Elixir has excellent Unicode support (UTF-8 native)
    elseif lang == :rust
        return 0.8  # Rust has good Unicode support (String is UTF-8)
    elseif lang == :haskell
        return 0.9  # Haskell Text library has good Unicode support
    else
        return 0.5
    end
end

"""
Score memory safety (does it prevent common bugs?).
"""
function score_memory_safety(impl::FunctionSignature)::Float64
    lang = impl.metadata["language"]

    # Language-based memory safety scores
    if lang == :rust
        return 1.0  # Rust has compile-time memory safety
    elseif lang == :elixir
        return 0.9  # Elixir/BEAM has runtime memory safety (no manual memory management)
    elseif lang == :haskell
        return 0.9  # Haskell has garbage collection
    else
        return 0.5
    end
end

"""
Score composability (can it be easily composed with other functions?).
"""
function score_composability(impl::FunctionSignature)::Float64
    score = 0.0

    # Point-free style (currying) - check if language supports it
    lang = impl.metadata["language"]
    if lang == :haskell
        score += 0.5  # Haskell is most composable (point-free by default)
    elseif lang == :elixir
        score += 0.3  # Elixir has pipe operator
    elseif lang == :rust
        score += 0.2  # Rust has closures and method chaining
    end

    # Return type is composable (not void/unit)
    if impl.return_type.name != "unit" && impl.return_type.name != "void"
        score += 0.3
    end

    # Number of parameters (fewer is more composable)
    if length(impl.params) <= 2
        score += 0.2
    end

    return min(1.0, score)
end

# ============================================================================
# Helper Functions
# ============================================================================

"""
Generate human-readable justification for choosing best implementation.
"""
function generate_justification(best_lang::Symbol,
                               best_impl::FunctionSignature,
                               scores::Dict{Symbol, Float64},
                               criteria::QualityCriteria)::String
    reasons = String[]

    # Compare best to others
    for (lang, score) in scores
        if lang != best_lang && score < scores[best_lang]
            diff = scores[best_lang] - score
            push!(reasons, "$lang score: $(round(score, digits=2)) (-$(round(diff, digits=2)))")
        end
    end

    # Identify strongest criteria
    lang = best_impl.metadata["language"]

    # API clarity
    api_score = score_api_clarity(best_impl)
    if api_score > 0.8
        push!(reasons, "Excellent API clarity ($(round(api_score, digits=2)))")
    end

    # Error handling
    error_score = score_error_handling(best_impl)
    if error_score >= 1.0
        push!(reasons, "Explicit error handling (Result/Either type)")
    elseif error_score >= 0.7
        push!(reasons, "Good error handling (Maybe/Option type)")
    end

    # Unicode support
    unicode_score = score_unicode_support(best_impl)
    if unicode_score >= 0.9
        push!(reasons, "Excellent Unicode support")
    end

    # Performance
    perf_score = score_performance(best_impl)
    if perf_score >= 0.9
        push!(reasons, "High performance")
    end

    # Composability
    comp_score = score_composability(best_impl)
    if comp_score >= 0.7
        push!(reasons, "Highly composable")
    end

    return join(reasons, "; ")
end

end # module Ranker
