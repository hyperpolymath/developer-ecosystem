# SPDX-License-Identifier: PMPL-1.0-or-later

"""
    StdlibMerger

Automated tool for extracting common patterns from multiple language standard libraries
and creating a merged aggregate-library with best-of-breed implementations.

# Examples

```julia
using StdlibMerger

# Parse stlibs
phronesis = parse_stdlib("/path/to/phronesis/stdlib", :elixir)
rust = parse_stdlib("/path/to/rust/std", :rust)
haskell = parse_stdlib("/path/to/haskell/base", :haskell)

# Find common patterns
patterns = find_patterns([phronesis, rust, haskell])

# Rank implementations
rankings = rank_implementations.(patterns)

# Extract to aggregate-library
for ranking in rankings
    extract_module(ranking, "output/aggregate_library")
end
```
"""
module StdlibMerger

# Export main API
export parse_stdlib, find_patterns, rank_implementations, extract_module, strip_stdlib
export merge_stlibs  # High-level convenience function

# Export data types
export StdLib, Module, FunctionSignature, Param, SourceLocation
export Pattern, Cluster, Ranking, QualityCriteria, Criterion

# Include submodules
include("models.jl")
include("parser.jl")
include("matcher.jl")
include("ranker.jl")
include("extractor.jl")
include("stripper.jl")
include("reporter.jl")
include("orchestrator.jl")

"""
    merge_stlibs(stdlib_paths; output_dir, config_path)

High-level convenience function that runs the complete merge pipeline.

# Arguments
- `stdlib_paths`: Dictionary of language => path pairs
- `output_dir`: Directory to write output files
- `config_path`: Path to configuration YAML file

# Returns
- `MergeResult` struct containing patterns, rankings, and output paths

# Example

```julia
result = merge_stlibs(
    Dict(
        :phronesis => "/path/to/phronesis/stdlib",
        :rust => "/path/to/rust/std",
        :haskell => "/path/to/haskell/base"
    ),
    output_dir = "aggregate-library-auto",
    config_path = "config/merger.yaml"
)

println("Generated \$(length(result.patterns)) modules")
```
"""
function merge_stlibs(stdlib_paths::Dict{Symbol, String};
                     output_dir::String = "output",
                     config_path::String = "config/merger.yaml")
    Orchestrator.run_pipeline(stdlib_paths, output_dir, config_path)
end

# Convenience overload for vector of pairs
function merge_stlibs(stdlib_paths::Vector{Pair{String, String}};
                     output_dir::String = "output",
                     config_path::String = "config/merger.yaml")
    dict = Dict(Symbol(k) => v for (k, v) in stdlib_paths)
    merge_stlibs(dict; output_dir = output_dir, config_path = config_path)
end

end # module StdlibMerger
