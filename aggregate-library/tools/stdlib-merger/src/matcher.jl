# SPDX-License-Identifier: PMPL-1.0-or-later

"""
Matcher module for identifying semantically similar functions across stlibs.
"""
module Matcher

using StringDistances

export find_patterns

include("models.jl")

"""
    find_patterns(stlibs::Vector{StdLib}, config::MergerConfig)::Vector{Pattern}

Find common patterns across multiple stlibs.

Uses multi-stage matching:
1. Name-based clustering (Levenshtein distance)
2. Semantic similarity (LLM-based) - TODO
3. Type-based validation

# Arguments
- `stlibs::Vector{StdLib}` - Parsed stlibs to analyze
- `config::MergerConfig` - Configuration including thresholds

# Returns
- `Vector{Pattern}` - Common patterns found across stlibs
"""
function find_patterns(stlibs::Vector{StdLib}, config::MatchingConfig)::Vector{Pattern}
    patterns = Pattern[]

    println("   Stage 1: Name-based clustering...")
    clusters = cluster_by_name(stlibs, config.name_similarity_threshold)
    println("      Found $(length(clusters)) potential clusters")

    println("   Stage 2: Semantic validation...")
    for cluster in clusters
        # Check if cluster has implementations from all stlibs
        if config.require_all_stlibs
            langs_in_cluster = Set(f.metadata["language"] for f in cluster.functions)
            if length(langs_in_cluster) < length(stlibs)
                continue  # Skip if not universal
            end
        end

        # Create pattern from cluster
        pattern = create_pattern_from_cluster(cluster, stlibs)
        if pattern !== nothing
            push!(patterns, pattern)
        end
    end

    println("      Validated $(length(patterns)) patterns")

    return patterns
end

"""
Cluster functions by name similarity using Levenshtein distance.
"""
function cluster_by_name(stlibs::Vector{StdLib}, threshold::Float64)::Vector{Cluster}
    # Collect all functions with metadata
    all_functions = FunctionSignature[]

    for stdlib in stlibs
        for func in stdlib.functions
            # Add language metadata
            func_copy = func
            func_copy.metadata["language"] = stdlib.language
            push!(all_functions, func_copy)
        end
    end

    # Build clusters
    clusters = Cluster[]
    used_indices = Set{Int}()

    for (i, func1) in enumerate(all_functions)
        if i in used_indices
            continue
        end

        # Start new cluster
        cluster_functions = [func1]
        push!(used_indices, i)

        # Find similar functions
        for (j, func2) in enumerate(all_functions)
            if j <= i || j in used_indices
                continue
            end

            # Compute name similarity
            similarity = compute_name_similarity(func1.name, func2.name)

            if similarity >= threshold
                push!(cluster_functions, func2)
                push!(used_indices, j)
            end
        end

        # Only create cluster if we have multiple functions
        if length(cluster_functions) > 1
            centroid = find_centroid_name(cluster_functions)
            avg_dist = compute_avg_distance(cluster_functions)
            push!(clusters, Cluster(cluster_functions, centroid, avg_dist))
        end
    end

    return clusters
end

"""
Compute name similarity using Levenshtein distance (normalized).
"""
function compute_name_similarity(name1::String, name2::String)::Float64
    # Normalize names (lowercase, remove underscores/hyphens)
    n1 = lowercase(replace(name1, r"[_-]" => ""))
    n2 = lowercase(replace(name2, r"[_-]" => ""))

    # Compute Levenshtein distance
    dist = Levenshtein()(n1, n2)
    max_len = max(length(n1), length(n2))

    if max_len == 0
        return 1.0
    end

    # Normalize to 0-1 (1 = identical, 0 = completely different)
    similarity = 1.0 - (dist / max_len)

    return similarity
end

"""
Find the centroid (most representative) name in a cluster.
"""
function find_centroid_name(functions::Vector{FunctionSignature})::String
    if isempty(functions)
        return ""
    end

    # Use the shortest, most common name as centroid
    names = [f.name for f in functions]
    name_counts = Dict{String, Int}()

    for name in names
        name_counts[name] = get(name_counts, name, 0) + 1
    end

    # Find most common name, breaking ties by shortest length
    centroid = argmax(name_counts)
    for (name, count) in name_counts
        if count > name_counts[centroid] ||
           (count == name_counts[centroid] && length(name) < length(centroid))
            centroid = name
        end
    end

    return centroid
end

"""
Compute average distance between all pairs in cluster.
"""
function compute_avg_distance(functions::Vector{FunctionSignature})::Float64
    if length(functions) < 2
        return 0.0
    end

    total_dist = 0.0
    count = 0

    for i in 1:length(functions)
        for j in (i+1):length(functions)
            dist = 1.0 - compute_name_similarity(functions[i].name, functions[j].name)
            total_dist += dist
            count += 1
        end
    end

    return count > 0 ? total_dist / count : 0.0
end

"""
Create a Pattern from a cluster of similar functions.
"""
function create_pattern_from_cluster(cluster::Cluster,
                                    stlibs::Vector{StdLib})::Union{Pattern, Nothing}
    # Group functions by language
    implementations = Dict{Symbol, FunctionSignature}()

    for func in cluster.functions
        lang = func.metadata["language"]
        if !haskey(implementations, lang)
            implementations[lang] = func
        else
            # If multiple functions from same language, choose the better one
            existing = implementations[lang]
            if length(func.docstring) > length(existing.docstring)
                implementations[lang] = func
            end
        end
    end

    # Create pattern ID and name
    pattern_id = string(hash(cluster.centroid_name))
    pattern_name = normalize_pattern_name(cluster.centroid_name)

    # Compute similarity score (inverse of average distance)
    similarity_score = 1.0 - cluster.avg_distance

    # Determine if universal (exists in all stlibs)
    is_universal = length(implementations) >= length(stlibs)

    # Categorize pattern
    category = categorize_pattern(pattern_name, implementations)

    pattern = Pattern(
        pattern_id,
        pattern_name,
        implementations,
        similarity_score,
        is_universal,
        category,
        Dict{String, Any}()
    )

    return pattern
end

"""
Normalize pattern name (remove language-specific prefixes/suffixes).
"""
function normalize_pattern_name(name::String)::String
    # Remove common language-specific parts
    normalized = lowercase(name)
    normalized = replace(normalized, r"^(std_|stdlib_)" => "")  # Remove std prefix
    normalized = replace(normalized, r"_(ex|rs|hs)$" => "")     # Remove language suffix

    return normalized
end

"""
Categorize pattern by name patterns.
"""
function categorize_pattern(name::String,
                           implementations::Dict{Symbol, FunctionSignature})::String
    name_lower = lowercase(name)

    # String operations
    if occursin(r"(split|join|trim|concat|substring|length|upper|lower)", name_lower)
        return "string"
    end

    # Collection operations
    if occursin(r"(map|filter|reduce|fold|find|sort|reverse|zip)", name_lower)
        return "collection"
    end

    # File I/O
    if occursin(r"(read|write|file|open|close)", name_lower)
        return "file_io"
    end

    # Time operations
    if occursin(r"(time|date|duration|now|timestamp)", name_lower)
        return "time"
    end

    # Result/Option operations
    if occursin(r"(result|option|maybe|either|ok|error)", name_lower)
        return "result"
    end

    # Stream/Iterator operations
    if occursin(r"(stream|iter|lazy|take|drop)", name_lower)
        return "stream"
    end

    return "other"
end

end # module Matcher
