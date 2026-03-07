#!/usr/bin/env julia
# SPDX-License-Identifier: PMPL-1.0-or-later

"""
CLI for stdlib-merger tool.

Usage:
    julia cli.jl merge --stdlib phronesis:/path/to/stdlib --stdlib rust:/path/to/std --output aggregate-library-auto
    julia cli.jl analyze --stdlib phronesis:/path/to/stdlib --stdlib rust:/path/to/std
    julia cli.jl rank --stdlib phronesis:/path/to/stdlib --pattern string_split
"""

using ArgParse
using YAML

# Add src/ to load path
push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using StdlibMerger

# ============================================================================
# Argument Parsing
# ============================================================================

function parse_commandline()
    s = ArgParseSettings(
        prog = "stdlib-merger",
        description = "Automated tool for extracting common patterns from multiple language stlibs",
        version = "0.1.0"
    )

    @add_arg_table! s begin
        "merge"
            help = "Merge multiple stlibs into aggregate-library"
            action = :command

        "analyze"
            help = "Analyze stlibs without merging (dry run)"
            action = :command

        "rank"
            help = "Show quality rankings for matched patterns"
            action = :command

        "extract"
            help = "Extract specific patterns (without full merge)"
            action = :command

        "strip"
            help = "Strip extracted patterns from a stdlib"
            action = :command

        "report"
            help = "Generate reports from previous merge"
            action = :command
    end

    # Common arguments for all commands
    for cmd in ["merge", "analyze", "rank", "extract"]
        @add_arg_table! s[cmd] begin
            "--stdlib", "-s"
                help = "Stdlib path in format lang:/path (can be specified multiple times)"
                action = :append_arg
                required = true
            "--config", "-c"
                help = "Path to configuration YAML file"
                default = joinpath(@__DIR__, "config", "merger.yaml")
        end
    end

    # Command-specific arguments
    @add_arg_table! s["merge"] begin
        "--output", "-o"
            help = "Output directory for aggregate-library"
            default = "aggregate-library-auto"
    end

    @add_arg_table! s["rank"] begin
        "--pattern", "-p"
            help = "Pattern name to rank (e.g., string_split)"
            required = true
    end

    @add_arg_table! s["extract"] begin
        "--pattern", "-p"
            help = "Comma-separated list of patterns to extract"
            required = true
        "--output", "-o"
            help = "Output directory"
            default = "extracted"
    end

    @add_arg_table! s["strip"] begin
        "--stdlib", "-s"
            help = "Stdlib path to strip"
            required = true
        "--patterns"
            help = "Path to patterns JSON file"
            required = true
        "--output", "-o"
            help = "Output directory"
            required = true
    end

    @add_arg_table! s["report"] begin
        "--results"
            help = "Path to results JSON from previous merge"
            required = true
        "--output", "-o"
            help = "Output directory for reports"
            default = "reports"
    end

    return parse_args(s)
end

# ============================================================================
# Command Handlers
# ============================================================================

function handle_merge(args)
    println("🔧 stdlib-merger: merge")
    println()

    # Parse stdlib paths
    stdlib_paths = parse_stdlib_args(args["stdlib"])
    output_dir = args["output"]
    config_path = args["config"]

    println("📋 Configuration:")
    println("   Stlibs: $(length(stdlib_paths))")
    for (lang, path) in stdlib_paths
        println("     - $lang: $path")
    end
    println("   Output: $output_dir")
    println("   Config: $config_path")
    println()

    # Run merge
    result = merge_stlibs(stdlib_paths; output_dir = output_dir, config_path = config_path)

    println()
    println("✅ Merge complete!")
    println("   Patterns: $(length(result.patterns))")
    println("   Modules: $(length(result.extracted_modules))")
    println("   Output: $output_dir")
end

function handle_analyze(args)
    println("📊 stdlib-merger: analyze")
    println()

    # Parse stdlib paths
    stdlib_paths = parse_stdlib_args(args["stdlib"])

    println("Analyzing $(length(stdlib_paths)) stlibs...")
    println()

    # Parse each stdlib
    stlibs = []
    for (lang, path) in stdlib_paths
        println("📖 Parsing $lang stdlib...")
        stdlib = parse_stdlib(path, lang)
        push!(stlibs, stdlib)

        println("   - $(length(stdlib.modules)) modules")
        println("   - $(length(stdlib.functions)) functions")
    end

    println()
    println("🔍 Finding common patterns...")
    patterns = find_patterns(stlibs)

    universal_patterns = filter(p -> p.is_universal, patterns)

    println()
    println("📊 Analysis Results:")
    println("   Total patterns: $(length(patterns))")
    println("   Universal patterns: $(length(universal_patterns))")
    println()

    # Show top 10 patterns
    println("Top 10 Universal Patterns:")
    for (i, pattern) in enumerate(sort(universal_patterns, by = p -> p.similarity_score, rev = true)[1:min(10, end)])
        println("   $i. $(pattern.name) (score: $(round(pattern.similarity_score, digits=2)))")
    end
end

function handle_rank(args)
    println("📈 stdlib-merger: rank")
    println()

    stdlib_paths = parse_stdlib_args(args["stdlib"])
    pattern_name = args["pattern"]

    # Parse stlibs
    stlibs = [parse_stdlib(path, lang) for (lang, path) in stdlib_paths]

    # Find patterns
    patterns = find_patterns(stlibs)

    # Find the requested pattern
    pattern = findfirst(p -> p.name == pattern_name, patterns)
    if pattern === nothing
        println("❌ Pattern '$pattern_name' not found")
        exit(1)
    end

    # Rank implementations
    ranking = rank_implementations(pattern)

    # Display results
    println("Pattern: $(pattern.name)")
    println()
    println("Implementations:")

    sorted_langs = sort(collect(keys(ranking.scores)), by = lang -> ranking.scores[lang], rev = true)

    for (i, lang) in enumerate(sorted_langs)
        score = ranking.scores[lang]
        impl = pattern.implementations[lang]
        is_best = (lang == ranking.best_language)

        println("   $i. $lang: $(impl.name)  Score: $(round(score, digits=2)) $(is_best ? "⭐" : "")")
    end

    println()
    println("Best: $(ranking.best_language)")
    println("Justification: $(ranking.justification)")
end

function handle_extract(args)
    println("✂️  stdlib-merger: extract")
    println()

    # TODO: Implement extract command
    println("Not yet implemented")
end

function handle_strip(args)
    println("🗑️  stdlib-merger: strip")
    println()

    # TODO: Implement strip command
    println("Not yet implemented")
end

function handle_report(args)
    println("📝 stdlib-merger: report")
    println()

    # TODO: Implement report command
    println("Not yet implemented")
end

# ============================================================================
# Helper Functions
# ============================================================================

"""
Parse stdlib arguments in format "lang:/path/to/stdlib"
Returns Dict{Symbol, String}
"""
function parse_stdlib_args(args::Vector{String})::Dict{Symbol, String}
    result = Dict{Symbol, String}()

    for arg in args
        parts = split(arg, ":")
        if length(parts) != 2
            error("Invalid stdlib format: $arg (expected lang:/path)")
        end

        lang = Symbol(parts[1])
        path = parts[2]

        result[lang] = path
    end

    return result
end

# ============================================================================
# Main
# ============================================================================

function main()
    args = parse_commandline()

    # Determine which command was called
    cmd = args["%COMMAND%"]

    if cmd == "merge"
        handle_merge(args[cmd])
    elseif cmd == "analyze"
        handle_analyze(args[cmd])
    elseif cmd == "rank"
        handle_rank(args[cmd])
    elseif cmd == "extract"
        handle_extract(args[cmd])
    elseif cmd == "strip"
        handle_strip(args[cmd])
    elseif cmd == "report"
        handle_report(args[cmd])
    else
        println("Unknown command: $cmd")
        exit(1)
    end
end

# Run main if executed as script
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
