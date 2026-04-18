defmodule ShellState.Commit do
  @moduledoc """
  Atomic commit operations for ShellState.
  
  This module implements the atomic commit protocol that replaces the
  current canonical state and preserves exactly one previous rollback version.
  """
  
  @current_dir "~/.config/shellstate/current"
  @previous_dir "~/.config/shellstate/previous"
  @tmp_dir "~/.config/shellstate/tmp"

  @spec commit(ShellState.State.t()) :: {:ok, ShellState.State.t()} | {:error, String.t()}
  def commit(state) do
    # Validate the state before commit
    with {:ok, _} <- validate_candidate(state),
         {:ok, toml} <- ShellState.Manifest.to_toml(state.manifest),
         {:ok, temp_path} <- write_temp(toml),
         :ok <- preserve_previous(),
         :ok <- atomic_replace(temp_path),
         :ok <- log_commit(state) do
      {:ok, state}
    else
      error -> {:error, "Commit failed: #{inspect(error)}"}
    end
  end

  @spec validate_candidate(ShellState.State.t()) :: {:ok, ShellState.State.t()} | {:error, String.t()}
  defp validate_candidate(state) do
    # Re-validate the manifest
    case ShellState.Manifest.load("test/tmp/validate.toml") do
      {:ok, _} ->
        File.write!("test/tmp/validate.toml", ShellState.Manifest.to_toml(state.manifest))
        :ok
      {:error, error} -> {:error, "Validation failed: #{error}"}
    end
  end

  @spec write_temp(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  defp write_temp(content) do
    File.mkdir_p!(@tmp_dir)
    temp_file = Path.join([@tmp_dir, "manifest-#{System.unique_integer()}.toml"])
    File.write!(temp_file, content)
    {:ok, temp_file}
  end

  @spec preserve_previous() :: :ok | {:error, String.t()}
  defp preserve_previous do
    current = Path.join([@current_dir, "manifest.toml"])
    previous = Path.join([@previous_dir, "manifest.toml"])
    if File.exists?(current) do
      File.mkdir_p!(@previous_dir)
      File.rename!(current, previous)
    end
    :ok
  end

  @spec atomic_replace(String.t()) :: :ok | {:error, String.t()}
  defp atomic_replace(temp_path) do
    target = Path.join([@current_dir, "manifest.toml"])
    File.rename!(temp_path, target)
    :ok
  end

  @spec log_commit(ShellState.State.t()) :: :ok | {:error, String.t()}
  defp log_commit(%ShellState.State{manifest: %ShellState.Manifest{version: version}}) do
    ShellState.Logger.log_commit(version)
  end
end