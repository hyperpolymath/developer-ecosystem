# SPDX-License-Identifier: PMPL-1.0-or-later

"""
Pipeline orchestrator for stdlib-merger.

Coordinates the complete merge pipeline: parse → match → rank → extract → strip → report
"""
module Orchestrator

using YAML
using ProgressMeter

export run_pipeline

include("models.jl")
include("parser.jl")
include("matcher.jl")
include("ranker.jl")
include("extractor.jl")
include("stripper.jl")
include("reporter.jl")

"""
    run_pipeline(stdlib_paths, output_dir, config_path)

Run the complete merge pipeline.

# Arguments
- `stdlib_paths::Dict{Symbol, String}` - Language => path mappings
- `output_dir::String` - Output directory for aggregate-library
- `config_path::String` - Path to configuration YAML

# Returns
- `MergeResult` - Complete pipeline results
"""
function run_pipeline(stdlib_paths::Dict{Symbol, String},
                     output_dir::String,
                     config_path::String)::MergeResult

    println("🚀 stdlib-merger pipeline starting...")
    println()

    # Load configuration
    config = load_config(config_path)

    # Step 1: Parse stlibs
    println("📖 Step 1/6: Parsing stlibs...")
    stlibs = parse_stlibs(stdlib_paths, config)
    println("   ✓ Parsed $(length(stlibs)) stlibs")
    println()

    # Step 2: Find common patterns
    println("🔍 Step 2/6: Finding common patterns...")
    patterns = Matcher.find_patterns(stlibs, config)
    universal_patterns = filter(p -> p.is_universal, patterns)
    println("   ✓ Found $(length(patterns)) patterns ($(length(universal_patterns)) universal)")
    println()

    # Step 3: Rank implementations
    println("📈 Step 3/6: Ranking implementations...")
    rankings = rank_patterns(patterns, config)
    println("   ✓ Ranked $(length(rankings)) patterns")
    print_ranking_summary(rankings)
    println()

    # Step 4: Extract to aggregate-library
    println("🔧 Step 4/6: Extracting to aggregate-library...")
    extracted_modules = extract_modules(rankings, output_dir, config)
    println("   ✓ Generated $(length(extracted_modules)) modules")
    println()

    # Step 5: Strip from original stlibs
    println("✂️  Step 5/6: Stripping original stlibs...")
    stripped_stlibs = strip_stlibs(stlibs, patterns, output_dir, config)
    println("   ✓ Stripped $(length(stripped_stlibs)) stlibs")
    println()

    # Step 6: Generate reports
    println("📝 Step 6/6: Generating reports...")
    reports = generate_reports(patterns, rankings, output_dir, config)
    println("   ✓ Generated $(length(reports)) reports")
    println()

    # Collect statistics
    statistics = Dict{String, Any}(
        "total_patterns" => length(patterns),
        "universal_patterns" => length(universal_patterns),
        "stlibs_parsed" => length(stlibs),
        "modules_generated" => length(extracted_modules),
        "total_lines" => sum(length(split(m.code, "\n")) for m in extracted_modules)
    )

    result = MergeResult(
        patterns,
        rankings,
        extracted_modules,
        stripped_stlibs,
        reports,
        statistics
    )

    println("✅ Pipeline complete!")
    println()
    print_final_summary(result)

    return result
end

"""
Parse all stlibs in parallel.
"""
function parse_stlibs(stdlib_paths::Dict{Symbol, String}, config::MergerConfig)::Vector{StdLib}
    stlibs = StdLib[]

    if config.parallel
        # Parse in parallel
        tasks = [@spawn Parser.parse_stdlib(path, lang) for (lang, path) in stdlib_paths]
        stlibs = fetch.(tasks)
    else
        # Parse sequentially
        for (lang, path) in stdlib_paths
            stdlib = Parser.parse_stdlib(path, lang)
            push!(stlibs, stdlib)
        end
    end

    return stlibs
end

"""
Rank all patterns.
"""
function rank_patterns(patterns::Vector{Pattern}, config::MergerConfig)::Vector{Ranking}
    rankings = Ranking[]

    @showprogress "Ranking patterns..." for pattern in patterns
        ranking = Ranker.rank_implementations(pattern, config.quality_criteria)
        push!(rankings, ranking)
    end

    return rankings
end

"""
Extract all modules to aggregate-library.
"""
function extract_modules(rankings::Vector{Ranking},
                        output_dir::String,
                        config::MergerConfig)::Vector{ExtractedModule}
    modules = ExtractedModule[]

    mkpath(output_dir)

    @showprogress "Extracting modules..." for ranking in rankings
        module_result = Extractor.extract_module(ranking, output_dir, config.extraction)
        push!(modules, module_result)
    end

    return modules
end

"""
Strip extracted functions from original stlibs.
"""
function strip_stlibs(stlibs::Vector{StdLib},
                     patterns::Vector{Pattern},
                     output_dir::String,
                     config::MergerConfig)::Vector{StrippedStdLib}
    stripped = StrippedStdLib[]

    for stdlib in stlibs
        stripped_dir = joinpath(output_dir, "stripped_stlibs", String(stdlib.language))
        result = Stripper.strip_stdlib(stdlib, patterns, stripped_dir, config)
        push!(stripped, result)
    end

    return stripped
end

"""
Generate all reports.
"""
function generate_reports(patterns::Vector{Pattern},
                         rankings::Vector{Ranking},
                         output_dir::String,
                         config::MergerConfig)::Dict{String, String}
    reports = Dict{String, String}()

    if !config.output.generate_reports
        return reports
    end

    # Composition guide
    composition_path = joinpath(output_dir, "COMPOSITION-GUIDE.md")
    Reporter.generate_composition_guide(patterns, rankings, composition_path)
    reports["composition_guide"] = composition_path

    # Migration guide
    migration_path = joinpath(output_dir, "MIGRATION-GUIDE.md")
    Reporter.generate_migration_guide(patterns, rankings, migration_path)
    reports["migration_guide"] = migration_path

    # Similarity report
    similarity_path = joinpath(output_dir, "SIMILARITY-REPORT.md")
    Reporter.generate_similarity_report(patterns, similarity_path)
    reports["similarity_report"] = similarity_path

    # Ranking report
    ranking_path = joinpath(output_dir, "RANKING-REPORT.md")
    Reporter.generate_ranking_report(rankings, ranking_path)
    reports["ranking_report"] = ranking_path

    return reports
end

"""
Load configuration from YAML file.
"""
function load_config(config_path::String)::MergerConfig
    data = YAML.load_file(config_path)

    # Parse quality criteria
    criteria_data = data["quality_criteria"]
    quality_criteria = QualityCriteria(
        Criterion(criteria_data["api_clarity"]["weight"], Ranker.score_api_clarity),
        Criterion(criteria_data["performance"]["weight"], Ranker.score_performance),
        Criterion(criteria_data["error_handling"]["weight"], Ranker.score_error_handling),
        Criterion(criteria_data["unicode_support"]["weight"], Ranker.score_unicode_support),
        Criterion(criteria_data["memory_safety"]["weight"], Ranker.score_memory_safety),
        Criterion(criteria_data["composability"]["weight"], Ranker.score_composability)
    )

    # Parse matching config
    matching_data = data["matching"]
    matching = MatchingConfig(
        matching_data["name_similarity_threshold"],
        matching_data["semantic_similarity_threshold"],
        matching_data["require_all_stlibs"]
    )

    # Parse extraction config
    extraction_data = data["extraction"]
    extraction = ExtractionConfig(
        Symbol(extraction_data["target_language"]),
        extraction_data["normalize_api"],
        extraction_data["add_docstrings"],
        extraction_data["preserve_comments"]
    )

    # Parse LLM config
    llm_data = data["llm"]
    llm = LLMConfig(
        llm_data["provider"],
        llm_data["model"],
        llm_data["api_key_env"],
        get(llm_data, "max_retries", 3),
        get(llm_data, "timeout_seconds", 30)
    )

    # Parse performance config
    perf_data = get(data, "performance", Dict())
    parallel = get(perf_data, "parallel", true)
    cache_dir = get(perf_data, "cache_dir", "/tmp/stdlib-merger-cache")

    # Parse output config
    output_data = get(data, "output", Dict())

    return MergerConfig(
        quality_criteria,
        matching,
        extraction,
        llm,
        cache_dir,
        parallel
    )
end

"""
Print ranking summary (best implementation per language).
"""
function print_ranking_summary(rankings::Vector{Ranking})
    lang_counts = Dict{Symbol, Int}()

    for ranking in rankings
        lang = ranking.best_language
        lang_counts[lang] = get(lang_counts, lang, 0) + 1
    end

    println("   Best implementations by language:")
    for (lang, count) in sort(collect(lang_counts), by = x -> x[2], rev = true)
        println("      $lang: $count patterns")
    end
end

"""
Print final summary of merge results.
"""
function print_final_summary(result::MergeResult)
    println("📊 Summary:")
    println("   Total patterns: $(result.statistics["total_patterns"])")
    println("   Universal patterns: $(result.statistics["universal_patterns"])")
    println("   Modules generated: $(result.statistics["modules_generated"])")
    println("   Total lines: $(result.statistics["total_lines"])")
    println()
    println("📁 Output:")
    for (name, path) in result.reports
        println("   $name: $path")
    end
end

end # module Orchestrator
