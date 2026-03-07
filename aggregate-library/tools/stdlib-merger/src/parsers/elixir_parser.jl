# SPDX-License-Identifier: PMPL-1.0-or-later

"""
Elixir stdlib parser.

Parses Elixir source files to extract function signatures, docstrings, and metadata.
"""
module ElixirParser

export parse

"""
    parse(stdlib_path::String)::StdLib

Parse an Elixir stdlib directory.
"""
function parse(stdlib_path::String)::StdLib
    stdlib = StdLib(:elixir, stdlib_path)

    # Find all .ex files
    ex_files = find_elixir_files(stdlib_path)

    println("   Found $(length(ex_files)) Elixir source files")

    # Parse each file
    for file_path in ex_files
        try
            module_data = parse_file(file_path, stdlib_path)
            if module_data !== nothing
                stdlib.modules[module_data.name] = module_data
                append!(stdlib.functions, module_data.functions)
            end
        catch e
            @warn "Failed to parse $file_path: $e"
        end
    end

    return stdlib
end

"""
Find all .ex files in a directory recursively.
"""
function find_elixir_files(dir::String)::Vector{String}
    files = String[]

    for (root, dirs, filenames) in walkdir(dir)
        for filename in filenames
            if endswith(filename, ".ex")
                push!(files, joinpath(root, filename))
            end
        end
    end

    return files
end

"""
Parse a single Elixir file to extract module and function signatures.
"""
function parse_file(file_path::String, stdlib_path::String)::Union{Module, Nothing}
    content = read(file_path, String)
    lines = split(content, "\n")

    # Extract module name
    module_name = extract_module_name(lines)
    if module_name === nothing
        return nothing
    end

    # Extract module docstring
    module_docstring = extract_module_docstring(lines)

    # Extract functions
    functions = extract_functions(lines, file_path, module_name)

    # Create source location
    source_loc = SourceLocation(file_path, 1, 1)

    return Module(
        module_name,
        relpath(file_path, stdlib_path),
        functions,
        Module[],  # submodules
        module_docstring,
        source_loc
    )
end

"""
Extract module name from source lines.
"""
function extract_module_name(lines::Vector{SubString{String}})::Union{String, Nothing}
    for line in lines
        m = match(r"^\s*defmodule\s+([A-Za-z0-9_.]+)\s+do", line)
        if m !== nothing
            return m.captures[1]
        end
    end
    return nothing
end

"""
Extract module docstring.
"""
function extract_module_docstring(lines::Vector{SubString{String}})::String
    in_moduledoc = false
    docstring_lines = String[]

    for line in lines
        if occursin(r"@moduledoc\s+\"\"\"", line)
            in_moduledoc = true
            continue
        end

        if in_moduledoc
            if occursin(r"\"\"\"", line)
                break
            end
            push!(docstring_lines, String(line))
        end
    end

    return join(docstring_lines, "\n")
end

"""
Extract all function signatures from source lines.
"""
function extract_functions(lines::Vector{SubString{String}},
                          file_path::String,
                          module_name::String)::Vector{FunctionSignature}
    functions = FunctionSignature[]
    i = 1

    while i <= length(lines)
        line = lines[i]

        # Check for function definition
        if occursin(r"^\s*def\s+", line) || occursin(r"^\s*defp\s+", line)
            func = parse_function_definition(lines, i, file_path, module_name)
            if func !== nothing
                push!(functions, func)
            end
        end

        i += 1
    end

    return functions
end

"""
Parse a single function definition starting at line index.
"""
function parse_function_definition(lines::Vector{SubString{String}},
                                  start_idx::Int,
                                  file_path::String,
                                  module_name::String)::Union{FunctionSignature, Nothing}
    line = String(lines[start_idx])

    # Extract function name and parameters
    m = match(r"def(?:p)?\s+([a-z_][a-z0-9_?!]*)\s*\((.*?)\)", line)
    if m === nothing
        # Function with no parameters
        m = match(r"def(?:p)?\s+([a-z_][a-z0-9_?!]*)\s*,?\s*do:", line)
        if m === nothing
            return nothing
        end
        func_name = m.captures[1]
        params = Param[]
    else
        func_name = m.captures[1]
        params_str = m.captures[2]
        params = parse_parameters(params_str)
    end

    # Extract docstring (look backwards for @doc)
    docstring = extract_function_docstring(lines, start_idx)

    # Extract examples from docstring
    examples = extract_examples(docstring)

    # Extract type spec (look backwards for @spec)
    return_type = extract_return_type(lines, start_idx, func_name)

    # Create source location
    source_loc = SourceLocation(file_path, start_idx, 1)

    return FunctionSignature(
        func_name,
        module_name,
        params,
        return_type,
        docstring,
        examples,
        source_loc,
        Dict{String, Any}()
    )
end

"""
Parse function parameters from parameter string.
"""
function parse_parameters(params_str::String)::Vector{Param}
    params = Param[]

    if isempty(strip(params_str))
        return params
    end

    # Split by comma (simple split, doesn't handle nested structures)
    param_parts = split(params_str, ",")

    for part in param_parts
        part = strip(String(part))
        if isempty(part)
            continue
        end

        # Extract parameter name and type
        # Format: name or name \\ default or name :: type
        if occursin(r"\\", part)
            # Has default value
            m = match(r"([a-z_][a-z0-9_]*)\s*\\\s*(.+)", part)
            if m !== nothing
                param_name = m.captures[1]
                default_val = m.captures[2]
                push!(params, Param(param_name, Type("any"), default_val))
            end
        elseif occursin("::", part)
            # Has type annotation
            m = match(r"([a-z_][a-z0-9_]*)\s*::\s*(.+)", part)
            if m !== nothing
                param_name = m.captures[1]
                type_str = m.captures[2]
                push!(params, Param(param_name, parse_type(type_str), nothing))
            end
        else
            # Just parameter name
            param_name = strip(part)
            push!(params, Param(param_name, Type("any"), nothing))
        end
    end

    return params
end

"""
Parse type string to Type struct.
"""
function parse_type(type_str::String)::Type
    type_str = strip(type_str)

    # Handle generic types: Map.t(), List.t(), etc.
    if occursin(r"\(", type_str)
        return Type(replace(type_str, r"\(\)" => ""))
    end

    return Type(type_str)
end

"""
Extract function docstring by looking backwards from function definition.
"""
function extract_function_docstring(lines::Vector{SubString{String}}, func_idx::Int)::String
    docstring_lines = String[]
    in_doc = false

    # Look backwards from function definition
    for i in (func_idx-1):-1:max(1, func_idx-20)
        line = String(lines[i])

        if occursin(r"\"\"\"", line) && in_doc
            # End of docstring (found opening """)
            break
        end

        if occursin(r"\"\"\"", line) && !in_doc
            # Start of docstring (found closing """)
            in_doc = true
            continue
        end

        if in_doc
            pushfirst!(docstring_lines, line)
        end

        # Stop if we hit another function or @doc/@spec
        if occursin(r"^\s*def", line) || occursin(r"^\s*@(doc|spec)", line)
            break
        end
    end

    return join(docstring_lines, "\n")
end

"""
Extract examples from docstring.
"""
function extract_examples(docstring::String)::Vector{String}
    examples = String[]
    in_example = false
    example_lines = String[]

    for line in split(docstring, "\n")
        if occursin(r"##\s*Examples?", line)
            in_example = true
            continue
        end

        if in_example
            if occursin(r"iex>", line)
                push!(example_lines, strip(line))
            elseif !isempty(example_lines) && occursin(r"^\s*$", line)
                # End of example block
                push!(examples, join(example_lines, "\n"))
                example_lines = String[]
            end
        end
    end

    if !isempty(example_lines)
        push!(examples, join(example_lines, "\n"))
    end

    return examples
end

"""
Extract return type from @spec annotation.
"""
function extract_return_type(lines::Vector{SubString{String}},
                            func_idx::Int,
                            func_name::String)::Type
    # Look backwards for @spec
    for i in (func_idx-1):-1:max(1, func_idx-10)
        line = String(lines[i])

        if occursin("@spec", line) && occursin(func_name, line)
            # Extract return type from @spec
            m = match(r"::\s*(.+?)(?:\s+when|$)", line)
            if m !== nothing
                return_type_str = strip(m.captures[1])
                return parse_type(return_type_str)
            end
        end

        # Stop if we hit another function
        if occursin(r"^\s*def", line)
            break
        end
    end

    return Type("any")
end

end # module ElixirParser
