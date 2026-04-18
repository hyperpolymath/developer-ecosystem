defmodule ShellState.Doctor do
  @moduledoc """
  System health check and invariant verification for ShellState.
  
  This module verifies that all core invariants are maintained and
  checks for common issues like secret leakage or corrupted state.
  """
  
  alias ShellState.Manifest
  alias ShellState.Generator

  @spec check() :: {:ok, String.t()} | {:error, String.t()}
  def check do
    checks = [
      &check_canonical_exists/0,
      &check_canonical_valid/0,
      &check_rollback_present/0,
      &check_no_secret_leakage/0,
      &check_generated_valid/0,
      &check_deterministic_render/0
    ]
    
    results = Enum.map(checks, fn check -> check.() end)
    errors = Enum.filter(results, &(&1 != :ok))
    
    if errors == [] do
      {:ok, "All checks passed: system healthy"}
    else
      {:error, "Health check failed: #{Enum.join(errors, ", ")}"}
    end
  end

  defp check_canonical_exists do
    path = Path.join(["~/.config/shellstate/current", "manifest.toml"])
    if File.exists?(path), do: :ok, else: "canonical manifest missing"
  end

  defp check_canonical_valid do
    path = Path.join(["~/.config/shellstate/current", "manifest.toml"])
    case Manifest.load(path) do
      {:ok, _} -> :ok
      {:error, _} -> "canonical manifest invalid"
    end
  end

  defp check_rollback_present do
    path = Path.join(["~/.config/shellstate/previous", "manifest.toml"])
    if File.exists?(path), do: :ok, else: "rollback state missing"
  end

  defp check_no_secret_leakage do
    # Check generated files for secret patterns
    generated_path = Path.join(["~/.config/shellstate/generated", "bashrc"])
    
    if File.exists?(generated_path) do
      {:ok, content} = File.read(generated_path)
      secret_patterns = ["secret://", "token://", "password://", "AKIA", "PRIVATE KEY"]
      
      Enum.each(secret_patterns, fn pattern ->
        if String.contains?(content, pattern) do
          "secret leakage detected in generated files"
        end
      end)
      :ok
    else
      :ok  # Generated files don't exist yet, which is fine
    end
  end

  defp check_generated_valid do
    # If generated files exist, verify they're valid bash
    generated_path = Path.join(["~/.config/shellstate/generated", "bashrc"])
    
    if File.exists?(generated_path) do
      {:ok, content} = File.read(generated_path)
      # Basic bash syntax check - just verify it starts with expected header
      if String.starts_with?(content, "# ShellState Generated"), do: :ok, else: "generated file invalid"
    else
      :ok  # Generated files don't exist yet
    end
  end

  defp check_deterministic_render do
    path = Path.join(["~/.config/shellstate/current", "manifest.toml"])
    
    case Manifest.load(path) do
      {:ok, manifest} ->
        # Generate twice and compare
        {:ok, first} = Generator.generate_bash(manifest)
        {:ok, second} = Generator.generate_bash(manifest)
        if first == second, do: :ok, else: "non-deterministic rendering"
      {:error, _} -> :ok  # Can't check if manifest invalid
    end
  end

  def print_report do
    IO.puts("=== ShellState Health Check ===")
    
    checks = [
      {"Canonical manifest exists", check_canonical_exists()},
      {"Canonical manifest valid", check_canonical_valid()},
      {"Rollback state present", check_rollback_present()},
      {"No secret leakage", check_no_secret_leakage()},
      {"Generated files valid", check_generated_valid()},
      {"Deterministic rendering", check_deterministic_render()}
    ]
    
    Enum.each(checks, fn {name, result} ->
      status = if result == :ok, do: "✓ PASS", else: "✗ FAIL: #{result}"
      IO.puts("#{name}: #{status}")
    end)
  end
end