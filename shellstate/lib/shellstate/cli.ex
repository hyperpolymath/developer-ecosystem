defmodule ShellState.CLI do
  @moduledoc """
  Command-line interface for ShellState.
  
  This module provides the main entry point for the shellstate command.
  """
  
  def main(args) do
    case parse_args(args) do
      [:init] -> init()
      [:load] -> load_manifest()
      [:commit] -> commit_changes()
      [:generate] -> generate_outputs()
      [:rollback] -> perform_rollback()
      [:doctor] -> doctor()
      _ -> print_usage()
    end
  end

  defp parse_args(args) do
    args
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp doctor do
    ShellState.Doctor.print_report()
  end

  defp init do
    ShellState.Init.initialize()
    :ok
  end

  defp load_manifest do
    path = Path.join(["~/.config/shellstate/current", "manifest.toml"])
    case ShellState.Manifest.load(path) do
      {:ok, manifest} ->
        IO.puts("Loaded manifest version #{manifest.version}")
        {:ok, ShellState.State.new(manifest)}
      {:error, reason} ->
        IO.puts("Error loading manifest: #{reason}")
        try_rollback()
    end
  end

  defp try_rollback do
    path = Path.join(["~/.config/shellstate/previous", "manifest.toml"])
    case ShellState.Manifest.load(path) do
      {:ok, manifest} ->
        IO.puts("Recovered from rollback version #{manifest.version}")
        {:ok, ShellState.State.new(manifest)}
      {:error, _} ->
        IO.puts("No valid manifest found - initialize with `shellstate init`")
        {:error, :no_valid_manifest}
    end
  end

  defp commit_changes do
    case load_manifest() do
      {:ok, state} ->
        case ShellState.Commit.commit(state) do
          {:ok, _} -> IO.puts("Commit successful")
          {:error, reason} -> IO.puts("Commit failed: #{reason}")
        end
      {:error, reason} -> IO.puts("Cannot commit: #{reason}")
    end
  end

  defp generate_outputs do
    case load_manifest() do
      {:ok, state} ->
        case ShellState.Generator.generate_bash(state.manifest) do
          {:ok, path} ->
            IO.puts("Generated bash configuration at #{path}")
            IO.puts("\nTo use it, add this to your ~/.bashrc or ~/.bash_profile:")
            IO.puts("if [ -f #{path} ]; then")
            IO.puts("  source #{path}")
            IO.puts("fi")
          {:error, reason} -> IO.puts("Generation failed: #{reason}")
        end
      {:error, reason} -> IO.puts("Cannot generate: #{reason}")
    end
  end

  defp perform_rollback do
    IO.puts("Rollback not yet implemented")
  end

  defp print_usage do
    IO.puts("Usage: shellstate <command>")
    IO.puts("")
    IO.puts("Commands:")
    IO.puts("  init          Initialize ShellState configuration")
    IO.puts("  load          Load the current manifest")
    IO.puts("  commit        Commit changes to canonical state")
    IO.puts("  generate      Generate bash configuration")
    IO.puts("  rollback      Rollback to previous version")
    IO.puts("  doctor        Check system health and invariants")
    IO.puts("  help          Show this help message")
  end
end