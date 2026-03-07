# SPDX-License-Identifier: PMPL-1.0-or-later

"""
Stripper module for removing extracted functions from original stlibs.
"""
module Stripper

export strip_stdlib

include("models.jl")

"""
    strip_stdlib(stdlib::StdLib, patterns::Vector{Pattern}, output_dir::String, config::MergerConfig)::StrippedStdLib

Strip extracted patterns from a stdlib.

# Arguments
- `stdlib::StdLib` - Original stdlib
- `patterns::Vector{Pattern}` - Patterns that were extracted
- `output_dir::String` - Output directory for stripped stdlib
- `config::MergerConfig` - Configuration

# Returns
- `StrippedStdLib` - Information about stripped stdlib
"""
function strip_stdlib(stdlib::StdLib,
                     patterns::Vector{Pattern},
                     output_dir::String,
                     config::MergerConfig)::StrippedStdLib
    # Find functions to remove
    removed_functions = FunctionSignature[]

    for pattern in patterns
        if haskey(pattern.implementations, stdlib.language)
            impl = pattern.implementations[stdlib.language]
            push!(removed_functions, impl)
        end
    end

    # Generate import statements
    added_imports = String[]
    for pattern in patterns
        if haskey(pattern.implementations, stdlib.language)
            module_name = "AggregateLibrary." * titlecase(pattern.name)
            push!(added_imports, "alias $module_name")
        end
    end

    # Create output directory
    mkpath(output_dir)

    # Write migration guide
    migration_path = joinpath(output_dir, "MIGRATION.md")
    write_migration_guide(migration_path, stdlib, removed_functions, added_imports)

    return StrippedStdLib(
        stdlib,
        removed_functions,
        added_imports,
        output_dir
    )
end

"""
Write migration guide for stripped stdlib.
"""
function write_migration_guide(path::String,
                               stdlib::StdLib,
                               removed::Vector{FunctionSignature},
                               imports::Vector{String})
    content = """
    # Migration Guide: $(stdlib.language)

    ## Functions Removed

    The following functions have been extracted to aggregate-library:

    $(join(["- $(full_name(f))" for f in removed], "\n"))

    ## Required Imports

    Add these imports to use aggregate-library:

    ```elixir
    $(join(imports, "\n"))
    ```

    ## Example Migration

    Before:
    ```elixir
    # Using stdlib directly
    result = Stdlib.function(arg)
    ```

    After:
    ```elixir
    # Using aggregate-library
    alias AggregateLibrary.Module
    result = Module.function(arg)
    ```
    """

    write(path, content)
end

end # module Stripper
