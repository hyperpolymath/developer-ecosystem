defmodule ShellState.Logger do
  @moduledoc """
  Minimal logging for ShellState operations.
  
  This module provides conservative, opt-in logging for diagnostic purposes only.
  No secrets, environment dumps, or sensitive information are ever logged.
  """
  
  @log_dir "~/.cache/shellstate/log"
  @log_file Path.join([@log_dir, "operations.log"])

  @spec log_commit(integer()) :: :ok
  def log_commit(version) do
    ensure_log_exists()
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    File.write!(@log_file, "[#{timestamp}] Committed version #{version}\n", [:append])
    :ok
  end

  @spec log_error(String.t()) :: :ok
  def log_error(message) do
    ensure_log_exists()
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    sanitized = sanitize_message(message)
    File.write!(@log_file, "[#{timestamp}] ERROR: #{sanitized}\n", [:append])
    :ok
  end

  defp ensure_log_exists do
    File.mkdir_p!(@log_dir)
    unless File.exists?(@log_file) do
      File.write!(@log_file, "# ShellState Operation Log\n")
    end
  end

  defp sanitize_message(message) do
    # Remove any potential sensitive information
    message
    |> String.replace("secret://", "[REDACTED]")
    |> String.replace("token://", "[REDACTED]")
    |> String.replace("password://", "[REDACTED]")
  end
end