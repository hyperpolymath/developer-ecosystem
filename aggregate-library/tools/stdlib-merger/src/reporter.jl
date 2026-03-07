# SPDX-License-Identifier: PMPL-1.0-or-later

"""
Reporter module for generating documentation and reports.
"""
module Reporter

export generate_composition_guide, generate_migration_guide
export generate_similarity_report, generate_ranking_report

include("models.jl")

"""
Generate COMPOSITION-GUIDE.md with formula and best-of-breed selection.
"""
function generate_composition_guide(patterns::Vector{Pattern},
                                   rankings::Vector{Ranking},
                                   output_path::String)
    universal = filter(p -> p.is_universal, patterns)

    content = """
    # Aggregate Library Composition Guide

    **Generated:** $(Dates.now())

    ## Formula

    ```
    aggregate-library = (common elements of phronesis stdlib ∩ Rust stdlib ∩ Haskell stdlib)
                      ∪ (compiler utilities)
    ```

    ## Statistics

    - Total patterns found: $(length(patterns))
    - Universal patterns: $(length(universal))
    - Languages analyzed: $(length(unique(r.best_language for r in rankings)))

    ## Best-of-Breed Selection

    | Pattern | Category | Best From | Score | Justification |
    |---------|----------|-----------|-------|---------------|
    $(join([format_ranking_row(r) for r in rankings], "\n"))

    ## Patterns by Category

    $(generate_category_breakdown(patterns))

    ## Language Distribution

    $(generate_language_distribution(rankings))
    """

    write(output_path, content)
end

"""
Generate MIGRATION-GUIDE.md with before/after examples.
"""
function generate_migration_guide(patterns::Vector{Pattern},
                                 rankings::Vector{Ranking},
                                 output_path::String)
    content = """
    # Migration Guide

    **Generated:** $(Dates.now())

    This guide shows how to migrate from original stlibs to aggregate-library.

    ## Overview

    $(length(patterns)) patterns have been extracted to aggregate-library.

    ## Before (Original Stdlib)

    ```elixir
    # Using individual stdlib functions
    Enum.map([1, 2, 3], fn x -> x * 2 end)
    File.read("file.txt")
    DateTime.utc_now()
    ```

    ## After (Using aggregate-library)

    ```elixir
    # Using aggregate-library
    alias AggregateLibrary.Collections
    alias AggregateLibrary.FileIO
    alias AggregateLibrary.Time

    Collections.map([1, 2, 3], fn x -> x * 2 end)
    FileIO.read("file.txt")
    Time.now()
    ```

    ## Pattern-by-Pattern Migration

    $(generate_pattern_migrations(patterns, rankings))
    """

    write(output_path, content)
end

"""
Generate SIMILARITY-REPORT.md with detailed similarity analysis.
"""
function generate_similarity_report(patterns::Vector{Pattern},
                                   output_path::String)
    content = """
    # Similarity Analysis Report

    **Generated:** $(Dates.now())

    ## Pattern Similarity Scores

    | Pattern | Similarity | Languages | Universal |
    |---------|-----------|-----------|-----------|
    $(join([format_similarity_row(p) for p in patterns], "\n"))

    ## High-Confidence Patterns (>0.9)

    $(generate_high_confidence_patterns(patterns))

    ## Medium-Confidence Patterns (0.7-0.9)

    $(generate_medium_confidence_patterns(patterns))
    """

    write(output_path, content)
end

"""
Generate RANKING-REPORT.md with detailed quality scores.
"""
function generate_ranking_report(rankings::Vector{Ranking},
                                output_path::String)
    content = """
    # Quality Ranking Report

    **Generated:** $(Dates.now())

    ## Overall Rankings

    | Pattern | Best | Score | Runners-up |
    |---------|------|-------|------------|
    $(join([format_full_ranking_row(r) for r in rankings], "\n"))

    ## Detailed Scores by Criterion

    $(generate_detailed_scores(rankings))
    """

    write(output_path, content)
end

# ============================================================================
# Helper Functions
# ============================================================================

function format_ranking_row(ranking::Ranking)::String
    pattern = ranking.pattern
    score = round(ranking.scores[ranking.best_language], digits=2)
    justification = replace(ranking.justification, ";" => ",")

    return "| $(pattern.name) | $(pattern.category) | $(ranking.best_language) | $score | $justification |"
end

function format_similarity_row(pattern::Pattern)::String
    score = round(pattern.similarity_score, digits=2)
    langs = join(keys(pattern.implementations), ", ")
    universal = pattern.is_universal ? "✓" : ""

    return "| $(pattern.name) | $score | $langs | $universal |"
end

function format_full_ranking_row(ranking::Ranking)::String
    best_score = round(ranking.scores[ranking.best_language], digits=2)

    # Find runners-up
    sorted_langs = sort(collect(keys(ranking.scores)),
                       by = l -> ranking.scores[l],
                       rev = true)
    runners_up = join(sorted_langs[2:end], ", ")

    return "| $(ranking.pattern.name) | $(ranking.best_language) | $best_score | $runners_up |"
end

function generate_category_breakdown(patterns::Vector{Pattern})::String
    by_category = Dict{String, Int}()

    for pattern in patterns
        cat = pattern.category
        by_category[cat] = get(by_category, cat, 0) + 1
    end

    rows = ["| Category | Count |\n|----------|-------|"]
    for (cat, count) in sort(collect(by_category), by = x -> x[2], rev = true)
        push!(rows, "| $cat | $count |")
    end

    return join(rows, "\n")
end

function generate_language_distribution(rankings::Vector{Ranking})::String
    lang_counts = Dict{Symbol, Int}()

    for ranking in rankings
        lang = ranking.best_language
        lang_counts[lang] = get(lang_counts, lang, 0) + 1
    end

    rows = ["| Language | Best Implementations |\n|----------|---------------------|"]
    for (lang, count) in sort(collect(lang_counts), by = x -> x[2], rev = true)
        push!(rows, "| $lang | $count |")
    end

    return join(rows, "\n")
end

function generate_pattern_migrations(patterns::Vector{Pattern},
                                    rankings::Vector{Ranking})::String
    sections = String[]

    for (pattern, ranking) in zip(patterns[1:min(10, end)], rankings[1:min(10, end)])
        impl = ranking.best_implementation

        section = """
        ### $(pattern.name)

        **Best implementation:** $(ranking.best_language)

        Before:
        ```
        $(full_name(impl))(...)
        ```

        After:
        ```
        AggregateLibrary.$(titlecase(pattern.name)).$(impl.name)(...)
        ```
        """

        push!(sections, section)
    end

    return join(sections, "\n\n")
end

function generate_high_confidence_patterns(patterns::Vector{Pattern})::String
    high_conf = filter(p -> p.similarity_score > 0.9, patterns)

    if isempty(high_conf)
        return "None found."
    end

    return join(["- $(p.name) ($(round(p.similarity_score, digits=2)))" for p in high_conf], "\n")
end

function generate_medium_confidence_patterns(patterns::Vector{Pattern})::String
    med_conf = filter(p -> 0.7 <= p.similarity_score <= 0.9, patterns)

    if isempty(med_conf)
        return "None found."
    end

    return join(["- $(p.name) ($(round(p.similarity_score, digits=2)))" for p in med_conf], "\n")
end

function generate_detailed_scores(rankings::Vector{Ranking})::String
    # TODO: Implement detailed criterion-by-criterion breakdown
    return "Detailed scores coming soon..."
end

end # module Reporter
