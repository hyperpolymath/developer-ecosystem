defmodule ShellState.Generator do
  @moduledoc """
  Bash configuration generator for ShellState.
  
  This module generates bash configuration files from the canonical manifest.
  The generated files are treated as derived artifacts and never as authority.
  """
  
  @output_dir "~/.config/shellstate/generated"

  @spec generate_bash(ShellState.Manifest.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_bash(%ShellState.Manifest{} = manifest) do
    try do
      content = """
# ShellState Generated Configuration - DO NOT EDIT
# Version: #{manifest.version}
# Profile: #{manifest.profile}
# Generated: #{DateTime.utc_now() |> DateTime.to_iso8601()}

#{generate_paths(manifest)}
#{generate_env(manifest)}
"""
      
      File.mkdir_p!(@output_dir)
      output_path = Path.join([@output_dir, "bashrc"])
      File.write!(output_path, content)
      {:ok, content}
    rescue
      error -> {:error, "Generation failed: #{inspect(error)}"}
    end
  end

  defp generate_paths(manifest) do
    if manifest.generation.render_paths do
      Enum.map(manifest.paths.entries, fn entry ->
        case entry.position do
          "prepend" -> "export PATH=\"#{entry.value}:$PATH\""
          "append" -> "export PATH=\"$PATH:#{entry.value}\""
        end
      end)
      |> Enum.join("\n")
    else
      ""
    end
  end

  defp generate_env(manifest) do
    if manifest.generation.render_env do
      manifest.env
      |> Enum.map(fn {name, config} ->
        value = config.value
        if config.export, do: "export #{name}=\"#{value}\"", else: "#{name}=\"#{value}\""
      end)
      |> Enum.join("\n")
    else
      ""
    end
  end
end