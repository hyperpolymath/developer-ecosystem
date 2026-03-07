# SPDX-License-Identifier: PMPL-1.0-or-later

"""
Extractor module for generating aggregate-library modules from best implementations.
"""
module Extractor

export extract_module

include("models.jl")

"""
    extract_module(ranking::Ranking, output_dir::String, config::ExtractionConfig)::ExtractedModule

Extract a pattern to an aggregate-library module.

# Arguments
- `ranking::Ranking` - Ranking with best implementation chosen
- `output_dir::String` - Output directory for generated module
- `config::ExtractionConfig` - Extraction configuration

# Returns
- `ExtractedModule` - Information about extracted module
"""
function extract_module(ranking::Ranking,
                       output_dir::String,
                       config::ExtractionConfig)::ExtractedModule
    best_impl = ranking.best_implementation
    best_lang = ranking.best_language

    # Generate module code
    if best_lang == config.target_language
        # Direct copy (same language)
        code = generate_elixir_module(ranking, config)
        translation = nothing
    else
        # Translation needed (TODO: implement translators)
        @warn "Translation from $best_lang to $(config.target_language) not yet implemented, using placeholder"
        code = generate_placeholder_module(ranking, config)
        translation = Translation(
            best_lang,
            config.target_language,
            "",  # source_code
            code,  # target_code
            0.0,  # confidence
            ["Translation not yet implemented"]
        )
    end

    # Write module file
    module_path = joinpath(output_dir, "$(ranking.pattern.name).ex")
    write(module_path, code)

    return ExtractedModule(
        ranking.pattern,
        ranking,
        translation,
        module_path,
        code
    )
end

"""
Generate Elixir module code from ranking (for Elixir implementations).
"""
function generate_elixir_module(ranking::Ranking, config::ExtractionConfig)::String
    impl = ranking.best_implementation
    pattern = ranking.pattern

    # Build module name
    module_name = "AggregateLibrary." * titlecase(pattern.name)

    code = """
    # SPDX-License-Identifier: $(config.spdx_header)

    defmodule $module_name do
      @moduledoc \"\"\"
      $(pattern.name) operation.

      Best implementation: $(ranking.best_language)
      $(ranking.justification)

      $(impl.docstring)
      \"\"\"

      @doc \"\"\"
      $(impl.name)

      $(impl.docstring)
      \"\"\"
      @spec $(impl.name)($(join([p.name for p in impl.params], ", "))) :: $(impl.return_type.name)
      def $(impl.name)($(join([p.name for p in impl.params], ", "))) do
        # TODO: Implement based on best implementation
        raise "Not yet implemented"
      end
    end
    """

    return code
end

"""
Generate placeholder module (for translations).
"""
function generate_placeholder_module(ranking::Ranking, config::ExtractionConfig)::String
    pattern = ranking.pattern
    module_name = "AggregateLibrary." * titlecase(pattern.name)

    code = """
    # SPDX-License-Identifier: $(config.spdx_header)

    defmodule $module_name do
      @moduledoc \"\"\"
      $(pattern.name) operation.

      Best implementation: $(ranking.best_language)
      Status: Translation pending

      $(ranking.justification)
      \"\"\"

      # TODO: Implement translation from $(ranking.best_language)
    end
    """

    return code
end

end # module Extractor
