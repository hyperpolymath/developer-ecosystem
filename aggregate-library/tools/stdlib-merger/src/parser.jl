# SPDX-License-Identifier: PMPL-1.0-or-later

"""
Parser module for extracting function signatures from stdlib source files.
"""
module Parser

export parse_stdlib

include("models.jl")
include("parsers/elixir_parser.jl")
# include("parsers/rust_parser.jl")  # TODO
# include("parsers/haskell_parser.jl")  # TODO

"""
    parse_stdlib(path::String, lang::Symbol)::StdLib

Parse a stdlib directory and extract all function signatures.

# Arguments
- `path::String` - Path to stdlib directory
- `lang::Symbol` - Language (:elixir, :rust, :haskell)

# Returns
- `StdLib` - Parsed stdlib structure

# Examples
```julia
phronesis = parse_stdlib("/path/to/phronesis/stdlib", :elixir)
println("Found \$(length(phronesis.functions)) functions")
```
"""
function parse_stdlib(path::String, lang::Symbol)::StdLib
    if !isdir(path)
        error("Stdlib path does not exist: $path")
    end

    if lang == :elixir
        return ElixirParser.parse(path)
    elseif lang == :rust
        # return RustParser.parse(path)
        error("Rust parser not yet implemented")
    elseif lang == :haskell
        # return HaskellParser.parse(path)
        error("Haskell parser not yet implemented")
    else
        error("Unsupported language: $lang")
    end
end

end # module Parser
